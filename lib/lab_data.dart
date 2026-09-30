import 'body_progress.dart';
import 'daily_inputs.dart';

/// Apply inclusion choices before building comparisons or AI evidence. A
/// comparison never gets access to a domain that the user excluded.
Map<String, dynamic> selectedLabState(Map<String, dynamic> state) {
  final raw = state['labDataDomains'];
  final domains = raw is List
      ? raw.map((value) => '$value').toSet()
      : LabDataDomain.values.map((domain) => domain.name).toSet();
  final selected = Map<String, dynamic>.of(state);
  void exclude(String domain, List<String> keys) {
    if (domains.contains(domain)) return;
    for (final key in keys) {
      selected[key] = <Object>[];
    }
  }

  exclude('workouts', [
    'logs',
    'workoutHistory',
    'importedWorkouts',
    'workoutResponses',
  ]);
  if (!domains.contains('workouts')) {
    selected['openWorkout'] = <String, dynamic>{};
    selected['curatedTraining'] = <String, dynamic>{};
  }
  exclude('supplements', ['supplementEvents', 'supplementPresets']);
  exclude('meals', ['mealEvents']);
  exclude('hydration', ['hydrationEvents']);
  exclude('recovery', ['recoveryCheckIns', 'workoutResponses']);
  exclude('athletic', ['athleticHistory', 'athleticAssessments']);
  if (!domains.contains('bodyMetrics')) {
    selected['bodyMeasurements'] = <Object>[];
    selected['recoveryCheckIns'] = labMaps(selected['recoveryCheckIns'])
        .map(
          (value) => {...value}
            ..remove('bodyWeight')
            ..remove('weightUnit'),
        )
        .toList();
  }
  return selected;
}

/// Current Body measurements use canonical kilograms. Legacy recovery weights
/// fill missing days only; they cannot duplicate or override a current reading.
List<BodyMeasurement> labDailyWeights(Map<String, dynamic> state) {
  final measurements = <BodyMeasurement>[];
  for (final raw in labMaps(state['bodyMeasurements'])) {
    try {
      final reading = BodyMeasurement.fromJson(raw);
      if (reading.valid) measurements.add(reading);
    } on Object {
      // A malformed imported reading cannot invalidate the rest of the history.
    }
  }
  final settings = state['bodySettings'];
  final source = settings is Map
      ? '${settings['weightSource'] ?? 'manual'}'
      : 'manual';
  final current = BodyAnalysis.dailyWeights(measurements, source: source);
  final days = current.map((reading) => reading.date).toSet();
  final legacy = <String, BodyMeasurement>{};
  for (final item in labMaps(state['recoveryCheckIns'])) {
    final value = (item['bodyWeight'] as num?)?.toDouble();
    final day = labDate(item['localDate']);
    if (value == null || !value.isFinite || value <= 0 || day == null) continue;
    final key = bodyDay(day);
    if (days.contains(key)) continue;
    final unit = '${item['weightUnit'] ?? state['unit'] ?? 'lb'}';
    if (unit != 'kg' && unit != 'lb') continue;
    final recordedAt = labDate(item['updatedAt'] ?? item['createdAt']) ?? day;
    final reading = BodyMeasurement(
      id: '${item['id'] ?? 'legacy-$key'}',
      metric: BodyMetric.weight,
      value: BodyMeasurement.canonical(BodyMetric.weight, value, unit),
      date: key,
      recordedAt: recordedAt,
      source: 'legacy-recovery',
      originalUnit: unit,
      originalValue: value,
    );
    if (legacy[key] == null || recordedAt.isAfter(legacy[key]!.recordedAt)) {
      legacy[key] = reading;
    }
  }
  return [...current, ...legacy.values]
    ..sort((a, b) => a.date.compareTo(b.date));
}

class LabCompletedSession {
  const LabCompletedSession({
    required this.id,
    required this.workoutName,
    required this.occurredAt,
    required this.mode,
    required this.logs,
    this.week,
    this.days,
  });

  final String id, workoutName, mode;
  final DateTime occurredAt;
  final List<Map<String, dynamic>> logs;
  final int? week, days;

  /// Only the same movements and tracking rules can be compared. Generic
  /// “Open Workout” names must not pool bench presses with unrelated squats.
  String comparisonKey({String? exerciseFilter}) {
    final exercises =
        logs
            .where(
              (log) =>
                  exerciseFilter == null ||
                  labExerciseName(
                    log,
                  ).toLowerCase().contains(exerciseFilter.toLowerCase()),
            )
            .map(
              (log) =>
                  '${labExerciseKey(log)}:${log['trackingType'] ?? 'weightReps'}',
            )
            .toSet()
            .toList()
          ..sort();
    return exercises.join('|');
  }
}

List<LabCompletedSession> labCompletedSessions(Map<String, dynamic> state) {
  final logs = labMaps(state['logs']);
  final result = <LabCompletedSession>[];
  final seen = <String>{};
  void add(Map<String, dynamic> record, String mode) {
    final status = '${record['status'] ?? 'completed'}';
    if (status != 'completed') return;
    final time = labDate(record['startedAt'] ?? record['date']);
    if (time == null) return;
    // Entering a past workout today must join its performed day, never the
    // entry timestamp or the active clock's start.
    final performed = mode == 'strength'
        ? labDate(record['date']) ?? time
        : time;
    final name =
        '${record['workout'] ?? record['title'] ?? record['name'] ?? (mode == 'open' ? 'Open Workout' : 'Workout')}';
    final id =
        '${record['sessionId'] ?? '${performed.microsecondsSinceEpoch}-$name'}';
    if (!seen.add(id)) return;
    final sessionLogs = logs.where((log) {
      final logId = '${log['s'] ?? log['sessionId'] ?? ''}';
      if (logId.isNotEmpty) return logId == id;
      final date = labDate(log['d'] ?? log['date']);
      return date != null &&
          bodyDay(date) == bodyDay(performed) &&
          '${log['o'] ?? log['workout'] ?? ''}' == name;
    }).toList();
    final explicitlyPerformed =
        (mode == 'strength' || mode == 'imported') &&
        (record['retroactive'] == true || record['importedWorkoutId'] != null);
    final logTimes =
        sessionLogs
            .map((log) => labDate(log['d'] ?? log['date']))
            .whereType<DateTime>()
            .toList()
          ..sort();
    final originalStart = labDate(record['startedAt']);
    // Ordinary records date their finish. Habit windows belong before the
    // original start (or first saved set in older data), not before finishing.
    // Keep a performed-day join for legacy records without a session ID.
    final useOriginalStart =
        originalStart != null &&
        (record['sessionId'] != null ||
            bodyDay(originalStart) == bodyDay(performed));
    final occurredAt = explicitlyPerformed
        ? performed
        : useOriginalStart
        ? originalStart
        : logTimes.firstOrNull ?? performed;
    result.add(
      LabCompletedSession(
        id: id,
        workoutName: name,
        occurredAt: occurredAt,
        mode: mode,
        logs: sessionLogs,
        week: (record['week'] as num?)?.toInt(),
        days: (record['days'] as num?)?.toInt(),
      ),
    );
  }

  for (final record in labMaps(state['workoutHistory'])) {
    add(record, 'strength');
  }
  // Imports do not need a Strength-program assignment to contribute history.
  // Assigned partial/skipped records retain that status and are not counted a
  // second time as standalone imports.
  final assignedImports = labMaps(
    state['workoutHistory'],
  ).map((record) => record['importedWorkoutId']).whereType<String>().toSet();
  for (final record in labMaps(state['importedWorkouts'])) {
    if (assignedImports.contains(record['id'])) continue;
    add({
      ...record,
      'importedWorkoutId': record['id'],
      'date': record['startedAt'],
    }, 'imported');
  }
  final open = state['openWorkout'];
  for (final record in labMaps(open is Map ? open['history'] : null)) {
    add(record, 'open');
  }
  final curated = state['curatedTraining'];
  for (final record in labMaps(curated is Map ? curated['history'] : null)) {
    add(record, 'iconic');
  }
  return result..sort((a, b) => a.occurredAt.compareTo(b.occurredAt));
}

String labExerciseName(Map<String, dynamic> log) =>
    '${log['e'] ?? log['exercise'] ?? ''}';
String labExerciseKey(Map<String, dynamic> log) {
  final id = '${log['exerciseId'] ?? ''}'.trim();
  return id.isEmpty ? labExerciseName(log).trim().toLowerCase() : id;
}

List<Map<String, dynamic>> labMaps(Object? value) => value is List
    ? [
        for (final item in value)
          if (item is Map) Map<String, dynamic>.from(item),
      ]
    : [];
DateTime? labDate(Object? value) =>
    value is String ? DateTime.tryParse(value) : null;
