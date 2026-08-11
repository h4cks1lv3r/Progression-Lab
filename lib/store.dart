import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'program.dart';

class SetLog {
  SetLog({
    required this.exercise,
    required this.weight,
    required this.reps,
    required this.date,
    required this.workout,
  });
  final String exercise;
  final double weight;
  final int reps;
  final DateTime date;
  final String workout;
  double get e1rm => weight * (1 + reps / 30);

  SetLog copyWith({
    String? exercise,
    double? weight,
    int? reps,
    DateTime? date,
    String? workout,
  }) => SetLog(
    exercise: exercise ?? this.exercise,
    weight: weight ?? this.weight,
    reps: reps ?? this.reps,
    date: date ?? this.date,
    workout: workout ?? this.workout,
  );

  Map<String, dynamic> toJson() => {
    'e': exercise,
    'w': weight,
    'r': reps,
    'd': date.toIso8601String(),
    'o': workout,
  };
  factory SetLog.fromJson(Map<String, dynamic> j) => SetLog(
    exercise: j['e'],
    weight: (j['w'] as num).toDouble(),
    reps: j['r'],
    date: DateTime.parse(j['d']),
    workout: j['o'],
  );
}

class AppStore extends ChangeNotifier {
  static const _channel = MethodChannel('iron_cadence/storage');
  static const double poundsToKilograms = 0.45359237;
  int days = 4;
  int week = 1;
  int workoutIndex = 0;
  String unit = 'lb';
  List<SetLog> logs = [];

  Future<void> load() async {
    try {
      final raw = await _channel.invokeMethod<String>('read');
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          final data = Map<String, dynamic>.from(decoded);
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

  Future<void> complete(int _workoutsThisWeek) async {
    // The store cadence is authoritative. A workout screen can remain open
    // across a settings change and pass a stale count from the old cadence.
    final previousWeek = week;
    final previousWorkoutIndex = workoutIndex;
    final currentWorkoutCount = ProgramEngine.workoutCount(days);
    workoutIndex = ProgramEngine.clampWorkoutIndex(workoutIndex, days) + 1;
    if (workoutIndex >= currentWorkoutCount) {
      workoutIndex = 0;
      week = week >= ProgramEngine.totalWeeks ? 1 : week + 1;
    }
    try {
      await save();
    } on Object {
      week = previousWeek;
      workoutIndex = previousWorkoutIndex;
      rethrow;
    }
    notifyListeners();
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
    final destinationIndex = nextWorkoutIndex ??
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
    final factor = unit == 'lb'
        ? poundsToKilograms
        : 1 / poundsToKilograms;
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
}
