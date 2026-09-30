import 'exercise_metrics.dart';
import 'dart:convert';
import 'dart:math' as math;

import 'daily_inputs.dart';
import 'store.dart';
import 'lab_data.dart';
import 'lab_conditions.dart';
import 'display_format.dart';

enum LabConfidence { insufficient, preliminary, developing, stronger }

class LabEvidence {
  const LabEvidence({
    required this.id,
    required this.title,
    required this.finding,
    required this.metric,
    required this.comparison,
    required this.sampleLabel,
    required this.confidence,
    required this.confounders,
    this.effectPercent,
    this.adherencePercent,
    this.positive = true,
    this.neutral = false,
  });

  final String id;
  final String title;
  final String finding;
  final String metric;
  final String comparison;
  final String sampleLabel;
  final LabConfidence confidence;
  final List<String> confounders;
  final double? effectPercent;
  final double? adherencePercent;
  final bool positive;
  final bool neutral;

  bool get hasEnoughData => confidence != LabConfidence.insufficient;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'finding': finding,
    'metric': metric,
    'comparison': comparison,
    'sample': sampleLabel,
    'confidence': confidence.name,
    'confounders': confounders,
    if (effectPercent != null) 'effectPercent': effectPercent,
    if (adherencePercent != null) 'adherencePercent': adherencePercent,
    if (!neutral) 'positive': positive,
    'neutral': neutral,
  };
}

class LabReport {
  const LabReport({
    required this.generatedAt,
    required this.windowStart,
    required this.windowEnd,
    required this.evidence,
    required this.dataSummary,
  });

  final DateTime generatedAt;
  final DateTime windowStart;
  final DateTime windowEnd;
  final List<LabEvidence> evidence;
  final Map<String, Object> dataSummary;

  List<LabEvidence> get supportedEvidence =>
      evidence.where((item) => item.hasEnoughData).toList();

  String toPromptPacket({String? question}) {
    final payload = {
      'task': question == null ? 'progress_summary' : 'answer_user_question',
      'question': ?question,
      'generatedAt': generatedAt.toIso8601String(),
      'window': {
        'start': windowStart.toIso8601String(),
        'end': windowEnd.toIso8601String(),
      },
      'dataSummary': dataSummary,
      'evidence': evidence.map((item) => item.toJson()).toList(),
      'rules': [
        'Use only the supplied evidence.',
        'Describe associations, never causation.',
        'State when evidence is insufficient.',
        'Mention sample size, confidence, and major confounders.',
        'Do not diagnose illness or recommend supplement dosing.',
        'Keep the answer concise and practical.',
      ],
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }
}

class LabAnalysisEngine {
  const LabAnalysisEngine();

  LabReport build(
    AppStore store, {
    DateTime? now,
    Set<LabDataDomain>? enabledDomains,
  }) {
    final end = now ?? DateTime.now();
    final start = end.subtract(const Duration(days: 56));
    final domains = enabledDomains ?? store.labDataDomains;
    final workoutsIncluded = domains.contains(LabDataDomain.workouts);
    final sessions = workoutsIncluded
        ? _strengthSessions(store, start: start, end: end)
        : <_StrengthSession>[];
    final completed = workoutsIncluded
        ? labCompletedSessions(store.exportState())
              .where(
                (item) =>
                    !item.occurredAt.isBefore(start) &&
                    !item.occurredAt.isAfter(end),
              )
              .length
        : 0;
    final evidence = <LabEvidence>[];

    if (domains.contains(LabDataDomain.workouts)) {
      evidence.add(_strengthTrend(store, end));
    }
    if (domains.contains(LabDataDomain.supplements)) {
      if (workoutsIncluded) evidence.add(_caffeineAssociation(store, sessions));
      evidence.add(
        _creatineConsistency(store, end, workoutsIncluded: workoutsIncluded),
      );
    }
    if (workoutsIncluded && domains.contains(LabDataDomain.meals)) {
      evidence.add(_mealAssociation(store, sessions));
    }
    if (workoutsIncluded && domains.contains(LabDataDomain.hydration)) {
      evidence.add(_hydrationAssociation(store, sessions));
    }
    if (workoutsIncluded && domains.contains(LabDataDomain.recovery)) {
      evidence.add(_sleepAssociation(store, sessions));
      evidence.add(_workoutResponseSummary(store, end));
    }
    if (domains.contains(LabDataDomain.bodyMetrics)) {
      evidence.add(_bodyweightTrend(store, end));
    }
    if (domains.contains(LabDataDomain.athletic)) {
      evidence.add(_athleticConsistency(store, end));
    }

    return LabReport(
      generatedAt: end,
      windowStart: start,
      windowEnd: end,
      evidence: evidence,
      dataSummary: {
        'strengthSessions': sessions.length,
        'completedWorkouts': completed,
        'workoutsWithoutComparableStrength': completed - sessions.length,
        'strengthSets': workoutsIncluded
            ? store.logs
                  .where(
                    (log) =>
                        !log.date.isBefore(start) && !log.date.isAfter(end),
                  )
                  .length
            : 0,
        'athleticSessions': domains.contains(LabDataDomain.athletic)
            ? store.athleticHistory
                  .where(
                    (record) =>
                        record.isComplete &&
                        !record.completedAt.isBefore(start) &&
                        !record.completedAt.isAfter(end),
                  )
                  .length
            : 0,
        'supplementEvents': domains.contains(LabDataDomain.supplements)
            ? store.supplementEvents
                  .where(
                    (event) =>
                        !event.takenAt.isBefore(start) &&
                        !event.takenAt.isAfter(end),
                  )
                  .length
            : 0,
        'mealEvents': domains.contains(LabDataDomain.meals)
            ? store.mealEvents
                  .where(
                    (event) =>
                        !event.occurredAt.isBefore(start) &&
                        !event.occurredAt.isAfter(end),
                  )
                  .length
            : 0,
        'hydrationEvents': domains.contains(LabDataDomain.hydration)
            ? store.hydrationEvents
                  .where(
                    (event) =>
                        !event.occurredAt.isBefore(start) &&
                        !event.occurredAt.isAfter(end),
                  )
                  .length
            : 0,
        'recoveryCheckIns': domains.contains(LabDataDomain.recovery)
            ? store.recoveryCheckIns
                  .where(
                    (item) =>
                        !item.localDate.isBefore(dateOnly(start)) &&
                        !item.localDate.isAfter(dateOnly(end)),
                  )
                  .length
            : 0,
        'workoutResponses':
            workoutsIncluded && domains.contains(LabDataDomain.recovery)
            ? store.workoutResponses
                  .where(
                    (item) =>
                        !item.recordedAt.isBefore(start) &&
                        !item.recordedAt.isAfter(end),
                  )
                  .length
            : 0,
        'bodyWeightEntries': domains.contains(LabDataDomain.bodyMetrics)
            ? labDailyWeights(store.exportState())
                  .where(
                    (item) =>
                        item.date.compareTo(_dayKey(start)) >= 0 &&
                        item.date.compareTo(_dayKey(end)) <= 0,
                  )
                  .length
            : 0,
        'includedCategories': domains.map((domain) => domain.name).toList(),
        'sessionMatching':
            'Completed Strength, Open and Iconic sessions plus imported workouts with the same exercises and tracking rules',
      },
    );
  }

  LabEvidence _strengthTrend(AppStore store, DateTime end) {
    final recentStart = end.subtract(const Duration(days: 28));
    final previousStart = end.subtract(const Duration(days: 56));
    final recent = <String, double>{};
    final previous = <String, double>{};
    for (final log in store.logs) {
      if (!supportsStrengthEstimate(log)) continue;
      if (log.date.isAfter(end)) continue;
      final target = !log.date.isBefore(recentStart)
          ? recent
          : !log.date.isBefore(previousStart)
          ? previous
          : null;
      if (target == null) continue;
      final current = target[log.exercise];
      if (current == null || log.e1rm > current) {
        target[log.exercise] = log.e1rm;
      }
    }
    final common = recent.keys.where(previous.containsKey).toList();
    if (common.length < 2) {
      return const LabEvidence(
        id: 'strength-trend',
        title: 'Strength trend',
        finding:
            'More repeated exercise data is needed across two four-week windows.',
        metric: 'Best estimated strength by exercise',
        comparison: 'Last 28 days vs previous 28 days',
        sampleLabel: 'Fewer than 2 matched exercises',
        confidence: LabConfidence.insufficient,
        confounders: ['Program phase', 'rep range', 'exercise substitutions'],
      );
    }
    final changes = [
      for (final exercise in common)
        ((recent[exercise]! - previous[exercise]!) / previous[exercise]!) * 100,
    ];
    final average = changes.reduce((a, b) => a + b) / changes.length;
    return LabEvidence(
      id: 'strength-trend',
      title: 'Strength trend',
      finding: average.abs() < 0.5
          ? 'Estimated strength was broadly stable across matched exercises.'
          : 'Estimated strength was ${average >= 0 ? 'higher' : 'lower'} across matched exercises.',
      metric: 'Best estimated strength by exercise',
      comparison: 'Last 28 days vs previous 28 days',
      sampleLabel: '${common.length} matched exercises',
      confidence: _confidence(common.length, common.length),
      confounders: const [
        'Program phase',
        'rep range',
        'exercise substitutions',
      ],
      effectPercent: average,
      positive: average >= 0,
    );
  }

  LabEvidence _caffeineAssociation(
    AppStore store,
    List<_StrengthSession> sessions,
  ) {
    final state = store.exportState();
    final doses = {
      for (final session in sessions)
        session.id: LabConditionDefinitions.caffeineBeforeWorkout(
          state,
          session.startedAt,
        ),
    };
    final usable = sessions.where((session) {
      final dose = doses[session.id]!;
      return dose == 0 || dose >= LabConditionDefinitions.caffeineMinimumMg;
    }).toList();
    final grouped = _matchedGroups(
      usable,
      (session) =>
          doses[session.id]! >= LabConditionDefinitions.caffeineMinimumMg,
    );
    if (grouped.withCondition < 3 || grouped.withoutCondition < 3) {
      return LabEvidence(
        id: 'caffeine',
        title: 'Caffeine and performance',
        finding: 'More matched workouts with and without caffeine are needed.',
        metric: 'Mean estimated one-rep max for matched exercises',
        comparison: LabConditionDefinitions.caffeineComparison,
        sampleLabel:
            '${grouped.withCondition} with · ${grouped.withoutCondition} without',
        confidence: LabConfidence.insufficient,
        confounders: const [
          'Sleep',
          'meal timing',
          'program phase',
          'Dose tolerance',
          'Missing entries do not confirm caffeine absence',
        ],
      );
    }
    final effect = grouped.effectPercent;
    return LabEvidence(
      id: 'caffeine',
      title: 'Caffeine and performance',
      finding: effect.abs() < 1
          ? 'Matched session performance was similar with and without caffeine.'
          : 'Matched session performance was ${effect >= 0 ? 'higher' : 'lower'} after logged caffeine.',
      metric: 'Mean estimated one-rep max for matched exercises',
      comparison: LabConditionDefinitions.caffeineComparison,
      sampleLabel:
          '${grouped.withCondition} with · ${grouped.withoutCondition} without',
      confidence: _confidence(grouped.withCondition, grouped.withoutCondition),
      confounders: const [
        'Sleep',
        'meal timing',
        'program phase',
        'Dose tolerance',
        'Missing entries do not confirm caffeine absence',
      ],
      effectPercent: effect,
      positive: effect >= 0,
    );
  }

  LabEvidence _mealAssociation(
    AppStore store,
    List<_StrengthSession> sessions,
  ) {
    final grouped = _matchedGroups(
      sessions,
      (session) => _mealBefore(store, session.startedAt),
    );
    if (grouped.withCondition < 3 || grouped.withoutCondition < 3) {
      return LabEvidence(
        id: 'meal-timing',
        title: 'Pre-workout meals',
        finding:
            'More matched workouts with and without a recent meal are needed.',
        metric: 'Mean estimated one-rep max for matched exercises',
        comparison: 'Meal 45–240 minutes before training vs no logged meal',
        sampleLabel:
            '${grouped.withCondition} with · ${grouped.withoutCondition} without',
        confidence: LabConfidence.insufficient,
        confounders: const ['Meal size', 'macros', 'hydration', 'workout time'],
      );
    }
    final effect = grouped.effectPercent;
    return LabEvidence(
      id: 'meal-timing',
      title: 'Pre-workout meals',
      finding: effect.abs() < 1
          ? 'Matched session performance was similar across meal conditions.'
          : 'Matched session performance was ${effect >= 0 ? 'higher' : 'lower'} when a meal was logged before training.',
      metric: 'Mean estimated one-rep max for matched exercises',
      comparison: 'Meal 45–240 minutes before training vs no logged meal',
      sampleLabel:
          '${grouped.withCondition} with · ${grouped.withoutCondition} without',
      confidence: _confidence(grouped.withCondition, grouped.withoutCondition),
      confounders: const ['Meal size', 'macros', 'hydration', 'workout time'],
      effectPercent: effect,
      positive: effect >= 0,
    );
  }

  LabEvidence _hydrationAssociation(
    AppStore store,
    List<_StrengthSession> sessions,
  ) {
    final grouped = _matchedGroups(
      sessions,
      (session) => _hydrationBefore(store, session.startedAt) >= 500,
    );
    if (grouped.withCondition < 3 || grouped.withoutCondition < 3) {
      return LabEvidence(
        id: 'hydration',
        title: 'Hydration and performance',
        finding:
            'More matched workouts with different hydration conditions are needed.',
        metric: 'Mean estimated one-rep max for matched exercises',
        comparison: '500+ mL logged in the four hours before training vs less',
        sampleLabel:
            '${grouped.withCondition} hydrated · ${grouped.withoutCondition} comparison',
        confidence: LabConfidence.insufficient,
        confounders: const ['Ambient heat', 'meal fluids', 'workout duration'],
      );
    }
    final effect = grouped.effectPercent;
    return LabEvidence(
      id: 'hydration',
      title: 'Hydration and performance',
      finding: effect.abs() < 1
          ? 'Matched session performance was similar across logged hydration conditions.'
          : 'Matched session performance was ${effect >= 0 ? 'higher' : 'lower'} when at least 500 mL was logged before training.',
      metric: 'Mean estimated one-rep max for matched exercises',
      comparison: '500+ mL logged in the four hours before training vs less',
      sampleLabel:
          '${grouped.withCondition} hydrated · ${grouped.withoutCondition} comparison',
      confidence: _confidence(grouped.withCondition, grouped.withoutCondition),
      confounders: const ['Ambient heat', 'meal fluids', 'workout duration'],
      effectPercent: effect,
      positive: effect >= 0,
    );
  }

  LabEvidence _sleepAssociation(
    AppStore store,
    List<_StrengthSession> sessions,
  ) {
    final state = store.exportState();
    final hours = {
      for (final session in sessions)
        session.id: LabConditionDefinitions.sleepHoursForWorkout(
          state,
          session.startedAt,
        ),
    };
    final usable = sessions
        .where((session) => hours[session.id] != null)
        .toList();
    final grouped = _matchedGroups(
      usable,
      (session) =>
          hours[session.id]! >= LabConditionDefinitions.sleepTargetHours,
    );
    if (grouped.withCondition < 3 || grouped.withoutCondition < 3) {
      return LabEvidence(
        id: 'sleep',
        title: 'Sleep and performance',
        finding:
            'More matched workouts with a sleep entry in their recovery record are needed.',
        metric: 'Mean estimated one-rep max for matched exercises',
        comparison: LabConditionDefinitions.sleepComparison,
        sampleLabel:
            '${grouped.withCondition} at 7+ h · ${grouped.withoutCondition} under 7 h',
        confidence: LabConfidence.insufficient,
        confounders: const ['Sleep quality', 'stress', 'training fatigue'],
      );
    }
    final effect = grouped.effectPercent;
    return LabEvidence(
      id: 'sleep',
      title: 'Sleep and performance',
      finding: effect.abs() < 1
          ? 'Matched session performance was similar across logged sleep amounts.'
          : 'Matched session performance was ${effect >= 0 ? 'higher' : 'lower'} after at least seven hours of sleep.',
      metric: 'Mean estimated one-rep max for matched exercises',
      comparison: LabConditionDefinitions.sleepComparison,
      sampleLabel:
          '${grouped.withCondition} at 7+ h · ${grouped.withoutCondition} under 7 h',
      confidence: _confidence(grouped.withCondition, grouped.withoutCondition),
      confounders: const ['Sleep quality', 'stress', 'training fatigue'],
      effectPercent: effect,
      positive: effect >= 0,
    );
  }

  LabEvidence _creatineConsistency(
    AppStore store,
    DateTime end, {
    required bool workoutsIncluded,
  }) {
    final start = dateOnly(end.subtract(const Duration(days: 27)));
    final creatineDays = <String>{};
    for (final event in store.supplementEvents) {
      if (!event.containsCreatine ||
          event.takenAt.isBefore(start) ||
          event.takenAt.isAfter(end)) {
        continue;
      }
      creatineDays.add(_dayKey(event.takenAt));
    }
    final adherence = creatineDays.length / 28 * 100;
    final workoutCount = workoutsIncluded
        ? labCompletedSessions(store.exportState())
              .where(
                (record) =>
                    !record.occurredAt.isBefore(start) &&
                    !record.occurredAt.isAfter(end),
              )
              .length
        : 0;
    if (store.supplementEvents
        .where((event) => event.containsCreatine)
        .isEmpty) {
      return const LabEvidence(
        id: 'creatine',
        title: 'Creatine consistency',
        finding: 'No creatine entries have been logged yet.',
        metric: 'Daily adherence',
        comparison: 'Last 28 days',
        sampleLabel: '0 logged days',
        confidence: LabConfidence.insufficient,
        confounders: ['Unlogged doses', 'training consistency'],
        adherencePercent: 0,
        neutral: true,
      );
    }
    return LabEvidence(
      id: 'creatine',
      title: 'Creatine consistency',
      finding:
          'Creatine was logged on ${creatineDays.length} of the last 28 days. This is an adherence signal, not proof of effect.',
      metric: 'Daily adherence',
      comparison: 'Last 28 days',
      sampleLabel:
          '${creatineDays.length}/28 days${workoutsIncluded ? ' · $workoutCount workouts' : ''}',
      confidence: creatineDays.length >= 14
          ? LabConfidence.developing
          : LabConfidence.preliminary,
      confounders: const [
        'Unlogged doses',
        'training consistency',
        'dietary intake',
      ],
      adherencePercent: adherence,
      neutral: true,
    );
  }

  LabEvidence _workoutResponseSummary(AppStore store, DateTime end) {
    final start = end.subtract(const Duration(days: 28));
    final values = store.workoutResponses
        .where(
          (item) =>
              !item.recordedAt.isBefore(start) && !item.recordedAt.isAfter(end),
        )
        .toList();
    if (values.length < 3) {
      return LabEvidence(
        id: 'workout-response',
        title: 'Workout ratings',
        finding: 'Save a few workout ratings to establish a baseline.',
        metric: 'Energy, focus, effort, and discomfort',
        comparison: 'Last 28 days',
        sampleLabel: '${values.length} ratings',
        confidence: LabConfidence.insufficient,
        confounders: const ['Subjective ratings', 'workout difficulty'],
      );
    }
    double average(Iterable<int> source) =>
        source.reduce((a, b) => a + b) / source.length;
    final energy = average(values.map((item) => item.energy));
    final focus = average(values.map((item) => item.focus));
    final discomfort = average(values.map((item) => item.discomfort));
    return LabEvidence(
      id: 'workout-response',
      title: 'Workout ratings',
      finding:
          'Average energy was ${energy.toStringAsFixed(1)}/5, focus ${focus.toStringAsFixed(1)}/5, and discomfort ${discomfort.toStringAsFixed(1)}/5.',
      metric: 'Post-workout self-ratings',
      comparison: 'Last 28 days',
      sampleLabel: '${values.length} ratings',
      confidence: _confidence(values.length, values.length),
      confounders: const ['Subjective ratings', 'workout difficulty'],
      neutral: true,
    );
  }

  LabEvidence _bodyweightTrend(AppStore store, DateTime end) {
    final start = dateOnly(end.subtract(const Duration(days: 56)));
    final values = labDailyWeights(store.exportState())
        .where(
          (item) =>
              item.date.compareTo(_dayKey(start)) >= 0 &&
              item.date.compareTo(_dayKey(end)) <= 0,
        )
        .toList();
    if (values.length < 3) {
      return LabEvidence(
        id: 'bodyweight',
        title: 'Bodyweight trend',
        finding: 'More bodyweight entries are needed to establish a trend.',
        metric: 'Bodyweight',
        comparison: 'Up to 56 days',
        sampleLabel: '${values.length} entries',
        confidence: LabConfidence.insufficient,
        confounders: const ['Hydration', 'time of day', 'food intake'],
      );
    }
    final first = values.first.value;
    final last = values.last.value;
    final change = ((last - first) / first) * 100;
    return LabEvidence(
      id: 'bodyweight',
      title: 'Bodyweight trend',
      finding:
          'Bodyweight changed ${change >= 0 ? 'up' : 'down'} by ${change.abs().toStringAsFixed(1)}% across the logged period.',
      metric: 'Bodyweight',
      comparison:
          '${_shortDate(DateTime.parse(values.first.date))} to ${_shortDate(DateTime.parse(values.last.date))}',
      sampleLabel: '${values.length} entries',
      confidence: _confidence(values.length, values.length),
      confounders: const ['Hydration', 'time of day', 'food intake'],
      effectPercent: change,
      positive: true,
      neutral: true,
    );
  }

  LabEvidence _athleticConsistency(AppStore store, DateTime end) {
    final start = end.subtract(const Duration(days: 28));
    final records = store.athleticHistory
        .where(
          (item) =>
              item.isComplete &&
              !item.completedAt.isBefore(start) &&
              !item.completedAt.isAfter(end),
        )
        .toList();
    if (records.isEmpty) {
      return const LabEvidence(
        id: 'athletic-consistency',
        title: 'Athletic consistency',
        finding: 'No Athletic sessions were completed in the last 28 days.',
        metric: 'Completed sessions',
        comparison: 'Last 28 days',
        sampleLabel: '0 sessions',
        confidence: LabConfidence.insufficient,
        confounders: ['Program start date', 'unlogged sessions'],
      );
    }
    final averageEffort =
        records.map((item) => item.effort).reduce((a, b) => a + b) /
        records.length;
    return LabEvidence(
      id: 'athletic-consistency',
      title: 'Athletic consistency',
      finding:
          '${records.length} Athletic sessions were completed with average effort ${averageEffort.toStringAsFixed(1)}/10.',
      metric: 'Completed Athletic sessions',
      comparison: 'Last 28 days',
      sampleLabel: '${records.length} sessions',
      confidence: _confidence(records.length, records.length),
      confounders: const ['Program start date', 'session difficulty'],
      neutral: true,
    );
  }

  List<_StrengthSession> _strengthSessions(
    AppStore store, {
    required DateTime start,
    required DateTime end,
  }) {
    final result = <_StrengthSession>[];
    for (final record in labCompletedSessions(store.exportState())) {
      final sessionLogs = record.logs
          .map(SetLog.fromJson)
          .where(supportsStrengthEstimate)
          .toList();
      if (sessionLogs.isEmpty) continue;
      final startedAt = record.occurredAt;
      if (startedAt.isBefore(start) || startedAt.isAfter(end)) continue;
      final bestByExercise = <String, double>{};
      for (final log in sessionLogs) {
        final key = log.exerciseId ?? log.exercise.trim().toLowerCase();
        final current = bestByExercise[key];
        if (current == null || log.e1rm > current) {
          bestByExercise[key] = log.e1rm;
        }
      }
      final keys = bestByExercise.keys.toList()..sort();
      result.add(
        _StrengthSession(
          id: record.id,
          workoutName: record.workoutName,
          comparisonKey: keys.join('|'),
          startedAt: startedAt,
          score:
              bestByExercise.values.reduce((a, b) => a + b) /
              bestByExercise.length,
        ),
      );
    }
    return result;
  }

  _MatchedComparison _matchedGroups(
    List<_StrengthSession> sessions,
    bool Function(_StrengthSession) hasCondition,
  ) {
    final byWorkout = <String, List<_StrengthSession>>{};
    for (final session in sessions) {
      byWorkout.putIfAbsent(session.comparisonKey, () => []).add(session);
    }
    var withCount = 0;
    var withoutCount = 0;
    var weightedDifference = 0.0;
    var comparisonWeight = 0;
    for (final group in byWorkout.values) {
      final withValues = group
          .where(hasCondition)
          .map((item) => item.score)
          .toList();
      final withoutValues = group
          .where((item) => !hasCondition(item))
          .map((item) => item.score)
          .toList();
      if (withValues.isEmpty || withoutValues.isEmpty) continue;
      final withMean = _mean(withValues);
      final withoutMean = _mean(withoutValues);
      if (withoutMean <= 0) continue;
      final weight = math.min(withValues.length, withoutValues.length);
      weightedDifference +=
          ((withMean - withoutMean) / withoutMean * 100) * weight;
      comparisonWeight += weight;
      withCount += withValues.length;
      withoutCount += withoutValues.length;
    }
    return _MatchedComparison(
      withCondition: withCount,
      withoutCondition: withoutCount,
      effectPercent: comparisonWeight == 0
          ? 0
          : weightedDifference / comparisonWeight,
    );
  }

  double _hydrationBefore(AppStore store, DateTime sessionStart) {
    final earliest = sessionStart.subtract(const Duration(hours: 4));
    return store.hydrationEvents
        .where(
          (event) =>
              !event.occurredAt.isBefore(earliest) &&
              !event.occurredAt.isAfter(sessionStart),
        )
        .fold(0.0, (sum, event) => sum + event.amountMl);
  }

  bool _mealBefore(AppStore store, DateTime sessionStart) {
    final earliest = sessionStart.subtract(const Duration(minutes: 240));
    final latest = sessionStart.subtract(const Duration(minutes: 45));
    return store.mealEvents.any(
      (event) =>
          !event.occurredAt.isBefore(earliest) &&
          !event.occurredAt.isAfter(latest),
    );
  }

  LabConfidence _confidence(int a, int b) {
    final minimum = math.min(a, b);
    if (minimum < 3) return LabConfidence.insufficient;
    if (minimum < 5) return LabConfidence.preliminary;
    if (minimum < 10) return LabConfidence.developing;
    return LabConfidence.stronger;
  }

  double _mean(List<double> values) =>
      values.reduce((a, b) => a + b) / values.length;

  String _dayKey(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  String _shortDate(DateTime value) => formatAppDate(value);
}

class _StrengthSession {
  const _StrengthSession({
    required this.id,
    required this.workoutName,
    required this.comparisonKey,
    required this.startedAt,
    required this.score,
  });

  final String id;
  final String workoutName;
  final String comparisonKey;
  final DateTime startedAt;
  final double score;
}

class _MatchedComparison {
  const _MatchedComparison({
    required this.withCondition,
    required this.withoutCondition,
    required this.effectPercent,
  });

  final int withCondition;
  final int withoutCondition;
  final double effectPercent;
}
