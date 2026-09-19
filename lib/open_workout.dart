import 'exercise_models.dart';

/// Keep the selected exercise's tracking rules with the session, including
/// custom exercises that may later be renamed or archived.
class OpenWorkoutExercise {
  const OpenWorkoutExercise({
    required this.id,
    required this.name,
    required this.trackingType,
  });
  final String id;
  final String name;
  final ExerciseTrackingType trackingType;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'trackingType': trackingType.name,
  };

  factory OpenWorkoutExercise.fromJson(Map<String, dynamic> json) =>
      OpenWorkoutExercise(
        id: json['id'] as String,
        name: json['name'] as String,
        trackingType: ExerciseTrackingType.values.byName(
          json['trackingType'] as String,
        ),
      );
}

class OpenWorkoutDraft {
  OpenWorkoutDraft({
    required this.sessionId,
    required this.startedAt,
    List<OpenWorkoutExercise> exercises = const [],
    this.selectedIndex = 0,
    this.nextSetSequence = 0,
    Map<String, String> inputs = const {},
    Map<int, Map<String, String>> inputsByExercise = const {},
  }) : exercises = List.unmodifiable(exercises),
       inputsByExercise = Map.unmodifiable({
         for (final entry in inputsByExercise.entries)
           entry.key: Map<String, String>.unmodifiable(entry.value),
         if (inputs.isNotEmpty)
           selectedIndex: Map<String, String>.unmodifiable(inputs),
       });

  final String sessionId;
  final DateTime startedAt;
  final List<OpenWorkoutExercise> exercises;
  final int selectedIndex;
  // Never reuse a sequence after deleting a set: a retry cannot resurrect it.
  final int nextSetSequence;
  final Map<int, Map<String, String>> inputsByExercise;
  Map<String, String> get inputs => inputsByExercise[selectedIndex] ?? const {};
  OpenWorkoutExercise? get selectedExercise =>
      exercises.isEmpty ? null : exercises[selectedIndex];

  OpenWorkoutDraft copyWith({
    List<OpenWorkoutExercise>? exercises,
    int? selectedIndex,
    int? nextSetSequence,
    Map<String, String>? inputs,
    Map<int, Map<String, String>>? inputsByExercise,
  }) => OpenWorkoutDraft(
    sessionId: sessionId,
    startedAt: startedAt,
    exercises: exercises ?? this.exercises,
    selectedIndex: selectedIndex ?? this.selectedIndex,
    nextSetSequence: nextSetSequence ?? this.nextSetSequence,
    inputsByExercise: {
      ...inputsByExercise ?? this.inputsByExercise,
      if (inputs != null) selectedIndex ?? this.selectedIndex: inputs,
    },
  );

  Map<String, dynamic> toJson() => {
    'sessionId': sessionId,
    'startedAt': startedAt.toIso8601String(),
    'exercises': exercises.map((value) => value.toJson()).toList(),
    'selectedIndex': selectedIndex,
    'nextSetSequence': nextSetSequence,
    'inputs': inputs,
    'inputsByExercise': {
      for (final entry in inputsByExercise.entries) '${entry.key}': entry.value,
    },
  };

  factory OpenWorkoutDraft.fromJson(Map<String, dynamic> json) {
    final result = OpenWorkoutDraft(
      sessionId: json['sessionId'] as String,
      startedAt: DateTime.parse(json['startedAt'] as String),
      exercises: [
        for (final raw in json['exercises'] as List)
          OpenWorkoutExercise.fromJson(Map<String, dynamic>.from(raw as Map)),
      ],
      selectedIndex: (json['selectedIndex'] as num).toInt(),
      nextSetSequence: (json['nextSetSequence'] as num).toInt(),
      inputs: json['inputsByExercise'] == null
          ? Map<String, String>.from(json['inputs'] as Map? ?? {})
          : const {},
      inputsByExercise: {
        for (final entry in (json['inputsByExercise'] as Map? ?? {}).entries)
          int.parse('${entry.key}'): Map<String, String>.from(
            entry.value as Map,
          ),
      },
    );
    if (result.sessionId.isEmpty ||
        result.selectedIndex < 0 ||
        (result.exercises.isEmpty
            ? result.selectedIndex != 0
            : result.selectedIndex >= result.exercises.length) ||
        result.nextSetSequence < 0) {
      throw const FormatException('This Open Workout could not be restored.');
    }
    return result;
  }
}

class OpenWorkoutRecord {
  const OpenWorkoutRecord({
    required this.sessionId,
    required this.startedAt,
    required this.completedAt,
  });
  final String sessionId;
  final DateTime startedAt;
  final DateTime completedAt;

  Map<String, dynamic> toJson() => {
    'sessionId': sessionId,
    'startedAt': startedAt.toIso8601String(),
    'completedAt': completedAt.toIso8601String(),
  };

  factory OpenWorkoutRecord.fromJson(Map<String, dynamic> json) =>
      OpenWorkoutRecord(
        sessionId: json['sessionId'] as String,
        startedAt: DateTime.parse(json['startedAt'] as String),
        completedAt: DateTime.parse(json['completedAt'] as String),
      );
}

class OpenWorkoutState {
  OpenWorkoutState({this.draft, List<OpenWorkoutRecord> history = const []})
    : history = List.unmodifiable(history);
  final OpenWorkoutDraft? draft;
  final List<OpenWorkoutRecord> history;

  Map<String, dynamic> toJson() => {
    'draft': draft?.toJson(),
    'history': history.map((value) => value.toJson()).toList(),
  };

  factory OpenWorkoutState.fromJson(Object? value) {
    if (value == null) return OpenWorkoutState();
    if (value is! Map) {
      throw const FormatException('Open Workout data could not be restored.');
    }
    return OpenWorkoutState(
      draft: value['draft'] == null
          ? null
          : OpenWorkoutDraft.fromJson(
              Map<String, dynamic>.from(value['draft'] as Map),
            ),
      history: [
        for (final raw in value['history'] as List? ?? [])
          OpenWorkoutRecord.fromJson(Map<String, dynamic>.from(raw as Map)),
      ],
    );
  }
}
