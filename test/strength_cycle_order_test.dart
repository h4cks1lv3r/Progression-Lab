import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:progression_lab/data_portability_core.dart';
import 'package:progression_lab/program.dart';
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

  AppStore createStore({int days = 4, int week = 1, int index = 0}) =>
      AppStore()
        ..automaticBackupsEnabled = false
        ..days = days
        ..week = week
        ..workoutIndex = index
        ..programStartDate = DateTime(2026, 1, 5);

  Future<void> finish(
    AppStore store, {
    WorkoutStatus status = WorkoutStatus.completed,
  }) => store.recordWorkout(
    weekNumber: store.week,
    targetWorkoutIndex: store.workoutIndex,
    workout: ProgramEngine.week(
      store.week,
      store.days,
    ).workouts[store.workoutIndex].name,
    status: status,
    sessionId:
        'run-${store.strengthProgramRun}-week-${store.week}-days-${store.days}-day-${store.workoutIndex}',
  );

  WorkoutRecord record(
    int index, {
    int run = 1,
    int days = 4,
    int week = 1,
    WorkoutStatus status = WorkoutStatus.completed,
    bool imported = false,
  }) => WorkoutRecord(
    week: week,
    workoutIndex: index,
    workout: 'Day $index',
    date: DateTime(2026, 1, 5),
    status: status,
    programRun: run,
    days: days,
    importedWorkoutId: imported ? 'import-$index' : null,
    retroactive: imported,
  );

  DraftSetInput draft(
    int index, {
    int run = 1,
    int days = 4,
    String? session,
  }) => DraftSetInput(
    week: 1,
    workoutIndex: index,
    workout: 'Day $index',
    exerciseIndex: 2,
    setNumber: 3,
    sessionId: session ?? 'draft-$run-$days-$index',
    weight: '135',
    reps: '8',
    notes: 'Keep this input',
    programRun: run,
    days: days,
    substitutions: const {1: 'Dumbbell Row'},
    startedAt: DateTime(2026, 1, 5, 10),
    restEndsAt: DateTime(2026, 1, 5, 10, 2),
  );

  test(
    'all cadences finish out of order without dropping deferred days',
    () async {
      for (final cadence in [3, 4, 5]) {
        final store = createStore(days: cadence);
        final remaining = {for (var index = 0; index < cadence; index++) index};
        for (var index = cadence - 1; index >= 0; index--) {
          await store.selectStrengthWorkout(index);
          expect(store.week, 1);
          expect(
            store.strengthCompletedWorkouts(1),
            cadence - remaining.length,
          );
          await finish(store);
          remaining.remove(index);
          expect(
            store.strengthCompletedWorkouts(1),
            cadence - remaining.length,
          );
          if (remaining.isNotEmpty) {
            expect(store.week, 1);
            expect(store.workoutIndex, remaining.first);
            expect(store.pendingStrengthWorkoutIndices, remaining.toList());
          }
        }
        expect(store.week, 2);
        expect(store.workoutIndex, 0);
        expect(
          store.workoutHistory.map((r) => r.workoutIndex),
          List.generate(cadence, (index) => cadence - index - 1),
        );
      }
    },
  );

  test(
    'selecting and reselecting never changes history, dates, or completion',
    () async {
      final store = createStore(week: 19);
      final start = store.programStartDate;
      final dates = List.generate(4, (index) => store.dateForSlot(19, index));
      for (final index in [3, 3, 1, 0, 2, 2]) {
        await store.selectStrengthWorkout(index);
        expect(store.workoutIndex, index);
        expect(store.pendingStrengthWorkoutIndices, [0, 1, 2, 3]);
        expect(store.workoutHistory, isEmpty);
        expect(store.strengthCompletedWorkouts(19), 0);
        expect(store.week, 19);
        expect(store.strengthProgramRun, 1);
        expect(store.programStartDate, start);
        expect(List.generate(4, (i) => store.dateForSlot(19, i)), dates);
      }
      expect(store.isPastSlot(19, 0), isFalse);
      expect(store.isPastSlot(18, 0), isTrue);
      expect(store.isPastSlot(20, 0), isFalse);
    },
  );

  test(
    'legacy midcycle entry preserves gaps and can enroll one earlier day',
    () async {
      saved = jsonEncode(
        createStore(days: 5, week: 7, index: 2).exportState()
          ..remove('strengthPendingWorkouts')
          ..['schemaVersion'] = 20,
      );
      final store = createStore();
      await store.load();
      expect(store.pendingStrengthWorkoutIndices, [2, 3, 4]);
      expect(store.isPastSlot(7, 0), isTrue);
      await store.selectStrengthWorkout(0);
      expect(store.pendingStrengthWorkoutIndices, [0, 2, 3, 4]);
      expect(store.isPastSlot(7, 1), isTrue);
      expect(store.workoutHistory, isEmpty);
      await finish(store);
      expect(store.workoutIndex, 2);
      for (final index in [4, 2, 3]) {
        await store.selectStrengthWorkout(index);
        await finish(store);
      }
      expect(store.week, 8);
      expect(store.recordsForSlot(7, 1), isEmpty);
      expect(store.strengthCompletedWorkouts(7), 4);
    },
  );

  test(
    'drafts, entered values, and logged sets survive switching away and back',
    () async {
      final store = createStore()..draft = draft(0);
      final original = store.draft!;
      store.logs.add(
        SetLog(
          exercise: 'Dumbbell Row',
          weight: 135,
          reps: 8,
          date: DateTime(2026, 1, 5),
          workout: 'Day 0',
          sessionId: original.sessionId,
        ),
      );
      final logsBefore = store.logs.map((log) => log.toJson()).toList();
      await store.selectStrengthWorkout(2);
      expect(store.draft, isNull);
      await store.setDraft(draft(2));
      await store.selectStrengthWorkout(0);
      expect(store.draft!.toJson(), original.toJson());
      expect(store.drafts, hasLength(2));
      expect(store.logs.map((log) => log.toJson()), logsBefore);
      await store.completeWorkout(workout: 'Day 0');
      expect(store.workoutHistory.single.sessionId, original.sessionId);
      expect(store.drafts.single.workoutIndex, 2);
      await store.selectStrengthWorkout(2);
      expect(store.draft!.notes, 'Keep this input');
    },
  );

  test(
    'finish helper uses the current slot draft and preserves another run',
    () async {
      final store = createStore();
      final other = draft(1);
      final oldRun = draft(0, run: 2);
      await store.setDraft(other);
      store.drafts.add(oldRun);
      await store.completeWorkout(workout: 'Day 0');
      expect(store.workoutHistory.single.sessionId, isNull);
      expect(store.draft!.sessionId, other.sessionId);
      expect(
        store.drafts.map((value) => value.sessionId),
        contains(oldRun.sessionId),
      );
    },
  );

  test(
    'reload and full backup restore preserve selection and remaining days',
    () async {
      final store = createStore(week: 16);
      await store.selectStrengthWorkout(3);
      await finish(store);
      await store.selectStrengthWorkout(2);
      final expected = store.exportState();
      final loaded = createStore();
      await loaded.load();
      expect(loaded.week, 16);
      expect(loaded.workoutIndex, 2);
      expect(loaded.pendingStrengthWorkoutIndices, [0, 1, 2]);
      final decoded = ProgressionBackupCodec.decode(
        ProgressionBackupCodec.encode(expected),
      );
      final restored = createStore();
      await restored.restoreState(decoded.state);
      expect(restored.exportState(), expected);
      await finish(restored);
      expect(restored.workoutIndex, 0);
      expect(restored.week, 16);
      expect(restored.strengthCompletedWorkouts(16), 2);
    },
  );

  test(
    'partial and skipped resolve a day but never count as completed',
    () async {
      final store = createStore(days: 3);
      await store.selectStrengthWorkout(2);
      await finish(store, status: WorkoutStatus.skipped);
      expect(store.week, 1);
      expect(store.workoutIndex, 0);
      expect(store.isStrengthWorkoutResolved(1, 2), isTrue);
      expect(store.strengthCompletedWorkouts(1), 0);
      await finish(store, status: WorkoutStatus.partial);
      expect(store.week, 1);
      expect(store.workoutIndex, 1);
      expect(store.strengthCompletedWorkouts(1), 0);
      await finish(store);
      expect(store.week, 2);
      expect(store.strengthCompletedWorkouts(1), 1);
    },
  );

  test(
    'imported records count only in their own run, cycle, and cadence',
    () async {
      final store = createStore()
        ..workoutHistory.addAll([
          record(0, imported: true),
          record(1, imported: true, status: WorkoutStatus.partial),
          record(2, run: 2),
          record(2, days: 5),
          record(2, week: 2),
        ]);
      expect(store.pendingStrengthWorkoutIndices, [2, 3]);
      expect(store.strengthCompletedWorkouts(1), 1);
      await store.selectStrengthWorkout(3);
      await finish(store);
      expect(store.workoutIndex, 2);
      expect(store.week, 1);
      await finish(store);
      expect(store.week, 2);
      expect(store.pendingStrengthWorkoutIndices, [0, 1, 3]);
    },
  );

  test(
    'finished slots cannot be selected or completed a second time',
    () async {
      final store = createStore();
      await finish(store);
      final before = store.exportState();
      await expectLater(store.selectStrengthWorkout(0), throwsStateError);
      await expectLater(
        store.recordWorkout(
          weekNumber: 1,
          targetWorkoutIndex: 0,
          workout: 'Day 0',
          status: WorkoutStatus.completed,
          sessionId: 'different',
        ),
        throwsStateError,
      );
      await expectLater(store.selectStrengthWorkout(4), throwsRangeError);
      await expectLater(store.selectStrengthWorkout(-1), throwsRangeError);
      expect(store.exportState(), before);
      await store.recordWorkout(
        weekNumber: 1,
        targetWorkoutIndex: 0,
        workout: 'Day 0',
        status: WorkoutStatus.completed,
        sessionId: store.workoutHistory.single.sessionId,
      );
      expect(store.exportState(), before);
    },
  );

  test(
    'failed selection and completion restore all pending state and drafts',
    () async {
      final store = createStore();
      await store.setDraft(draft(0));
      var before = store.exportState();
      failWrites = true;
      await expectLater(
        store.selectStrengthWorkout(3),
        throwsA(isA<PlatformException>()),
      );
      expect(store.exportState(), before);
      failWrites = false;
      await store.selectStrengthWorkout(3);
      before = store.exportState();
      failWrites = true;
      await expectLater(finish(store), throwsA(isA<PlatformException>()));
      expect(store.exportState(), before);
      failWrites = false;
      await finish(store);
      expect(store.pendingStrengthWorkoutIndices, [0, 1, 2]);
      expect(store.draft!.workoutIndex, 0);
    },
  );

  test(
    'cadence changes preserve each schedule and rollback on failure',
    () async {
      final store = createStore();
      await store.selectStrengthWorkout(3);
      await finish(store);
      await store.setDays(5, nextWorkoutIndex: 4);
      expect(store.pendingStrengthWorkoutIndices, [4]);
      await store.selectStrengthWorkout(1);
      expect(store.pendingStrengthWorkoutIndices, [1, 4]);
      await store.setDays(4, nextWorkoutIndex: 2);
      expect(store.pendingStrengthWorkoutIndices, [0, 1, 2]);
      expect(store.strengthCompletedWorkouts(1), 1);
      final before = store.exportState();
      failWrites = true;
      await expectLater(
        store.setDays(5, nextWorkoutIndex: 1),
        throwsA(isA<PlatformException>()),
      );
      expect(store.exportState(), before);
      failWrites = false;
      await store.setDays(5, nextWorkoutIndex: 1);
      expect(store.pendingStrengthWorkoutIndices, [1, 4]);
      expect(store.strengthCompletedWorkouts(1), 0);
    },
  );

  test(
    'explicit starting point resets pending schedule without invented records',
    () async {
      final store = createStore();
      await store.selectStrengthWorkout(3);
      await store.setStrengthProgramPosition(
        phase: 2,
        microcycle: 4,
        cadence: 5,
        nextWorkoutIndex: 3,
        nextWorkoutDate: DateTime(2026, 9, 25),
        startNewRun: true,
      );
      expect(store.strengthProgramRun, 2);
      expect(store.week, 20);
      expect(store.pendingStrengthWorkoutIndices, [3, 4]);
      expect(store.workoutHistory, isEmpty);
      final before = store.exportState();
      failWrites = true;
      await expectLater(
        store.setStrengthProgramPosition(
          phase: 1,
          microcycle: 1,
          cadence: 4,
          nextWorkoutIndex: 0,
          nextWorkoutDate: DateTime(2026, 9, 26),
          startNewRun: true,
        ),
        throwsA(isA<PlatformException>()),
      );
      expect(store.exportState(), before);
    },
  );

  test(
    'last cycle rolls to a new run only after deferred days resolve',
    () async {
      final store = createStore(days: 3, week: 48);
      final start = store.programStartDate;
      await store.selectStrengthWorkout(2);
      await finish(store);
      expect(store.week, 48);
      expect(store.strengthProgramRun, 1);
      await store.selectStrengthWorkout(1);
      await finish(store);
      expect(store.week, 48);
      expect(store.workoutIndex, 0);
      await finish(store);
      expect(store.week, 1);
      expect(store.strengthProgramRun, 2);
      expect(store.pendingStrengthWorkoutIndices, [0, 1, 2]);
      expect(store.programStartDate, start.add(const Duration(days: 48 * 7)));
      expect(store.strengthCompletedWorkouts(48), 0);
      expect(store.workoutHistory, hasLength(3));
    },
  );

  test(
    'legacy complete count remains compatible with midcycle starts',
    () async {
      final store = createStore(days: 3, week: 48, index: 2);
      await store.complete(5);
      expect(store.week, 1);
      expect(store.workoutIndex, 0);
      expect(store.strengthProgramRun, 2);
      expect(store.workoutHistory, isEmpty);
      final pending = createStore();
      await pending.selectStrengthWorkout(3);
      await pending.complete(4);
      expect(pending.week, 1);
      expect(pending.pendingStrengthWorkoutIndices, [0, 1, 2]);
    },
  );

  test(
    'retroactive entries do not move selection or erase deferred days',
    () async {
      final store = createStore(week: 3);
      await store.selectStrengthWorkout(3);
      await store.recordWorkout(
        weekNumber: 2,
        targetWorkoutIndex: 1,
        workout: 'Past day',
        status: WorkoutStatus.completed,
        sessionId: 'past',
        retroactive: true,
      );
      expect(store.week, 3);
      expect(store.workoutIndex, 3);
      expect(store.pendingStrengthWorkoutIndices, [0, 1, 2, 3]);
      expect(store.strengthCompletedWorkouts(2), 1);
    },
  );

  test(
    'invalid stored pending entries are ignored without losing valid scope',
    () async {
      final state = createStore(index: 2).exportState();
      state['strengthPendingWorkouts'] = {
        '1:1:4': [0, 2, 2, -1, 9, '1'],
        'bad': [0],
        '0:1:4': [0],
        '1:99:4': [0],
        '1:1:6': [0],
      };
      saved = jsonEncode(state);
      final store = createStore();
      await store.load();
      expect(store.pendingStrengthWorkoutIndices, [0, 2]);
      expect((store.exportState()['strengthPendingWorkouts'] as Map).keys, [
        '1:1:4',
      ]);
      expect(store.loadFailure, isNull);
    },
  );
}
