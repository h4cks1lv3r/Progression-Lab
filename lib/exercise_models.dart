enum MuscleGroup {
  absCore,
  rectusAbdominis,
  obliques,
  deepCore,
  spinalStabilizers,
  chest,
  upperChest,
  serratus,
  lats,
  midBack,
  traps,
  spinalErectors,
  frontDelts,
  sideDelts,
  rearDelts,
  rotatorCuff,
  biceps,
  brachialis,
  triceps,
  forearms,
  grip,
  quads,
  hamstrings,
  glutes,
  adductors,
  abductors,
  calves,
  tibialis,
  hipFlexors,
  fullBody,
  cardio,
  mobility,
  neck,
  other,
}

extension MuscleGroupInfo on MuscleGroup {
  String get label => switch (this) {
    MuscleGroup.absCore => 'Abs & Core',
    MuscleGroup.rectusAbdominis => 'Rectus Abdominis',
    MuscleGroup.obliques => 'Obliques',
    MuscleGroup.deepCore => 'Deep Core',
    MuscleGroup.spinalStabilizers => 'Spinal Stabilizers',
    MuscleGroup.chest => 'Chest',
    MuscleGroup.upperChest => 'Upper Chest',
    MuscleGroup.serratus => 'Serratus',
    MuscleGroup.lats => 'Lats',
    MuscleGroup.midBack => 'Mid Back',
    MuscleGroup.traps => 'Traps',
    MuscleGroup.spinalErectors => 'Spinal Erectors',
    MuscleGroup.frontDelts => 'Front Delts',
    MuscleGroup.sideDelts => 'Side Delts',
    MuscleGroup.rearDelts => 'Rear Delts',
    MuscleGroup.rotatorCuff => 'Rotator Cuff',
    MuscleGroup.biceps => 'Biceps',
    MuscleGroup.brachialis => 'Brachialis / Brachioradialis',
    MuscleGroup.triceps => 'Triceps',
    MuscleGroup.forearms => 'Forearms',
    MuscleGroup.grip => 'Grip',
    MuscleGroup.quads => 'Quadriceps',
    MuscleGroup.hamstrings => 'Hamstrings',
    MuscleGroup.glutes => 'Glutes',
    MuscleGroup.adductors => 'Adductors',
    MuscleGroup.abductors => 'Abductors',
    MuscleGroup.calves => 'Calves',
    MuscleGroup.tibialis => 'Tibialis',
    MuscleGroup.hipFlexors => 'Hip Flexors',
    MuscleGroup.fullBody => 'Full Body',
    MuscleGroup.cardio => 'Cardio / Conditioning',
    MuscleGroup.mobility => 'Mobility / Recovery',
    MuscleGroup.neck => 'Neck',
    MuscleGroup.other => 'Other / Unclassified',
  };

  String get region => switch (this) {
    MuscleGroup.absCore ||
    MuscleGroup.rectusAbdominis ||
    MuscleGroup.obliques ||
    MuscleGroup.deepCore ||
    MuscleGroup.spinalStabilizers => 'Abs & Core',
    MuscleGroup.chest ||
    MuscleGroup.upperChest ||
    MuscleGroup.serratus => 'Chest',
    MuscleGroup.lats ||
    MuscleGroup.midBack ||
    MuscleGroup.traps ||
    MuscleGroup.spinalErectors => 'Back',
    MuscleGroup.frontDelts ||
    MuscleGroup.sideDelts ||
    MuscleGroup.rearDelts ||
    MuscleGroup.rotatorCuff => 'Shoulders',
    MuscleGroup.biceps ||
    MuscleGroup.brachialis ||
    MuscleGroup.triceps ||
    MuscleGroup.forearms ||
    MuscleGroup.grip => 'Arms',
    MuscleGroup.quads ||
    MuscleGroup.hamstrings ||
    MuscleGroup.glutes ||
    MuscleGroup.adductors ||
    MuscleGroup.abductors ||
    MuscleGroup.calves ||
    MuscleGroup.tibialis ||
    MuscleGroup.hipFlexors => 'Lower Body',
    MuscleGroup.fullBody => 'Full Body',
    MuscleGroup.cardio => 'Conditioning',
    MuscleGroup.mobility => 'Mobility',
    MuscleGroup.neck => 'Neck',
    MuscleGroup.other => 'Other',
  };
}

enum ExerciseEquipment {
  barbell,
  dumbbell,
  ezBar,
  trapBar,
  safetySquatBar,
  smithMachine,
  cable,
  selectorizedMachine,
  plateLoadedMachine,
  legPressMachine,
  kettlebell,
  resistanceBand,
  bodyweight,
  assistedBodyweight,
  pullUpBar,
  dipStation,
  bench,
  landmine,
  rings,
  medicineBall,
  stabilityBall,
  abWheel,
  weightPlate,
  sled,
  cardioMachine,
  other,
}

extension ExerciseEquipmentInfo on ExerciseEquipment {
  String get label => switch (this) {
    ExerciseEquipment.barbell => 'Barbell',
    ExerciseEquipment.dumbbell => 'Dumbbell',
    ExerciseEquipment.ezBar => 'EZ Bar',
    ExerciseEquipment.trapBar => 'Trap Bar',
    ExerciseEquipment.safetySquatBar => 'Safety Squat Bar',
    ExerciseEquipment.smithMachine => 'Smith Machine',
    ExerciseEquipment.cable => 'Cable',
    ExerciseEquipment.selectorizedMachine => 'Selectorized Machine',
    ExerciseEquipment.plateLoadedMachine => 'Plate-Loaded Machine',
    ExerciseEquipment.legPressMachine => 'Leg Press / Hack Squat',
    ExerciseEquipment.kettlebell => 'Kettlebell',
    ExerciseEquipment.resistanceBand => 'Resistance Band',
    ExerciseEquipment.bodyweight => 'Bodyweight',
    ExerciseEquipment.assistedBodyweight => 'Assisted Bodyweight',
    ExerciseEquipment.pullUpBar => 'Pull-Up Bar',
    ExerciseEquipment.dipStation => 'Dip Station',
    ExerciseEquipment.bench => 'Bench',
    ExerciseEquipment.landmine => 'Landmine',
    ExerciseEquipment.rings => 'Rings / Suspension',
    ExerciseEquipment.medicineBall => 'Medicine Ball',
    ExerciseEquipment.stabilityBall => 'Stability Ball',
    ExerciseEquipment.abWheel => 'Ab Wheel',
    ExerciseEquipment.weightPlate => 'Weight Plate',
    ExerciseEquipment.sled => 'Sled',
    ExerciseEquipment.cardioMachine => 'Cardio Machine',
    ExerciseEquipment.other => 'Other / Custom',
  };
}

enum MovementPattern {
  horizontalPush,
  horizontalPull,
  verticalPush,
  verticalPull,
  squat,
  hinge,
  lunge,
  hipExtension,
  kneeExtension,
  kneeFlexion,
  elbowFlexion,
  elbowExtension,
  shoulderRaise,
  shoulderRotation,
  spinalFlexion,
  spinalExtension,
  antiExtension,
  rotation,
  antiRotation,
  antiLateralFlexion,
  carry,
  calfRaise,
  conditioning,
  mobility,
  other,
}

extension MovementPatternInfo on MovementPattern {
  String get label => switch (this) {
    MovementPattern.horizontalPush => 'Horizontal Push',
    MovementPattern.horizontalPull => 'Horizontal Pull',
    MovementPattern.verticalPush => 'Vertical Push',
    MovementPattern.verticalPull => 'Vertical Pull',
    MovementPattern.squat => 'Squat',
    MovementPattern.hinge => 'Hinge',
    MovementPattern.lunge => 'Lunge / Split Squat',
    MovementPattern.hipExtension => 'Hip Extension',
    MovementPattern.kneeExtension => 'Knee Extension',
    MovementPattern.kneeFlexion => 'Knee Flexion',
    MovementPattern.elbowFlexion => 'Elbow Flexion',
    MovementPattern.elbowExtension => 'Elbow Extension',
    MovementPattern.shoulderRaise => 'Shoulder Raise',
    MovementPattern.shoulderRotation => 'Shoulder Rotation',
    MovementPattern.spinalFlexion => 'Spinal Flexion',
    MovementPattern.spinalExtension => 'Spinal Extension',
    MovementPattern.antiExtension => 'Anti-Extension',
    MovementPattern.rotation => 'Rotation',
    MovementPattern.antiRotation => 'Anti-Rotation',
    MovementPattern.antiLateralFlexion => 'Anti-Lateral Flexion',
    MovementPattern.carry => 'Carry',
    MovementPattern.calfRaise => 'Calf Raise',
    MovementPattern.conditioning => 'Conditioning',
    MovementPattern.mobility => 'Mobility',
    MovementPattern.other => 'Other',
  };
}

enum ExerciseTrackingType {
  weightReps,
  bodyweightReps,
  weightedBodyweight,
  assistedBodyweight,
  repsOnly,
  weightOnly,
  duration,
  durationWeight,
  distanceDuration,
  weightDistance,
  repsDuration,
  repsDistance,
  distanceOnly,
  caloriesDuration,
}

extension ExerciseTrackingTypeInfo on ExerciseTrackingType {
  String get label => switch (this) {
    ExerciseTrackingType.weightReps => 'Weight + Reps',
    ExerciseTrackingType.bodyweightReps => 'Bodyweight Reps',
    ExerciseTrackingType.weightedBodyweight => 'Weighted Bodyweight',
    ExerciseTrackingType.assistedBodyweight => 'Assisted Bodyweight',
    ExerciseTrackingType.repsOnly => 'Reps Only',
    ExerciseTrackingType.weightOnly => 'Weight Only',
    ExerciseTrackingType.duration => 'Duration',
    ExerciseTrackingType.durationWeight => 'Duration + Weight',
    ExerciseTrackingType.distanceDuration => 'Distance + Duration',
    ExerciseTrackingType.weightDistance => 'Weight + Distance',
    ExerciseTrackingType.repsDuration => 'Reps + Duration',
    ExerciseTrackingType.repsDistance => 'Reps + Distance',
    ExerciseTrackingType.distanceOnly => 'Distance Only',
    ExerciseTrackingType.caloriesDuration => 'Calories + Duration',
  };

  bool get usesWeight => switch (this) {
    ExerciseTrackingType.weightReps ||
    ExerciseTrackingType.weightedBodyweight ||
    ExerciseTrackingType.assistedBodyweight ||
    ExerciseTrackingType.weightOnly ||
    ExerciseTrackingType.durationWeight ||
    ExerciseTrackingType.weightDistance => true,
    _ => false,
  };

  bool get requiresPositiveWeight => switch (this) {
    ExerciseTrackingType.weightReps ||
    ExerciseTrackingType.weightOnly ||
    ExerciseTrackingType.durationWeight ||
    ExerciseTrackingType.weightDistance => true,
    _ => false,
  };

  bool get usesReps => switch (this) {
    ExerciseTrackingType.weightReps ||
    ExerciseTrackingType.bodyweightReps ||
    ExerciseTrackingType.weightedBodyweight ||
    ExerciseTrackingType.assistedBodyweight ||
    ExerciseTrackingType.repsOnly ||
    ExerciseTrackingType.repsDuration ||
    ExerciseTrackingType.repsDistance => true,
    _ => false,
  };

  bool get usesDuration => switch (this) {
    ExerciseTrackingType.duration ||
    ExerciseTrackingType.durationWeight ||
    ExerciseTrackingType.distanceDuration ||
    ExerciseTrackingType.repsDuration ||
    ExerciseTrackingType.caloriesDuration => true,
    _ => false,
  };

  bool get usesDistance => switch (this) {
    ExerciseTrackingType.distanceDuration ||
    ExerciseTrackingType.weightDistance ||
    ExerciseTrackingType.repsDistance ||
    ExerciseTrackingType.distanceOnly => true,
    _ => false,
  };

  bool get usesCalories => this == ExerciseTrackingType.caloriesDuration;

  String get weightLabel => switch (this) {
    ExerciseTrackingType.weightedBodyweight => 'ADDED WEIGHT',
    ExerciseTrackingType.assistedBodyweight => 'ASSISTANCE',
    _ => 'WEIGHT',
  };

  String get performanceLabel => switch (this) {
    ExerciseTrackingType.bodyweightReps ||
    ExerciseTrackingType.repsOnly => 'Most Reps',
    ExerciseTrackingType.assistedBodyweight => 'Lowest Assistance',
    ExerciseTrackingType.duration => 'Longest Hold',
    ExerciseTrackingType.distanceOnly ||
    ExerciseTrackingType.distanceDuration => 'Distance',
    _ => 'Estimated Strength',
  };
}

enum UnilateralMode { bilateral, perSide, alternating, singleSide }

extension UnilateralModeInfo on UnilateralMode {
  String get label => switch (this) {
    UnilateralMode.bilateral => 'Bilateral',
    UnilateralMode.perSide => 'Per Side',
    UnilateralMode.alternating => 'Alternating',
    UnilateralMode.singleSide => 'Single Side',
  };
}

abstract interface class ExerciseDescriptor {
  String get id;
  String get name;
  List<String> get aliases;
  MuscleGroup get primaryMuscle;
  List<MuscleGroup> get secondaryMuscles;
  ExerciseEquipment get equipment;
  MovementPattern get movementPattern;
  ExerciseTrackingType get trackingType;
  UnilateralMode get unilateralMode;
  bool get isPrimaryCompound;
  bool get warmupEligible;
  String get notes;
}

class BuiltInExercise implements ExerciseDescriptor {
  const BuiltInExercise({
    required this.id,
    required this.name,
    required this.primaryMuscle,
    required this.equipment,
    required this.movementPattern,
    this.trackingType = ExerciseTrackingType.weightReps,
    this.aliases = const [],
    this.secondaryMuscles = const [],
    this.unilateralMode = UnilateralMode.bilateral,
    this.isPrimaryCompound = false,
    this.warmupEligible = false,
    this.notes = '',
  });

  @override
  final String id;
  @override
  final String name;
  @override
  final List<String> aliases;
  @override
  final MuscleGroup primaryMuscle;
  @override
  final List<MuscleGroup> secondaryMuscles;
  @override
  final ExerciseEquipment equipment;
  @override
  final MovementPattern movementPattern;
  @override
  final ExerciseTrackingType trackingType;
  @override
  final UnilateralMode unilateralMode;
  @override
  final bool isPrimaryCompound;
  @override
  final bool warmupEligible;
  @override
  final String notes;
}

class CustomExercise implements ExerciseDescriptor {
  const CustomExercise({
    required this.id,
    required this.name,
    this.aliases = const [],
    this.primaryMuscle = MuscleGroup.other,
    this.secondaryMuscles = const [],
    this.equipment = ExerciseEquipment.other,
    this.movementPattern = MovementPattern.other,
    this.trackingType = ExerciseTrackingType.weightReps,
    this.unilateralMode = UnilateralMode.bilateral,
    this.unitOverride,
    this.defaultRestSeconds,
    this.isPrimaryCompound = false,
    this.warmupEligible = false,
    this.notes = '',
    this.tags = const [],
    this.mediaReference,
    this.isFavorite = false,
    this.isArchived = false,
  });

  @override
  final String id;
  @override
  final String name;
  @override
  final List<String> aliases;
  @override
  final MuscleGroup primaryMuscle;
  @override
  final List<MuscleGroup> secondaryMuscles;
  @override
  final ExerciseEquipment equipment;
  @override
  final MovementPattern movementPattern;
  @override
  final ExerciseTrackingType trackingType;
  @override
  final UnilateralMode unilateralMode;
  final String? unitOverride;
  final int? defaultRestSeconds;
  @override
  final bool isPrimaryCompound;
  @override
  final bool warmupEligible;
  @override
  final String notes;
  final List<String> tags;
  final String? mediaReference;
  final bool isFavorite;
  final bool isArchived;

  CustomExercise copyWith({
    String? name,
    List<String>? aliases,
    MuscleGroup? primaryMuscle,
    List<MuscleGroup>? secondaryMuscles,
    ExerciseEquipment? equipment,
    MovementPattern? movementPattern,
    ExerciseTrackingType? trackingType,
    UnilateralMode? unilateralMode,
    String? unitOverride,
    bool clearUnitOverride = false,
    int? defaultRestSeconds,
    bool clearDefaultRest = false,
    bool? isPrimaryCompound,
    bool? warmupEligible,
    String? notes,
    List<String>? tags,
    String? mediaReference,
    bool clearMediaReference = false,
    bool? isFavorite,
    bool? isArchived,
  }) => CustomExercise(
    id: id,
    name: name ?? this.name,
    aliases: aliases ?? this.aliases,
    primaryMuscle: primaryMuscle ?? this.primaryMuscle,
    secondaryMuscles: secondaryMuscles ?? this.secondaryMuscles,
    equipment: equipment ?? this.equipment,
    movementPattern: movementPattern ?? this.movementPattern,
    trackingType: trackingType ?? this.trackingType,
    unilateralMode: unilateralMode ?? this.unilateralMode,
    unitOverride: clearUnitOverride ? null : unitOverride ?? this.unitOverride,
    defaultRestSeconds: clearDefaultRest
        ? null
        : defaultRestSeconds ?? this.defaultRestSeconds,
    isPrimaryCompound: isPrimaryCompound ?? this.isPrimaryCompound,
    warmupEligible: warmupEligible ?? this.warmupEligible,
    notes: notes ?? this.notes,
    tags: tags ?? this.tags,
    mediaReference: clearMediaReference
        ? null
        : mediaReference ?? this.mediaReference,
    isFavorite: isFavorite ?? this.isFavorite,
    isArchived: isArchived ?? this.isArchived,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'aliases': aliases,
    'primaryMuscle': primaryMuscle.name,
    'secondaryMuscles': secondaryMuscles.map((value) => value.name).toList(),
    'equipment': equipment.name,
    'movementPattern': movementPattern.name,
    'trackingType': trackingType.name,
    'unilateralMode': unilateralMode.name,
    if (unitOverride != null) 'unitOverride': unitOverride,
    if (defaultRestSeconds != null) 'defaultRestSeconds': defaultRestSeconds,
    'isPrimaryCompound': isPrimaryCompound,
    'warmupEligible': warmupEligible,
    'notes': notes,
    'tags': tags,
    if (mediaReference != null) 'mediaReference': mediaReference,
    'isFavorite': isFavorite,
    'isArchived': isArchived,
  };

  factory CustomExercise.fromJson(Map<String, dynamic> json) {
    T enumValue<T extends Enum>(List<T> values, Object? raw, T fallback) {
      if (raw is String) {
        for (final value in values) {
          if (value.name == raw) return value;
        }
      }
      return fallback;
    }

    return CustomExercise(
      id: json['id'] as String,
      name: json['name'] as String,
      aliases: json['aliases'] is List
          ? (json['aliases'] as List).whereType<String>().toList()
          : const [],
      primaryMuscle: enumValue(
        MuscleGroup.values,
        json['primaryMuscle'],
        MuscleGroup.other,
      ),
      secondaryMuscles: json['secondaryMuscles'] is List
          ? [
              for (final raw in json['secondaryMuscles'] as List)
                if (raw is String)
                  for (final value in MuscleGroup.values)
                    if (value.name == raw) value,
            ]
          : const [],
      equipment: enumValue(
        ExerciseEquipment.values,
        json['equipment'],
        ExerciseEquipment.other,
      ),
      movementPattern: enumValue(
        MovementPattern.values,
        json['movementPattern'],
        MovementPattern.other,
      ),
      trackingType: enumValue(
        ExerciseTrackingType.values,
        json['trackingType'],
        ExerciseTrackingType.weightReps,
      ),
      unilateralMode: enumValue(
        UnilateralMode.values,
        json['unilateralMode'],
        UnilateralMode.bilateral,
      ),
      unitOverride: json['unitOverride'] is String
          ? json['unitOverride'] as String
          : null,
      defaultRestSeconds: json['defaultRestSeconds'] is num
          ? (json['defaultRestSeconds'] as num).toInt()
          : null,
      isPrimaryCompound: json['isPrimaryCompound'] == true,
      warmupEligible: json['warmupEligible'] == true,
      notes: json['notes'] is String ? json['notes'] as String : '',
      tags: json['tags'] is List
          ? (json['tags'] as List).whereType<String>().toList()
          : const [],
      mediaReference: json['mediaReference'] is String
          ? json['mediaReference'] as String
          : null,
      isFavorite: json['isFavorite'] == true,
      isArchived: json['isArchived'] == true,
    );
  }
}

class ExerciseOption {
  const ExerciseOption({
    required this.id,
    required this.name,
    required this.primaryMuscle,
    required this.secondaryMuscles,
    required this.equipment,
    required this.movementPattern,
    required this.trackingType,
    required this.unilateralMode,
    required this.isPrimaryCompound,
    required this.warmupEligible,
    this.customId,
    this.aliases = const [],
    this.notes = '',
    this.isFavorite = false,
  });

  factory ExerciseOption.builtIn(
    BuiltInExercise exercise, {
    bool isFavorite = false,
  }) => ExerciseOption(
    id: exercise.id,
    name: exercise.name,
    aliases: exercise.aliases,
    primaryMuscle: exercise.primaryMuscle,
    secondaryMuscles: exercise.secondaryMuscles,
    equipment: exercise.equipment,
    movementPattern: exercise.movementPattern,
    trackingType: exercise.trackingType,
    unilateralMode: exercise.unilateralMode,
    isPrimaryCompound: exercise.isPrimaryCompound,
    warmupEligible: exercise.warmupEligible,
    notes: exercise.notes,
    isFavorite: isFavorite,
  );

  factory ExerciseOption.custom(CustomExercise exercise) => ExerciseOption(
    id: exercise.id,
    customId: exercise.id,
    name: exercise.name,
    aliases: exercise.aliases,
    primaryMuscle: exercise.primaryMuscle,
    secondaryMuscles: exercise.secondaryMuscles,
    equipment: exercise.equipment,
    movementPattern: exercise.movementPattern,
    trackingType: exercise.trackingType,
    unilateralMode: exercise.unilateralMode,
    isPrimaryCompound: exercise.isPrimaryCompound,
    warmupEligible: exercise.warmupEligible,
    notes: exercise.notes,
    isFavorite: exercise.isFavorite,
  );

  final String id;
  final String name;
  final String? customId;
  final List<String> aliases;
  final MuscleGroup primaryMuscle;
  final List<MuscleGroup> secondaryMuscles;
  final ExerciseEquipment equipment;
  final MovementPattern movementPattern;
  final ExerciseTrackingType trackingType;
  final UnilateralMode unilateralMode;
  final bool isPrimaryCompound;
  final bool warmupEligible;
  final String notes;
  final bool isFavorite;

  bool get isBuiltIn => customId == null;
  String get subtitle => '${primaryMuscle.label} · ${equipment.label}';
}
