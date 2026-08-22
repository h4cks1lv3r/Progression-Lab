import 'dart:math' as math;

enum LabExperimentTemplate {
  caffeineTiming,
  creatineConsistency,
  preWorkoutMealTiming,
  sleepTarget,
  hydrationTarget,
  custom,
}

enum LabExperimentMetric {
  estimatedStrength,
  totalVolume,
  topSetRepetitions,
  workoutCompletion,
  sessionEnergy,
  sessionFocus,
  athleticAssessment,
}

enum LabExperimentStatus { draft, active, collecting, complete, archived }

enum LabExperimentConfidence { insufficient, preliminary, moderate, strong }

class LabExperimentCondition {
  const LabExperimentCondition({
    required this.id,
    required this.label,
    required this.kind,
    this.minimum,
    this.maximum,
    this.windowMinutes,
    this.rollingDays,
    this.metadata = const <String, dynamic>{},
  });

  final String id;
  final String label;
  final String kind;
  final double? minimum;
  final double? maximum;
  final int? windowMinutes;
  final int? rollingDays;
  final Map<String, dynamic> metadata;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'label': label,
    'kind': kind,
    if (minimum != null) 'minimum': minimum,
    if (maximum != null) 'maximum': maximum,
    if (windowMinutes != null) 'windowMinutes': windowMinutes,
    if (rollingDays != null) 'rollingDays': rollingDays,
    if (metadata.isNotEmpty) 'metadata': metadata,
  };

  factory LabExperimentCondition.fromJson(Map<String, dynamic> value) =>
      LabExperimentCondition(
        id: '${value['id']}',
        label: '${value['label']}',
        kind: '${value['kind']}',
        minimum: (value['minimum'] as num?)?.toDouble(),
        maximum: (value['maximum'] as num?)?.toDouble(),
        windowMinutes: (value['windowMinutes'] as num?)?.toInt(),
        rollingDays: (value['rollingDays'] as num?)?.toInt(),
        metadata: value['metadata'] is Map
            ? Map<String, dynamic>.from(value['metadata'] as Map)
            : const <String, dynamic>{},
      );
}

class LabExperiment {
  const LabExperiment({
    required this.id,
    required this.name,
    required this.template,
    required this.metric,
    required this.conditionA,
    required this.conditionB,
    required this.startedAt,
    required this.minimumSessionsPerCondition,
    this.endedAt,
    this.status = LabExperimentStatus.draft,
    this.workoutNameFilter,
    this.exerciseFilter,
    this.exclusionNotes = '',
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final LabExperimentTemplate template;
  final LabExperimentMetric metric;
  final LabExperimentCondition conditionA;
  final LabExperimentCondition conditionB;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int minimumSessionsPerCondition;
  final LabExperimentStatus status;
  final String? workoutNameFilter;
  final String? exerciseFilter;
  final String exclusionNotes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  LabExperiment copyWith({
    String? name,
    DateTime? endedAt,
    LabExperimentStatus? status,
    DateTime? updatedAt,
  }) => LabExperiment(
    id: id,
    name: name ?? this.name,
    template: template,
    metric: metric,
    conditionA: conditionA,
    conditionB: conditionB,
    startedAt: startedAt,
    endedAt: endedAt ?? this.endedAt,
    minimumSessionsPerCondition: minimumSessionsPerCondition,
    status: status ?? this.status,
    workoutNameFilter: workoutNameFilter,
    exerciseFilter: exerciseFilter,
    exclusionNotes: exclusionNotes,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'template': template.name,
    'metric': metric.name,
    'conditionA': conditionA.toJson(),
    'conditionB': conditionB.toJson(),
    'startedAt': startedAt.toUtc().toIso8601String(),
    if (endedAt != null) 'endedAt': endedAt!.toUtc().toIso8601String(),
    'minimumSessionsPerCondition': minimumSessionsPerCondition,
    'status': status.name,
    if (workoutNameFilter != null) 'workoutNameFilter': workoutNameFilter,
    if (exerciseFilter != null) 'exerciseFilter': exerciseFilter,
    if (exclusionNotes.isNotEmpty) 'exclusionNotes': exclusionNotes,
    if (createdAt != null) 'createdAt': createdAt!.toUtc().toIso8601String(),
    if (updatedAt != null) 'updatedAt': updatedAt!.toUtc().toIso8601String(),
  };

  factory LabExperiment.fromJson(Map<String, dynamic> value) {
    T enumByName<T extends Enum>(List<T> values, Object? raw, T fallback) =>
        values.where((item) => item.name == '$raw').firstOrNull ?? fallback;
    return LabExperiment(
      id: '${value['id']}',
      name: '${value['name']}',
      template: enumByName(
        LabExperimentTemplate.values,
        value['template'],
        LabExperimentTemplate.custom,
      ),
      metric: enumByName(
        LabExperimentMetric.values,
        value['metric'],
        LabExperimentMetric.estimatedStrength,
      ),
      conditionA: LabExperimentCondition.fromJson(
        Map<String, dynamic>.from(value['conditionA'] as Map),
      ),
      conditionB: LabExperimentCondition.fromJson(
        Map<String, dynamic>.from(value['conditionB'] as Map),
      ),
      startedAt: DateTime.parse('${value['startedAt']}').toUtc(),
      endedAt: value['endedAt'] is String
          ? DateTime.tryParse(value['endedAt'] as String)?.toUtc()
          : null,
      minimumSessionsPerCondition:
          (value['minimumSessionsPerCondition'] as num?)?.toInt() ?? 6,
      status: enumByName(
        LabExperimentStatus.values,
        value['status'],
        LabExperimentStatus.draft,
      ),
      workoutNameFilter: value['workoutNameFilter'] is String
          ? value['workoutNameFilter'] as String
          : null,
      exerciseFilter: value['exerciseFilter'] is String
          ? value['exerciseFilter'] as String
          : null,
      exclusionNotes: value['exclusionNotes'] is String
          ? value['exclusionNotes'] as String
          : '',
      createdAt: value['createdAt'] is String
          ? DateTime.tryParse(value['createdAt'] as String)?.toUtc()
          : null,
      updatedAt: value['updatedAt'] is String
          ? DateTime.tryParse(value['updatedAt'] as String)?.toUtc()
          : null,
    );
  }
}

class LabExperimentSample {
  const LabExperimentSample({
    required this.sessionId,
    required this.occurredAt,
    required this.conditionId,
    required this.value,
    required this.workoutName,
    this.confounders = const <String>[],
  });

  final String sessionId;
  final DateTime occurredAt;
  final String conditionId;
  final double value;
  final String workoutName;
  final List<String> confounders;
}

class LabExperimentResult {
  const LabExperimentResult({
    required this.experiment,
    required this.samplesA,
    required this.samplesB,
    required this.meanA,
    required this.meanB,
    required this.difference,
    required this.percentDifference,
    required this.effectSize,
    required this.confidence,
    required this.summary,
    required this.confounders,
  });

  final LabExperiment experiment;
  final List<LabExperimentSample> samplesA;
  final List<LabExperimentSample> samplesB;
  final double? meanA;
  final double? meanB;
  final double? difference;
  final double? percentDifference;
  final double? effectSize;
  final LabExperimentConfidence confidence;
  final String summary;
  final List<String> confounders;

  bool get sufficient => confidence != LabExperimentConfidence.insufficient;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'experimentId': experiment.id,
    'sampleCountA': samplesA.length,
    'sampleCountB': samplesB.length,
    if (meanA != null) 'meanA': meanA,
    if (meanB != null) 'meanB': meanB,
    if (difference != null) 'difference': difference,
    if (percentDifference != null) 'percentDifference': percentDifference,
    if (effectSize != null) 'effectSize': effectSize,
    'confidence': confidence.name,
    'summary': summary,
    'confounders': confounders,
  };
}

class WeeklyLabReview {
  const WeeklyLabReview({
    required this.start,
    required this.end,
    required this.completedStrengthWorkouts,
    required this.completedAthleticSessions,
    required this.workingSets,
    required this.personalRecords,
    required this.creatineAdherenceDays,
    required this.averageSleepHours,
    required this.averageSessionEnergy,
    required this.signals,
    required this.dataGaps,
  });

  final DateTime start;
  final DateTime end;
  final int completedStrengthWorkouts;
  final int completedAthleticSessions;
  final int workingSets;
  final int personalRecords;
  final int creatineAdherenceDays;
  final double? averageSleepHours;
  final double? averageSessionEnergy;
  final List<String> signals;
  final List<String> dataGaps;
}

abstract final class LabExperimentTemplates {
  static LabExperiment caffeineTiming({DateTime? start}) => LabExperiment(
    id: _id('caffeine'),
    name: 'Caffeine timing and workout performance',
    template: LabExperimentTemplate.caffeineTiming,
    metric: LabExperimentMetric.estimatedStrength,
    conditionA: const LabExperimentCondition(
      id: 'caffeine-window',
      label: '100–300 mg, 30–120 minutes before training',
      kind: 'caffeineBeforeWorkout',
      minimum: 100,
      maximum: 300,
      windowMinutes: 120,
      metadata: <String, dynamic>{'minimumLeadMinutes': 30},
    ),
    conditionB: const LabExperimentCondition(
      id: 'no-caffeine-window',
      label: 'No caffeine in the prior 4 hours',
      kind: 'caffeineBeforeWorkout',
      maximum: 0,
      windowMinutes: 240,
    ),
    startedAt: start ?? DateTime.now().toUtc(),
    minimumSessionsPerCondition: 6,
    status: LabExperimentStatus.active,
  );

  static LabExperiment creatineConsistency({DateTime? start}) => LabExperiment(
    id: _id('creatine'),
    name: 'Creatine consistency and strength trend',
    template: LabExperimentTemplate.creatineConsistency,
    metric: LabExperimentMetric.estimatedStrength,
    conditionA: const LabExperimentCondition(
      id: 'creatine-consistent',
      label: 'Creatine logged on at least 6 of 7 days',
      kind: 'supplementAdherence',
      minimum: 6,
      rollingDays: 7,
      metadata: <String, dynamic>{'supplement': 'creatine'},
    ),
    conditionB: const LabExperimentCondition(
      id: 'creatine-inconsistent',
      label: 'Creatine logged on 3 or fewer of 7 days',
      kind: 'supplementAdherence',
      maximum: 3,
      rollingDays: 7,
      metadata: <String, dynamic>{'supplement': 'creatine'},
    ),
    startedAt: start ?? DateTime.now().toUtc(),
    minimumSessionsPerCondition: 8,
    status: LabExperimentStatus.active,
  );

  static LabExperiment mealTiming({DateTime? start}) => LabExperiment(
    id: _id('meal'),
    name: 'Pre-workout meal timing and session energy',
    template: LabExperimentTemplate.preWorkoutMealTiming,
    metric: LabExperimentMetric.sessionEnergy,
    conditionA: const LabExperimentCondition(
      id: 'meal-60-180',
      label: 'Meal 60–180 minutes before training',
      kind: 'mealBeforeWorkout',
      windowMinutes: 180,
      metadata: <String, dynamic>{'minimumLeadMinutes': 60},
    ),
    conditionB: const LabExperimentCondition(
      id: 'no-recent-meal',
      label: 'No meal in the prior 3 hours',
      kind: 'mealBeforeWorkout',
      maximum: 0,
      windowMinutes: 180,
    ),
    startedAt: start ?? DateTime.now().toUtc(),
    minimumSessionsPerCondition: 5,
    status: LabExperimentStatus.active,
  );

  static LabExperiment sleepTarget({
    DateTime? start,
    double targetHours = 7.5,
  }) => LabExperiment(
    id: _id('sleep'),
    name: 'Sleep target and workout performance',
    template: LabExperimentTemplate.sleepTarget,
    metric: LabExperimentMetric.estimatedStrength,
    conditionA: LabExperimentCondition(
      id: 'sleep-target',
      label: 'At least ${targetHours.toStringAsFixed(1)} hours of sleep',
      kind: 'previousNightSleep',
      minimum: targetHours,
    ),
    conditionB: LabExperimentCondition(
      id: 'below-sleep-target',
      label: 'Less than ${targetHours.toStringAsFixed(1)} hours of sleep',
      kind: 'previousNightSleep',
      maximum: targetHours - 0.01,
    ),
    startedAt: start ?? DateTime.now().toUtc(),
    minimumSessionsPerCondition: 6,
    status: LabExperimentStatus.active,
  );

  static String _id(String prefix) =>
      'experiment-$prefix-${DateTime.now().microsecondsSinceEpoch}';
}

abstract final class LabExperimentAnalyzer {
  static LabExperimentResult analyze(
    LabExperiment experiment,
    Map<String, dynamic> state,
  ) {
    final sessions = _sessions(state, experiment);
    final samplesA = <LabExperimentSample>[];
    final samplesB = <LabExperimentSample>[];
    for (final session in sessions) {
      final value = _metricValue(experiment.metric, session, state);
      if (value == null || !value.isFinite) continue;
      final conditionA = _matches(experiment.conditionA, session, state);
      final conditionB = _matches(experiment.conditionB, session, state);
      if (conditionA == conditionB) continue;
      final sample = LabExperimentSample(
        sessionId: session.id,
        occurredAt: session.occurredAt,
        conditionId: conditionA
            ? experiment.conditionA.id
            : experiment.conditionB.id,
        value: value,
        workoutName: session.workoutName,
        confounders: _confounders(session, state),
      );
      (conditionA ? samplesA : samplesB).add(sample);
    }

    final meanA = _mean(samplesA.map((sample) => sample.value));
    final meanB = _mean(samplesB.map((sample) => sample.value));
    final difference = meanA == null || meanB == null ? null : meanA - meanB;
    final percent = difference == null || meanB == 0
        ? null
        : difference / meanB * 100;
    final effect = _cohensD(
      samplesA.map((sample) => sample.value).toList(),
      samplesB.map((sample) => sample.value).toList(),
    );
    final confidence = _confidence(
      samplesA.length,
      samplesB.length,
      experiment.minimumSessionsPerCondition,
      effect,
    );
    final confounders = <String>{
      for (final sample in <LabExperimentSample>[...samplesA, ...samplesB])
        ...sample.confounders,
    }.toList()..sort();

    return LabExperimentResult(
      experiment: experiment,
      samplesA: samplesA,
      samplesB: samplesB,
      meanA: meanA,
      meanB: meanB,
      difference: difference,
      percentDifference: percent,
      effectSize: effect,
      confidence: confidence,
      summary: _summary(
        experiment,
        samplesA.length,
        samplesB.length,
        percent,
        confidence,
      ),
      confounders: confounders,
    );
  }

  static WeeklyLabReview weeklyReview(
    Map<String, dynamic> state, {
    DateTime? ending,
  }) {
    final end = (ending ?? DateTime.now()).toUtc();
    final start = end.subtract(const Duration(days: 7));
    final workoutHistory = _maps(state['workoutHistory']).where((item) {
      final date = _date(item['loggedAt'] ?? item['date']);
      return date != null && !date.isBefore(start) && !date.isAfter(end);
    }).toList();
    final athleticHistory = _maps(state['athleticHistory']).where((item) {
      final date = _date(item['completedAt'] ?? item['date']);
      return date != null && !date.isBefore(start) && !date.isAfter(end);
    }).toList();
    final logs = _maps(state['logs']).where((item) {
      final date = _date(item['d'] ?? item['date']);
      return date != null && !date.isBefore(start) && !date.isAfter(end);
    }).toList();
    final responses = _maps(state['workoutResponses']).where((item) {
      final date = _date(item['recordedAt']);
      return date != null && !date.isBefore(start) && !date.isAfter(end);
    }).toList();
    final recovery = _maps(state['recoveryCheckIns']).where((item) {
      final date = _date(item['localDate']);
      return date != null && !date.isBefore(start) && !date.isAfter(end);
    }).toList();
    final supplements = _maps(state['supplementEvents']).where((item) {
      final date = _date(item['takenAt']);
      return date != null && !date.isBefore(start) && !date.isAfter(end);
    }).toList();
    final creatineDays = supplements
        .where((item) => '${item['name']}'.toLowerCase().contains('creatine'))
        .map((item) => _dateOnly(_date(item['takenAt'])!))
        .toSet()
        .length;
    final sleep = recovery
        .map((item) => (item['sleepHours'] as num?)?.toDouble())
        .whereType<double>();
    final energy = responses
        .map((item) => (item['energy'] as num?)?.toDouble())
        .whereType<double>();
    final signals = <String>[];
    final dataGaps = <String>[];
    if (workoutHistory.isNotEmpty) {
      signals.add('${workoutHistory.length} Strength workouts completed.');
    }
    if (athleticHistory.isNotEmpty) {
      signals.add('${athleticHistory.length} Athletic sessions completed.');
    }
    if (creatineDays >= 6) {
      signals.add(
        'Creatine logging was consistent on $creatineDays of 7 days.',
      );
    }
    final averageSleep = _mean(sleep);
    if (averageSleep != null) {
      signals.add('Average sleep: ${averageSleep.toStringAsFixed(1)} hours.');
    } else {
      dataGaps.add('Sleep was not logged this week.');
    }
    final averageEnergy = _mean(energy);
    if (averageEnergy == null) {
      dataGaps.add('Post-workout energy was not logged.');
    }
    if (supplements.isEmpty) {
      dataGaps.add('No supplement inputs were logged.');
    }
    return WeeklyLabReview(
      start: start,
      end: end,
      completedStrengthWorkouts: workoutHistory.length,
      completedAthleticSessions: athleticHistory.length,
      workingSets: logs.length,
      personalRecords: 0,
      creatineAdherenceDays: creatineDays,
      averageSleepHours: averageSleep,
      averageSessionEnergy: averageEnergy,
      signals: signals,
      dataGaps: dataGaps,
    );
  }

  static List<_Session> _sessions(
    Map<String, dynamic> state,
    LabExperiment experiment,
  ) {
    final history = _maps(state['workoutHistory']);
    final sessions = <_Session>[];
    for (final item in history) {
      final status = '${item['status']}';
      if (status.isNotEmpty && status != 'completed') continue;
      final occurredAt = _date(item['loggedAt'] ?? item['date']);
      if (occurredAt == null || occurredAt.isBefore(experiment.startedAt))
        continue;
      if (experiment.endedAt != null &&
          occurredAt.isAfter(experiment.endedAt!)) {
        continue;
      }
      final workoutName = '${item['workout'] ?? item['name'] ?? 'Workout'}';
      if (experiment.workoutNameFilter case final String filter) {
        if (!workoutName.toLowerCase().contains(filter.toLowerCase())) continue;
      }
      final sessionId =
          '${item['sessionId'] ?? '${occurredAt.microsecondsSinceEpoch}-$workoutName'}';
      sessions.add(
        _Session(
          id: sessionId,
          occurredAt: occurredAt,
          workoutName: workoutName,
          week: (item['week'] as num?)?.toInt(),
          days: (item['days'] as num?)?.toInt(),
        ),
      );
    }
    sessions.sort((a, b) => a.occurredAt.compareTo(b.occurredAt));
    return sessions;
  }

  static double? _metricValue(
    LabExperimentMetric metric,
    _Session session,
    Map<String, dynamic> state,
  ) {
    final sessionLogs = _maps(state['logs']).where((item) {
      final id = '${item['s'] ?? item['sessionId'] ?? ''}';
      if (id.isNotEmpty) return id == session.id;
      final date = _date(item['d'] ?? item['date']);
      final workout = '${item['o'] ?? item['workout'] ?? ''}';
      return date != null &&
          _dateOnly(date) == _dateOnly(session.occurredAt) &&
          workout == session.workoutName;
    }).toList();
    final responses = _maps(
      state['workoutResponses'],
    ).where((item) => '${item['workoutSessionId']}' == session.id);
    return switch (metric) {
      LabExperimentMetric.estimatedStrength => _maxDouble(
        sessionLogs.map((item) {
          final weight = (item['w'] ?? item['weight']) as num?;
          final reps = (item['r'] ?? item['reps']) as num?;
          if (weight == null || reps == null || weight <= 0 || reps <= 0) {
            return null;
          }
          return weight.toDouble() * (1 + reps.toDouble() / 30);
        }),
      ),
      LabExperimentMetric.totalVolume => sessionLogs.fold<double>(0, (
        total,
        item,
      ) {
        final weight = ((item['w'] ?? item['weight']) as num?)?.toDouble() ?? 0;
        final reps = ((item['r'] ?? item['reps']) as num?)?.toDouble() ?? 0;
        return total + weight * reps;
      }),
      LabExperimentMetric.topSetRepetitions => _maxDouble(
        sessionLogs.map(
          (item) => ((item['r'] ?? item['reps']) as num?)?.toDouble(),
        ),
      ),
      LabExperimentMetric.workoutCompletion => 1.0,
      LabExperimentMetric.sessionEnergy => _firstMetric(responses, 'energy'),
      LabExperimentMetric.sessionFocus => _firstMetric(responses, 'focus'),
      LabExperimentMetric.athleticAssessment => null,
    };
  }

  static bool _matches(
    LabExperimentCondition condition,
    _Session session,
    Map<String, dynamic> state,
  ) {
    double? value;
    switch (condition.kind) {
      case 'caffeineBeforeWorkout':
        final window = Duration(minutes: condition.windowMinutes ?? 240);
        final minimumLead = Duration(
          minutes:
              (condition.metadata['minimumLeadMinutes'] as num?)?.toInt() ?? 0,
        );
        final start = session.occurredAt.subtract(window);
        final end = session.occurredAt.subtract(minimumLead);
        value = _maps(state['supplementEvents'])
            .where((item) {
              final time = _date(item['takenAt']);
              return time != null &&
                  !time.isBefore(start) &&
                  !time.isAfter(end);
            })
            .fold<double>(
              0,
              (total, item) =>
                  total + ((item['caffeineMg'] as num?)?.toDouble() ?? 0),
            );
        break;
      case 'mealBeforeWorkout':
        final window = Duration(minutes: condition.windowMinutes ?? 180);
        final minimumLead = Duration(
          minutes:
              (condition.metadata['minimumLeadMinutes'] as num?)?.toInt() ?? 0,
        );
        final start = session.occurredAt.subtract(window);
        final end = session.occurredAt.subtract(minimumLead);
        value = _maps(state['mealEvents'])
            .where((item) {
              final time = _date(item['occurredAt']);
              return time != null &&
                  !time.isBefore(start) &&
                  !time.isAfter(end);
            })
            .length
            .toDouble();
        break;
      case 'previousNightSleep':
        final targetDate = _dateOnly(
          session.occurredAt.subtract(const Duration(days: 1)),
        );
        value = _maps(state['recoveryCheckIns'])
            .where((item) {
              final date = _date(item['localDate']);
              return date != null && _dateOnly(date) == targetDate;
            })
            .map((item) => (item['sleepHours'] as num?)?.toDouble())
            .whereType<double>()
            .firstOrNull;
        break;
      case 'supplementAdherence':
        final supplement = '${condition.metadata['supplement'] ?? ''}'
            .toLowerCase();
        final days = condition.rollingDays ?? 7;
        final start = _dateOnly(
          session.occurredAt.subtract(Duration(days: days - 1)),
        );
        final end = _dateOnly(session.occurredAt);
        value = _maps(state['supplementEvents'])
            .where((item) {
              if (!'${item['name']}'.toLowerCase().contains(supplement))
                return false;
              final date = _date(item['takenAt']);
              return date != null &&
                  !_dateOnly(date).isBefore(start) &&
                  !_dateOnly(date).isAfter(end);
            })
            .map((item) => _dateOnly(_date(item['takenAt'])!))
            .toSet()
            .length
            .toDouble();
        break;
      default:
        value = null;
        break;
    }
    if (value == null) return false;
    if (condition.minimum != null && value < condition.minimum!) return false;
    if (condition.maximum != null && value > condition.maximum!) return false;
    return true;
  }

  static List<String> _confounders(
    _Session session,
    Map<String, dynamic> state,
  ) {
    final values = <String>[];
    final recovery = _maps(state['recoveryCheckIns']).where((item) {
      final date = _date(item['localDate']);
      return date != null && _dateOnly(date) == _dateOnly(session.occurredAt);
    }).firstOrNull;
    if (recovery == null) {
      values.add('Recovery data missing');
    } else {
      final sleep = (recovery['sleepHours'] as num?)?.toDouble();
      if (sleep != null && sleep < 6) values.add('Short sleep');
      final stress = (recovery['stress'] as num?)?.toInt();
      if (stress != null && stress >= 4) values.add('High stress');
      if (recovery['illness'] == true) values.add('Illness logged');
    }
    if (session.week != null && session.week! % 4 == 0) {
      values.add('Possible deload cycle');
    }
    return values;
  }

  static LabExperimentConfidence _confidence(
    int countA,
    int countB,
    int minimum,
    double? effect,
  ) {
    if (countA < minimum || countB < minimum) {
      return LabExperimentConfidence.insufficient;
    }
    final smaller = math.min(countA, countB);
    if (smaller >= 20 && effect != null && effect.abs() >= 0.5) {
      return LabExperimentConfidence.strong;
    }
    if (smaller >= 12) return LabExperimentConfidence.moderate;
    return LabExperimentConfidence.preliminary;
  }

  static String _summary(
    LabExperiment experiment,
    int countA,
    int countB,
    double? percent,
    LabExperimentConfidence confidence,
  ) {
    if (confidence == LabExperimentConfidence.insufficient || percent == null) {
      return 'More matched workouts are needed. '
          '${experiment.conditionA.label}: $countA; '
          '${experiment.conditionB.label}: $countB.';
    }
    final direction = percent >= 0 ? 'higher' : 'lower';
    return '${experiment.metric.name} was ${percent.abs().toStringAsFixed(1)}% '
        '$direction under “${experiment.conditionA.label}” across $countA versus '
        '$countB matched workouts. This is an association, not proof of cause.';
  }

  static double? _cohensD(List<double> a, List<double> b) {
    if (a.length < 2 || b.length < 2) return null;
    final meanA = _mean(a)!;
    final meanB = _mean(b)!;
    double variance(List<double> values, double mean) =>
        values
            .map((value) => math.pow(value - mean, 2).toDouble())
            .reduce((left, right) => left + right) /
        (values.length - 1);
    final pooled = math.sqrt(
      ((a.length - 1) * variance(a, meanA) +
              (b.length - 1) * variance(b, meanB)) /
          (a.length + b.length - 2),
    );
    if (pooled == 0) return 0;
    return (meanA - meanB) / pooled;
  }

  static double? _mean(Iterable<double> values) {
    final items = values.toList();
    if (items.isEmpty) return null;
    return items.reduce((left, right) => left + right) / items.length;
  }

  static double? _maxDouble(Iterable<double?> values) {
    final items = values.whereType<double>().toList();
    if (items.isEmpty) return null;
    return items.reduce(math.max);
  }

  static double? _firstMetric(
    Iterable<Map<String, dynamic>> values,
    String key,
  ) => values
      .map((item) => (item[key] as num?)?.toDouble())
      .whereType<double>()
      .firstOrNull;

  static List<Map<String, dynamic>> _maps(Object? value) => value is List
      ? <Map<String, dynamic>>[
          for (final item in value)
            if (item is Map) Map<String, dynamic>.from(item),
        ]
      : <Map<String, dynamic>>[];

  static DateTime? _date(Object? value) =>
      value is String ? DateTime.tryParse(value)?.toUtc() : null;

  static DateTime _dateOnly(DateTime value) =>
      DateTime.utc(value.year, value.month, value.day);
}

class _Session {
  const _Session({
    required this.id,
    required this.occurredAt,
    required this.workoutName,
    this.week,
    this.days,
  });

  final String id;
  final DateTime occurredAt;
  final String workoutName;
  final int? week;
  final int? days;
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
