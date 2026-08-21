import 'dart:convert';
import 'dart:math' as math;

import 'package:shared_preferences/shared_preferences.dart';

import 'store.dart';

enum ExperimentVariable {
  caffeine,
  creatineConsistency,
  preWorkoutMeal,
  sleepDuration,
  hydration,
  custom,
}

enum ExperimentMetric {
  estimatedStrength,
  volume,
  repetitions,
  sessionEnergy,
  athleticAssessment,
}

enum ExperimentStatus { draft, collecting, ready, completed, paused }

class PersonalExperiment {
  const PersonalExperiment({
    required this.id,
    required this.name,
    required this.variable,
    required this.metric,
    required this.startedAt,
    required this.minimumMatchedSessions,
    required this.durationDays,
    this.status = ExperimentStatus.collecting,
    this.conditionLabel = '',
    this.controlLabel = '',
    this.notes = '',
  });

  final String id;
  final String name;
  final ExperimentVariable variable;
  final ExperimentMetric metric;
  final DateTime startedAt;
  final int minimumMatchedSessions;
  final int durationDays;
  final ExperimentStatus status;
  final String conditionLabel;
  final String controlLabel;
  final String notes;

  PersonalExperiment copyWith({
    String? name,
    ExperimentVariable? variable,
    ExperimentMetric? metric,
    DateTime? startedAt,
    int? minimumMatchedSessions,
    int? durationDays,
    ExperimentStatus? status,
    String? conditionLabel,
    String? controlLabel,
    String? notes,
  }) => PersonalExperiment(
    id: id,
    name: name ?? this.name,
    variable: variable ?? this.variable,
    metric: metric ?? this.metric,
    startedAt: startedAt ?? this.startedAt,
    minimumMatchedSessions:
        minimumMatchedSessions ?? this.minimumMatchedSessions,
    durationDays: durationDays ?? this.durationDays,
    status: status ?? this.status,
    conditionLabel: conditionLabel ?? this.conditionLabel,
    controlLabel: controlLabel ?? this.controlLabel,
    notes: notes ?? this.notes,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'variable': variable.name,
    'metric': metric.name,
    'startedAt': startedAt.toIso8601String(),
    'minimumMatchedSessions': minimumMatchedSessions,
    'durationDays': durationDays,
    'status': status.name,
    'conditionLabel': conditionLabel,
    'controlLabel': controlLabel,
    'notes': notes,
  };

  factory PersonalExperiment.fromJson(Map<String, dynamic> json) =>
      PersonalExperiment(
        id: '${json['id']}',
        name: '${json['name']}',
        variable: ExperimentVariable.values.firstWhere(
          (value) => value.name == json['variable'],
          orElse: () => ExperimentVariable.custom,
        ),
        metric: ExperimentMetric.values.firstWhere(
          (value) => value.name == json['metric'],
          orElse: () => ExperimentMetric.estimatedStrength,
        ),
        startedAt: DateTime.parse('${json['startedAt']}'),
        minimumMatchedSessions:
            (json['minimumMatchedSessions'] as num?)?.toInt() ?? 8,
        durationDays: (json['durationDays'] as num?)?.toInt() ?? 28,
        status: ExperimentStatus.values.firstWhere(
          (value) => value.name == json['status'],
          orElse: () => ExperimentStatus.collecting,
        ),
        conditionLabel: '${json['conditionLabel'] ?? ''}',
        controlLabel: '${json['controlLabel'] ?? ''}',
        notes: '${json['notes'] ?? ''}',
      );
}

class ExperimentResult {
  const ExperimentResult({
    required this.experiment,
    required this.conditionSamples,
    required this.controlSamples,
    required this.conditionAverage,
    required this.controlAverage,
    required this.effectPercent,
    required this.confidence,
    required this.confounders,
  });

  final PersonalExperiment experiment;
  final int conditionSamples;
  final int controlSamples;
  final double? conditionAverage;
  final double? controlAverage;
  final double? effectPercent;
  final String confidence;
  final List<String> confounders;

  bool get hasEnoughData =>
      conditionSamples >= experiment.minimumMatchedSessions ~/ 2 &&
      controlSamples >= experiment.minimumMatchedSessions ~/ 2;
}

class PersonalExperimentRepository {
  static const _key = 'progression_lab_personal_experiments_v1';

  Future<List<PersonalExperiment>> load() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_key);
    if (raw == null || raw.isEmpty) return <PersonalExperiment>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <PersonalExperiment>[];
      return <PersonalExperiment>[
        for (final item in decoded)
          if (item is Map)
            PersonalExperiment.fromJson(Map<String, dynamic>.from(item)),
      ];
    } on Object {
      return <PersonalExperiment>[];
    }
  }

  Future<void> save(List<PersonalExperiment> values) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _key,
      jsonEncode(values.map((value) => value.toJson()).toList()),
    );
  }

  Future<void> upsert(PersonalExperiment value) async {
    final values = await load();
    final index = values.indexWhere((item) => item.id == value.id);
    if (index < 0) {
      values.add(value);
    } else {
      values[index] = value;
    }
    await save(values);
  }

  Future<void> remove(String id) async {
    final values = await load()..removeWhere((item) => item.id == id);
    await save(values);
  }
}

/// Computes experiment results from Progression Lab's own deterministic data.
/// Gemini may explain this result but never calculates or replaces it.
abstract final class PersonalExperimentEngine {
  static ExperimentResult evaluate(
    PersonalExperiment experiment,
    AppStore store,
  ) {
    final condition = <double>[];
    final control = <double>[];
    final state = store.exportState();
    final supplementEvents = _maps(state['supplementEvents']);
    final meals = _maps(state['mealEvents']);
    final hydration = _maps(state['hydrationEvents']);
    final recovery = _maps(state['recoveryCheckIns']);
    final responses = _maps(state['workoutResponses']);

    final workouts = store.workoutHistory
        .where((record) => record.status == WorkoutStatus.completed)
        .where((record) => !record.loggedAt.isBefore(experiment.startedAt))
        .toList()
      ..sort((a, b) => a.loggedAt.compareTo(b.loggedAt));

    for (final workout in workouts) {
      final metric = _metricForWorkout(experiment.metric, workout, store, responses);
      if (metric == null || !metric.isFinite) continue;
      final exposed = _conditionForWorkout(
        experiment.variable,
        workout.loggedAt,
        supplementEvents,
        meals,
        hydration,
        recovery,
      );
      (exposed ? condition : control).add(metric);
    }

    final conditionAverage = _average(condition);
    final controlAverage = _average(control);
    final effect = conditionAverage != null &&
            controlAverage != null &&
            controlAverage.abs() > 1e-9
        ? ((conditionAverage - controlAverage) / controlAverage.abs()) * 100
        : null;
    final total = condition.length + control.length;
    final confidence = total >= 24 && condition.length >= 8 && control.length >= 8
        ? 'moderate'
        : total >= experiment.minimumMatchedSessions &&
                condition.isNotEmpty &&
                control.isNotEmpty
            ? 'preliminary'
            : 'insufficient';
    final confounders = <String>[
      'Program phase and workout selection may differ.',
      'Sleep, nutrition, stress, and training age may contribute.',
      if (experiment.variable == ExperimentVariable.caffeine)
        'Caffeine tolerance and dose timing are not perfectly controlled.',
      if (experiment.variable == ExperimentVariable.creatineConsistency)
        'Creatine is evaluated as rolling adherence, not a same-day switch.',
    ];

    return ExperimentResult(
      experiment: experiment,
      conditionSamples: condition.length,
      controlSamples: control.length,
      conditionAverage: conditionAverage,
      controlAverage: controlAverage,
      effectPercent: effect,
      confidence: confidence,
      confounders: confounders,
    );
  }

  static double? _metricForWorkout(
    ExperimentMetric metric,
    WorkoutRecord workout,
    AppStore store,
    List<Map<String, dynamic>> responses,
  ) {
    final sets = store.logs.where((set) {
      if (workout.sessionId != null && set.sessionId == workout.sessionId) {
        return true;
      }
      return set.workout == workout.workout &&
          set.date.difference(workout.loggedAt).abs() < const Duration(hours: 8);
    }).toList();
    return switch (metric) {
      ExperimentMetric.estimatedStrength => sets.isEmpty
          ? null
          : sets.map((set) => set.e1rm).reduce(math.max),
      ExperimentMetric.volume => sets.isEmpty
          ? null
          : sets.fold<double>(0, (sum, set) => sum + set.weight * set.reps),
      ExperimentMetric.repetitions => sets.isEmpty
          ? null
          : sets.fold<double>(0, (sum, set) => sum + set.reps),
      ExperimentMetric.sessionEnergy => _responseMetric(
          responses,
          workout.sessionId,
          'energy',
        ),
      ExperimentMetric.athleticAssessment => null,
    };
  }

  static bool _conditionForWorkout(
    ExperimentVariable variable,
    DateTime workout,
    List<Map<String, dynamic>> supplements,
    List<Map<String, dynamic>> meals,
    List<Map<String, dynamic>> hydration,
    List<Map<String, dynamic>> recovery,
  ) {
    bool within(Object? value, Duration before, Duration after) {
      final date = DateTime.tryParse('$value');
      if (date == null) return false;
      return !date.isBefore(workout.subtract(before)) &&
          !date.isAfter(workout.add(after));
    }

    return switch (variable) {
      ExperimentVariable.caffeine => supplements.any(
          (item) =>
              ((item['caffeineMg'] as num?)?.toDouble() ?? 0) >= 50 &&
              within(item['takenAt'], const Duration(hours: 3), Duration.zero),
        ),
      ExperimentVariable.creatineConsistency => _creatineAdherence(
          workout,
          supplements,
        ) >=
        0.7,
      ExperimentVariable.preWorkoutMeal => meals.any(
          (item) =>
              within(item['occurredAt'], const Duration(hours: 4), Duration.zero) &&
              '${item['timing']}'.toLowerCase().contains('pre'),
        ),
      ExperimentVariable.sleepDuration => recovery.any((item) {
          final date = DateTime.tryParse('${item['localDate']}');
          final hours = (item['sleepHours'] as num?)?.toDouble();
          return date != null &&
              hours != null &&
              _sameDay(date, workout.subtract(const Duration(days: 1))) &&
              hours >= 7;
        }),
      ExperimentVariable.hydration => hydration
              .where(
                (item) => within(
                  item['occurredAt'],
                  const Duration(hours: 8),
                  Duration.zero,
                ),
              )
              .fold<double>(
                0,
                (sum, item) =>
                    sum + ((item['amountMl'] as num?)?.toDouble() ?? 0),
              ) >=
          1000,
      ExperimentVariable.custom => false,
    };
  }

  static double _creatineAdherence(
    DateTime workout,
    List<Map<String, dynamic>> supplements,
  ) {
    final days = <String>{};
    for (final item in supplements) {
      if (!'${item['name']}'.toLowerCase().contains('creatine')) continue;
      final date = DateTime.tryParse('${item['takenAt']}');
      if (date == null ||
          date.isBefore(workout.subtract(const Duration(days: 7))) ||
          date.isAfter(workout)) {
        continue;
      }
      days.add('${date.year}-${date.month}-${date.day}');
    }
    return days.length / 7;
  }

  static double? _responseMetric(
    List<Map<String, dynamic>> responses,
    String? sessionId,
    String field,
  ) {
    if (sessionId == null) return null;
    for (final item in responses.reversed) {
      if (item['workoutSessionId'] == sessionId && item[field] is num) {
        return (item[field] as num).toDouble();
      }
    }
    return null;
  }

  static List<Map<String, dynamic>> _maps(Object? value) {
    if (value is! List) return <Map<String, dynamic>>[];
    return <Map<String, dynamic>>[
      for (final item in value)
        if (item is Map) Map<String, dynamic>.from(item),
    ];
  }

  static double? _average(List<double> values) => values.isEmpty
      ? null
      : values.reduce((a, b) => a + b) / values.length;

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
