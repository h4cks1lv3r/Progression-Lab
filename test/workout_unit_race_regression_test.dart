import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:progression_lab/curated_programs.dart';
import 'package:progression_lab/curated_training.dart';
import 'package:progression_lab/store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const storage = MethodChannel('iron_cadence/storage');
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storage, null),
  );

  test(
    'a unit change waits for a pending Iconic log failure and rollback',
    () async {
      final store = AppStore()..automaticBackupsEnabled = false;
      addTearDown(store.dispose);
      final id = CuratedPrograms.all.first.id;
      final draft = CuratedWorkoutDraft(
        programId: id,
        sessionId: 'pending-unit-review',
        week: 1,
        dayIndex: 0,
        run: 1,
        startedAt: DateTime(2026, 9, 30),
        inputs: {'weight': '100', 'reps': '8'},
        day: const CuratedDay(
          title: 'Upper',
          movements: [
            CuratedMovement(
              name: 'Bench',
              metric: CuratedMetric.loadedReps,
              targets: [CuratedSetTarget(reps: '8')],
            ),
          ],
        ),
      );
      store.curatedTraining = CuratedTrainingState(drafts: {id: draft});
      final entered = Completer<void>();
      final release = Completer<void>();
      var writes = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(storage, (call) async {
            if (call.method == 'write' && writes++ == 0) {
              entered.complete();
              await release.future;
              throw PlatformException(code: 'storage_failed');
            }
            return null;
          });
      final log = store.logCuratedSet(
        programId: id,
        sessionId: draft.sessionId,
        stepIndex: 0,
        weight: 100,
        reps: 8,
      );
      final failure = expectLater(log, throwsA(isA<PlatformException>()));
      await entered.future;
      final change = store.setUnit('kg');
      await Future<void>.delayed(Duration.zero);
      final unitWhileWritePending = store.unit;
      release.complete();
      await failure;
      await change;
      expect(unitWhileWritePending, 'lb');
      expect(store.unit, 'kg');
      expect(store.logs, isEmpty);
      expect(
        double.parse(store.curatedDraftFor(id)!.inputs['weight']!),
        closeTo(45.36, .001),
      );
      expect(store.curatedDraftFor(id)!.nextStepIndex, 0);
    },
  );
}
