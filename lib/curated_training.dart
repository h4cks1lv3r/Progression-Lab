import 'curated_programs.dart';

/// A performed session uses a snapshot of its prescriptions, so an app update
/// cannot change the steps of an unfinished workout.
class CuratedStep {
  const CuratedStep(this.movementIndex, this.targetIndex, this.movement);
  final int movementIndex;
  final int targetIndex;
  final CuratedMovement movement;
  CuratedSetTarget get target => movement.targets[targetIndex];
}

List<CuratedStep> curatedSteps(CuratedDay day) {
  final steps = <CuratedStep>[];
  var index = 0;
  while (index < day.movements.length) {
    final first = day.movements[index];
    if (first.group == null) {
      for (var set = 0; set < first.targets.length; set++) {
        steps.add(CuratedStep(index, set, first));
      }
      index++;
      continue;
    }
    var end = index + 1;
    while (end < day.movements.length &&
        day.movements[end].group == first.group) {
      end++;
    }
    final rounds = day.movements
        .sublist(index, end)
        .map((movement) => movement.targets.length)
        .reduce((a, b) => a > b ? a : b);
    for (var set = 0; set < rounds; set++) {
      for (var movement = index; movement < end; movement++) {
        if (set < day.movements[movement].targets.length) {
          steps.add(CuratedStep(movement, set, day.movements[movement]));
        }
      }
    }
    index = end;
  }
  return List.unmodifiable(steps);
}

class CuratedProgress {
  const CuratedProgress({this.completedSessions = 0, this.run = 1});
  final int completedSessions;
  final int run;
  int get week => completedSessions ~/ 5 + 1;
  int get dayIndex => completedSessions % 5;
  Map<String, dynamic> toJson() => {
    'completedSessions': completedSessions,
    'run': run,
  };
  factory CuratedProgress.fromJson(Map<String, dynamic> json) {
    final completed = (json['completedSessions'] as num).toInt();
    final run = (json['run'] as num).toInt();
    if (completed < 0 || run < 1) {
      throw const FormatException('Invalid curated progress.');
    }
    return CuratedProgress(completedSessions: completed, run: run);
  }
}

class CuratedWorkoutDraft {
  CuratedWorkoutDraft({
    required this.programId,
    required this.sessionId,
    required this.week,
    required this.dayIndex,
    required this.run,
    required this.startedAt,
    required this.day,
    this.nextStepIndex = 0,
    Map<String, String> inputs = const {},
    this.restEndsAt,
  }) : inputs = Map.unmodifiable(inputs);
  final String programId;
  final String sessionId;
  final int week;
  final int dayIndex;
  final int run;
  final DateTime startedAt;
  final CuratedDay day;
  final int nextStepIndex;
  final Map<String, String> inputs;
  final DateTime? restEndsAt;
  List<CuratedStep> get steps => curatedSteps(day);

  CuratedWorkoutDraft withInputs(Map<String, String> value) =>
      CuratedWorkoutDraft(
        programId: programId,
        sessionId: sessionId,
        week: week,
        dayIndex: dayIndex,
        run: run,
        startedAt: startedAt,
        day: day,
        nextStepIndex: nextStepIndex,
        inputs: value,
        restEndsAt: restEndsAt,
      );
  CuratedWorkoutDraft moveTo(int stepIndex, {DateTime? restEnd}) =>
      CuratedWorkoutDraft(
        programId: programId,
        sessionId: sessionId,
        week: week,
        dayIndex: dayIndex,
        run: run,
        startedAt: startedAt,
        day: day,
        nextStepIndex: stepIndex,
        restEndsAt: restEnd,
      );
  Map<String, dynamic> toJson() => {
    'programId': programId,
    'sessionId': sessionId,
    'week': week,
    'dayIndex': dayIndex,
    'run': run,
    'startedAt': startedAt.toIso8601String(),
    'nextStepIndex': nextStepIndex,
    'inputs': inputs,
    if (restEndsAt != null) 'restEndsAt': restEndsAt!.toIso8601String(),
    'day': _dayJson(day),
  };
  factory CuratedWorkoutDraft.fromJson(Map<String, dynamic> json) {
    final draft = CuratedWorkoutDraft(
      programId: json['programId'] as String,
      sessionId: json['sessionId'] as String,
      week: (json['week'] as num).toInt(),
      dayIndex: (json['dayIndex'] as num).toInt(),
      run: (json['run'] as num).toInt(),
      startedAt: DateTime.parse(json['startedAt'] as String),
      day: _readDay(Map<String, dynamic>.from(json['day'] as Map)),
      nextStepIndex: (json['nextStepIndex'] as num).toInt(),
      inputs: Map<String, String>.from(json['inputs'] as Map? ?? {}),
      restEndsAt: DateTime.tryParse('${json['restEndsAt']}'),
    );
    if (draft.programId.isEmpty ||
        draft.sessionId.isEmpty ||
        draft.week < 1 ||
        draft.run < 1 ||
        draft.dayIndex < 0 ||
        draft.dayIndex >= 5 ||
        draft.steps.isEmpty ||
        draft.nextStepIndex < 0 ||
        draft.nextStepIndex > draft.steps.length) {
      throw const FormatException('Invalid curated workout draft.');
    }
    return draft;
  }
}

class CuratedSessionRecord {
  const CuratedSessionRecord({
    required this.programId,
    required this.sessionId,
    required this.week,
    required this.dayIndex,
    required this.run,
    required this.title,
    required this.startedAt,
    required this.completedAt,
    required this.status,
    required this.setCount,
    required this.totalSteps,
  });
  final String programId;
  final String sessionId;
  final int week;
  final int dayIndex;
  final int run;
  final String title;
  final DateTime startedAt;
  final DateTime completedAt;
  final String status;
  final int setCount;
  final int totalSteps;
  CuratedSessionRecord withSetCount(int count) => CuratedSessionRecord(
    programId: programId,
    sessionId: sessionId,
    week: week,
    dayIndex: dayIndex,
    run: run,
    title: title,
    startedAt: startedAt,
    completedAt: completedAt,
    status: count < totalSteps ? 'partial' : status,
    setCount: count,
    totalSteps: totalSteps,
  );
  Map<String, dynamic> toJson() => {
    'programId': programId,
    'sessionId': sessionId,
    'week': week,
    'dayIndex': dayIndex,
    'run': run,
    'title': title,
    'startedAt': startedAt.toIso8601String(),
    'completedAt': completedAt.toIso8601String(),
    'status': status,
    'setCount': setCount,
    'totalSteps': totalSteps,
  };
  factory CuratedSessionRecord.fromJson(Map<String, dynamic> json) =>
      CuratedSessionRecord(
        programId: json['programId'] as String,
        sessionId: json['sessionId'] as String,
        week: (json['week'] as num).toInt(),
        dayIndex: (json['dayIndex'] as num).toInt(),
        run: (json['run'] as num).toInt(),
        title: json['title'] as String,
        startedAt: DateTime.parse(json['startedAt'] as String),
        completedAt: DateTime.parse(json['completedAt'] as String),
        status: json['status'] as String,
        setCount: (json['setCount'] as num).toInt(),
        totalSteps: (json['totalSteps'] as num).toInt(),
      );
}

class CuratedTrainingState {
  CuratedTrainingState({
    Map<String, CuratedProgress> progress = const {},
    Map<String, CuratedWorkoutDraft> drafts = const {},
    List<CuratedSessionRecord> history = const [],
  }) : progress = Map.unmodifiable(progress),
       drafts = Map.unmodifiable(drafts),
       history = List.unmodifiable(history);
  final Map<String, CuratedProgress> progress;
  final Map<String, CuratedWorkoutDraft> drafts;
  final List<CuratedSessionRecord> history;
  CuratedTrainingState copyWith({
    Map<String, CuratedProgress>? progress,
    Map<String, CuratedWorkoutDraft>? drafts,
    List<CuratedSessionRecord>? history,
  }) => CuratedTrainingState(
    progress: progress ?? this.progress,
    drafts: drafts ?? this.drafts,
    history: history ?? this.history,
  );
  Map<String, dynamic> toJson() => {
    'progress': {for (final e in progress.entries) e.key: e.value.toJson()},
    'drafts': {for (final e in drafts.entries) e.key: e.value.toJson()},
    'history': history.map((e) => e.toJson()).toList(),
  };
  factory CuratedTrainingState.fromJson(Object? raw) {
    if (raw == null) return CuratedTrainingState();
    final json = Map<String, dynamic>.from(raw as Map);
    return CuratedTrainingState(
      progress: {
        for (final e in (json['progress'] as Map? ?? {}).entries)
          e.key as String: CuratedProgress.fromJson(
            Map<String, dynamic>.from(e.value as Map),
          ),
      },
      drafts: {
        for (final e in (json['drafts'] as Map? ?? {}).entries)
          e.key as String: CuratedWorkoutDraft.fromJson(
            Map<String, dynamic>.from(e.value as Map),
          ),
      },
      history: [
        for (final item in json['history'] as List? ?? [])
          CuratedSessionRecord.fromJson(Map<String, dynamic>.from(item as Map)),
      ],
    );
  }
}

Map<String, dynamic> _dayJson(CuratedDay day) => {
  'title': day.title,
  'notes': day.notes,
  'movements': [
    for (final m in day.movements)
      {
        'name': m.name,
        'metric': m.metric.name,
        'restSeconds': m.restSeconds,
        'instructions': m.instructions,
        'group': m.group,
        'targets': [
          for (final t in m.targets)
            {
              'reps': t.reps,
              'seconds': t.seconds,
              'meters': t.meters,
              'note': t.note,
            },
        ],
      },
  ],
};

CuratedDay _readDay(Map<String, dynamic> json) => CuratedDay(
  title: json['title'] as String,
  notes: json['notes'] as String? ?? '',
  movements: [
    for (final raw in json['movements'] as List)
      () {
        final m = Map<String, dynamic>.from(raw as Map);
        return CuratedMovement(
          name: m['name'] as String,
          metric: CuratedMetric.values.byName(m['metric'] as String),
          restSeconds: (m['restSeconds'] as num).toInt(),
          instructions: m['instructions'] as String? ?? '',
          group: m['group'] as String?,
          targets: [
            for (final rawTarget in m['targets'] as List)
              () {
                final t = Map<String, dynamic>.from(rawTarget as Map);
                return CuratedSetTarget(
                  reps: t['reps'] as String?,
                  seconds: (t['seconds'] as num?)?.toInt(),
                  meters: (t['meters'] as num?)?.toDouble(),
                  note: t['note'] as String? ?? '',
                );
              }(),
          ],
        );
      }(),
  ],
);
