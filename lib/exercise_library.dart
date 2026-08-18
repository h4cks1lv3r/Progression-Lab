class BuiltInExercise {
  const BuiltInExercise(this.name);

  final String name;
}

class CustomExercise {
  const CustomExercise({
    required this.id,
    required this.name,
    this.isArchived = false,
  });

  final String id;
  final String name;
  final bool isArchived;

  CustomExercise copyWith({String? name, bool? isArchived}) => CustomExercise(
    id: id,
    name: name ?? this.name,
    isArchived: isArchived ?? this.isArchived,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'isArchived': isArchived,
  };

  factory CustomExercise.fromJson(Map<String, dynamic> json) => CustomExercise(
    id: json['id'] as String,
    name: json['name'] as String,
    isArchived: json['isArchived'] == true,
  );
}

class ExerciseOption {
  const ExerciseOption.builtIn(this.name) : customId = null;
  const ExerciseOption.custom(this.name, this.customId);

  final String name;
  final String? customId;
  bool get isBuiltIn => customId == null;
}

/// Permanent compiled-in reference data. These values are never seeded into,
/// edited through, or deleted from the mutable custom-exercise store.
abstract final class BuiltInExercises {
  static const barbellBenchPress = BuiltInExercise('Barbell Bench Press');
  static const closeGripBenchPress = BuiltInExercise('Close-Grip Bench Press');
  static const inclineBarbellBench = BuiltInExercise('Incline Barbell Bench');
  static const reverseGripBenchPress = BuiltInExercise(
    'Reverse-Grip Bench Press',
  );
  static const dumbbellBenchPress = BuiltInExercise('Dumbbell Bench Press');
  static const inclineDumbbellPress = BuiltInExercise('Incline Dumbbell Press');
  static const dip = BuiltInExercise('Dip');
  static const standingMilitaryPress = BuiltInExercise(
    'Standing Military Press',
  );
  static const seatedMilitaryPress = BuiltInExercise('Seated Military Press');
  static const pushPress = BuiltInExercise('Push Press');
  static const dumbbellShoulderPress = BuiltInExercise(
    'Dumbbell Shoulder Press',
  );
  static const dumbbellSideRaise = BuiltInExercise('Dumbbell Side Raise');
  static const dumbbellRearDeltFly = BuiltInExercise('Dumbbell Rear Delt Fly');
  static const cableLateralRaise = BuiltInExercise('Cable Lateral Raise');
  static const barbellDeadlift = BuiltInExercise('Barbell Deadlift');
  static const trapBarDeadlift = BuiltInExercise('Trap-Bar Deadlift');
  static const sumoDeadlift = BuiltInExercise('Sumo Deadlift');
  static const pullUp = BuiltInExercise('Pull-up');
  static const chinUp = BuiltInExercise('Chin-up');
  static const latPulldown = BuiltInExercise('Lat Pulldown');
  static const oneArmDumbbellRow = BuiltInExercise('One-Arm Dumbbell Row');
  static const seatedCableRow = BuiltInExercise('Seated Cable Row');
  static const barbellRow = BuiltInExercise('Barbell Row');
  static const tBarRow = BuiltInExercise('T-Bar Row');
  static const chestSupportedRow = BuiltInExercise('Chest-Supported Row');
  static const barbellBackSquat = BuiltInExercise('Barbell Back Squat');
  static const barbellFrontSquat = BuiltInExercise('Barbell Front Squat');
  static const legPress = BuiltInExercise('Leg Press');
  static const walkingDumbbellLunge = BuiltInExercise('Walking Dumbbell Lunge');
  static const bulgarianSplitSquat = BuiltInExercise('Bulgarian Split Squat');
  static const hackSquat = BuiltInExercise('Hack Squat');
  static const gobletSquat = BuiltInExercise('Goblet Squat');
  static const romanianDeadlift = BuiltInExercise('Romanian Deadlift');
  static const legCurl = BuiltInExercise('Leg Curl');
  static const seatedLegCurl = BuiltInExercise('Seated Leg Curl');
  static const seatedCalfRaise = BuiltInExercise('Seated Calf Raise');
  static const standingCalfRaise = BuiltInExercise('Standing Calf Raise');
  static const legPressCalfRaise = BuiltInExercise('Leg Press Calf Raise');
  static const singleLegCalfRaise = BuiltInExercise('Single-Leg Calf Raise');
  static const tricepsPressdown = BuiltInExercise('Triceps Pressdown');
  static const ezBarSkullcrusher = BuiltInExercise('EZ-Bar Skullcrusher');
  static const tricepsOverheadPress = BuiltInExercise('Triceps Overhead Press');
  static const dumbbellSkullcrusher = BuiltInExercise('Dumbbell Skullcrusher');
  static const barbellCurl = BuiltInExercise('Barbell Curl');
  static const cableCurl = BuiltInExercise('Cable Curl');
  static const alternatingDumbbellCurl = BuiltInExercise(
    'Alternating Dumbbell Curl',
  );
  static const hammerCurl = BuiltInExercise('Hammer Curl');

  static const values = <BuiltInExercise>[
    barbellBenchPress,
    closeGripBenchPress,
    inclineBarbellBench,
    reverseGripBenchPress,
    dumbbellBenchPress,
    inclineDumbbellPress,
    dip,
    standingMilitaryPress,
    seatedMilitaryPress,
    pushPress,
    dumbbellShoulderPress,
    dumbbellSideRaise,
    dumbbellRearDeltFly,
    cableLateralRaise,
    barbellDeadlift,
    trapBarDeadlift,
    sumoDeadlift,
    pullUp,
    chinUp,
    latPulldown,
    oneArmDumbbellRow,
    seatedCableRow,
    barbellRow,
    tBarRow,
    chestSupportedRow,
    barbellBackSquat,
    barbellFrontSquat,
    legPress,
    walkingDumbbellLunge,
    bulgarianSplitSquat,
    hackSquat,
    gobletSquat,
    romanianDeadlift,
    legCurl,
    seatedLegCurl,
    seatedCalfRaise,
    standingCalfRaise,
    legPressCalfRaise,
    singleLegCalfRaise,
    tricepsPressdown,
    ezBarSkullcrusher,
    tricepsOverheadPress,
    dumbbellSkullcrusher,
    barbellCurl,
    cableCurl,
    alternatingDumbbellCurl,
    hammerCurl,
  ];
}

abstract final class ExerciseLibrary {
  static List<ExerciseOption> selectable(List<CustomExercise> custom) {
    final options = <ExerciseOption>[
      for (final exercise in BuiltInExercises.values)
        ExerciseOption.builtIn(exercise.name),
      for (final exercise in custom)
        if (!exercise.isArchived)
          ExerciseOption.custom(exercise.name, exercise.id),
    ];
    options.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    return options;
  }
}
