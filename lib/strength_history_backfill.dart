import 'exercise_library.dart';
import 'program.dart';

/// An existing imported session. Counts include actual working sets only.
class StrengthHistorySession {
  const StrengthHistorySession({
    required this.id,
    required this.sessionId,
    required this.name,
    required this.source,
    required this.date,
    required this.workingSets,
  });

  final String id;
  final String sessionId;
  final String name;
  final String source;
  final DateTime date;
  final Map<String, int> workingSets;
}

class StrengthHistorySlot {
  const StrengthHistorySlot({
    required this.week,
    required this.workoutIndex,
    required this.workout,
    required this.date,
    this.blocked = false,
  });

  final int week;
  final int workoutIndex;
  final WorkoutPlan workout;
  final DateTime date;
  final bool blocked;
  String get id => '$week:$workoutIndex';
  String get label =>
      'P${ProgramEngine.phaseForWeek(week)} · MC ${ProgramEngine.microcycleForWeek(week)} · ${workout.name}';

  int matchedExercises(StrengthHistorySession session) => workout.exercises
      .where(
        (exercise) =>
            (session.workingSets[exerciseKey(exercise.name)] ?? 0) > 0,
      )
      .length;

  bool hasAllWorkingSets(StrengthHistorySession session) =>
      workout.exercises.every(
        (exercise) =>
            (session.workingSets[exerciseKey(exercise.name)] ?? 0) >=
            exercise.sets,
      );
}

String exerciseKey(String name) =>
    ExerciseLibrary.builtInByName(name)?.id ?? ExerciseLibrary.normalize(name);

class StrengthHistoryPreview {
  const StrengthHistoryPreview({
    required this.fingerprint,
    required this.slots,
    required this.sessions,
  });

  final String fingerprint;
  final List<StrengthHistorySlot> slots;
  final List<StrengthHistorySession> sessions;

  /// Sequence alignment maximizes matching evidence while preserving date
  /// order. A missed week stays empty instead of shifting every later session.
  /// The three-day window is a suggestion rule; users can review older sessions.
  Map<String, String> suggest() {
    final available = slots.where((slot) => !slot.blocked).toList();
    if (available.isEmpty) return {};
    final first = calendarDay(
      available.first.date,
    ).subtract(const Duration(days: 3));
    final last = calendarDay(available.last.date).add(const Duration(days: 3));
    final candidates = sessions.where((session) {
      final date = calendarDay(session.date);
      return !date.isBefore(first) && !date.isAfter(last);
    }).toList();
    final scores = List.generate(
      available.length + 1,
      (_) => List<double>.filled(candidates.length + 1, 0),
    );
    final choices = List.generate(
      available.length + 1,
      (_) => List<int>.filled(candidates.length + 1, 0),
    );
    for (var i = 1; i <= available.length; i++) {
      for (var j = 1; j <= candidates.length; j++) {
        scores[i][j] = scores[i - 1][j];
        choices[i][j] = 1;
        if (scores[i][j - 1] > scores[i][j]) {
          scores[i][j] = scores[i][j - 1];
          choices[i][j] = 2;
        }
        final slot = available[i - 1];
        final session = candidates[j - 1];
        final days = calendarDay(
          slot.date,
        ).difference(calendarDay(session.date)).inDays.abs();
        final matches = slot.matchedExercises(session);
        final coverage = matches / slot.workout.exercises.length;
        // Names alone, warmups alone, or one shared accessory are insufficient.
        if (days > 3 || matches < 2 || coverage < .5) continue;
        final score = scores[i - 1][j - 1] + 100 * coverage + (3 - days);
        if (score > scores[i][j]) {
          scores[i][j] = score;
          choices[i][j] = 3;
        }
      }
    }
    final result = <String, String>{};
    var i = available.length;
    var j = candidates.length;
    while (i > 0 && j > 0) {
      switch (choices[i][j]) {
        case 3:
          result[available[i - 1].id] = candidates[j - 1].id;
          i--;
          j--;
        case 2:
          j--;
        default:
          i--;
      }
    }
    return result;
  }

  /// Rechecked at save time, including manual assignments.
  void validate(Map<String, String> assignments) {
    final slotById = {for (final slot in slots) slot.id: slot};
    final sessionById = {for (final session in sessions) session.id: session};
    final used = <String>{};
    for (final entry in assignments.entries) {
      final slot = slotById[entry.key];
      final session = sessionById[entry.value];
      if (slot == null || slot.blocked || session == null) {
        throw StateError('History changed. Review the workout matches again.');
      }
      if (!used.add(session.sessionId)) {
        throw StateError('Use each imported workout only once.');
      }
      if (slot.matchedExercises(session) == 0) {
        throw StateError('A workout must have at least one matching exercise.');
      }
    }
    DateTime? previous;
    for (final slot in slots) {
      final session = sessionById[assignments[slot.id]];
      if (session == null) continue;
      if (previous != null && session.date.isBefore(previous)) {
        throw StateError('Keep the selected imported workouts in date order.');
      }
      previous = session.date;
    }
  }
}

/// UTC is used only for date arithmetic, avoiding daylight-saving-hour shifts.
DateTime calendarDay(DateTime value) {
  final local = value.toLocal();
  return DateTime.utc(local.year, local.month, local.day);
}

class StrengthHistorySelection {
  StrengthHistorySelection(this.preview, Map<String, String> assignments)
    : assignments = Map.unmodifiable(assignments);

  final StrengthHistoryPreview preview;
  final Map<String, String> assignments;
}
