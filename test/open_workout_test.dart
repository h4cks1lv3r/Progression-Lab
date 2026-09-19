import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:progression_lab/comprehensive_export.dart';
import 'package:progression_lab/curated_training.dart';
import 'package:progression_lab/data_portability_core.dart';
import 'package:progression_lab/exercise_models.dart';
import 'package:progression_lab/open_workout.dart';
import 'package:progression_lab/store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('iron_cadence/storage');
  String? saved;
  var failWrites = false;
  setUp(() {
    saved = null;
    failWrites = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'read') return saved;
          if (call.method == 'write') {
            if (failWrites) throw PlatformException(code: 'write_failed');
            saved = call.arguments as String;
          }
          return null;
        });
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );
  AppStore newStore() => AppStore()..automaticBackupsEnabled = false;

  Future<void> log(
    AppStore store, {
    double? weight,
    int? reps = 10,
    int? seconds = 30,
    double? meters = 100,
    double? calories = 20,
  }) {
    final draft = store.openWorkoutDraft!;
    return store.logOpenWorkoutSet(
      sessionId: draft.sessionId,
      exerciseIndex: draft.selectedIndex,
      setSequence: draft.nextSetSequence,
      weight: weight,
      reps: reps,
      seconds: seconds,
      meters: meters,
      calories: calories,
    );
  }

  test(
    'open sessions resume, avoid duplicate sets and finish independently with backup and exports',
    () async {
      final store = newStore()
        ..week = 20
        ..workoutIndex = 2
        ..athleticWeek = 7
        ..athleticSessionIndex = 1
        ..curatedTraining = CuratedTrainingState(
          progress: {
            'hunnam_arthur': const CuratedProgress(completedSessions: 4),
          },
        );
      final draft = await store.beginOpenWorkout();
      expect((await store.beginOpenWorkout()).sessionId, draft.sessionId);
      await store.addOpenWorkoutExercise(
        sessionId: draft.sessionId,
        exerciseId: 'dip',
      );
      await store.saveOpenWorkoutInputs(
        sessionId: draft.sessionId,
        exerciseIndex: 0,
        setSequence: 0,
        inputs: {'reps': '10', 'notes': 'First set'},
      );
      await Future.wait([log(store), log(store)]);
      expect(store.logs, hasLength(1));
      expect(store.logs.single.weight, 0);
      expect(
        store.logs.single.resolvedTrackingType,
        ExerciseTrackingType.bodyweightReps,
      );
      final reloaded = newStore();
      await reloaded.load();
      expect(reloaded.openWorkoutDraft!.selectedExercise!.name, 'Dip');
      expect(reloaded.openWorkoutDraft!.inputs['reps'], '10');
      expect(reloaded.logs.single.reps, 10);
      await reloaded.addOpenWorkoutExercise(
        sessionId: draft.sessionId,
        exerciseId: 'weighted_dip',
      );
      await log(reloaded); // No added weight is a valid bodyweight set.
      await reloaded.finishOpenWorkout(draft.sessionId);
      await reloaded.finishOpenWorkout(draft.sessionId);
      expect(reloaded.openWorkoutDraft, isNull);
      expect(reloaded.openWorkoutHistory, hasLength(1));
      expect(
        [
          reloaded.week,
          reloaded.workoutIndex,
          reloaded.athleticWeek,
          reloaded.athleticSessionIndex,
        ],
        [20, 2, 7, 1],
      );
      expect(reloaded.curatedProgressFor('hunnam_arthur').completedSessions, 4);
      expect(reloaded.workoutHistory, isEmpty);
      expect(reloaded.athleticHistory, isEmpty);

      final state = reloaded.exportState();
      final backup = ProgressionBackupCodec.decode(
        ProgressionBackupCodec.encode(state),
      );
      expect(backup.state['openWorkout'], state['openWorkout']);
      expect(backup.files.containsKey('open_workout.json'), isTrue);
      final files = ComprehensivePortableExport.portableFiles(state);
      final workouts = utf8.decode(files['workouts.csv']!);
      final sets = utf8.decode(files['sets.csv']!);
      expect(workouts, contains('progression_lab_open'));
      expect(workouts, contains(draft.sessionId));
      expect(sets, contains('Weighted Dip,1,1,normal,0.0,lb,10'));
      expect(
        utf8.decode(files['open_workouts.csv']!),
        contains(draft.sessionId),
      );
    },
  );

  test(
    'every exercise tracking type stores only its actual metrics and validates required values',
    () async {
      for (final type in ExerciseTrackingType.values) {
        final store = newStore();
        final draft = OpenWorkoutDraft(
          sessionId: 'metric-${type.name}',
          startedAt: DateTime.now(),
          exercises: [
            OpenWorkoutExercise(
              id: type.name,
              name: type.name,
              trackingType: type,
            ),
          ],
        );
        store.openWorkout = OpenWorkoutState(draft: draft);
        await expectLater(
          log(store, weight: -1, reps: 0, seconds: 0, meters: 0, calories: 0),
          throwsArgumentError,
          reason: type.name,
        );
        expect(store.logs, isEmpty);
        await log(store, weight: 25);
        final set = store.logs.single;
        expect(set.resolvedTrackingType, type);
        expect(set.weight, type.usesWeight ? 25 : 0);
        expect(set.reps, type.usesReps ? 10 : 0);
        expect(set.durationSeconds, type.usesDuration ? 30 : null);
        expect(set.distance, type.usesDistance ? 100 : null);
        expect(set.calories, type.usesCalories ? 20 : null);
        if (type.usesWeight) {
          await expectLater(
            log(store, weight: double.nan),
            throwsArgumentError,
          );
        }
      }
    },
  );

  test(
    'failed saves roll back start, logging, edits, deletion and finish',
    () async {
      final store = newStore();
      failWrites = true;
      await expectLater(
        store.beginOpenWorkout(),
        throwsA(isA<PlatformException>()),
      );
      expect(store.openWorkoutDraft, isNull);
      failWrites = false;
      final draft = await store.beginOpenWorkout();
      await store.addOpenWorkoutExercise(
        sessionId: draft.sessionId,
        exerciseId: 'dip',
      );
      await expectLater(
        store.finishOpenWorkout(draft.sessionId),
        throwsStateError,
      );
      failWrites = true;
      await expectLater(log(store), throwsA(isA<PlatformException>()));
      expect(store.logs, isEmpty);
      expect(store.openWorkoutDraft!.nextSetSequence, 0);
      failWrites = false;
      await log(store);
      final set = store.logs.single;
      failWrites = true;
      await expectLater(
        store.updateSet(set, weight: 0, reps: 12, notes: 'Edit'),
        throwsA(isA<PlatformException>()),
      );
      expect(store.logs.single, set);
      await expectLater(
        store.removeSet(set),
        throwsA(isA<PlatformException>()),
      );
      expect(store.logs.single, set);
      await expectLater(
        store.finishOpenWorkout(draft.sessionId),
        throwsA(isA<PlatformException>()),
      );
      expect(store.openWorkoutDraft, isNotNull);
      expect(store.openWorkoutHistory, isEmpty);
      failWrites = false;
      await store.removeSet(set);
      await log(store, reps: 8);
      expect(store.logs.single.sourceId, '${draft.sessionId}:set:1');
      await store.finishOpenWorkout(draft.sessionId);
      await store.removeSet(store.logs.single);
      expect(store.logs, isEmpty);
      final csv = utf8.decode(
        ComprehensivePortableExport.portableFiles(
          store.exportState(),
        )['open_workouts.csv']!,
      );
      expect(csv, contains(',0'));
    },
  );

  test(
    'switching exercises and re-adding the selection preserve each draft through reload and units',
    () async {
      final store = newStore();
      final draft = await store.beginOpenWorkout();
      await store.addOpenWorkoutExercise(
        sessionId: draft.sessionId,
        exerciseId: 'weighted_dip',
      );
      const first = {'weight': '100', 'reps': '8', 'notes': 'First exercise'};
      const second = {'weight': '80', 'reps': '12', 'notes': 'Second exercise'};
      await store.saveOpenWorkoutInputs(
        sessionId: draft.sessionId,
        exerciseIndex: 0,
        setSequence: 0,
        inputs: first,
      );
      await store.addOpenWorkoutExercise(
        sessionId: draft.sessionId,
        exerciseId: 'close_grip_bench_press',
      );
      expect(store.openWorkoutDraft!.inputs, isEmpty);
      await store.saveOpenWorkoutInputs(
        sessionId: draft.sessionId,
        exerciseIndex: 1,
        setSequence: 0,
        inputs: second,
      );
      await store.selectOpenWorkoutExercise(
        sessionId: draft.sessionId,
        exerciseIndex: 0,
      );
      expect(store.openWorkoutDraft!.inputs, first);
      await store.addOpenWorkoutExercise(
        sessionId: draft.sessionId,
        exerciseId: 'weighted_dip',
      );
      expect(store.openWorkoutDraft!.inputs, first);
      expect(store.openWorkoutDraft!.exercises, hasLength(2));
      final reloaded = newStore();
      await reloaded.load();
      expect(reloaded.openWorkoutDraft!.inputs, first);
      await reloaded.selectOpenWorkoutExercise(
        sessionId: draft.sessionId,
        exerciseIndex: 1,
      );
      expect(reloaded.openWorkoutDraft!.inputs, second);
      await reloaded.setUnit('kg');
      expect(reloaded.openWorkoutDraft!.inputs, {...second, 'weight': '36.29'});
      await reloaded.selectOpenWorkoutExercise(
        sessionId: draft.sessionId,
        exerciseIndex: 0,
      );
      expect(reloaded.openWorkoutDraft!.inputs, {...first, 'weight': '45.36'});
      final converted = newStore();
      await converted.load();
      expect(converted.openWorkoutDraft!.inputsByExercise, {
        0: {...first, 'weight': '45.36'},
        1: {...second, 'weight': '36.29'},
      });
      // Existing draft snapshots that stored only the selected inputs still load.
      final oldDraft = converted.openWorkoutDraft!.toJson()
        ..remove('inputsByExercise');
      expect(OpenWorkoutDraft.fromJson(oldDraft).inputs, {
        ...first,
        'weight': '45.36',
      });
    },
  );

  test(
    'draft weights convert with history and stale autosaves cannot change a finished session',
    () async {
      final store = newStore();
      final draft = await store.beginOpenWorkout();
      await store.addOpenWorkoutExercise(
        sessionId: draft.sessionId,
        exerciseId: 'weighted_dip',
      );
      await store.saveOpenWorkoutInputs(
        sessionId: draft.sessionId,
        exerciseIndex: 0,
        setSequence: 0,
        inputs: {'weight': '100', 'reps': '8'},
      );
      await log(store, weight: 100);
      await store.setUnit('kg');
      expect(store.logs.single.weight, closeTo(45.359237, .0001));
      expect(store.openWorkoutDraft!.inputs['weight'], '45.36');
      failWrites = true;
      await expectLater(store.setUnit('lb'), throwsA(isA<PlatformException>()));
      expect(store.unit, 'kg');
      expect(store.openWorkoutDraft!.inputs['weight'], '45.36');
      failWrites = false;
      await store.finishOpenWorkout(draft.sessionId);
      final next = await store.beginOpenWorkout();
      await store.saveOpenWorkoutInputs(
        sessionId: draft.sessionId,
        exerciseIndex: 0,
        setSequence: 1,
        inputs: {'reps': '999'},
      );
      expect(store.openWorkoutDraft!.sessionId, next.sessionId);
      expect(store.openWorkoutDraft!.inputs, isEmpty);
      final state = jsonDecode(saved!) as Map<String, dynamic>;
      state.remove('openWorkout');
      state['schemaVersion'] = 19;
      saved = jsonEncode(state);
      final upgraded = newStore();
      await upgraded.load();
      expect(upgraded.openWorkoutHistory, isEmpty);
      expect(upgraded.openWorkoutDraft, isNull);
      expect(upgraded.logs, hasLength(1));
    },
  );
}
