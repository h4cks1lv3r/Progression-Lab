import 'lab_data.dart';

/// Definitions shared by automatic insights and newly created experiments.
/// These are analysis categories, not recommended caffeine doses or sleep goals.
abstract final class LabConditionDefinitions {
  static const version = 2;
  static const caffeineMinimumMg = 25.0;
  static const caffeineMinimumLeadMinutes = 20;
  static const caffeineWindowMinutes = 180;
  static const sleepTargetHours = 7.0;

  static const caffeineWithLabel =
      '25+ mg logged 20–180 minutes before workout start';
  static const caffeineWithoutLabel =
      '0 mg logged 20–180 minutes before workout start';
  static const caffeineComparison =
      '$caffeineWithLabel vs $caffeineWithoutLabel. '
      'Totals above 0 and below 25 mg are excluded. Both window endpoints are included.';
  static const sleepComparison =
      '7+ hours vs under 7 hours of previous-night sleep, from the recovery entry '
      'on the workout’s local date. Workouts without a sleep entry are excluded.';
  static const strengthEstimateExplanation =
      'Estimated one-rep max (e1RM) predicts the weight you might lift once from '
      'a saved weight and rep count. It is an estimate, not a tested maximum.';

  static double caffeineBeforeWorkout(
    Map<String, dynamic> state,
    DateTime workoutStart, {
    int windowMinutes = caffeineWindowMinutes,
    int minimumLeadMinutes = caffeineMinimumLeadMinutes,
  }) {
    final start = workoutStart.subtract(Duration(minutes: windowMinutes));
    final end = workoutStart.subtract(Duration(minutes: minimumLeadMinutes));
    var total = 0.0;
    for (final event in labMaps(state['supplementEvents'])) {
      final time = labDate(event['takenAt']);
      final dose = (event['caffeineMg'] as num?)?.toDouble();
      if (time == null ||
          dose == null ||
          !dose.isFinite ||
          dose <= 0 ||
          time.isBefore(start) ||
          time.isAfter(end)) {
        continue;
      }
      total += dose;
    }
    return total;
  }

  /// Recovery.localDate is a calendar label. It must never be shifted by UTC
  /// conversion. Workout timestamps are instants and use the device's local day.
  static Map<String, dynamic>? recoveryForWorkoutDay(
    Map<String, dynamic> state,
    DateTime workoutStart, {
    DateTime Function(DateTime)? localize,
  }) {
    final localStart = (localize ?? _deviceLocal)(workoutStart);
    for (final entry in labMaps(state['recoveryCheckIns']).reversed) {
      final day = labDate(entry['localDate']);
      if (day != null &&
          day.year == localStart.year &&
          day.month == localStart.month &&
          day.day == localStart.day) {
        return entry;
      }
    }
    return null;
  }

  static double? sleepHoursForWorkout(
    Map<String, dynamic> state,
    DateTime workoutStart, {
    DateTime Function(DateTime)? localize,
  }) {
    final entry = recoveryForWorkoutDay(
      state,
      workoutStart,
      localize: localize,
    );
    final hours = (entry?['sleepHours'] as num?)?.toDouble();
    return hours != null && hours.isFinite && hours >= 0 && hours <= 24
        ? hours
        : null;
  }

  static DateTime _deviceLocal(DateTime value) => value.toLocal();
}
