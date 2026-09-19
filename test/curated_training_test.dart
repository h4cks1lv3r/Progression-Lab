import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:progression_lab/curated_programs.dart';
import 'package:progression_lab/curated_training.dart';
import 'package:progression_lab/data_portability_core.dart';
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

  CuratedWorkoutDraft seed(AppStore store, CuratedDay day) {
    final draft = CuratedWorkoutDraft(
      programId: CuratedPrograms.all.first.id,
      sessionId: 'curated-test',
      week: 1,
      dayIndex: 0,
      run: 1,
      startedAt: DateTime(2026, 9, 19),
      day: day,
    );
    store.curatedTraining = CuratedTrainingState(
      drafts: {draft.programId: draft},
    );
    return draft;
  }

  Future<void> log(
    AppStore store,
    CuratedWorkoutDraft draft, {
    int? index,
    double? weight = 25,
    int? reps = 8,
    int? seconds = 30,
    double? meters = 100,
  }) => store.logCuratedSet(
    programId: draft.programId,
    sessionId: draft.sessionId,
    stepIndex: index ?? store.curatedDraftFor(draft.programId)!.nextStepIndex,
    weight: weight,
    reps: reps,
    seconds: seconds,
    meters: meters,
  );

  const mixedDay = CuratedDay(
    title: 'All metrics',
    movements: [
      CuratedMovement(
        name: 'Dip',
        metric: CuratedMetric.reps,
        targets: [CuratedSetTarget(reps: '8')],
        restSeconds: 30,
      ),
      CuratedMovement(
        name: 'Barbell Bench Press',
        metric: CuratedMetric.loadedReps,
        targets: [CuratedSetTarget(reps: '8')],
      ),
      CuratedMovement(
        name: 'Plank',
        metric: CuratedMetric.duration,
        targets: [CuratedSetTarget(seconds: 30)],
      ),
      CuratedMovement(
        name: 'Row',
        metric: CuratedMetric.distance,
        targets: [CuratedSetTarget(meters: 100)],
      ),
      CuratedMovement(
        name: 'Farmer Carry',
        metric: CuratedMetric.loadedDistance,
        targets: [CuratedSetTarget(meters: 100)],
      ),
    ],
  );

  test(
    'deleting a set reopens its target without losing later sets or history counts',
    () async {
      final store = newStore();
      final draft = seed(store, mixedDay);
      for (var i = 0; i < 5; i++) {
        await log(store, draft);
      }
      final first = store.logs.first;
      failWrites = true;
      await expectLater(
        store.removeSet(first),
        throwsA(isA<PlatformException>()),
      );
      expect(store.logs, hasLength(5));
      expect(store.curatedDraftFor(draft.programId)!.nextStepIndex, 5);
      failWrites = false;
      await store.removeSet(first);
      expect(store.curatedDraftFor(draft.programId)!.nextStepIndex, 0);
      await log(store, draft, reps: 11);
      expect(store.logs, hasLength(5));
      expect(store.curatedDraftFor(draft.programId)!.nextStepIndex, 5);
      await store.finishCuratedWorkout(
        programId: draft.programId,
        sessionId: draft.sessionId,
      );
      await store.removeSet(store.logs.first);
      expect(store.curatedHistory.single.setCount, 4);
      expect(store.curatedHistory.single.status, 'partial');
      expect(store.curatedProgressFor(draft.programId).dayIndex, 1);
    },
  );

  test(
    'failed input autosave cannot roll back a concurrent saved-set edit',
    () async {
      final store = newStore();
      final draft = seed(store, mixedDay);
      await log(store, draft);
      final entered = Completer<void>();
      final release = Completer<void>();
      var writes = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'read') return saved;
            if (call.method == 'write') {
              if (writes++ == 0) {
                entered.complete();
                await release.future;
                throw PlatformException(code: 'first_write_failed');
              }
              saved = call.arguments as String;
            }
            return null;
          });
      final autosave = store.saveCuratedInputs(
        programId: draft.programId,
        sessionId: draft.sessionId,
        stepIndex: 1,
        inputs: {'weight': '90'},
      );
      final failure = expectLater(autosave, throwsA(isA<PlatformException>()));
      await entered.future;
      final edit = store.updateSet(
        store.logs.first,
        weight: 0,
        reps: 12,
        notes: 'corrected',
      );
      release.complete();
      await failure;
      await edit;
      expect(store.logs.single.reps, 12);
      expect(store.logs.single.notes, 'corrected');
      final reloaded = newStore();
      await reloaded.load();
      expect(reloaded.logs.single.toJson(), store.logs.single.toJson());
      expect(reloaded.curatedDraftFor(draft.programId)!.inputs, isEmpty);
    },
  );

  test('records compare the logged metric instead of the exercise default', () {
    final store = newStore();
    SetLog carry(double meters) => SetLog(
      exercise: 'Farmer Carry',
      exerciseId: 'farmer_carry',
      weight: 30,
      reps: 0,
      date: DateTime(2026, 9, 19),
      workout: 'Carries',
      trackingType: 'weightDistance',
      distance: meters,
      distanceUnit: 'm',
    );
    store.logs.add(carry(50));
    expect(store.isPr(carry(20)), isFalse);
    expect(store.isPr(carry(60)), isTrue);
    expect(
      store.isPr(carry(50).copyWith(trackingType: 'weightReps', reps: 5)),
      isTrue,
    );
  });

  test(
    'all catalogs can start independently without moving existing programs',
    () async {
      final store = newStore();
      store.week = 20;
      store.workoutIndex = 2;
      store.athleticWeek = 7;
      for (final program in CuratedPrograms.all) {
        final draft = await store.beginCuratedWorkout(program.id);
        expect(draft.day.title, program.days.first.title);
        expect(draft.nextStepIndex, 0);
        expect(
          (await store.beginCuratedWorkout(program.id)).sessionId,
          draft.sessionId,
        );
      }
      expect(store.curatedTraining.drafts, hasLength(12));
      expect(store.week, 20);
      expect(store.workoutIndex, 2);
      expect(store.athleticWeek, 7);
      expect(store.logs, isEmpty);
      expect(store.workoutHistory, isEmpty);
    },
  );

  test(
    'actual reps, duration, distance and load are validated and recorded once',
    () async {
      final store = newStore();
      final draft = seed(store, mixedDay);
      await expectLater(
        log(store, draft, weight: null, reps: 0),
        throwsArgumentError,
      );
      expect(store.logs, isEmpty);
      await Future.wait([
        log(store, draft, index: 0, weight: null),
        log(store, draft, index: 0, weight: null),
      ]);
      expect(store.logs, hasLength(1));
      expect(store.logs.first.weight, 0);
      expect(store.logs.first.trackingType, 'bodyweightReps');
      expect(store.curatedDraftFor(draft.programId)!.nextStepIndex, 1);
      for (final value in [null, 0.0, double.nan, double.infinity, -1.0]) {
        await expectLater(
          log(store, draft, weight: value),
          throwsArgumentError,
        );
      }
      await log(store, draft);
      await expectLater(log(store, draft, seconds: 0), throwsArgumentError);
      await log(store, draft);
      await expectLater(
        log(store, draft, meters: double.infinity),
        throwsArgumentError,
      );
      await log(store, draft);
      await expectLater(log(store, draft, weight: null), throwsArgumentError);
      await log(store, draft);
      expect(store.logs.map((e) => e.trackingType), [
        'bodyweightReps',
        'weightReps',
        'duration',
        'distanceOnly',
        'weightDistance',
      ]);
      expect(store.logs[2].durationSeconds, 30);
      expect(store.logs[3].distance, 100);
      expect(store.logs[4].weight, 25);
      expect(store.logs.map((e) => e.sourceId).toSet(), hasLength(5));
      expect(
        store.logs.every((e) => e.sourceApp == 'progression_lab_curated'),
        isTrue,
      );
      await store.finishCuratedWorkout(
        programId: draft.programId,
        sessionId: draft.sessionId,
      );
      await store.finishCuratedWorkout(
        programId: draft.programId,
        sessionId: draft.sessionId,
      );
      expect(store.curatedHistory, hasLength(1));
      expect(store.curatedHistory.single.status, 'completed');
      expect(store.curatedProgressFor(draft.programId).dayIndex, 1);
    },
  );

  test(
    'stale input autosaves cannot overwrite the next step or finished session',
    () async {
      final store = newStore();
      final draft = seed(store, mixedDay);
      await store.saveCuratedInputs(
        programId: draft.programId,
        sessionId: draft.sessionId,
        stepIndex: 0,
        inputs: {'reps': '9', 'notes': 'before', 'unexpected': 'discard'},
      );
      expect(store.curatedDraftFor(draft.programId)!.inputs, {
        'reps': '9',
        'notes': 'before',
      });
      await log(store, draft);
      await store.saveCuratedInputs(
        programId: draft.programId,
        sessionId: draft.sessionId,
        stepIndex: 0,
        inputs: {'reps': '9'},
      );
      expect(store.curatedDraftFor(draft.programId)!.inputs, isEmpty);
      await store.finishCuratedWorkout(
        programId: draft.programId,
        sessionId: draft.sessionId,
        allowPartial: true,
      );
      final next = await store.beginCuratedWorkout(draft.programId);
      await store.saveCuratedInputs(
        programId: draft.programId,
        sessionId: draft.sessionId,
        stepIndex: 0,
        inputs: {'reps': '99'},
      );
      expect(store.curatedDraftFor(draft.programId)!.sessionId, next.sessionId);
      expect(store.curatedDraftFor(draft.programId)!.inputs, isEmpty);
    },
  );

  test(
    'storage failures roll back begin, inputs, logging, and completion',
    () async {
      final store = newStore();
      final id = CuratedPrograms.all.first.id;
      failWrites = true;
      await expectLater(
        store.beginCuratedWorkout(id),
        throwsA(isA<PlatformException>()),
      );
      expect(store.curatedTraining.drafts, isEmpty);
      failWrites = false;
      final draft = seed(store, mixedDay);
      failWrites = true;
      await expectLater(
        store.saveCuratedInputs(
          programId: id,
          sessionId: draft.sessionId,
          stepIndex: 0,
          inputs: {'reps': '8'},
        ),
        throwsA(isA<PlatformException>()),
      );
      expect(store.curatedDraftFor(id)!.inputs, isEmpty);
      await expectLater(log(store, draft), throwsA(isA<PlatformException>()));
      expect(store.logs, isEmpty);
      expect(store.curatedDraftFor(id)!.nextStepIndex, 0);
      failWrites = false;
      await log(store, draft);
      failWrites = true;
      await expectLater(
        store.finishCuratedWorkout(
          programId: id,
          sessionId: draft.sessionId,
          allowPartial: true,
        ),
        throwsA(isA<PlatformException>()),
      );
      expect(store.curatedHistory, isEmpty);
      expect(store.curatedDraftFor(id)!.nextStepIndex, 1);
      expect(store.logs, hasLength(1));
      expect(store.curatedProgressFor(id).completedSessions, 0);
      failWrites = false;
      await store.finishCuratedWorkout(
        programId: id,
        sessionId: draft.sessionId,
        allowPartial: true,
      );
      expect(store.curatedHistory.single.status, 'partial');
    },
  );

  test(
    'draft snapshot, inputs, rest and logs survive reload and backup restore',
    () async {
      final store = newStore();
      final draft = seed(store, mixedDay);
      await log(store, draft);
      await store.saveCuratedInputs(
        programId: draft.programId,
        sessionId: draft.sessionId,
        stepIndex: 1,
        inputs: {'weight': '125', 'reps': '8', 'notes': 'next set'},
      );
      final restored = newStore();
      await restored.load();
      expect(restored.loadFailure, isNull);
      expect(restored.curatedTraining.toJson(), store.curatedTraining.toJson());
      expect(
        restored.curatedDraftFor(draft.programId)!.day.title,
        'All metrics',
      );
      expect(restored.curatedDraftFor(draft.programId)!.restEndsAt, isNotNull);
      final decoded = ProgressionBackupCodec.decode(
        ProgressionBackupCodec.encode(store.exportState()),
      );
      final fromBackup = newStore();
      await fromBackup.restoreState(decoded.state);
      expect(
        fromBackup.curatedTraining.toJson(),
        store.curatedTraining.toJson(),
      );
      expect(fromBackup.logs.single.toJson(), store.logs.single.toJson());
      final json = jsonDecode(saved!) as Map<String, dynamic>;
      expect(json['schemaVersion'], AppStore.schemaVersion);
    },
  );

  test(
    'old schema defaults to empty curated state without changing existing data',
    () async {
      final store = newStore();
      final old = store.exportState()..remove('curatedTraining');
      old['schemaVersion'] = 18;
      old['week'] = 26;
      await store.restoreState(old);
      expect(store.curatedTraining.drafts, isEmpty);
      expect(store.curatedHistory, isEmpty);
      expect(store.week, 26);
    },
  );

  test(
    'partial requires explicit choice and a logged set; day five rolls into next week',
    () async {
      final store = newStore();
      final id = CuratedPrograms.all.first.id;
      for (var day = 0; day < 5; day++) {
        final draft = await store.beginCuratedWorkout(id);
        expect(draft.dayIndex, day);
        expect(draft.week, 1);
        await expectLater(
          store.finishCuratedWorkout(
            programId: id,
            sessionId: draft.sessionId,
            allowPartial: true,
          ),
          throwsStateError,
        );
        await log(store, draft);
        await expectLater(
          store.finishCuratedWorkout(programId: id, sessionId: draft.sessionId),
          throwsStateError,
        );
        await store.finishCuratedWorkout(
          programId: id,
          sessionId: draft.sessionId,
          allowPartial: true,
        );
      }
      expect(store.curatedHistory, hasLength(5));
      expect(store.curatedHistory.every((r) => r.status == 'partial'), isTrue);
      final next = await store.beginCuratedWorkout(id);
      expect(next.dayIndex, 0);
      expect(next.week, 2);
      expect(
        store.curatedProgressFor(CuratedPrograms.all[1].id).completedSessions,
        0,
      );
    },
  );

  test(
    'circuits alternate movements and rest after each complete round',
    () async {
      const day = CuratedDay(
        title: 'Circuit',
        movements: [
          CuratedMovement(
            name: 'Push-up',
            metric: CuratedMetric.reps,
            group: 'pair',
            targets: [
              CuratedSetTarget(reps: '8'),
              CuratedSetTarget(reps: '8'),
            ],
          ),
          CuratedMovement(
            name: 'Dip',
            metric: CuratedMetric.reps,
            group: 'pair',
            targets: [
              CuratedSetTarget(reps: '8'),
              CuratedSetTarget(reps: '8'),
            ],
          ),
          CuratedMovement(
            name: 'Plank',
            metric: CuratedMetric.duration,
            targets: [CuratedSetTarget(seconds: 30)],
          ),
        ],
      );
      expect(curatedSteps(day).map((s) => (s.movementIndex, s.targetIndex)), [
        (0, 0),
        (1, 0),
        (0, 1),
        (1, 1),
        (2, 0),
      ]);
      final store = newStore();
      final draft = seed(store, day);
      await log(store, draft);
      expect(store.curatedDraftFor(draft.programId)!.restEndsAt, isNull);
      await log(store, draft);
      expect(store.curatedDraftFor(draft.programId)!.restEndsAt, isNotNull);
    },
  );

  test(
    'changing units converts draft loads and saved loads and rolls back on failure',
    () async {
      final store = newStore();
      final draft = seed(store, mixedDay);
      await log(store, draft);
      await log(store, draft, weight: 100);
      await store.saveCuratedInputs(
        programId: draft.programId,
        sessionId: draft.sessionId,
        stepIndex: 2,
        inputs: {'weight': '100', 'seconds': '40'},
      );
      await store.setUnit('kg');
      expect(store.logs[1].weight, closeTo(45.3592, .001));
      expect(store.curatedDraftFor(draft.programId)!.inputs['weight'], '45.36');
      expect(store.curatedDraftFor(draft.programId)!.inputs['seconds'], '40');
      failWrites = true;
      await expectLater(store.setUnit('lb'), throwsA(isA<PlatformException>()));
      expect(store.unit, 'kg');
      expect(store.curatedDraftFor(draft.programId)!.inputs['weight'], '45.36');
    },
  );
}
