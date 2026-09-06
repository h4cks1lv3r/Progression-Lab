import 'store.dart';
import 'exercise_models.dart';

enum ExerciseMetric {
  estimatedOneRepMax,
  weight,
  addedWeight,
  assistance,
  reps,
  volume,
  duration,
  distance,
  speed,
  loadTime,
  loadDistance,
  repsDistance,
  calories,
}

extension ExerciseMetricInfo on ExerciseMetric {
  String get label => switch (this) {
    ExerciseMetric.estimatedOneRepMax => 'Estimated 1RM',
    ExerciseMetric.weight => 'Working weight',
    ExerciseMetric.addedWeight => 'Added weight',
    ExerciseMetric.assistance => 'Assistance',
    ExerciseMetric.reps => 'Repetitions',
    ExerciseMetric.volume => 'Set volume',
    ExerciseMetric.duration => 'Duration',
    ExerciseMetric.distance => 'Distance',
    ExerciseMetric.speed => 'Speed',
    ExerciseMetric.loadTime => 'Load × time',
    ExerciseMetric.loadDistance => 'Load × distance',
    ExerciseMetric.repsDistance => 'Reps × distance',
    ExerciseMetric.calories => 'Calories',
  };
  bool get lowerIsBetter => this == ExerciseMetric.assistance;
  String unit(String weightUnit) => switch (this) {
    ExerciseMetric.estimatedOneRepMax ||
    ExerciseMetric.weight ||
    ExerciseMetric.addedWeight ||
    ExerciseMetric.assistance => weightUnit,
    ExerciseMetric.reps => 'reps',
    ExerciseMetric.volume => '$weightUnit·reps',
    ExerciseMetric.duration => 'sec',
    ExerciseMetric.distance => 'm',
    ExerciseMetric.speed => 'm/s',
    ExerciseMetric.loadTime => '$weightUnit·sec',
    ExerciseMetric.loadDistance => '$weightUnit·m',
    ExerciseMetric.repsDistance => 'reps·m',
    ExerciseMetric.calories => 'kcal',
  };
  double value(SetLog log) => switch (this) {
    ExerciseMetric.estimatedOneRepMax => log.e1rm,
    ExerciseMetric.weight ||
    ExerciseMetric.addedWeight ||
    ExerciseMetric.assistance => log.weight,
    ExerciseMetric.reps => log.reps.toDouble(),
    ExerciseMetric.volume => log.standardVolume,
    ExerciseMetric.duration => (log.durationSeconds ?? 0).toDouble(),
    ExerciseMetric.distance => distanceMeters(log),
    ExerciseMetric.speed =>
      (log.durationSeconds ?? 0) > 0
          ? distanceMeters(log) / log.durationSeconds!
          : 0,
    ExerciseMetric.loadTime => log.weight * (log.durationSeconds ?? 0),
    ExerciseMetric.loadDistance => log.weight * distanceMeters(log),
    ExerciseMetric.repsDistance => log.reps * distanceMeters(log),
    ExerciseMetric.calories => log.calories ?? 0,
  };
}

double distanceMeters(SetLog log) => log.distanceInMeters;

List<ExerciseMetric> metricsFor(ExerciseTrackingType type) => switch (type) {
  ExerciseTrackingType.weightReps => [
    ExerciseMetric.estimatedOneRepMax,
    ExerciseMetric.weight,
    ExerciseMetric.reps,
    ExerciseMetric.volume,
  ],
  ExerciseTrackingType.weightedBodyweight => [
    ExerciseMetric.addedWeight,
    ExerciseMetric.reps,
    ExerciseMetric.volume,
  ],
  ExerciseTrackingType.assistedBodyweight => [
    ExerciseMetric.assistance,
    ExerciseMetric.reps,
  ],
  ExerciseTrackingType.bodyweightReps ||
  ExerciseTrackingType.repsOnly => [ExerciseMetric.reps],
  ExerciseTrackingType.weightOnly => [ExerciseMetric.weight],
  ExerciseTrackingType.duration => [ExerciseMetric.duration],
  ExerciseTrackingType.durationWeight => [
    ExerciseMetric.loadTime,
    ExerciseMetric.duration,
    ExerciseMetric.weight,
  ],
  ExerciseTrackingType.distanceDuration => [
    ExerciseMetric.distance,
    ExerciseMetric.speed,
    ExerciseMetric.duration,
  ],
  ExerciseTrackingType.weightDistance => [
    ExerciseMetric.loadDistance,
    ExerciseMetric.distance,
    ExerciseMetric.weight,
  ],
  ExerciseTrackingType.repsDuration => [
    ExerciseMetric.reps,
    ExerciseMetric.duration,
  ],
  ExerciseTrackingType.repsDistance => [
    ExerciseMetric.repsDistance,
    ExerciseMetric.reps,
    ExerciseMetric.distance,
  ],
  ExerciseTrackingType.distanceOnly => [ExerciseMetric.distance],
  ExerciseTrackingType.caloriesDuration => [
    ExerciseMetric.calories,
    ExerciseMetric.duration,
  ],
};

String metricNumber(double value) => !value.isFinite
    ? '—'
    : value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toStringAsFixed(1);
String setDescription(SetLog log, String unit) {
  final type = log.resolvedTrackingType;
  final parts = <String>[];
  if (type.usesWeight)
    parts.add(
      '${type == ExerciseTrackingType.weightedBodyweight ? '+' : ''}${metricNumber(log.weight)} $unit${type == ExerciseTrackingType.assistedBodyweight ? ' assistance' : ''}',
    );
  if (type.usesReps) parts.add('${log.reps} reps');
  if (type.usesDuration) parts.add('${log.durationSeconds ?? 0} sec');
  if (type.usesDistance)
    parts.add('${metricNumber(log.distance ?? 0)} ${log.distanceUnit ?? 'm'}');
  if (type.usesCalories) parts.add('${metricNumber(log.calories ?? 0)} kcal');
  return parts.join(' · ');
}

bool supportsStrengthEstimate(SetLog log) =>
    log.resolvedTrackingType == ExerciseTrackingType.weightReps &&
    log.weight > 0 &&
    log.reps > 0 &&
    log.e1rm.isFinite;
