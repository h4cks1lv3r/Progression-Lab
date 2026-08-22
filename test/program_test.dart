import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:progression_lab/athletic_history.dart';
import 'package:progression_lab/athletic_program.dart';
import 'package:progression_lab/exercise_library.dart';
import 'package:progression_lab/program.dart';
import 'package:progression_lab/store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const storageChannel = MethodChannel('iron_cadence/storage');
  String? storedValue;
  var failWrites = false;

  setUp(() {
    storedValue = null;
    failWrites = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storageChannel, (call) async {
          switch (call.method) {
            case 'read':
              return storedValue;
            case 'write':
              if (failWrites) {
                throw PlatformException(code: 'write_failed');
              }
              storedValue = call.arguments as String;
              return null;
            default:
              throw PlatformException(code: 'unknown_method');
          }
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storageChannel, null);
  });

  group('program boundaries', () {
    test('generates the verified 48-week, three-phase program', () {
      final year = ProgramEngine.year(4);
      expect(year, hasLength(ProgramEngine.totalWeeks));
      expect(ProgramEngine.totalWeeks, 48);
      expect(year.first.phase, 1);
      expect(year[15].kind, WeekKind.fullDeload);
      expect(year[16].phase, 2);
      expect(year[31].kind, WeekKind.fullDeload);
      expect(year[32].phase, 3);
      expect(year.last.phase, 3);
      expect(year.last.microcycle, 16);
    });

    test('exposes phase and microcycle helpers', () {
      expect(ProgramEngine.firstWeekOfPhase(1), 1);
      expect(ProgramEngine.firstWeekOfPhase(2), 17);
      expect(ProgramEngine.firstWeekOfPhase(3), 33);
      expect(ProgramEngine.phaseForWeek(48), 3);
      expect(ProgramEngine.microcycleForWeek(17), 1);
      expect(ProgramEngine.clampWeek(-20), 1);
      expect(ProgramEngine.clampWeek(80), 48);
    });

    test('rejects unsupported cadences and non-authored weeks', () {
      expect(() => ProgramEngine.year(2), throwsArgumentError);
      expect(() => ProgramEngine.week(49, 4), throwsRangeError);
      expect(() => ProgramEngine.week(0, 4), throwsRangeError);
      expect(() => ProgramEngine.firstWeekOfPhase(4), throwsArgumentError);
    });

    test('cadences produce the selected number of workouts', () {
      expect(ProgramEngine.week(1, 3).workouts, hasLength(3));
      expect(ProgramEngine.week(1, 4).workouts, hasLength(4));
      expect(ProgramEngine.week(1, 5).workouts, hasLength(5));
    });
  });

  group('prescriptions', () {
    test('volume deloads use verified primary and accessory targets', () {
      final microcycle4 = ProgramEngine.week(4, 4).workouts.first.exercises;
      final microcycle8 = ProgramEngine.week(8, 4).workouts.first.exercises;
      final microcycle12 = ProgramEngine.week(12, 4).workouts.first.exercises;

      expect(microcycle4.first.primary, isTrue);
      expect(microcycle4.first.reps, '3');
      expect(microcycle4[1].primary, isFalse);
      expect(microcycle4[1].reps, '8');
      expect(microcycle8.first.reps, '2');
      expect(microcycle8[1].reps, '6');
      expect(microcycle12.first.reps, '1');
      expect(microcycle12[1].reps, '6');
      expect(microcycle12.every((exercise) => exercise.sets == 2), isTrue);
    });

    test('microcycle 15 includes an AMRAP prescription', () {
      final week = ProgramEngine.week(15, 4);
      expect(week.kind, WeekKind.strength);
      expect(week.workouts.first.exercises.first.amrap, isTrue);
      expect(week.workouts.first.exercises.first.reps, contains('AMRAP'));
    });
  });

  group('cadence mapping', () {
    test('keeps equivalent push and pull sessions aligned', () {
      expect(
        ProgramEngine.defaultWorkoutIndexForCadenceSwitch(
          week: 9,
          fromDays: 3,
          toDays: 5,
          currentWorkoutIndex: 0,
        ),
        0,
      );
      expect(
        ProgramEngine.defaultWorkoutIndexForCadenceSwitch(
          week: 9,
          fromDays: 3,
          toDays: 4,
          currentWorkoutIndex: 1,
        ),
        1,
      );
    });

    test('uses the anchor lift to break an exercise-overlap tie', () {
      final mapped = ProgramEngine.defaultWorkoutIndexForCadenceSwitch(
        week: 1,
        fromDays: 3,
        toDays: 4,
        currentWorkoutIndex: 2,
      );
      expect(mapped, 3);
      expect(ProgramEngine.week(1, 4).workouts[mapped].name, 'Legs & Calves');
    });

    test('maps the fifth session to its closest four-day equivalent', () {
      final mapped = ProgramEngine.defaultWorkoutIndexForCadenceSwitch(
        week: 20,
        fromDays: 5,
        toDays: 4,
        currentWorkoutIndex: 4,
      );
      expect(mapped, 2);
      expect(ProgramEngine.week(20, 4).workouts[mapped].name, 'Upper Body B');
    });

    test('preview is pure and clamps an obsolete source index', () {
      final preview = ProgramEngine.previewCadenceSwitch(
        week: 22,
        fromDays: 3,
        toDays: 5,
        currentWorkoutIndex: 99,
      );
      expect(preview.week, 22);
      expect(preview.currentWorkoutIndex, 2);
      expect(preview.currentWorkout.name, 'Full Body');
      expect(preview.suggestedWorkoutIndex, 3);
      expect(preview.suggestedWorkout.name, 'Legs & Calves');
    });
  });

  group('store cadence changes and recovery', () {
    test(
      'default cadence switch preserves week and maps next workout',
      () async {
        final store = AppStore()
          ..days = 3
          ..week = 27
          ..workoutIndex = 1;

        await store.setDays(5);

        expect(store.days, 5);
        expect(store.week, 27);
        expect(store.workoutIndex, 1);
        final saved = jsonDecode(storedValue!) as Map<String, dynamic>;
        expect(saved['week'], 27);
        expect(saved['days'], 5);
        expect(saved['workout'], 1);
      },
    );

    test(
      'explicit next workout wins without resetting the microcycle',
      () async {
        final store = AppStore()
          ..days = 5
          ..week = 34
          ..workoutIndex = 4;

        await store.setDays(3, nextWorkoutIndex: 0);

        expect(store.days, 3);
        expect(store.week, 34);
        expect(ProgramEngine.phaseForWeek(store.week), 3);
        expect(ProgramEngine.microcycleForWeek(store.week), 2);
        expect(store.workoutIndex, 0);
      },
    );

    test('invalid switch inputs fail before state changes', () async {
      final store = AppStore()
        ..days = 4
        ..week = 12
        ..workoutIndex = 2;

      await expectLater(store.setDays(6), throwsArgumentError);
      await expectLater(
        store.setDays(3, nextWorkoutIndex: 3),
        throwsRangeError,
      );
      expect(store.days, 4);
      expect(store.week, 12);
      expect(store.workoutIndex, 2);
    });

    test(
      'load repairs cadence, week, workout, unit, and bad log rows',
      () async {
        storedValue = jsonEncode({
          'days': 8,
          'week': 500,
          'workout': 99,
          'unit': 'stone',
          'logs': [
            {'broken': true},
            {
              'e': 'Barbell Bench Press',
              'w': 185,
              'r': 5,
              'd': '2026-08-11T12:00:00.000Z',
              'o': 'Upper Body A',
            },
          ],
        });
        final store = AppStore();

        await store.load();

        expect(store.days, 4);
        expect(store.week, 48);
        expect(store.workoutIndex, 3);
        expect(store.unit, 'lb');
        expect(store.logs, hasLength(1));
      },
    );

    test(
      'completion uses the current cadence and wraps after week 48',
      () async {
        final store = AppStore()
          ..days = 3
          ..week = 48
          ..workoutIndex = 2;

        await store.complete(
          5,
        ); // Deliberately stale count from an old cadence.

        expect(store.week, 1);
        expect(store.workoutIndex, 0);
      },
    );

    test(
      'failed cadence persistence rolls back the in-memory switch',
      () async {
        final store = AppStore()
          ..days = 4
          ..week = 22
          ..workoutIndex = 2;
        failWrites = true;

        await expectLater(
          store.setDays(3, nextWorkoutIndex: 1),
          throwsA(isA<PlatformException>()),
        );

        expect(store.days, 4);
        expect(store.week, 22);
        expect(store.workoutIndex, 2);
      },
    );
  });

  group('unit conversion', () {
    test(
      'switching units converts every historical weight exactly once',
      () async {
        final store = AppStore()
          ..unit = 'lb'
          ..logs = [
            SetLog(
              exercise: 'Barbell Bench Press',
              weight: 220.46226218487757,
              reps: 5,
              date: DateTime(2026, 8, 11),
              workout: 'Upper Body A',
            ),
            SetLog(
              exercise: 'Barbell Back Squat',
              weight: 315,
              reps: 3,
              date: DateTime(2026, 8, 11),
              workout: 'Legs & Calves',
            ),
          ];

        await store.setUnit('kg');
        final convertedBench = store.logs.first.weight;
        final convertedSquat = store.logs.last.weight;
        expect(convertedBench, closeTo(100, 0.0000001));
        expect(
          convertedSquat,
          closeTo(315 * AppStore.poundsToKilograms, 0.0000001),
        );

        final reloaded = AppStore();
        await reloaded.load();
        expect(reloaded.unit, 'kg');
        expect(reloaded.logs.first.weight, convertedBench);

        await reloaded.setUnit('kg');
        expect(reloaded.logs.first.weight, convertedBench);
        expect(reloaded.logs.last.weight, convertedSquat);

        await reloaded.setUnit('lb');
        expect(
          reloaded.logs.first.weight,
          closeTo(220.46226218487757, 0.000001),
        );
        expect(reloaded.logs.last.weight, closeTo(315, 0.000001));
      },
    );

    test('invalid unit fails without relabeling or converting data', () async {
      final store = AppStore()
        ..unit = 'lb'
        ..logs = [
          SetLog(
            exercise: 'Barbell Bench Press',
            weight: 185,
            reps: 5,
            date: DateTime(2026),
            workout: 'Upper Body A',
          ),
        ];

      await expectLater(store.setUnit('stone'), throwsArgumentError);
      expect(store.unit, 'lb');
      expect(store.logs.single.weight, 185);
    });

    test('failed unit persistence restores the original values', () async {
      final store = AppStore()
        ..unit = 'lb'
        ..logs = [
          SetLog(
            exercise: 'Barbell Bench Press',
            weight: 225,
            reps: 5,
            date: DateTime(2026),
            workout: 'Upper Body A',
          ),
        ];
      failWrites = true;

      await expectLater(store.setUnit('kg'), throwsA(isA<PlatformException>()));

      expect(store.unit, 'lb');
      expect(store.logs.single.weight, 225);
    });
  });

  test('PR comparison recognizes higher estimated strength', () {
    final store = AppStore();
    store.logs.add(
      SetLog(
        exercise: 'Barbell Bench Press',
        weight: 185,
        reps: 5,
        date: DateTime(2026),
        workout: 'Upper Body A',
      ),
    );
    final candidate = SetLog(
      exercise: 'Barbell Bench Press',
      weight: 190,
      reps: 5,
      date: DateTime(2026, 1, 2),
      workout: 'Upper Body A',
    );
    expect(store.isPr(candidate), isTrue);
  });

  group('workout log persistence', () {
    test('migrates legacy logs additively and preserves their data', () async {
      storedValue = jsonEncode({
        'days': 4,
        'week': 7,
        'workout': 1,
        'unit': 'lb',
        'logs': [
          {
            'e': 'Barbell Bench Press',
            'w': 185,
            'r': 5,
            'd': '2026-08-11T12:00:00.000Z',
            'o': 'Upper Body A',
          },
        ],
      });

      final store = AppStore();
      await store.load();

      expect(store.logs.single.notes, isEmpty);
      expect(store.logs.single.weight, 185);
      final migrated = jsonDecode(storedValue!) as Map<String, dynamic>;
      expect(migrated['schemaVersion'], AppStore.schemaVersion);
      expect((migrated['logs'] as List).single['n'], '');
      expect(migrated['workoutHistory'], isEmpty);
      expect(migrated['customExercises'], isEmpty);
    });

    test('set edits commit only through update and persist notes', () async {
      final original = SetLog(
        exercise: 'Barbell Bench Press',
        weight: 185,
        reps: 5,
        date: DateTime(2026, 8, 17),
        workout: 'Upper Body A',
      );
      final store = AppStore()..logs = [original];

      expect(store.logs.single.weight, 185);
      await store.updateSet(
        original,
        weight: 190,
        reps: 6,
        notes: 'Paused first rep',
      );

      expect(store.logs.single.weight, 190);
      expect(store.logs.single.reps, 6);
      expect(store.logs.single.notes, 'Paused first rep');
      final saved = jsonDecode(storedValue!) as Map<String, dynamic>;
      expect((saved['logs'] as List).single['n'], 'Paused first rep');
    });

    test('draft input round-trips through the existing store', () async {
      const draft = DraftSetInput(
        week: 9,
        workoutIndex: 2,
        workout: 'Upper Body B',
        exerciseIndex: 1,
        setNumber: 3,
        sessionId: 'session-9-2',
        weight: '92.5',
        reps: '8',
        notes: 'Slow eccentric',
      );
      await AppStore().setDraft(draft);

      final restored = AppStore();
      await restored.load();

      expect(restored.draft?.sessionId, 'session-9-2');
      expect(restored.draft?.weight, '92.5');
      expect(restored.draft?.notes, 'Slow eccentric');
    });

    test('skipping records status, clears the draft, and advances', () async {
      final store = AppStore()
        ..days = 4
        ..week = 3
        ..workoutIndex = 1
        ..draft = const DraftSetInput(
          week: 3,
          workoutIndex: 1,
          workout: 'Lower Body A',
          exerciseIndex: 0,
          setNumber: 1,
          sessionId: 'active',
          weight: '225',
          reps: '6',
          notes: '',
        );

      await store.skipWorkout(workout: 'Lower Body A');

      expect(store.workoutIndex, 2);
      expect(store.draft, isNull);
      expect(store.workoutHistory.single.status, WorkoutStatus.skipped);
      expect(store.workoutHistory.single.week, 3);
      final saved = jsonDecode(storedValue!) as Map<String, dynamic>;
      expect((saved['workoutHistory'] as List).single['status'], 'skipped');
    });

    test(
      'retroactive completion preserves current position and metadata',
      () async {
        final store = AppStore()
          ..days = 5
          ..week = 8
          ..workoutIndex = 3
          ..programStartDate = DateTime(2026, 6, 1);

        await store.recordWorkout(
          weekNumber: 7,
          targetWorkoutIndex: 4,
          workout: 'Upper Body C',
          status: WorkoutStatus.completed,
          sessionId: 'retro-7-4',
          substitutions: const {1: 'Dumbbell Bench Press'},
          retroactive: true,
          scheduledDate: store.dateForSlot(7, 4),
        );

        expect(store.week, 8);
        expect(store.workoutIndex, 3);
        final record = store.workoutHistory.single;
        expect(record.retroactive, isTrue);
        expect(record.sessionId, 'retro-7-4');
        expect(record.days, 5);
        expect(record.loggedAt, isNot(record.scheduledDate));
        expect(record.substitutions[1], 'Dumbbell Bench Press');

        final restored = AppStore();
        await restored.load();
        expect(restored.workoutHistory.single.retroactive, isTrue);
        expect(
          restored.workoutHistory.single.substitutions[1],
          'Dumbbell Bench Press',
        );
      },
    );

    test('slot dates and slot counts follow every supported cadence', () {
      const expectedOffsets = {
        3: [0, 2, 4],
        4: [0, 1, 3, 4],
        5: [0, 1, 2, 3, 4],
      };
      for (final entry in expectedOffsets.entries) {
        final store = AppStore()
          ..days = entry.key
          ..programStartDate = DateTime(2026, 1, 5);
        final week = ProgramEngine.week(2, entry.key);
        expect(week.workouts, hasLength(entry.key));
        final dates = [
          for (var index = 0; index < entry.key; index++)
            store.dateForSlot(2, index),
        ];
        expect(dates, [
          for (final offset in entry.value)
            DateTime(2026, 1, 12).add(Duration(days: offset)),
        ]);
      }
    });

    test('set slot and substituted draft round-trip additively', () async {
      final store = AppStore()
        ..logs = [
          SetLog(
            exercise: 'Dumbbell Bench Press',
            weight: 40,
            reps: 10,
            date: DateTime(2026, 8, 18),
            workout: 'Upper Body A',
            sessionId: 'session-sub',
            exerciseIndex: 0,
          ),
        ]
        ..draft = const DraftSetInput(
          week: 4,
          workoutIndex: 0,
          workout: 'Upper Body A',
          exerciseIndex: 2,
          setNumber: 1,
          sessionId: 'session-sub',
          weight: '',
          reps: '10',
          notes: '',
          days: 3,
          substitutions: {0: 'Dumbbell Bench Press'},
        );
      await store.save();

      final restored = AppStore();
      await restored.load();
      expect(restored.logs.single.exerciseIndex, 0);
      expect(restored.draft?.days, 3);
      expect(restored.draft?.substitutions[0], 'Dumbbell Bench Press');
    });

    test(
      'retroactive draft does not replace the current workout draft',
      () async {
        final store = AppStore()
          ..days = 4
          ..week = 6
          ..workoutIndex = 2;
        const current = DraftSetInput(
          week: 6,
          workoutIndex: 2,
          workout: 'Upper Body B',
          exerciseIndex: 1,
          setNumber: 2,
          sessionId: 'current-session',
          weight: '100',
          reps: '8',
          notes: 'Current input',
        );
        const retro = DraftSetInput(
          week: 5,
          workoutIndex: 0,
          workout: 'Upper Body A',
          exerciseIndex: 0,
          setNumber: 1,
          sessionId: 'retro-session',
          weight: '80',
          reps: '10',
          notes: 'Past input',
          retroactive: true,
        );
        await store.setDraft(current);
        await store.setDraft(retro);

        await store.recordWorkout(
          weekNumber: 5,
          targetWorkoutIndex: 0,
          workout: 'Upper Body A',
          status: WorkoutStatus.completed,
          sessionId: 'retro-session',
          retroactive: true,
        );

        expect(
          store
              .draftFor(
                weekNumber: 6,
                targetWorkoutIndex: 2,
                cadence: 4,
                retroactive: false,
              )
              ?.notes,
          'Current input',
        );
        expect(store.week, 6);
        expect(store.workoutIndex, 2);
      },
    );
  });

  group('custom exercise library', () {
    test(
      'fresh install needs no custom rows for the complete default program',
      () async {
        final store = AppStore();
        await store.load();

        expect(store.customExercises, isEmpty);
        expect(
          store.selectableExercises.where((item) => item.isBuiltIn),
          hasLength(BuiltInExercises.values.length),
        );
        final builtInNames = BuiltInExercises.values
            .map((exercise) => exercise.name)
            .toSet();
        for (final days in ProgramEngine.supportedCadences) {
          for (final week in ProgramEngine.year(days)) {
            for (final workout in week.workouts) {
              for (final exercise in workout.exercises) {
                expect(builtInNames, contains(exercise.name));
              }
            }
          }
        }
      },
    );

    test(
      'custom exercises add, rename, soft-delete, and persist separately',
      () async {
        final store = AppStore();
        final custom = await store.addCustomExercise(
          '  Researcher Offset Row  ',
        );
        expect(custom.name, 'Researcher Offset Row');
        expect(
          store.selectableExercises.map((item) => item.name),
          contains('Researcher Offset Row'),
        );

        await store.renameCustomExercise(custom.id, 'Researcher Cable Sweep');
        expect(store.customExercises.single.name, 'Researcher Cable Sweep');
        store.logs.add(
          SetLog(
            exercise: 'Researcher Cable Sweep',
            weight: 30,
            reps: 12,
            date: DateTime(2026, 8, 18),
            workout: 'Custom workout',
          ),
        );

        await store.archiveCustomExercise(custom.id);
        expect(store.customExercises.single.isArchived, isTrue);
        expect(
          store.selectableExercises.map((item) => item.name),
          isNot(contains('Researcher Cable Sweep')),
        );
        expect(store.logs.single.exercise, 'Researcher Cable Sweep');

        final restored = AppStore();
        await restored.load();
        expect(restored.customExercises.single.isArchived, isTrue);
        expect(restored.logs.single.exercise, 'Researcher Cable Sweep');
      },
    );

    test('built-in and custom names cannot be shadowed', () async {
      final store = AppStore();
      await expectLater(
        store.addCustomExercise('barbell bench press'),
        throwsA(isA<ArgumentError>()),
      );
      await store.addCustomExercise('Researcher Offset Row');
      await expectLater(
        store.addCustomExercise('RESEARCHER OFFSET ROW'),
        throwsA(isA<ArgumentError>()),
      );
      expect(store.customExercises, hasLength(1));
    });

    test('malformed custom rows cannot break the built-in program', () async {
      storedValue = jsonEncode({
        'schemaVersion': AppStore.schemaVersion,
        'days': 3,
        'week': 1,
        'workout': 0,
        'unit': 'lb',
        'logs': <Object>[],
        'workoutHistory': <Object>[],
        'drafts': <Object>[],
        'customExercises': [
          {'broken': true},
          {'id': '', 'name': 'Invalid'},
        ],
      });

      final store = AppStore();
      await store.load();

      expect(store.customExercises, isEmpty);
      expect(ProgramEngine.week(1, store.days).workouts, hasLength(3));
      expect(store.selectableExercises, isNotEmpty);
    });
  });

  test('exercise library covers every authored exercise', () {
    final libraryNames = BuiltInExercises.values
        .map((item) => item.name)
        .toSet();
    for (final days in ProgramEngine.supportedCadences) {
      for (final week in ProgramEngine.year(days)) {
        for (final workout in week.workouts) {
          for (final exercise in workout.exercises) {
            expect(libraryNames, contains(exercise.name));
          }
        }
      }
    }
  });

  group('athletic functional program', () {
    test('authors twelve weeks with four complete coached sessions each', () {
      expect(AthleticProgram.totalWeeks, 12);
      expect(AthleticProgram.sessionsPerWeek, 4);
      for (var weekNumber = 1; weekNumber <= 12; weekNumber++) {
        final week = AthleticProgram.week(weekNumber);
        expect(week.sessions, hasLength(4));
        expect(week.cycleNumber, ((weekNumber - 1) ~/ 4) + 1);
        for (final session in week.sessions) {
          expect(session.drills.length, greaterThanOrEqualTo(6));
          expect(session.durationMinutes, inInclusiveRange(40, 60));
          for (final drill in session.drills) {
            expect(drill.name, isNotEmpty);
            expect(drill.prescription, isNotEmpty);
            expect(drill.purpose, isNotEmpty);
            expect(drill.cues, isNotEmpty);
            expect(drill.regression, isNotEmpty);
            expect(drill.progression, isNotEmpty);
          }
        }
      }
      expect(() => AthleticProgram.week(0), throwsRangeError);
      expect(() => AthleticProgram.week(13), throwsRangeError);
    });

    test(
      'completion advances independently from the strength program',
      () async {
        final store = AppStore()
          ..week = 19
          ..workoutIndex = 2
          ..athleticWeek = 1
          ..athleticSessionIndex = 0;

        await store.completeAthleticSession(
          effort: 7,
          notes: 'Stable landings',
        );

        expect(store.week, 19);
        expect(store.workoutIndex, 2);
        expect(store.athleticWeek, 1);
        expect(store.athleticSessionIndex, 1);
        expect(store.athleticCompletedSessions, 1);
        expect(store.athleticHistory.single.effort, 7);
        expect(store.athleticHistory.single.notes, 'Stable landings');

        final restored = AppStore();
        await restored.load();
        expect(restored.week, 19);
        expect(restored.athleticWeek, 1);
        expect(restored.athleticSessionIndex, 1);
        expect(restored.athleticHistory.single.notes, 'Stable landings');
      },
    );

    test('the last session completes without silently wrapping', () async {
      final store = AppStore()
        ..athleticWeek = 12
        ..athleticSessionIndex = 3;

      await store.completeAthleticSession(effort: 8, notes: 'Final test');

      expect(store.athleticProgramComplete, isTrue);
      expect(store.athleticWeek, 12);
      expect(store.athleticSessionIndex, 3);
      await expectLater(
        store.completeAthleticSession(effort: 8, notes: ''),
        throwsStateError,
      );
    });

    test('restart creates a new run while preserving prior history', () async {
      final store = AppStore();
      await store.completeAthleticSession(effort: 6, notes: 'Run one');
      await store.restartAthleticProgram();

      expect(store.athleticProgramRun, 2);
      expect(store.athleticWeek, 1);
      expect(store.athleticSessionIndex, 0);
      expect(store.athleticHistory.single.programRun, 1);
      expect(store.athleticCompletedSessions, 0);

      await store.completeAthleticSession(effort: 5, notes: 'Run two');
      expect(store.athleticHistory, hasLength(2));
      expect(store.athleticCompletedSessions, 1);
    });

    test('field measures persist with the active athletic run', () async {
      final store = AppStore();
      await store.saveAthleticAssessment(
        AthleticAssessment(
          programRun: store.athleticProgramRun,
          recordedAt: DateTime(2026, 8, 19),
          leftBalanceSeconds: 31.2,
          rightBalanceSeconds: 29.8,
          broadJumpCentimeters: 184,
          sprint10MetersSeconds: 2.04,
          changeOfDirection505Seconds: 2.61,
          movementQuality: 4,
          notes: 'Same shoes and surface',
        ),
      );

      final restored = AppStore();
      await restored.load();
      final assessment = restored.athleticAssessments.single;
      expect(assessment.broadJumpCentimeters, 184);
      expect(assessment.movementQuality, 4);
      expect(assessment.notes, 'Same shoes and surface');
    });

    test('schema six migrates additively through the current schema', () async {
      storedValue = jsonEncode({
        'schemaVersion': 6,
        'days': 4,
        'week': 7,
        'workout': 1,
        'unit': 'lb',
        'logs': <Object>[],
        'workoutHistory': <Object>[],
        'customExercises': <Object>[],
        'drafts': <Object>[],
        'programStartDate': '2026-01-01T00:00:00.000',
      });

      final store = AppStore();
      await store.load();

      expect(store.athleticWeek, 1);
      expect(store.athleticSessionIndex, 0);
      expect(store.athleticHistory, isEmpty);
      final migrated = jsonDecode(storedValue!) as Map<String, dynamic>;
      expect(migrated['schemaVersion'], AppStore.schemaVersion);
      expect(migrated['strengthProgramRun'], 1);
      expect(migrated['athleticProgramRun'], 1);
      expect(migrated['athleticHistory'], isEmpty);
      expect(migrated['onboardingVersionSeen'], 0);
      expect(migrated['preferredTrack'], 'strength');
    });

    test('tour and preferred program choices persist locally', () async {
      final store = AppStore();

      await store.markOnboardingSeen(1);
      await store.setPreferredTrack(TrainingTrack.athletic);

      final restored = AppStore();
      await restored.load();
      expect(restored.onboardingVersionSeen, 1);
      expect(restored.preferredTrack, TrainingTrack.athletic);
    });
  });

  group('program starting positions', () {
    test(
      'a new strength run can begin at any authored phase and cycle',
      () async {
        final oldRecord = WorkoutRecord(
          week: 19,
          workoutIndex: 4,
          workout: 'Upper Body C',
          date: DateTime(2026, 8, 1),
          status: WorkoutStatus.completed,
          programRun: 1,
          days: 5,
        );
        final activeDraft = DraftSetInput(
          week: 2,
          workoutIndex: 0,
          workout: 'Upper Body A',
          exerciseIndex: 0,
          setNumber: 1,
          sessionId: 'active-draft',
          weight: '185',
          reps: '6',
          notes: '',
          programRun: 1,
        );
        final store = AppStore()
          ..days = 4
          ..week = 2
          ..workoutIndex = 0
          ..strengthProgramRun = 1
          ..workoutHistory = [oldRecord]
          ..draft = activeDraft
          ..drafts = [activeDraft];

        await store.setStrengthProgramPosition(
          phase: 2,
          microcycle: 3,
          cadence: 5,
          nextWorkoutIndex: 4,
          nextWorkoutDate: DateTime(2026, 9, 1),
          startNewRun: true,
        );

        expect(store.strengthProgramRun, 2);
        expect(store.week, 19);
        expect(store.days, 5);
        expect(store.workoutIndex, 4);
        expect(store.dateForSlot(19, 4), DateTime(2026, 9, 1));
        expect(store.workoutHistory, [oldRecord]);
        expect(store.recordsForSlot(19, 4), isEmpty);
        expect(store.draft, isNull);
        expect(store.drafts, isEmpty);

        final restored = AppStore();
        await restored.load();
        expect(restored.strengthProgramRun, 2);
        expect(restored.week, 19);
        expect(restored.days, 5);
        expect(restored.workoutIndex, 4);
        expect(restored.dateForSlot(19, 4), DateTime(2026, 9, 1));
        expect(restored.workoutHistory.single.programRun, 1);
      },
    );

    test(
      'moving within a run rejects an already-recorded target workout',
      () async {
        final store = AppStore()
          ..days = 4
          ..week = 1
          ..workoutIndex = 0
          ..strengthProgramRun = 3
          ..workoutHistory = [
            WorkoutRecord(
              week: 17,
              workoutIndex: 0,
              workout: 'Upper Body A',
              date: DateTime(2026, 8, 1),
              status: WorkoutStatus.completed,
              programRun: 3,
              days: 4,
            ),
          ];

        expect(
          store.setStrengthProgramPosition(
            phase: 2,
            microcycle: 1,
            cadence: 4,
            nextWorkoutIndex: 0,
            nextWorkoutDate: DateTime(2026, 9, 1),
            startNewRun: false,
          ),
          throwsStateError,
        );
        expect(store.week, 1);
        expect(store.strengthProgramRun, 3);
      },
    );

    test(
      'athletic training can start at a selected cycle and session',
      () async {
        final previous = AthleticSessionRecord(
          programRun: 1,
          week: 6,
          sessionIndex: 2,
          completedAt: DateTime(2026, 8, 1),
          effort: 7,
        );
        final store = AppStore()
          ..athleticProgramRun = 1
          ..athleticHistory = [previous];

        await store.setAthleticProgramPosition(
          weekNumber: 6,
          sessionIndex: 2,
          nextSessionDate: DateTime(2026, 9, 3),
          startNewRun: true,
        );

        expect(store.athleticProgramRun, 2);
        expect(store.athleticWeek, 6);
        expect(store.athleticSessionIndex, 2);
        expect(store.athleticDateForSlot(6, 2), DateTime(2026, 9, 3));
        expect(store.currentAthleticRunHistory, isEmpty);
        expect(store.athleticHistory, [previous]);
      },
    );
  });
}
