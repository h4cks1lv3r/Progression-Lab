import 'package:flutter_test/flutter_test.dart';
import 'package:progression_lab/exercise_library.dart';

void main() {
  group('Exercise Library 2.0 catalog', () {
    test('contains a large reviewed catalog with stable unique identities', () {
      expect(BuiltInExercises.values.length, greaterThanOrEqualTo(250));
      expect(ExerciseLibrary.validateCatalog, returnsNormally);

      final ids = BuiltInExercises.values
          .map((exercise) => exercise.id)
          .toSet();
      final names = BuiltInExercises.values
          .map((exercise) => ExerciseLibrary.normalize(exercise.name))
          .toSet();
      expect(ids.length, BuiltInExercises.values.length);
      expect(names.length, BuiltInExercises.values.length);
    });

    test('provides full Abs and Core coverage', () {
      const coreMuscles = {
        MuscleGroup.absCore,
        MuscleGroup.rectusAbdominis,
        MuscleGroup.obliques,
        MuscleGroup.deepCore,
        MuscleGroup.spinalStabilizers,
      };
      final coreExercises = BuiltInExercises.values
          .where((exercise) => coreMuscles.contains(exercise.primaryMuscle))
          .toList();

      expect(coreExercises.length, greaterThanOrEqualTo(40));
      expect(
        coreExercises.map((exercise) => exercise.name),
        containsAll(<String>[
          'Captain’s Chair Leg Lift',
          'Captain’s Chair Knee Raise',
          'Ab-Wheel Rollout — Kneeling',
          'Pallof Press',
          'Weighted Plank',
        ]),
      );
    });

    test('Captain’s Chair Leg Lift is a bodyweight exercise with aliases', () {
      final exercise = ExerciseLibrary.builtInById('captains_chair_leg_lift');
      expect(exercise, isNotNull);
      expect(exercise!.equipment, ExerciseEquipment.bodyweight);
      expect(exercise.trackingType, ExerciseTrackingType.bodyweightReps);
      expect(exercise.trackingType.usesWeight, isFalse);
      expect(exercise.warmupEligible, isFalse);
      expect(
        exercise.aliases,
        containsAll(<String>[
          'Captain’s Chair Leg Raise',
          'Captains Chair Leg Lift',
          'Vertical Knee Raise Station Leg Raise',
        ]),
      );
      expect(
        ExerciseLibrary.builtInByName('Captain Chair Leg Raise')?.id,
        'captains_chair_leg_lift',
      );
      expect(
        ExerciseLibrary.builtInByName(
          'Vertical Knee Raise Station Leg Raise',
        )?.id,
        'captains_chair_leg_lift',
      );
    });

    test('standard bodyweight exercises never require weight input', () {
      for (final id in <String>[
        'bodyweight_squat',
        'push_up',
        'pull_up',
        'chin_up',
        'front_plank',
      ]) {
        final exercise = ExerciseLibrary.builtInById(id);
        expect(exercise, isNotNull, reason: 'Missing $id');
        expect(
          exercise!.trackingType.usesWeight,
          isFalse,
          reason: '$id must not expose a required weight field',
        );
        expect(
          exercise.warmupEligible,
          isFalse,
          reason: '$id must not receive the barbell percentage warm-up ramp',
        );
      }
    });

    test(
      'weighted and assisted bodyweight variants keep distinct semantics',
      () {
        final weighted = ExerciseLibrary.builtInById('weighted_pull_up');
        final assisted = ExerciseLibrary.builtInById('assisted_pull_up');

        expect(weighted, isNotNull);
        expect(weighted!.trackingType, ExerciseTrackingType.weightedBodyweight);
        expect(weighted.trackingType.weightLabel, 'ADDED WEIGHT');
        expect(weighted.trackingType.requiresPositiveWeight, isFalse);

        expect(assisted, isNotNull);
        expect(assisted!.trackingType, ExerciseTrackingType.assistedBodyweight);
        expect(assisted.trackingType.weightLabel, 'ASSISTANCE');
        expect(assisted.trackingType.performanceLabel, 'Lowest Assistance');
      },
    );

    test('search resolves common aliases and abbreviations', () {
      expect(ExerciseLibrary.builtInByName('RDL')?.id, isNotNull);
      expect(ExerciseLibrary.builtInByName('OHP')?.id, isNotNull);
      expect(ExerciseLibrary.builtInByName('Pullup')?.id, 'pull_up');
      expect(
        ExerciseLibrary.builtInByName('Captain’s Chair Leg Raise')?.id,
        'captains_chair_leg_lift',
      );
    });
  });
}
