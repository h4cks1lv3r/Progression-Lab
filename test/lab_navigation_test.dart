import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:progression_lab/brand.dart';
import 'package:progression_lab/lab_screen.dart';
import 'package:progression_lab/progress_hub.dart';
import 'package:progression_lab/store.dart';

void main() {
  testWidgets(
    'direct Lab page opens insights and habit comparisons on a phone',
    (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: ProgressionBrand.theme(),
          home: LabHub(store: AppStore()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('The Lab'), findsOneWidget);
      await tester.tap(find.text('Training insights'));
      await tester.pumpAndSettle();
      expect(find.byType(LabScreen), findsOneWidget);
      expect(find.text('Explain with AI'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Habits & performance'));
      await tester.pumpAndSettle();
      expect(find.byType(InputsPerformanceScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
