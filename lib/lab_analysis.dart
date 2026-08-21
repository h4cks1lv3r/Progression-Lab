import 'dart:convert';
import 'dart:math' as math;

import 'daily_inputs.dart';
import 'store.dart';

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
    this.positive = true,
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
  final bool positive;

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
    'positive': positive,
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
      if (question != null) 'question': question,
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
    final sessions = _strengthSessions(store, start: start, end: end);
    final evidence = <LabEvidence>[];

    if (domains.contains(LabDataDomain.workouts)) {
      evidence.add(_strengthTrend(store, end));
    }
    if (domains.contains(LabDataDomain.supplements)) {
      evidence.add(_caffeineAssociation(store, sessions));
      evidence.add(_creatineConsistency(store, end));
    }
    if (domains.contains(LabDataDomain.meals)) {
      evidence.add(_mealAssociation(store, sessions));
    }
    if (domains.contains(LabDataDomain.hydration)) {
      evidence.add(_hydrationAssociation(store, sessions));
    }
    if (domains.contains(LabDataDomain.recovery)) {
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
        'strengthSets': store.logs.where((log) => !log.date.isBefore(start)).length,
        'athleticSessions': store.athleticHistory
            .where((record) => !record.completedAt.isBefore(start))
            .length,
        'supplementEvents': store.supplementEvents
            .where((event) => !event.takenAt.isBefore(start))
            .length,
        'mealEvents': store.mealEvents
            .where((event) => !event.occurredAt.isBefore(start))
            .length,
        'recoveryCheckIns': store.recoveryCheckIns
            .where((item) => !item.localDate.isBefore(dateOnly(start)))
            .length,
        'workoutResponses': store.workoutResponses
            .where((item) => !item.recordedAt.isBefore(start))
            .length,
      },
    );
  }

  LabEvidence _strengthTrend(AppStore store, DateTime end) {
    final recentStart = end.subtract(const Duration(days: 28));
    final previousStart = end.subtract(const Duration(days: 56));
    final recent = <String, double>{};
    final previous = <String, double>{};
    for (final log in store.logs) {
      if (log.date.isAfter(end)) continue;
      final target = !log.date.isBefore(recentStart)
          ? recent
          : !log.date.isBefore(previousStart)
              ? previous
              : null;
      if (target == null) continue;
      final current = target[log.exercise];
      if (current == null || log.e1rm > current) target[log.exercise] = log.e1rm;
    }
    final common = recent.keys.where(previous.containsKey).toList();
    if (common.length < 2) {
      return const LabEvidence(
        id: 'strength-trend',
        title: 'Strength trend',
        finding: 'More repeated exercise data is needed across two four-week windows.',
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
      confounders: const ['Program phase', 'rep range', 'exercise substitutions'],
      effectPercent: average,
      positive: average >= 0,
    );
  }

  LabEvidence _caffeineAssociation(
    AppStore store,
    List<_StrengthSession> sessions,
  ) {
    final grouped = _matchedGroups(
      sessions,
      (session) => _caffeineBefore(store, session.startedAt) >= 25,
    );
    if (grouped.withCondition < 3 || grouped.withoutCondition < 3) {
      return LabEvidence(
        id: 'caffeine',
        title: 'Caffeine and performance',
        finding: 'More matched workouts with and without caffeine are needed.',
        metric: 'Normalized session strength score',
        comparison: '25+ mg caffeine 20–180 minutes before training vs none',
        sampleLabel:
            '${grouped.withCondition} with · ${grouped.withoutCondition} without',
        confidence: LabConfidence.insufficient,
        confounders: const ['Sleep', 'meal timing', 'program phase', 'dose tolerance'],
      );
    }
    final effect = grouped.effectPercent;
    return LabEvidence(
      id: 'caffeine',
      title: 'Caffeine and performance',
      finding: effect.abs() < 1
          ? 'Matched session performance was similar with and without caffeine.'
          : 'Matched session performance was ${effect >= 0 ? 'higher' : 'lower'} after logged caffeine.',
      metric: 'Normalized session strength score',
      comparison: '25+ mg caffeine 20–180 minutes before training vs none',
      sampleLabel:
          '${grouped.withCondition} with · ${grouped.withoutCondition} without',
      confidence: _confidence(grouped.withCondition, grouped.withoutCondition),
      confounders: const ['Sleep', 'meal timing', 'program phase', 'dose tolerance'],
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
        finding: 'More matched workouts with and without a recent meal are needed.',
        metric: 'Normalized session strength score',
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
      metric: 'Normalized session strength score',
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
        finding: 'More matched workouts with different hydration conditions are needed.',
        metric: 'Normalized session strength score',
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
      metric: 'Normalized session strength score',
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
    final usable = sessions
        .where((session) => store.recoveryForDay(session.startedAt)?.sleepHours != null)
        .toList();
    final grouped = _matchedGroups(
      usable,
      (session) =>
          (store.recoveryForDay(session.startedAt)?.sleepHours ?? 0) >= 7,
    );
    if (grouped.withCondition < 3 || grouped.withoutCondition < 3) {
      return LabEvidence(
        id: 'sleep',
        title: 'Sleep and performance',
        finding: 'More matched workouts with complete sleep check-ins are needed.',
        metric: 'Normalized session strength score',
        comparison: '7+ hours sleep vs under 7 hours',
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
      metric: 'Normalized session strength score',
      comparison: '7+ hours sleep vs under 7 hours',
      sampleLabel:
          '${grouped.withCondition} at 7+ h · ${grouped.withoutCondition} under 7 h',
      confidence: _confidence(grouped.withCondition, grouped.withoutCondition),
      confounders: const ['Sleep quality', 'stress', 'training fatigue'],
      effectPercent: effect,
      positive: effect >= 0,
    );
  }

  LabEvidence _creatineConsistency(AppStore store, DateTime end) {
    final start = dateOnly(end.subtract(const Duration(days: 27)));
    final creatineDays = <String>{};
    for (final event in store.supplementEvents) {
      if (!event.containsCreatine || event.takenAt.isBefore(start)) continue;
      creatineDays.add(_dayKey(event.takenAt));
    }
    final adherence = creatineDays.length / 28 * 100;
    final workoutCount = store.workoutHistory
        .where(
          (record) =>
              record.status == WorkoutStatus.completed &&
              !record.loggedAt.isBefore(start),
        )
        .length;
    if (store.supplementEvents.where((event) => event.containsCreatine).isEmpty) {
      return const LabEvidence(
        id: 'creatine',
        title: 'Creatine consistency',
        finding: 'No creatine entries have been logged yet.',
        metric: 'Daily adherence',
        comparison: 'Last 28 days',
        sampleLabel: '0 logged days',
        confidence: LabConfidence.insufficient,
        confounders: ['Unlogged doses', 'training consistency'],
      );
    }
    return LabEvidence(
      id: 'creatine',
      title: 'Creatine consistency',
      finding:
          'Creatine was logged on ${creatineDays.length} of the last 28 days. This is an adherence signal, not proof of effect.',
      metric: 'Daily adherence',
      comparison: 'Last 28 days',
      sampleLabel: '${creatineDays.length}/28 days · $workoutCount workouts',
      confidence: creatineDays.length >= 14
          ? LabConfidence.developing
          : LabConfidence.preliminary,
      confounders: const ['Unlogged doses', 'training consistency', 'dietary intake'],
      effectPercent: adherence,
      positive: adherence >= 70,
    );
  }

  LabEvidence _workoutResponseSummary(AppStore store, DateTime end) {
    final start = end.subtract(const Duration(days: 28));
    final values = store.workoutResponses
        .where((item) => !item.recordedAt.isBefore(start))
        .toList();
    if (values.length < 3) {
      return LabEvidence(
        id: 'workout-response',
        title: 'Session response',
        finding: 'Complete a few post-workout check-ins to establish a baseline.',
        metric: 'Energy, focus, effort, and discomfort',
        comparison: 'Last 28 days',
        sampleLabel: '${values.length} check-ins',
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
      title: 'Session response',
      finding:
          'Average energy was ${energy.toStringAsFixed(1)}/5, focus ${focus.toStringAsFixed(1)}/5, and discomfort ${discomfort.toStringAsFixed(1)}/5.',
      metric: 'Post-workout self-ratings',
      comparison: 'Last 28 days',
      sampleLabel: '${values.length} check-ins',
      confidence: _confidence(values.length, values.length),
      confounders: const ['Subjective ratings', 'workout difficulty'],
      positive: energy >= 3 && focus >= 3 && discomfort <= 3,
    );
  }

  LabEvidence _bodyweightTrend(AppStore store, DateTime end) {
    final start = dateOnly(end.subtract(const Duration(days: 56)));
    final values = store.recoveryCheckIns
        .where(
          (item) =>
              item.bodyWeight != null && !item.localDate.isBefore(start),
        )
        .toList()
      ..sort((a, b) => a.localDate.compareTo(b.localDate));
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
    final first = values.first.bodyWeight!;
    final last = values.last.bodyWeight!;
    final change = ((last - first) / first) * 100;
    return LabEvidence(
      id: 'bodyweight',
      title: 'Bodyweight trend',
      finding:
          'Bodyweight changed ${change >= 0 ? 'up' : 'down'} by ${change.abs().toStringAsFixed(1)}% across the logged period.',
      metric: 'Bodyweight',
      comparison:
          '${_shortDate(values.first.localDate)} to ${_shortDate(values.last.localDate)}',
      sampleLabel: '${values.length} entries',
      confidence: _confidence(values.length, values.length),
      confounders: const ['Hydration', 'time of day', 'food intake'],
      effectPercent: change,
      positive: change.abs() <= 2,
    );
  }

  LabEvidence _athleticConsistency(AppStore store, DateTime end) {
    final start = end.subtract(const Duration(days: 28));
    final records = store.athleticHistory
        .where((item) => !item.completedAt.isBefore(start))
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
      positive: records.length >= 8,
    );
  }

  List<_StrengthSession> _strengthSessions(
    AppStore store, {
    required DateTime start,
    required DateTime end,
  }) {
    final result = <_StrengthSession>[];
    for (final record in store.workoutHistory) {
      if (record.status != WorkoutStatus.completed || record.sessionId == null) {
        continue;
      }
      final sessionLogs = store.logs
          .where((log) => log.sessionId == record.sessionId)
          .toList();
      if (sessionLogs.isEmpty) continue;
      sessionLogs.sort((a, b) => a.date.compareTo(b.date));
      final startedAt = sessionLogs.first.date;
      if (startedAt.isBefore(start) || startedAt.isAfter(end)) continue;
      final bestByExercise = <String, double>{};
      for (final log in sessionLogs) {
        final current = bestByExercise[log.exercise];
        if (current == null || log.e1rm > current) {
          bestByExercise[log.exercise] = log.e1rm;
        }
      }
      if (bestByExercise.isEmpty) continue;
      final score = bestByExercise.values.reduce((a, b) => a + b) /
          bestByExercise.length;
      result.add(
        _StrengthSession(
          id: record.sessionId!,
          workoutName: record.workout,
          startedAt: startedAt,
          score: score,
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
      byWorkout.putIfAbsent(session.workoutName, () => []).add(session);
    }
    var withCount = 0;
    var withoutCount = 0;
    var weightedDifference = 0.0;
    var comparisonWeight = 0;
    for (final group in byWorkout.values) {
      final withValues = group.where(hasCondition).map((item) => item.score).toList();
      final withoutValues = group.where((item) => !hasCondition(item)).map((item) => item.score).toList();
      if (withValues.isEmpty || withoutValues.isEmpty) continue;
      final withMean = _mean(withValues);
      final withoutMean = _mean(withoutValues);
      if (withoutMean <= 0) continue;
      final weight = math.min(withValues.length, withoutValues.length);
      weightedDifference += ((withMean - withoutMean) / withoutMean * 100) * weight;
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

  double _caffeineBefore(AppStore store, DateTime sessionStart) {
    final earliest = sessionStart.subtract(const Duration(minutes: 180));
    final latest = sessionStart.subtract(const Duration(minutes: 20));
    return store.supplementEvents
        .where(
          (event) =>
              event.caffeineMg > 0 &&
              !event.takenAt.isBefore(earliest) &&
              !event.takenAt.isAfter(latest),
        )
        .fold(0.0, (sum, event) => sum + event.caffeineMg);
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

  String _shortDate(DateTime value) => '${value.month}/${value.day}';
}

class _StrengthSession {
  const _StrengthSession({
    required this.id,
    required this.workoutName,
    required this.startedAt,
    required this.score,
  });

  final String id;
  final String workoutName;
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
