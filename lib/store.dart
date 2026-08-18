import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'exercise_library.dart';
import 'program.dart';

class SetLog {
  SetLog({
    required this.exercise,
    required this.weight,
    required this.reps,
    required this.date,
    required this.workout,
    this.notes = '',
    this.sessionId,
    this.exerciseIndex,
  });
  final String exercise;
  final double weight;
  final int reps;
  final DateTime date;
  final String workout;
  final String notes;
  final String? sessionId;
  final int? exerciseIndex;
  double get e1rm => weight * (1 + reps / 30);

  SetLog copyWith({
    String? exercise,
    double? weight,
    int? reps,
    DateTime? date,
    String? workout,
    String? notes,
    String? sessionId,
    int? exerciseIndex,
  }) => SetLog(
    exercise: exercise ?? this.exercise,
    weight: weight ?? this.weight,
    reps: reps ?? this.reps,
    date: date ?? this.date,
    workout: workout ?? this.workout,
    notes: notes ?? this.notes,
    sessionId: sessionId ?? this.sessionId,
    exerciseIndex: exerciseIndex ?? this.exerciseIndex,
  );

  Map<String, dynamic> toJson() => {
    'e': exercise,
    'w': weight,
    'r': reps,
    'd': date.toIso8601String(),
    'o': workout,
    'n': notes,
    if (sessionId != null) 's': sessionId,
    if (exerciseIndex != null) 'i': exerciseIndex,
  };
  factory SetLog.fromJson(Map<String, dynamic> j) => SetLog(
    exercise: j['e'],
    weight: (j['w'] as num).toDouble(),
    reps: j['r'],
    date: DateTime.parse(j['d']),
    workout: j['o'],
    notes: j['n'] is String ? j['n'] as String : '',
    sessionId: j['s'] is String ? j['s'] as String : null,
    exerciseIndex: j['i'] is num ? (j['i'] as num).toInt() : null,
  );
}

enum WorkoutStatus { completed, skipped }

class WorkoutRecord {
  const WorkoutRecord({
    required this.week,
    required this.workoutIndex,
    required this.workout,
    required this.date,
    required this.status,
    this.days = 4,
    DateTime? scheduledDate,
    DateTime? loggedAt,
    this.retroactive = false,
    this.sessionId,
    this.substitutions = const {},
  }) : scheduledDate = scheduledDate ?? date,
       loggedAt = loggedAt ?? date;

  final int week;
  final int workoutIndex;
  final String workout;
  final DateTime date;
  final WorkoutStatus status;
  final int days;
  final DateTime scheduledDate;
  final DateTime loggedAt;
  final bool retroactive;
  final String? sessionId;
  final Map<int, String> substitutions;

  Map<String, dynamic> toJson() => {
    'week': week,
    'workoutIndex': workoutIndex,
    'workout': workout,
    'date': date.toIso8601String(),
    'status': status.name,
    'days': days,
    'scheduledDate': scheduledDate.toIso8601String(),
    'loggedAt': loggedAt.toIso8601String(),
    'retroactive': retroactive,
    if (sessionId != null) 'sessionId': sessionId,
    'substitutions': {
      for (final entry in substitutions.entries) '${entry.key}': entry.value,
    },
  };

  factory WorkoutRecord.fromJson(Map<String, dynamic> json) => WorkoutRecord(
    week: json['week'] as int,
    workoutIndex: json['workoutIndex'] as int,
    workout: json['workout'] as String,
    date: DateTime.parse(json['date'] as String),
    status: WorkoutStatus.values.byName(json['status'] as String),
    days: json['days'] is num ? (json['days'] as num).toInt() : 4,
    scheduledDate: json['scheduledDate'] is String
        ? DateTime.parse(json['scheduledDate'] as String)
        : null,
    loggedAt: json['loggedAt'] is String
        ? DateTime.parse(json['loggedAt'] as String)
        : null,
    retroactive: json['retroactive'] == true,
    sessionId: json['sessionId'] is String ? json['sessionId'] as String : null,
    substitutions: _readSubstitutions(json['substitutions']),
  );

  static Map<int, String> _readSubstitutions(Object? value) {
    if (value is! Map) return const {};
    return {
      for (final entry in value.entries)
        if (int.tryParse('${entry.key}') case final int index)
          if (entry.value is String) index: entry.value as String,
    };
  }
}

class DraftSetInput {
  const DraftSetInput({
    required this.week,
    required this.workoutIndex,
    required this.workout,
    required this.exerciseIndex,
    required this.setNumber,
    required this.sessionId,
    required this.weight,
    required this.reps,
    required this.notes,
    this.days = 4,
    this.retroactive = false,
    this.scheduledDate,
    this.substitutions = const {},
  });

  final int week;
  final int workoutIndex;
  final String workout;
  final int exerciseIndex;
  final int setNumber;
  final String sessionId;
  final String weight;
  final String reps;
  final String notes;
  final int days;
  final bool retroactive;
  final DateTime? scheduledDate;
  final Map<int, String> substitutions;

  Map<String, dynamic> toJson() => {
    'week': week,
    'workoutIndex': workoutIndex,
    'workout': workout,
    'exerciseIndex': exerciseIndex,
    'setNumber': setNumber,
    'sessionId': sessionId,
    'weight': weight,
    'reps': reps,
    'notes': notes,
    'days': days,
    'retroactive': retroactive,
    if (scheduledDate != null)
      'scheduledDate': scheduledDate!.toIso8601String(),
    'substitutions': {
      for (final entry in substitutions.entries) '${entry.key}': entry.value,
    },
  };

  factory DraftSetInput.fromJson(Map<String, dynamic> json) => DraftSetInput(
    week: json['week'] as int,
    workoutIndex: json['workoutIndex'] as int,
    workout: json['workout'] as String,
    exerciseIndex: json['exerciseIndex'] as int,
    setNumber: json['setNumber'] as int,
    sessionId: json['sessionId'] as String,
    weight: json['weight'] as String,
    reps: json['reps'] as String,
    notes: json['notes'] is String ? json['notes'] as String : '',
    days: json['days'] is num ? (json['days'] as num).toInt() : 4,
    retroactive: json['retroactive'] == true,
    scheduledDate: json['scheduledDate'] is String
        ? DateTime.parse(json['scheduledDate'] as String)
        : null,
    substitutions: WorkoutRecord._readSubstitutions(json['substitutions']),
  );
}

class AppStore extends ChangeNotifier {
  static const _channel = MethodChannel('iron_cadence/storage');
  static const int schemaVersion = 6;
  static const double poundsToKilograms = 0.45359237;
  int days = 4;
  int week = 1;
  int workoutIndex = 0;
  String unit = 'lb';
  List<SetLog> logs = [];
  List<WorkoutRecord> workoutHistory = [];
  List<CustomExercise> customExercises = [];
  DraftSetInput? draft;
  List<DraftSetInput> drafts = [];
  DateTime programStartDate = _dateOnly(DateTime.now());

  Future<void> load() async {
    try {
      final raw = await _channel.invokeMethod<String>('read');
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          final original = Map<String, dynamic>.from(decoded);
          final originalVersion = _readInt(original['schemaVersion']) ?? 1;
          final data = _migrate(original);
          final storedDays = _readInt(data['days']) ?? 4;
          days = ProgramEngine.isSupportedDays(storedDays) ? storedDays : 4;
          week = ProgramEngine.clampWeek(_readInt(data['week']) ?? 1);
          workoutIndex = ProgramEngine.clampWorkoutIndex(
            _readInt(data['workout']) ?? 0,
            days,
          );
          final storedUnit = data['unit'];
          unit = storedUnit == 'kg' ? 'kg' : 'lb';
          final storedLogs = data['logs'];
          if (storedLogs is List) {
            logs = storedLogs.map(_readLog).whereType<SetLog>().toList();
          }
          final storedWorkouts = data['workoutHistory'];
          if (storedWorkouts is List) {
            workoutHistory = storedWorkouts
                .map(_readWorkout)
                .whereType<WorkoutRecord>()
                .toList();
          }
          final storedCustomExercises = data['customExercises'];
          if (storedCustomExercises is List) {
            customExercises = storedCustomExercises
                .map(_readCustomExercise)
                .whereType<CustomExercise>()
                .toList();
          }
          draft = _readDraft(data['draft']);
          final storedDrafts = data['drafts'];
          if (storedDrafts is List) {
            drafts = storedDrafts
                .map(_readDraft)
                .whereType<DraftSetInput>()
                .toList();
          }
          if (draft != null &&
              !drafts.any((item) => item.sessionId == draft!.sessionId)) {
            drafts.add(draft!);
          }
          programStartDate = data['programStartDate'] is String
              ? DateTime.parse(data['programStartDate'] as String)
              : _inferredProgramStartDate();
          if (originalVersion < schemaVersion) {
            try {
              await _channel.invokeMethod('write', jsonEncode(data));
            } on PlatformException {
              // The in-memory migration is still usable; retry on next save.
            }
          }
        }
      }
    } on FormatException {
      // Keep the last usable in-memory state if local JSON is incomplete.
    } on PlatformException {
      // Storage being temporarily unavailable must not prevent app startup.
    } on Object {
      // Ignore structurally invalid legacy state and keep usable defaults.
    }
    notifyListeners();
  }

  Future<void> save() async {
    await _channel.invokeMethod(
      'write',
      jsonEncode({
        'days': days,
        'week': week,
        'workout': workoutIndex,
        'unit': unit,
        'logs': logs.map((e) => e.toJson()).toList(),
        'schemaVersion': schemaVersion,
        'workoutHistory': workoutHistory.map((e) => e.toJson()).toList(),
        'customExercises': customExercises
            .map((exercise) => exercise.toJson())
            .toList(),
        'draft': draft?.toJson(),
        'drafts': _draftsForSave.map((item) => item.toJson()).toList(),
        'programStartDate': programStartDate.toIso8601String(),
      }),
    );
  }

  bool isPr(SetLog candidate) => !logs
      .where((l) => l.exercise == candidate.exercise)
      .any((l) => l.weight >= candidate.weight && l.e1rm >= candidate.e1rm);
  SetLog? best(String exercise) {
    final items = logs.where((l) => l.exercise == exercise).toList()
      ..sort((a, b) => b.e1rm.compareTo(a.e1rm));
    return items.isEmpty ? null : items.first;
  }

  List<ExerciseOption> get selectableExercises =>
      ExerciseLibrary.selectable(customExercises);

  Future<CustomExercise> addCustomExercise(String value) async {
    final name = _validatedExerciseName(value);
    final exercise = CustomExercise(
      id: 'custom-${DateTime.now().microsecondsSinceEpoch}',
      name: name,
    );
    customExercises.add(exercise);
    try {
      await save();
    } on Object {
      customExercises.removeLast();
      rethrow;
    }
    notifyListeners();
    return exercise;
  }

  Future<void> renameCustomExercise(String id, String value) async {
    final index = customExercises.indexWhere((exercise) => exercise.id == id);
    if (index < 0) throw StateError('The custom exercise no longer exists.');
    final name = _validatedExerciseName(value, exceptId: id);
    final previous = customExercises[index];
    customExercises[index] = previous.copyWith(name: name);
    try {
      await save();
    } on Object {
      customExercises[index] = previous;
      rethrow;
    }
    notifyListeners();
  }

  Future<void> archiveCustomExercise(String id) async {
    final index = customExercises.indexWhere((exercise) => exercise.id == id);
    if (index < 0) throw StateError('The custom exercise no longer exists.');
    final previous = customExercises[index];
    customExercises[index] = previous.copyWith(isArchived: true);
    try {
      await save();
    } on Object {
      customExercises[index] = previous;
      rethrow;
    }
    notifyListeners();
  }

  String _validatedExerciseName(String value, {String? exceptId}) {
    final name = value.trim();
    if (name.isEmpty) throw ArgumentError('Exercise name cannot be empty.');
    final normalized = name.toLowerCase();
    final builtInCollision = BuiltInExercises.values.any(
      (exercise) => exercise.name.toLowerCase() == normalized,
    );
    final customCollision = customExercises.any(
      (exercise) =>
          exercise.id != exceptId && exercise.name.toLowerCase() == normalized,
    );
    if (builtInCollision || customCollision) {
      throw ArgumentError('An exercise with that name already exists.');
    }
    return name;
  }

  Future<bool> add(SetLog log) async {
    final pr = isPr(log);
    logs.add(log);
    try {
      await save();
    } on Object {
      logs.removeLast();
      rethrow;
    }
    notifyListeners();
    return pr;
  }

  Future<void> updateSet(
    SetLog original, {
    required double weight,
    required int reps,
    required String notes,
  }) async {
    if (!weight.isFinite || weight <= 0 || reps <= 0) {
      throw ArgumentError('Weight and reps must be above zero.');
    }
    final index = logs.indexOf(original);
    if (index < 0) throw StateError('The set no longer exists.');
    final updated = original.copyWith(weight: weight, reps: reps, notes: notes);
    logs[index] = updated;
    try {
      await save();
    } on Object {
      logs[index] = original;
      rethrow;
    }
    notifyListeners();
  }

  Future<void> setDraft(DraftSetInput value) async {
    final previousDraft = draft;
    final previousDrafts = List<DraftSetInput>.of(drafts);
    drafts.removeWhere((item) => _sameDraftTarget(item, value));
    drafts.add(value);
    draft = value;
    try {
      await save();
    } on Object {
      draft = previousDraft;
      drafts = previousDrafts;
      rethrow;
    }
  }

  Future<void> clearDraft() async {
    final previous = draft;
    final previousDrafts = List<DraftSetInput>.of(drafts);
    if (draft != null) {
      drafts.removeWhere((item) => item.sessionId == draft!.sessionId);
    } else {
      drafts.clear();
    }
    draft = null;
    try {
      await save();
    } on Object {
      draft = previous;
      drafts = previousDrafts;
      rethrow;
    }
    notifyListeners();
  }

  Future<void> complete(int workoutsThisWeek) async {
    assert(workoutsThisWeek > 0, 'Workout count must be positive.');
    // The store cadence is authoritative. A workout screen can remain open
    // across a settings change and pass a stale count from the old cadence.
    final previousWeek = week;
    final previousWorkoutIndex = workoutIndex;
    final previousProgramStartDate = programStartDate;
    _advanceWorkout();
    try {
      await save();
    } on Object {
      week = previousWeek;
      workoutIndex = previousWorkoutIndex;
      programStartDate = previousProgramStartDate;
      rethrow;
    }
    notifyListeners();
  }

  Future<void> completeWorkout({required String workout}) => recordWorkout(
    weekNumber: week,
    targetWorkoutIndex: workoutIndex,
    workout: workout,
    status: WorkoutStatus.completed,
    sessionId: draft?.sessionId,
    substitutions: draft?.substitutions ?? const {},
  );

  Future<void> skipWorkout({required String workout}) => recordWorkout(
    weekNumber: week,
    targetWorkoutIndex: workoutIndex,
    workout: workout,
    status: WorkoutStatus.skipped,
    sessionId: draft?.sessionId,
    substitutions: draft?.substitutions ?? const {},
  );

  Future<void> recordWorkout({
    required int weekNumber,
    required int targetWorkoutIndex,
    required String workout,
    required WorkoutStatus status,
    required String? sessionId,
    Map<int, String> substitutions = const {},
    bool retroactive = false,
    DateTime? scheduledDate,
  }) async {
    final previousWeek = week;
    final previousWorkoutIndex = workoutIndex;
    final previousProgramStartDate = programStartDate;
    final previousDraft = draft;
    final previousDrafts = List<DraftSetInput>.of(drafts);
    final record = WorkoutRecord(
      week: weekNumber,
      workoutIndex: targetWorkoutIndex,
      workout: workout,
      date: DateTime.now(),
      status: status,
      days: days,
      scheduledDate:
          scheduledDate ?? dateForSlot(weekNumber, targetWorkoutIndex),
      loggedAt: DateTime.now(),
      retroactive: retroactive,
      sessionId: sessionId,
      substitutions: Map.unmodifiable(substitutions),
    );
    workoutHistory.add(record);
    drafts.removeWhere(
      (item) =>
          item.sessionId == sessionId ||
          (item.week == weekNumber &&
              item.workoutIndex == targetWorkoutIndex &&
              item.days == days &&
              item.retroactive == retroactive),
    );
    if (!retroactive) _advanceWorkout();
    draft = draftFor(
      weekNumber: week,
      targetWorkoutIndex: workoutIndex,
      cadence: days,
      retroactive: false,
    );
    try {
      await save();
    } on Object {
      week = previousWeek;
      workoutIndex = previousWorkoutIndex;
      programStartDate = previousProgramStartDate;
      draft = previousDraft;
      drafts = previousDrafts;
      workoutHistory.removeLast();
      rethrow;
    }
    notifyListeners();
  }

  DateTime dateForSlot(int weekNumber, int targetWorkoutIndex) {
    final offsets = switch (days) {
      3 => const [0, 2, 4],
      4 => const [0, 1, 3, 4],
      5 => const [0, 1, 2, 3, 4],
      _ => throw ArgumentError.value(days, 'days'),
    };
    final index = targetWorkoutIndex.clamp(0, offsets.length - 1);
    return _dateOnly(
      programStartDate.add(
        Duration(days: (weekNumber - 1) * 7 + offsets[index]),
      ),
    );
  }

  bool isPastSlot(int weekNumber, int targetWorkoutIndex) {
    if (weekNumber < week) return true;
    if (weekNumber > week) return false;
    return targetWorkoutIndex < workoutIndex;
  }

  List<WorkoutRecord> recordsForSlot(int weekNumber, int targetWorkoutIndex) =>
      workoutHistory
          .where(
            (record) =>
                record.week == weekNumber &&
                record.workoutIndex == targetWorkoutIndex &&
                record.days == days,
          )
          .toList()
        ..sort((a, b) => b.loggedAt.compareTo(a.loggedAt));

  DraftSetInput? draftFor({
    required int weekNumber,
    required int targetWorkoutIndex,
    required int cadence,
    required bool retroactive,
  }) {
    for (final item in drafts.reversed) {
      if (item.week == weekNumber &&
          item.workoutIndex == targetWorkoutIndex &&
          item.days == cadence &&
          item.retroactive == retroactive) {
        return item;
      }
    }
    final legacy = draft;
    if (legacy != null &&
        legacy.week == weekNumber &&
        legacy.workoutIndex == targetWorkoutIndex &&
        legacy.days == cadence &&
        legacy.retroactive == retroactive) {
      return legacy;
    }
    return null;
  }

  void _advanceWorkout() {
    final currentWorkoutCount = ProgramEngine.workoutCount(days);
    workoutIndex = ProgramEngine.clampWorkoutIndex(workoutIndex, days) + 1;
    if (workoutIndex >= currentWorkoutCount) {
      workoutIndex = 0;
      if (week >= ProgramEngine.totalWeeks) {
        week = 1;
        programStartDate = programStartDate.add(
          const Duration(days: ProgramEngine.totalWeeks * 7),
        );
      } else {
        week++;
      }
    }
  }

  /// Changes cadence without moving the user to another program week.
  ///
  /// With no override, the engine selects the new cadence workout that most
  /// closely matches the current next workout. A UI-provided
  /// [nextWorkoutIndex] always wins after it passes range validation.
  Future<void> setDays(int value, {int? nextWorkoutIndex}) async {
    ProgramEngine.validateDays(value);
    if (nextWorkoutIndex != null &&
        (nextWorkoutIndex < 0 || nextWorkoutIndex >= value)) {
      throw RangeError.range(
        nextWorkoutIndex,
        0,
        value - 1,
        'nextWorkoutIndex',
      );
    }
    final safeWeek = ProgramEngine.clampWeek(week);
    final sourceDays = ProgramEngine.isSupportedDays(days) ? days : 4;
    final destinationIndex =
        nextWorkoutIndex ??
        ProgramEngine.defaultWorkoutIndexForCadenceSwitch(
          week: safeWeek,
          fromDays: sourceDays,
          toDays: value,
          currentWorkoutIndex: workoutIndex,
        );
    final previousDays = days;
    final previousWorkoutIndex = workoutIndex;
    days = value;
    // This is unchanged for valid state; clamping only repairs corrupt legacy
    // values. The week still encodes the same phase and microcycle.
    week = safeWeek;
    workoutIndex = destinationIndex;
    try {
      await save();
    } on Object {
      days = previousDays;
      workoutIndex = previousWorkoutIndex;
      rethrow;
    }
    notifyListeners();
  }

  Future<void> setUnit(String value) async {
    if (value != 'lb' && value != 'kg') {
      throw ArgumentError.value(value, 'value', 'Must be lb or kg');
    }
    if (value == unit) return;

    // Interim persistence model: stored weights use the user's active display
    // unit, so changing units must convert every historical value exactly once.
    // A future database migration should store a canonical base unit and only
    // convert at display/input boundaries.
    final factor = unit == 'lb' ? poundsToKilograms : 1 / poundsToKilograms;
    final previousUnit = unit;
    final previousLogs = logs;
    logs = [for (final log in logs) log.copyWith(weight: log.weight * factor)];
    unit = value;
    try {
      await save();
    } on Object {
      unit = previousUnit;
      logs = previousLogs;
      rethrow;
    }
    notifyListeners();
  }

  static int? _readInt(Object? value) {
    if (value is int) return value;
    if (value is num && value.isFinite) return value.toInt();
    return null;
  }

  static SetLog? _readLog(Object? value) {
    if (value is! Map) return null;
    try {
      return SetLog.fromJson(Map<String, dynamic>.from(value));
    } on Object {
      return null;
    }
  }

  static WorkoutRecord? _readWorkout(Object? value) {
    if (value is! Map) return null;
    try {
      return WorkoutRecord.fromJson(Map<String, dynamic>.from(value));
    } on Object {
      return null;
    }
  }

  static DraftSetInput? _readDraft(Object? value) {
    if (value is! Map) return null;
    try {
      return DraftSetInput.fromJson(Map<String, dynamic>.from(value));
    } on Object {
      return null;
    }
  }

  static CustomExercise? _readCustomExercise(Object? value) {
    if (value is! Map) return null;
    try {
      final exercise = CustomExercise.fromJson(
        Map<String, dynamic>.from(value),
      );
      if (exercise.id.isEmpty || exercise.name.trim().isEmpty) return null;
      return exercise;
    } on Object {
      return null;
    }
  }

  static Map<String, dynamic> _migrate(Map<String, dynamic> source) {
    final data = Map<String, dynamic>.from(source);
    var version = _readInt(data['schemaVersion']) ?? 1;
    if (version < 2) {
      final storedLogs = data['logs'];
      if (storedLogs is List) {
        data['logs'] = [
          for (final value in storedLogs)
            if (value is Map)
              Map<String, dynamic>.from(value)..putIfAbsent('n', () => '')
            else
              value,
        ];
      }
      version = 2;
      data['schemaVersion'] = version;
    }
    if (version < 3) {
      data.putIfAbsent('workoutHistory', () => <Object>[]);
      data.putIfAbsent('draft', () => null);
      version = 3;
      data['schemaVersion'] = version;
    }
    if (version < 4) {
      final storedDays = _readInt(data['days']) ?? 4;
      final storedWeek = ProgramEngine.clampWeek(_readInt(data['week']) ?? 1);
      final storedWorkout = ProgramEngine.clampWorkoutIndex(
        _readInt(data['workout']) ?? 0,
        ProgramEngine.isSupportedDays(storedDays) ? storedDays : 4,
      );
      final now = _dateOnly(DateTime.now());
      final offsets = switch (storedDays) {
        3 => const [0, 2, 4],
        5 => const [0, 1, 2, 3, 4],
        _ => const [0, 1, 3, 4],
      };
      final slotOffset = offsets[storedWorkout.clamp(0, offsets.length - 1)];
      data.putIfAbsent(
        'programStartDate',
        () => now
            .subtract(Duration(days: (storedWeek - 1) * 7 + slotOffset))
            .toIso8601String(),
      );
      final history = data['workoutHistory'];
      if (history is List) {
        data['workoutHistory'] = [
          for (final value in history)
            if (value is Map)
              Map<String, dynamic>.from(value)
                ..putIfAbsent('days', () => storedDays)
                ..putIfAbsent('scheduledDate', () => value['date'])
                ..putIfAbsent('loggedAt', () => value['date'])
                ..putIfAbsent('retroactive', () => false)
                ..putIfAbsent('substitutions', () => <String, String>{})
            else
              value,
        ];
      }
      version = 4;
      data['schemaVersion'] = version;
    }
    if (version < 5) {
      final legacyDraft = data['draft'];
      data.putIfAbsent(
        'drafts',
        () => legacyDraft is Map ? <Object>[legacyDraft] : <Object>[],
      );
      version = 5;
      data['schemaVersion'] = version;
    }
    if (version < 6) {
      data.putIfAbsent('customExercises', () => <Object>[]);
      version = 6;
      data['schemaVersion'] = version;
    }
    return data;
  }

  List<DraftSetInput> get _draftsForSave {
    final values = List<DraftSetInput>.of(drafts);
    final legacy = draft;
    if (legacy != null &&
        !values.any((item) => item.sessionId == legacy.sessionId)) {
      values.add(legacy);
    }
    return values;
  }

  static bool _sameDraftTarget(DraftSetInput a, DraftSetInput b) =>
      a.week == b.week &&
      a.workoutIndex == b.workoutIndex &&
      a.days == b.days &&
      a.retroactive == b.retroactive;

  DateTime _inferredProgramStartDate() {
    final today = _dateOnly(DateTime.now());
    final offsets = switch (days) {
      3 => const [0, 2, 4],
      4 => const [0, 1, 3, 4],
      5 => const [0, 1, 2, 3, 4],
      _ => const [0, 1, 3, 4],
    };
    return today.subtract(
      Duration(days: (week - 1) * 7 + offsets[workoutIndex]),
    );
  }

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);
}
