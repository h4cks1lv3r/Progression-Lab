import 'exercise_library.dart';

enum WeekKind { build, volumeDeload, strength, fullDeload }

class ExercisePlan {
  const ExercisePlan(
    this.name,
    this.sets,
    this.reps, {
    this.primary = false,
    this.amrap = false,
  });
  final String name;
  final int sets;
  final String reps;
  final bool primary;
  final bool amrap;
}

class WorkoutPlan {
  const WorkoutPlan(this.name, this.exercises);
  final String name;
  final List<ExercisePlan> exercises;
}

class ProgramWeek {
  const ProgramWeek({
    required this.number,
    required this.phase,
    required this.microcycle,
    required this.kind,
    required this.workouts,
  });
  final int number;
  final int phase;
  final int microcycle;
  final WeekKind kind;
  final List<WorkoutPlan> workouts;

  String get label => switch (kind) {
    WeekKind.build => 'BUILD',
    WeekKind.volumeDeload => 'VOLUME DELOAD',
    WeekKind.strength => 'STRENGTH WEEK',
    WeekKind.fullDeload => 'FULL DELOAD',
  };
}

/// A read-only description of where a cadence change will place the user.
///
/// [currentWorkout] and [suggestedWorkout] belong to the same program week. A
/// UI can show this before it calls `AppStore.setDays` and can override
/// [suggestedWorkoutIndex] when the user deliberately chooses another session.
class CadenceSwitchPreview {
  const CadenceSwitchPreview({
    required this.week,
    required this.fromDays,
    required this.toDays,
    required this.currentWorkoutIndex,
    required this.suggestedWorkoutIndex,
    required this.currentWorkout,
    required this.suggestedWorkout,
  });

  final int week;
  final int fromDays;
  final int toDays;
  final int currentWorkoutIndex;
  final int suggestedWorkoutIndex;
  final WorkoutPlan currentWorkout;
  final WorkoutPlan suggestedWorkout;
}

class ProgramEngine {
  static const int phaseCount = 3;
  static const int weeksPerPhase = 16;
  static const int totalWeeks = phaseCount * weeksPerPhase;
  static const Set<int> supportedCadences = {3, 4, 5};

  /// The verified source material contains three complete 16-week phases.
  /// Weeks 49-52 are not generated because silently repeating phase 1 would
  /// present an invented fourth phase as authored programming.
  static List<ProgramWeek> year(int days) {
    validateDays(days);
    return List.generate(totalWeeks, (i) => week(i + 1, days));
  }

  static bool isSupportedDays(int days) => supportedCadences.contains(days);

  static void validateDays(int days) {
    if (!isSupportedDays(days)) {
      throw ArgumentError.value(days, 'days', 'Must be 3, 4, or 5');
    }
  }

  static int clampWeek(int value) => value.clamp(1, totalWeeks).toInt();

  static int phaseForWeek(int number) {
    _validateWeek(number);
    return ((number - 1) ~/ weeksPerPhase) + 1;
  }

  static int microcycleForWeek(int number) {
    _validateWeek(number);
    return (number - 1) % weeksPerPhase + 1;
  }

  static int firstWeekOfPhase(int phase) {
    if (phase < 1 || phase > phaseCount) {
      throw ArgumentError.value(
        phase,
        'phase',
        'Must be from 1 to $phaseCount',
      );
    }
    return ((phase - 1) * weeksPerPhase) + 1;
  }

  static int workoutCount(int days) {
    validateDays(days);
    return days;
  }

  static int clampWorkoutIndex(int value, int days) {
    final count = workoutCount(days);
    return value.clamp(0, count - 1).toInt();
  }

  static ProgramWeek week(int number, int days) {
    validateDays(days);
    _validateWeek(number);
    final phase = phaseForWeek(number);
    final micro = microcycleForWeek(number);
    final kind = micro == 15
        ? WeekKind.strength
        : micro == 16
        ? WeekKind.fullDeload
        : {4, 8, 12}.contains(micro)
        ? WeekKind.volumeDeload
        : WeekKind.build;
    return ProgramWeek(
      number: number,
      phase: phase,
      microcycle: micro,
      kind: kind,
      workouts: _templates(days, phase)
          .map(
            (w) => WorkoutPlan(w.$1, [
              for (var i = 0; i < w.$2.length; i++)
                _prescribe(
                  w.$2[i],
                  i == 0 || (w.$1.contains('Upper Body C') && i == 1),
                  micro,
                  kind,
                ),
            ]),
          )
          .toList(),
    );
  }

  /// Suggests the closest equivalent *next* workout in another cadence.
  ///
  /// Exercise overlap is the primary signal, so Push/Pull sessions remain
  /// Push/Pull when possible. Matching the first (anchor) lift and then the
  /// normalized position in the training week break ties. This maps the
  /// three-day Full Body session to Legs & Calves instead of an extra upper
  /// session.
  static int defaultWorkoutIndexForCadenceSwitch({
    required int week,
    required int fromDays,
    required int toDays,
    required int currentWorkoutIndex,
  }) {
    validateDays(fromDays);
    validateDays(toDays);
    _validateWeek(week);

    final fromWorkouts = ProgramEngine.week(week, fromDays).workouts;
    final toWorkouts = ProgramEngine.week(week, toDays).workouts;
    final safeCurrent = currentWorkoutIndex
        .clamp(0, fromWorkouts.length - 1)
        .toInt();
    if (fromDays == toDays) return safeCurrent;

    final current = fromWorkouts[safeCurrent];
    final currentExercises = current.exercises.map((e) => e.name).toSet();
    final normalizedPosition = fromWorkouts.length == 1
        ? 0.0
        : safeCurrent / (fromWorkouts.length - 1);
    final targetPosition = normalizedPosition * (toWorkouts.length - 1);

    var bestIndex = 0;
    var bestOverlap = -1;
    var bestAnchorMatch = false;
    var bestNameMatch = false;
    var bestDistance = double.infinity;
    for (var i = 0; i < toWorkouts.length; i++) {
      final candidate = toWorkouts[i];
      final overlap = candidate.exercises
          .where((e) => currentExercises.contains(e.name))
          .length;
      final anchorMatch =
          candidate.exercises.first.name == current.exercises.first.name;
      final nameMatch = candidate.name == current.name;
      final distance = (i - targetPosition).abs();
      final isBetter =
          overlap > bestOverlap ||
          (overlap == bestOverlap && anchorMatch && !bestAnchorMatch) ||
          (overlap == bestOverlap &&
              anchorMatch == bestAnchorMatch &&
              nameMatch &&
              !bestNameMatch) ||
          (overlap == bestOverlap &&
              anchorMatch == bestAnchorMatch &&
              nameMatch == bestNameMatch &&
              distance < bestDistance);
      if (isBetter) {
        bestIndex = i;
        bestOverlap = overlap;
        bestAnchorMatch = anchorMatch;
        bestNameMatch = nameMatch;
        bestDistance = distance;
      }
    }
    return bestIndex;
  }

  static CadenceSwitchPreview previewCadenceSwitch({
    required int week,
    required int fromDays,
    required int toDays,
    required int currentWorkoutIndex,
  }) {
    final safeWeek = clampWeek(week);
    validateDays(fromDays);
    validateDays(toDays);
    final current = ProgramEngine.week(safeWeek, fromDays);
    final safeCurrent = currentWorkoutIndex
        .clamp(0, current.workouts.length - 1)
        .toInt();
    final suggested = defaultWorkoutIndexForCadenceSwitch(
      week: safeWeek,
      fromDays: fromDays,
      toDays: toDays,
      currentWorkoutIndex: safeCurrent,
    );
    final destination = ProgramEngine.week(safeWeek, toDays);
    return CadenceSwitchPreview(
      week: safeWeek,
      fromDays: fromDays,
      toDays: toDays,
      currentWorkoutIndex: safeCurrent,
      suggestedWorkoutIndex: suggested,
      currentWorkout: current.workouts[safeCurrent],
      suggestedWorkout: destination.workouts[suggested],
    );
  }

  static void _validateWeek(int number) {
    if (number < 1 || number > totalWeeks) {
      throw RangeError.range(number, 1, totalWeeks, 'number');
    }
  }

  static ExercisePlan _prescribe(
    BuiltInExercise exercise,
    bool primary,
    int micro,
    WeekKind kind,
  ) {
    final name = exercise.name;
    if (kind == WeekKind.strength) {
      return ExercisePlan(
        name,
        primary ? 2 : 2,
        primary ? 'AMRAP + 4' : '6–8',
        primary: primary,
        amrap: primary,
      );
    }
    if (kind == WeekKind.fullDeload) {
      return ExercisePlan(name, 2, '5', primary: primary);
    }
    if (kind == WeekKind.volumeDeload) {
      // The source plan halves both sets and repetitions while keeping the
      // preceding working weight. Primary work is 3/2/1 in microcycles 4/8/12.
      // Accessory targets are the slot-safe integer approximation 8/6/6; some
      // authored movements (for example, bodyweight pull-ups) may need an
      // exercise-specific override in a future normalized program data model.
      final rep = micro == 4
          ? '3'
          : micro == 8
          ? '2'
          : '1';
      final accessoryRep = micro == 4 ? '8' : '6';
      return ExercisePlan(
        name,
        2,
        primary ? rep : accessoryRep,
        primary: primary,
      );
    }
    const main = {
      1: '10',
      2: '8',
      3: '6',
      5: '8',
      6: '6',
      7: '4',
      9: '6',
      10: '4',
      11: '2',
      13: '4',
      14: '2',
    };
    final accessory = micro <= 4
        ? '10–12'
        : micro <= 12
        ? '8–10'
        : '6–8';
    return ExercisePlan(
      name,
      4,
      primary ? (main[micro] ?? '6') : accessory,
      primary: primary,
    );
  }

  static List<(String, List<BuiltInExercise>)> _templates(int days, int phase) {
    final p = _phase[phase]!;
    if (days == 3) {
      return [
        ('Push', [p[0], p[1], p[2], p[3]]),
        ('Pull & Calves', [p[4], p[5], p[6], p[7]]),
        ('Full Body', [p[12], p[13], p[9], p[11]]),
      ];
    }
    final four = <(String, List<BuiltInExercise>)>[
      ('Upper Body A', [p[0], p[1], p[2], p[3]]),
      ('Pull & Calves', [p[4], p[5], p[6], p[7]]),
      ('Upper Body B', [p[8], p[9], p[10], p[11]]),
      ('Legs & Calves', [p[12], p[13], p[14], p[15]]),
    ];
    if (days == 5) four.add(('Upper Body C', [p[9], p[0], p[6], p[11]]));
    return four;
  }

  static const _phase = <int, List<BuiltInExercise>>{
    1: [
      BuiltInExercises.barbellBenchPress,
      BuiltInExercises.closeGripBenchPress,
      BuiltInExercises.dumbbellSideRaise,
      BuiltInExercises.tricepsPressdown,
      BuiltInExercises.barbellDeadlift,
      BuiltInExercises.pullUp,
      BuiltInExercises.oneArmDumbbellRow,
      BuiltInExercises.seatedCalfRaise,
      BuiltInExercises.standingMilitaryPress,
      BuiltInExercises.inclineBarbellBench,
      BuiltInExercises.seatedCableRow,
      BuiltInExercises.barbellCurl,
      BuiltInExercises.barbellBackSquat,
      BuiltInExercises.legPress,
      BuiltInExercises.legCurl,
      BuiltInExercises.legPressCalfRaise,
    ],
    2: [
      BuiltInExercises.barbellBenchPress,
      BuiltInExercises.dip,
      BuiltInExercises.dumbbellRearDeltFly,
      BuiltInExercises.ezBarSkullcrusher,
      BuiltInExercises.trapBarDeadlift,
      BuiltInExercises.chinUp,
      BuiltInExercises.seatedCableRow,
      BuiltInExercises.standingCalfRaise,
      BuiltInExercises.seatedMilitaryPress,
      BuiltInExercises.reverseGripBenchPress,
      BuiltInExercises.barbellRow,
      BuiltInExercises.cableCurl,
      BuiltInExercises.barbellFrontSquat,
      BuiltInExercises.romanianDeadlift,
      BuiltInExercises.walkingDumbbellLunge,
      BuiltInExercises.seatedCalfRaise,
    ],
    3: [
      BuiltInExercises.barbellBenchPress,
      BuiltInExercises.closeGripBenchPress,
      BuiltInExercises.dumbbellSideRaise,
      BuiltInExercises.tricepsOverheadPress,
      BuiltInExercises.sumoDeadlift,
      BuiltInExercises.pullUp,
      BuiltInExercises.tBarRow,
      BuiltInExercises.seatedCalfRaise,
      BuiltInExercises.pushPress,
      BuiltInExercises.inclineBarbellBench,
      BuiltInExercises.oneArmDumbbellRow,
      BuiltInExercises.alternatingDumbbellCurl,
      BuiltInExercises.barbellBackSquat,
      BuiltInExercises.romanianDeadlift,
      BuiltInExercises.bulgarianSplitSquat,
      BuiltInExercises.legPressCalfRaise,
    ],
  };
}
