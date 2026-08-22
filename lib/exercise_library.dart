import 'exercise_catalog.dart';
import 'exercise_models.dart';

export 'exercise_catalog.dart';
export 'exercise_models.dart';

/// Canonical exercise lookup and discovery logic shared by the library,
/// workout substitutions, imports, charts, and The Lab.
abstract final class ExerciseLibrary {
  static const _captainsChairLegLift = BuiltInExercise(
    id: 'captains_chair_leg_lift',
    name: 'Captain’s Chair Leg Lift',
    primaryMuscle: MuscleGroup.rectusAbdominis,
    equipment: ExerciseEquipment.bodyweight,
    movementPattern: MovementPattern.spinalFlexion,
    trackingType: ExerciseTrackingType.bodyweightReps,
    aliases: [
      'Captain’s Chair Leg Raise',
      'Captain Chair Leg Raise',
      'Captains Chair Leg Lift',
      'Vertical Knee Raise Station Leg Raise',
      'VK Raise',
      'Roman Chair Leg Raise',
    ],
    secondaryMuscles: [MuscleGroup.hipFlexors, MuscleGroup.obliques],
    notes:
        'Straight-leg captain’s-chair raise. Log repetitions; use the separate weighted variant for added load.',
  );

  /// Corrected canonical catalog used by every user-facing lookup. Keeping the
  /// repair at this boundary also preserves the stable ID from older builds.
  static final List<BuiltInExercise> _catalog = [
    for (final exercise in BuiltInExercises.values)
      if (exercise.id == _captainsChairLegLift.id)
        _captainsChairLegLift
      else
        exercise,
  ];

  static final Map<String, BuiltInExercise> _builtInById = {
    for (final exercise in _catalog) exercise.id: exercise,
  };

  static final Map<String, BuiltInExercise> _builtInByNormalizedName = {
    for (final exercise in _catalog) ...{
      normalize(exercise.name): exercise,
      for (final alias in exercise.aliases) normalize(alias): exercise,
    },
  };

  static List<BuiltInExercise> get builtIns => List.unmodifiable(_catalog);

  static String normalize(String value) => value
      .trim()
      .toLowerCase()
      .replaceAll('’', "'")
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static BuiltInExercise? builtInById(String id) => _builtInById[id];

  static BuiltInExercise? builtInByName(String name) =>
      _builtInByNormalizedName[normalize(name)];

  static ExerciseDescriptor? descriptorFor({
    String? id,
    String? name,
    required List<CustomExercise> customExercises,
  }) {
    if (id != null) {
      final builtIn = _builtInById[id];
      if (builtIn != null) return builtIn;
      for (final exercise in customExercises) {
        if (exercise.id == id) return exercise;
      }
    }
    if (name != null) {
      final builtIn = builtInByName(name);
      if (builtIn != null) return builtIn;
      final normalized = normalize(name);
      for (final exercise in customExercises) {
        if (normalize(exercise.name) == normalized ||
            exercise.aliases.any((alias) => normalize(alias) == normalized)) {
          return exercise;
        }
      }
    }
    return null;
  }

  static ExerciseOption optionForDescriptor(
    ExerciseDescriptor exercise, {
    Set<String> favoriteBuiltInIds = const {},
  }) => switch (exercise) {
    BuiltInExercise value => ExerciseOption.builtIn(
      value,
      isFavorite: favoriteBuiltInIds.contains(value.id),
    ),
    CustomExercise value => ExerciseOption.custom(value),
    _ => throw StateError('Unsupported exercise descriptor.'),
  };

  static List<ExerciseOption> selectable(
    List<CustomExercise> custom, {
    Set<String> favoriteBuiltInIds = const {},
  }) {
    final options = <ExerciseOption>[
      for (final exercise in _catalog)
        ExerciseOption.builtIn(
          exercise,
          isFavorite: favoriteBuiltInIds.contains(exercise.id),
        ),
      for (final exercise in custom)
        if (!exercise.isArchived) ExerciseOption.custom(exercise),
    ];
    options.sort((a, b) => a.name.compareTo(b.name));
    return options;
  }

  static List<ExerciseOption> search({
    required List<CustomExercise> custom,
    Set<String> favoriteBuiltInIds = const {},
    String query = '',
    Set<MuscleGroup> muscles = const {},
    Set<ExerciseEquipment> equipment = const {},
    Set<MovementPattern> patterns = const {},
    Set<ExerciseTrackingType> trackingTypes = const {},
    bool includeSecondaryMuscles = true,
    bool favoritesOnly = false,
    bool customOnly = false,
    bool builtInOnly = false,
    bool archivedOnly = false,
  }) {
    final normalizedQuery = normalize(query);
    final tokens = normalizedQuery.isEmpty
        ? const <String>[]
        : normalizedQuery.split(' ');
    final scored = <({ExerciseOption option, int score})>[];

    final candidates = <ExerciseOption>[
      if (!customOnly)
        for (final exercise in _catalog)
          ExerciseOption.builtIn(
            exercise,
            isFavorite: favoriteBuiltInIds.contains(exercise.id),
          ),
      if (!builtInOnly)
        for (final exercise in custom)
          if (archivedOnly ? exercise.isArchived : !exercise.isArchived)
            ExerciseOption.custom(exercise),
    ];

    for (final option in candidates) {
      if (favoritesOnly && !option.isFavorite) continue;
      if (muscles.isNotEmpty) {
        final matchPrimary = muscles.contains(option.primaryMuscle);
        final matchSecondary =
            includeSecondaryMuscles &&
            option.secondaryMuscles.any(muscles.contains);
        if (!matchPrimary && !matchSecondary) continue;
      }
      if (equipment.isNotEmpty && !equipment.contains(option.equipment)) {
        continue;
      }
      if (patterns.isNotEmpty && !patterns.contains(option.movementPattern)) {
        continue;
      }
      if (trackingTypes.isNotEmpty &&
          !trackingTypes.contains(option.trackingType)) {
        continue;
      }

      var score = 0;
      if (tokens.isNotEmpty) {
        final name = normalize(option.name);
        final aliases = option.aliases.map(normalize).toList();
        final metadata = normalize(
          '${option.primaryMuscle.label} '
          '${option.secondaryMuscles.map((value) => value.label).join(' ')} '
          '${option.equipment.label} ${option.movementPattern.label} '
          '${option.trackingType.label}',
        );
        final searchable = '$name ${aliases.join(' ')} $metadata';
        if (!tokens.every(searchable.contains)) continue;
        if (name == normalizedQuery) score += 100;
        if (name.startsWith(normalizedQuery)) score += 60;
        if (aliases.any((alias) => alias == normalizedQuery)) score += 80;
        score += tokens.where(name.contains).length * 12;
        score += tokens.where((token) => metadata.contains(token)).length * 3;
      }
      if (option.isFavorite) score += 20;
      if (!option.isBuiltIn) score += 2;
      scored.add((option: option, score: score));
    }

    scored.sort((a, b) {
      final score = b.score.compareTo(a.score);
      if (score != 0) return score;
      return a.option.name.compareTo(b.option.name);
    });
    return [for (final item in scored) item.option];
  }

  /// Returns compatible substitutes rather than every movement sharing a
  /// broad body part. Movement pattern and tracking semantics receive the
  /// largest score, followed by muscle and equipment compatibility.
  static List<ExerciseOption> rankedSubstitutions({
    required ExerciseDescriptor target,
    required List<CustomExercise> custom,
    Set<String> favoriteBuiltInIds = const {},
    Set<ExerciseEquipment> availableEquipment = const {},
    int limit = 30,
  }) {
    final ranked = <({ExerciseOption option, int score})>[];
    for (final option in selectable(
      custom,
      favoriteBuiltInIds: favoriteBuiltInIds,
    )) {
      if (option.id == target.id ||
          normalize(option.name) == normalize(target.name)) {
        continue;
      }
      var score = 0;
      if (option.movementPattern == target.movementPattern) score += 50;
      if (option.primaryMuscle == target.primaryMuscle) score += 42;
      if (target.secondaryMuscles.contains(option.primaryMuscle)) score += 10;
      if (option.secondaryMuscles.contains(target.primaryMuscle)) score += 14;
      if (option.trackingType == target.trackingType) score += 28;
      if (option.equipment == target.equipment) score += 18;
      if (availableEquipment.isNotEmpty &&
          availableEquipment.contains(option.equipment)) {
        score += 12;
      }
      if (option.isPrimaryCompound == target.isPrimaryCompound) score += 12;
      if (option.unilateralMode == target.unilateralMode) score += 6;
      if (option.isFavorite) score += 5;
      if (score >= 60) ranked.add((option: option, score: score));
    }
    ranked.sort((a, b) {
      final score = b.score.compareTo(a.score);
      if (score != 0) return score;
      return a.option.name.compareTo(b.option.name);
    });
    return [for (final item in ranked.take(limit)) item.option];
  }

  static void validateCatalog() {
    final ids = <String>{};
    final names = <String>{};
    for (final exercise in _catalog) {
      if (exercise.id.trim().isEmpty || !ids.add(exercise.id)) {
        throw StateError(
          'Duplicate or empty built-in exercise ID: ${exercise.id}',
        );
      }
      final name = normalize(exercise.name);
      if (name.isEmpty || !names.add(name)) {
        throw StateError('Duplicate or empty exercise name: ${exercise.name}');
      }
    }
  }
}
