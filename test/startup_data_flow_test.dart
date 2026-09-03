import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:progression_lab/brand.dart';
import 'package:progression_lab/first_launch_data_flow.dart';
import 'package:progression_lab/store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const storage = MethodChannel('iron_cadence/storage');
  const portability = MethodChannel('progression_lab/data_portability');

  Future<void> pumpFlow(WidgetTester tester, AppStore store) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ProgressionBrand.theme(),
        home: Builder(
          builder: (context) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              FirstLaunchDataFlow.present(context, store);
            });
            return const Scaffold(body: SizedBox.expand());
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'fresh install requires an explicit import or fresh-start choice',
    (tester) async {
      var writes = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(storage, (call) async {
            switch (call.method) {
              case 'read':
                return null;
              case 'write':
                writes++;
                return null;
              case 'quarantine':
                return null;
            }
            return null;
          });
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(portability, (call) async {
            switch (call.method) {
              case 'listAutomaticBackups':
                return <Object?>[];
              case 'writeAutomaticBackup':
                return '/test/backup.plab';
            }
            return null;
          });
      addTearDown(() async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(storage, null);
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(portability, null);
      });

      final store = AppStore();
      await store.load();
      await pumpFlow(tester, store);

      expect(find.text('Bring your workout history?'), findsOneWidget);
      expect(find.text('IMPORT HISTORY'), findsOneWidget);
      expect(find.text('START FRESH'), findsOneWidget);

      await tester.tap(find.text('START FRESH'));
      await tester.pumpAndSettle();

      expect(store.primaryStateLoaded, isTrue);
      expect(store.dataOnboardingVersionSeen, FirstLaunchDataFlow.version);
      expect(writes, greaterThanOrEqualTo(2));
    },
  );

  testWidgets('existing device state is kept and import remains optional', (
    tester,
  ) async {
    final existing = AppStore().exportState()
      ..['dataOnboardingVersionSeen'] = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storage, (call) async {
          if (call.method == 'read') return jsonEncode(existing);
          return null;
        });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(portability, (call) async {
          if (call.method == 'listAutomaticBackups') return <Object?>[];
          if (call.method == 'writeAutomaticBackup') {
            return '/test/upgrade.plab';
          }
          return null;
        });
    addTearDown(() async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(storage, null);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(portability, null);
    });

    final store = AppStore();
    await store.load();
    await pumpFlow(tester, store);

    expect(store.primaryStateLoaded, isTrue);
    expect(find.text('Your saved data is ready'), findsOneWidget);
    expect(find.text('NOT NOW'), findsOneWidget);

    await tester.tap(find.text('NOT NOW'));
    await tester.pumpAndSettle();
    expect(store.dataOnboardingVersionSeen, FirstLaunchDataFlow.version);
  });
}
