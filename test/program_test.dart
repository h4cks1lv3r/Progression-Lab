import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
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
      expect(
        ProgramEngine.week(1, 4).workouts[mapped].name,
        'Legs & Calves',
      );
    });

    test('maps the fifth session to its closest four-day equivalent', () {
      final mapped = ProgramEngine.defaultWorkoutIndexForCadenceSwitch(
        week: 20,
        fromDays: 5,
        toDays: 4,
        currentWorkoutIndex: 4,
      );
      expect(mapped, 2);
      expect(
        ProgramEngine.week(20, 4).workouts[mapped].name,
        'Upper Body B',
      );
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
    test('default cadence switch preserves week and maps next workout', () async {
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
    });

    test('explicit next workout wins without resetting the microcycle', () async {
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
    });

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

    test('load repairs cadence, week, workout, unit, and bad log rows', () async {
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
    });

    test('completion uses the current cadence and wraps after week 48', () async {
      final store = AppStore()
        ..days = 3
        ..week = 48
        ..workoutIndex = 2;

      await store.complete(5); // Deliberately stale count from an old cadence.

      expect(store.week, 1);
      expect(store.workoutIndex, 0);
    });

    test('failed cadence persistence rolls back the in-memory switch', () async {
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
    });
  });

  group('unit conversion', () {
    test('switching units converts every historical weight exactly once', () async {
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
    });

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

      await expectLater(
        store.setUnit('kg'),
        throwsA(isA<PlatformException>()),
      );

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
}
