import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:progression_lab/brand.dart';
import 'package:progression_lab/main.dart';
import 'package:progression_lab/program.dart';
import 'package:progression_lab/store.dart';
import 'package:progression_lab/warmup.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const storageChannel = MethodChannel('iron_cadence/storage');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storageChannel, (call) async {
          if (call.method == 'write' || call.method == 'read') return null;
          throw PlatformException(code: 'unknown_method');
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storageChannel, null);
  });

  group('automatic compound warm-ups', () {
    test('uses the 50-percent by 6 and 70-percent by 4 ramp', () {
      final recommendation = WarmupCalculator.calculate(
        exercise: 'Barbell Bench Press',
        isPrimary: true,
        workingWeight: 185,
        workingReps: 6,
        unit: 'lb',
      );

      expect(recommendation, isNotNull);
      expect(recommendation!.sets, hasLength(2));
      expect(recommendation.sets[0].weight, 95);
      expect(recommendation.sets[0].reps, 6);
      expect(recommendation.sets[1].weight, 130);
      expect(recommendation.sets[1].reps, 4);
    });

    test('rounds kilogram recommendations to practical plate increments', () {
      final recommendation = WarmupCalculator.calculate(
        exercise: 'Barbell Back Squat',
        isPrimary: true,
        workingWeight: 107.5,
        workingReps: 5,
        unit: 'kg',
      );

      expect(recommendation, isNotNull);
      expect(recommendation!.sets.map((set) => set.weight), [55, 75]);
    });

    test('does not recommend warm-ups for isolation or secondary work', () {
      expect(
        WarmupCalculator.calculate(
          exercise: 'Dumbbell Side Raise',
          isPrimary: true,
          workingWeight: 20,
          workingReps: 10,
          unit: 'lb',
        ),
        isNull,
      );
      expect(
        WarmupCalculator.calculate(
          exercise: 'Barbell Bench Press',
          isPrimary: false,
          workingWeight: 185,
          workingReps: 6,
          unit: 'lb',
        ),
        isNull,
      );
    });

    testWidgets('shows the warm-up above the first compound working set', (
      tester,
    ) async {
      final store = AppStore()
        ..unit = 'lb'
        ..logs = [
          SetLog(
            exercise: 'Barbell Bench Press',
            weight: 185,
            reps: 6,
            date: DateTime(2026, 8, 19),
            workout: 'Upper Body A',
            sessionId: 'previous-session',
          ),
        ];
      final week = ProgramEngine.week(1, 4);
      final workout = week.workouts.first;

      await tester.pumpWidget(
        MaterialApp(
          theme: ProgressionBrand.theme(),
          home: WorkoutScreen(
            store: store,
            week: week,
            workout: workout,
            workoutIndex: 0,
            scheduledDate: DateTime(2026, 8, 20),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('AUTOMATIC WARM-UP'), findsOneWidget);
      expect(find.text('95 lb × 6'), findsOneWidget);
      expect(find.text('130 lb × 4'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  });
}
