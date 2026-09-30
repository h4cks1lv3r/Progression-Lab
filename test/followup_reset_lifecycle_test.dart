import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:progression_lab/contextual_guides.dart';
import 'package:progression_lab/data_management_screen.dart';
import 'package:progression_lab/main.dart';
import 'package:progression_lab/share_options.dart';
import 'package:progression_lab/store.dart';

void main() {
  const storage = MethodChannel('iron_cadence/storage');
  const cloud = MethodChannel('progression_lab/cloud_sync');
  const guidesChannel = MethodChannel('progression_lab/guide_state');
  String? state;
  var needsRetry = false;
  var nativeReads = 0;
  var cloudStatusReads = 0;

  setUp(() {
    needsRetry = false;
    nativeReads = 0;
    cloudStatusReads = 0;
    final seed = AppStore()
      ..onboardingVersionSeen = 2
      ..dataOnboardingVersionSeen = 1
      ..automaticBackupsEnabled = false
      ..integrationState = {
        'contextualGuides': {'tipsEnabled': false},
      };
    state = jsonEncode(seed.exportState());
    seed.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storage, (call) async {
          switch (call.method) {
            case 'deletionStatus':
              return {'needsRetry': needsRetry};
            case 'read':
              nativeReads++;
              return state;
            case 'write':
              state = call.arguments as String;
              return null;
            case 'deleteAllLocalData':
              state = null;
              needsRetry = false;
              return true;
            default:
              return null;
          }
        });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(cloud, (call) async {
          if (call.method == 'status') {
            cloudStatusReads++;
            return {'configured': false};
          }
          return null;
        });
  });
  tearDown(() {
    for (final channel in [storage, cloud, guidesChannel]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    }
    AdvancedWorkoutShareCardGenerator.currentPreferences =
        const WorkoutSharePreferences();
  });

  testWidgets(
    'reset removes old routes, replaces store and clears cached preferences',
    (tester) async {
      await tester.pumpWidget(const ProgressionLabApp());
      await tester.pumpAndSettle();
      final oldStore = tester.widget<Shell>(find.byType(Shell)).store;
      AdvancedWorkoutShareCardGenerator.currentPreferences =
          const WorkoutSharePreferences(
            template: WorkoutShareTemplate.sessionRecap,
            aspect: WorkoutShareAspect.square,
          );
      Navigator.of(tester.element(find.byType(Shell))).push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('Old settings route')),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Old settings route'), findsOneWidget);
      await oldStore.deleteAllLocalData();
      await tester.pumpAndSettle();
      expect(find.text('Old settings route'), findsNothing);
      final newStore = tester.widget<Shell>(find.byType(Shell)).store;
      expect(identical(oldStore, newStore), isFalse);
      expect(newStore.logs, isEmpty);
      expect(newStore.workoutHistory, isEmpty);
      expect(newStore.integrationState['externalWorkouts'], isNull);
      expect(
        AdvancedWorkoutShareCardGenerator.currentPreferences.template,
        WorkoutShareTemplate.cleanPerformance,
      );
      expect(
        AdvancedWorkoutShareCardGenerator.currentPreferences.aspect,
        WorkoutShareAspect.story,
      );
      await expectLater(oldStore.save(), throwsA(isA<StateError>()));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'startup cleanup gate reads no old data and starts no cloud service',
    (tester) async {
      needsRetry = true;
      await tester.pumpWidget(const ProgressionLabApp());
      await tester.pumpAndSettle();
      expect(nativeReads, 0);
      expect(cloudStatusReads, 0);
      expect(find.byType(Shell), findsNothing);
      expect(find.byType(DataManagementScreen), findsOneWidget);
      expect(
        tester
            .widget<IconButton>(
              find.byWidgetPredicate(
                (widget) =>
                    widget is IconButton && widget.tooltip == 'Cloud backup',
              ),
            )
            .onPressed,
        isNull,
      );
      final bodyTile = find.ancestor(
        of: find.text('Photos, measurements & backup'),
        matching: find.byType(ListTile),
      );
      expect(tester.widget<ListTile>(bodyTile).onTap, isNull);
      expect(
        find.textContaining('Try Delete all data again before using the app'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'incomplete deletion removes retained routes and exposes recovery only',
    (tester) async {
      await tester.pumpWidget(const ProgressionLabApp());
      await tester.pumpAndSettle();
      final oldStore = tester.widget<Shell>(find.byType(Shell)).store;
      Navigator.of(tester.element(find.byType(Shell))).push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('Private old route')),
        ),
      );
      await tester.pumpAndSettle();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(storage, (call) async {
            if (call.method == 'deleteAllLocalData') {
              needsRetry = true;
              throw PlatformException(code: 'local_data_delete_incomplete');
            }
            return null;
          });
      await expectLater(
        oldStore.deleteAllLocalData(),
        throwsA(isA<PlatformException>()),
      );
      await tester.pumpAndSettle();
      expect(find.text('Private old route'), findsNothing);
      expect(find.byType(Shell), findsNothing);
      expect(find.byType(DataManagementScreen), findsOneWidget);
      expect(
        tester
            .widget<IconButton>(
              find.byWidgetPredicate(
                (widget) =>
                    widget is IconButton && widget.tooltip == 'Cloud backup',
              ),
            )
            .onPressed,
        isNull,
      );
      final bodyTile = find.ancestor(
        of: find.text('Photos, measurements & backup'),
        matching: find.byType(ListTile),
      );
      expect(tester.widget<ListTile>(bodyTile).onTap, isNull);
      await expectLater(oldStore.save(), throwsA(isA<StateError>()));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  test(
    'guide mirror cannot recreate old settings after a concurrent reset',
    () async {
      final store = AppStore()..automaticBackupsEnabled = false;
      final writeStarted = Completer<void>();
      final releaseWrite = Completer<void>();
      var mirrorWrites = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(storage, (call) async {
            if (call.method == 'write') {
              writeStarted.complete();
              await releaseWrite.future;
            }
            return call.method == 'deleteAllLocalData' ? true : null;
          });
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(guidesChannel, (call) async {
            if (call.method == 'write') mirrorWrites++;
            return null;
          });
      final guides = ContextualGuideState(store: store);
      final saving = guides.setTipsEnabled(false);
      await writeStarted.future;
      final deleting = store.deleteAllLocalData();
      releaseWrite.complete();
      await saving;
      await deleting;
      expect(mirrorWrites, 0);
      expect(store.deletedAllLocalData, isTrue);
      guides.dispose();
      store.dispose();
    },
  );
}
