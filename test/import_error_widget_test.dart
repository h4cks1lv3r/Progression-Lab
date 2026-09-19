import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:progression_lab/brand.dart';
import 'package:progression_lab/data_management_screen.dart';
import 'package:progression_lab/store.dart';

void main() {
  testWidgets(
    'unsupported import shows its message without exception fragments',
    (tester) async {
      const channel = MethodChannel('progression_lab/data_portability');
      var pickedFiles = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'listAutomaticBackups') return <Object?>[];
            if (call.method == 'pickFile') {
              pickedFiles++;
              return {
                'name': 'workouts.unsupported',
                'mimeType': 'application/octet-stream',
                'bytes': Uint8List.fromList([1, 2, 3]),
              };
            }
            return null;
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: ProgressionBrand.theme(),
          home: DataManagementScreen(store: AppStore()),
        ),
      );
      await tester.pumpAndSettle();
      final import = find.text('Restore or import a file');
      await tester.scrollUntilVisible(import.hitTestable(), 250);
      await tester.pumpAndSettle();
      await tester.tap(import);
      await tester.pumpAndSettle();

      expect(pickedFiles, 1);
      final snack = tester.widget<SnackBar>(find.byType(SnackBar));
      final message = (snack.content as Text).data!;
      expect(message, startsWith('Choose a .plab backup'));
      expect(message, contains('.fitnotes'));
      expect(message, isNot(contains('FormatChoose')));
      expect(message, isNot(contains('Exception')));
      expect(tester.takeException(), isNull);
    },
  );
}
