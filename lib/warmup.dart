import 'dart:math' as math;

import 'exercise_library.dart';

class WarmupSetRecommendation {
  const WarmupSetRecommendation({
    required this.weight,
    required this.reps,
    required this.percentage,
  });

  final double weight;
  final int reps;
  final int percentage;
}

class WarmupRecommendation {
  const WarmupRecommendation({
    required this.exercise,
    required this.workingWeight,
    required this.workingReps,
    required this.unit,
    required this.sets,
  });

  final String exercise;
  final double workingWeight;
  final int workingReps;
  final String unit;
  final List<WarmupSetRecommendation> sets;
}

/// Builds the short ramp-up used in Mike Matthews' Bigger Leaner Stronger
/// guidance: 6 reps at about 50% of the hard-set weight, then 4 reps at about
/// 70%. The recommendation is intentionally limited to primary compound lifts.
abstract final class WarmupCalculator {
  static final Set<String> _compoundExercises = {
    BuiltInExercises.barbellBenchPress.name,
    BuiltInExercises.closeGripBenchPress.name,
    BuiltInExercises.inclineBarbellBench.name,
    BuiltInExercises.reverseGripBenchPress.name,
    BuiltInExercises.dumbbellBenchPress.name,
    BuiltInExercises.inclineDumbbellPress.name,
    BuiltInExercises.standingMilitaryPress.name,
    BuiltInExercises.seatedMilitaryPress.name,
    BuiltInExercises.pushPress.name,
    BuiltInExercises.dumbbellShoulderPress.name,
    BuiltInExercises.barbellDeadlift.name,
    BuiltInExercises.trapBarDeadlift.name,
    BuiltInExercises.sumoDeadlift.name,
    BuiltInExercises.romanianDeadlift.name,
    BuiltInExercises.barbellRow.name,
    BuiltInExercises.tBarRow.name,
    BuiltInExercises.oneArmDumbbellRow.name,
    BuiltInExercises.barbellBackSquat.name,
    BuiltInExercises.barbellFrontSquat.name,
    BuiltInExercises.legPress.name,
    BuiltInExercises.hackSquat.name,
  };

  static final Set<String> _barbellOrTrapBarExercises = {
    BuiltInExercises.barbellBenchPress.name,
    BuiltInExercises.closeGripBenchPress.name,
    BuiltInExercises.inclineBarbellBench.name,
    BuiltInExercises.reverseGripBenchPress.name,
    BuiltInExercises.standingMilitaryPress.name,
    BuiltInExercises.seatedMilitaryPress.name,
    BuiltInExercises.pushPress.name,
    BuiltInExercises.barbellDeadlift.name,
    BuiltInExercises.trapBarDeadlift.name,
    BuiltInExercises.sumoDeadlift.name,
    BuiltInExercises.romanianDeadlift.name,
    BuiltInExercises.barbellRow.name,
    BuiltInExercises.barbellBackSquat.name,
    BuiltInExercises.barbellFrontSquat.name,
  };

  static bool supports(String exercise) => _compoundExercises.contains(exercise);

  static WarmupRecommendation? calculate({
    required String exercise,
    required bool isPrimary,
    required double? workingWeight,
    required int? workingReps,
    required String unit,
  }) {
    if (!isPrimary || !supports(exercise)) return null;
    if (workingWeight == null || workingWeight <= 0) return null;
    if (workingReps == null || workingReps <= 0) return null;

    final normalizedUnit = unit.toLowerCase() == 'kg' ? 'kg' : 'lb';
    final increment = normalizedUnit == 'kg' ? 2.5 : 5.0;
    final minimumBarWeight = normalizedUnit == 'kg' ? 20.0 : 45.0;
    final hasStandardBar = _barbellOrTrapBarExercises.contains(exercise);

    double practicalWeight(double percentage) {
      var value = _roundToIncrement(workingWeight * percentage, increment);
      if (hasStandardBar && workingWeight > minimumBarWeight) {
        value = math.max(value, minimumBarWeight);
      }
      return math.min(value, workingWeight);
    }

    final candidates = <WarmupSetRecommendation>[
      WarmupSetRecommendation(
        weight: practicalWeight(.50),
        reps: 6,
        percentage: 50,
      ),
      WarmupSetRecommendation(
        weight: practicalWeight(.70),
        reps: 4,
        percentage: 70,
      ),
    ];

    final sets = <WarmupSetRecommendation>[];
    for (final candidate in candidates) {
      if (candidate.weight <= 0 || candidate.weight >= workingWeight) continue;
      if (sets.isNotEmpty && sets.last.weight == candidate.weight) continue;
      sets.add(candidate);
    }
    if (sets.isEmpty) return null;

    return WarmupRecommendation(
      exercise: exercise,
      workingWeight: workingWeight,
      workingReps: workingReps,
      unit: normalizedUnit,
      sets: List.unmodifiable(sets),
    );
  }

  static double _roundToIncrement(double value, double increment) =>
      (value / increment).round() * increment;
}
