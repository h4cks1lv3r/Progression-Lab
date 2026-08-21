import 'package:flutter/material.dart';

import 'brand.dart';
import 'exercise_library.dart';
import 'safe_layout.dart';
import 'store.dart';

const _cyan = BrandColors.cyan;
const _violet = BrandColors.violet;


extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}

class ExerciseLibraryScreen extends StatefulWidget {
  const ExerciseLibraryScreen({super.key, required this.store});

  final AppStore store;

  @override
  State<ExerciseLibraryScreen> createState() => _ExerciseLibraryScreenState();
}

class _ExerciseLibraryScreenState extends State<ExerciseLibraryScreen> {
  final _search = TextEditingController();
  final Set<MuscleGroup> _muscles = {};
  final Set<ExerciseEquipment> _equipment = {};
  final Set<ExerciseTrackingType> _tracking = {};
  var _includeSecondary = true;
  var _favoritesOnly = false;
  var _customOnly = false;
  var _archivedOnly = false;

  bool get _hasFilters =>
      _muscles.isNotEmpty ||
      _equipment.isNotEmpty ||
      _tracking.isNotEmpty ||
      !_includeSecondary ||
      _favoritesOnly ||
      _customOnly ||
      _archivedOnly;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _clearFilters() => setState(() {
    _muscles.clear();
    _equipment.clear();
    _tracking.clear();
    _includeSecondary = true;
    _favoritesOnly = false;
    _customOnly = false;
    _archivedOnly = false;
  });

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.store,
    builder: (context, _) {
      final results = ExerciseLibrary.search(
        custom: widget.store.customExercises,
        favoriteBuiltInIds: widget.store.favoriteBuiltInExerciseIds,
        query: _search.text,
        muscles: _muscles,
        equipment: _equipment,
        trackingTypes: _tracking,
        includeSecondaryMuscles: _includeSecondary,
        favoritesOnly: _favoritesOnly,
        customOnly: _customOnly,
        archivedOnly: _archivedOnly,
      );
      final showDiscovery = _search.text.trim().isEmpty && !_hasFilters;
      return Scaffold(
        appBar: AppBar(
          title: const Text('Exercise Library'),
          actions: [
            IconButton(
              tooltip: 'Filters',
              onPressed: _showFilters,
              icon: Badge(
                isLabelVisible: _hasFilters,
                child: const Icon(Icons.tune_rounded),
              ),
            ),
          ],
        ),
        body: LabSafeScreen(
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 112),
            children: [
              const _LibraryHeader(),
              const SizedBox(height: 18),
              TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Search lifts, muscles, equipment, or aliases',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _search.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear search',
                          onPressed: () {
                            _search.clear();
                            setState(() {});
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                ),
              ),
              if (_hasFilters) ...[
                const SizedBox(height: 12),
                _ActiveFilters(
                  muscles: _muscles,
                  equipment: _equipment,
                  tracking: _tracking,
                  favoritesOnly: _favoritesOnly,
                  customOnly: _customOnly,
                  archivedOnly: _archivedOnly,
                  onClear: _clearFilters,
                ),
              ],
              if (showDiscovery && widget.store.recentExercises.isNotEmpty) ...[
                const SizedBox(height: 24),
                const _SectionTitle('RECENT'),
                const SizedBox(height: 10),
                _HorizontalExerciseRail(
                  items: widget.store.recentExercises,
                  onOpen: _openDetail,
                ),
              ],
              if (showDiscovery && widget.store.favoriteExercises.isNotEmpty) ...[
                const SizedBox(height: 24),
                const _SectionTitle('FAVORITES'),
                const SizedBox(height: 10),
                _HorizontalExerciseRail(
                  items: widget.store.favoriteExercises,
                  onOpen: _openDetail,
                ),
              ],
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _SectionTitle(
                      _archivedOnly ? 'ARCHIVED CUSTOM' : 'ALL EXERCISES',
                    ),
                  ),
                  Text(
                    '${results.length}',
                    style: const TextStyle(
                      color: Colors.white38,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (results.isEmpty)
                _EmptyResults(onClear: () {
                  _search.clear();
                  _clearFilters();
                })
              else
                Card(
                  margin: EdgeInsets.zero,
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      for (final entry in results.asMap().entries) ...[
                        _ExerciseTile(
                          option: entry.value,
                          onTap: () => _openDetail(entry.value),
                          onFavorite: _archivedOnly
                              ? null
                              : () => widget.store.toggleExerciseFavorite(
                                  entry.value,
                                ),
                        ),
                        if (entry.key < results.length - 1)
                          const Divider(height: 1, indent: 66),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _openEditor(),
          backgroundColor: _violet,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add_rounded),
          label: const Text('CREATE EXERCISE'),
        ),
      );
    },
  );

  Future<void> _showFilters() async {
    var muscles = Set<MuscleGroup>.of(_muscles);
    var equipment = Set<ExerciseEquipment>.of(_equipment);
    var tracking = Set<ExerciseTrackingType>.of(_tracking);
    var includeSecondary = _includeSecondary;
    var favoritesOnly = _favoritesOnly;
    var customOnly = _customOnly;
    var archivedOnly = _archivedOnly;

    final apply = await showLabBottomSheet<bool>(
      context: context,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => LabSafeBottomSheet(
          scrollable: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SheetHeading(
                title: 'FILTER THE LIBRARY',
                subtitle: 'Find the movement that fits the work.',
              ),
              const SizedBox(height: 22),
              const _SectionTitle('QUICK FILTERS'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilterChip(
                    label: const Text('Favorites'),
                    selected: favoritesOnly,
                    onSelected: (value) =>
                        setSheetState(() => favoritesOnly = value),
                  ),
                  FilterChip(
                    label: const Text('Custom'),
                    selected: customOnly,
                    onSelected: (value) => setSheetState(() {
                      customOnly = value;
                      if (value) archivedOnly = false;
                    }),
                  ),
                  FilterChip(
                    label: const Text('Archived'),
                    selected: archivedOnly,
                    onSelected: (value) => setSheetState(() {
                      archivedOnly = value;
                      if (value) customOnly = false;
                    }),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              const _SectionTitle('MUSCLE'),
              const SizedBox(height: 8),
              _MultiChoiceWrap<MuscleGroup>(
                values: MuscleGroup.values
                    .where((item) => item != MuscleGroup.other)
                    .toList(),
                selected: muscles,
                label: (value) => value.label,
                onToggle: (value) => setSheetState(() {
                  muscles.contains(value)
                      ? muscles.remove(value)
                      : muscles.add(value);
                }),
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: includeSecondary,
                onChanged: (value) =>
                    setSheetState(() => includeSecondary = value),
                title: const Text('Include secondary-muscle matches'),
              ),
              const SizedBox(height: 12),
              const _SectionTitle('EQUIPMENT'),
              const SizedBox(height: 8),
              _MultiChoiceWrap<ExerciseEquipment>(
                values: ExerciseEquipment.values,
                selected: equipment,
                label: (value) => value.label,
                onToggle: (value) => setSheetState(() {
                  equipment.contains(value)
                      ? equipment.remove(value)
                      : equipment.add(value);
                }),
              ),
              const SizedBox(height: 22),
              const _SectionTitle('TRACKING TYPE'),
              const SizedBox(height: 8),
              _MultiChoiceWrap<ExerciseTrackingType>(
                values: ExerciseTrackingType.values,
                selected: tracking,
                label: (value) => value.label,
                onToggle: (value) => setSheetState(() {
                  tracking.contains(value)
                      ? tracking.remove(value)
                      : tracking.add(value);
                }),
              ),
              const SizedBox(height: 26),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(sheetContext, false),
                      child: const Text('CANCEL'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(sheetContext, true),
                      child: const Text('APPLY FILTERS'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (apply != true || !mounted) return;
    setState(() {
      _muscles
        ..clear()
        ..addAll(muscles);
      _equipment
        ..clear()
        ..addAll(equipment);
      _tracking
        ..clear()
        ..addAll(tracking);
      _includeSecondary = includeSecondary;
      _favoritesOnly = favoritesOnly;
      _customOnly = customOnly;
      _archivedOnly = archivedOnly;
    });
  }

  Future<void> _openEditor({CustomExercise? exercise}) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ExerciseEditorScreen(
          store: widget.store,
          exercise: exercise,
        ),
      ),
    );
  }

  Future<void> _openDetail(ExerciseOption option) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ExerciseDetailScreen(
          store: widget.store,
          option: option,
        ),
      ),
    );
  }
}

class ExerciseDetailScreen extends StatelessWidget {
  const ExerciseDetailScreen({
    super.key,
    required this.store,
    required this.option,
  });

  final AppStore store;
  final ExerciseOption option;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: store,
    builder: (context, _) {
      final fresh = store.selectableExercises
          .where((item) => item.id == option.id)
          .firstOrNull;
      final current = fresh ?? option;
      final history = store.logs
          .where(
            (log) => log.exerciseId == current.id ||
                ExerciseLibrary.normalize(log.exercise) ==
                    ExerciseLibrary.normalize(current.name),
          )
          .toList()
        ..sort((a, b) => b.date.compareTo(a.date));
      final best = store.best(current.name, exerciseId: current.id);
      final descriptor = store.exerciseDescriptor(
        id: current.id,
        name: current.name,
      );
      final substitutes = descriptor == null
          ? const <ExerciseOption>[]
          : ExerciseLibrary.rankedSubstitutions(
              target: descriptor,
              custom: store.customExercises,
              favoriteBuiltInIds: store.favoriteBuiltInExerciseIds,
              limit: 6,
            );
      return Scaffold(
        appBar: AppBar(
          title: Text(current.name),
          actions: [
            IconButton(
              tooltip: current.isFavorite
                  ? 'Remove from favorites'
                  : 'Add to favorites',
              onPressed: () => store.toggleExerciseFavorite(current),
              icon: Icon(
                current.isFavorite
                    ? Icons.star_rounded
                    : Icons.star_border_rounded,
                color: current.isFavorite ? _violet : null,
              ),
            ),
          ],
        ),
        body: LabSafeScreen(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
            children: [
              _ExerciseHero(option: current),
              const SizedBox(height: 18),
              _MetadataPanel(option: current),
              if (current.notes.trim().isNotEmpty) ...[
                const SizedBox(height: 18),
                _InfoPanel(
                  title: 'SETUP & CUES',
                  body: current.notes,
                ),
              ],
              const SizedBox(height: 18),
              _InfoPanel(
                title: 'HISTORY',
                body: history.isEmpty
                    ? 'No logged sets yet. The signal starts with your first clean entry.'
                    : '${history.length} logged set${history.length == 1 ? '' : 's'} · '
                          'Last used ${_shortDate(history.first.date)}${best == null ? '' : ' · Best ${_bestSummary(best, current.trackingType, store.unit)}'}',
              ),
              if (substitutes.isNotEmpty) ...[
                const SizedBox(height: 18),
                const _SectionTitle('SMART SUBSTITUTIONS'),
                const SizedBox(height: 10),
                Card(
                  margin: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (final entry in substitutes.asMap().entries) ...[
                        ListTile(
                          leading: CircleAvatar(
                            backgroundColor: _cyan.withValues(alpha: .12),
                            child: Text('${entry.key + 1}'),
                          ),
                          title: Text(entry.value.name),
                          subtitle: Text(entry.value.subtitle),
                          onTap: () => Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                              builder: (_) => ExerciseDetailScreen(
                                store: store,
                                option: entry.value,
                              ),
                            ),
                          ),
                        ),
                        if (entry.key < substitutes.length - 1)
                          const Divider(height: 1, indent: 64),
                      ],
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
              if (current.isBuiltIn)
                FilledButton.icon(
                  onPressed: () async {
                    final created = await store.duplicateBuiltInExercise(
                      current.id,
                    );
                    if (!context.mounted) return;
                    await Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => ExerciseEditorScreen(
                          store: store,
                          exercise: created,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.copy_rounded),
                  label: const Text('DUPLICATE AS CUSTOM'),
                )
              else ...[
                FilledButton.icon(
                  onPressed: () {
                    final custom = store.customExercises
                        .where((item) => item.id == current.id)
                        .firstOrNull;
                    if (custom == null) return;
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ExerciseEditorScreen(
                          store: store,
                          exercise: custom,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.edit_rounded),
                  label: const Text('EDIT CUSTOM EXERCISE'),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () async {
                    final custom = store.customExercises
                        .where((item) => item.id == current.id)
                        .firstOrNull;
                    if (custom == null) return;
                    custom.isArchived
                        ? await store.restoreCustomExercise(custom.id)
                        : await store.archiveCustomExercise(custom.id);
                    if (context.mounted) Navigator.pop(context);
                  },
                  icon: Icon(
                    store.customExercises
                            .where((item) => item.id == current.id)
                            .firstOrNull
                            ?.isArchived ==
                        true
                        ? Icons.unarchive_rounded
                        : Icons.archive_outlined,
                  ),
                  label: Text(
                    store.customExercises
                                .where((item) => item.id == current.id)
                                .firstOrNull
                                ?.isArchived ==
                            true
                        ? 'RESTORE EXERCISE'
                        : 'ARCHIVE EXERCISE',
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    },
  );

  static String _shortDate(DateTime value) =>
      '${value.month}/${value.day}/${value.year}';

  static String _bestSummary(
    SetLog log,
    ExerciseTrackingType type,
    String unit,
  ) => switch (type) {
    ExerciseTrackingType.bodyweightReps || ExerciseTrackingType.repsOnly =>
      '${log.reps} reps',
    ExerciseTrackingType.assistedBodyweight =>
      '${log.weight.toStringAsFixed(log.weight % 1 == 0 ? 0 : 1)} $unit assistance × ${log.reps}',
    ExerciseTrackingType.duration => '${log.durationSeconds ?? 0}s',
    ExerciseTrackingType.distanceOnly ||
    ExerciseTrackingType.distanceDuration =>
      '${log.distance?.toStringAsFixed(1) ?? '0'} ${log.distanceUnit ?? 'm'}',
    _ =>
      '${log.weight.toStringAsFixed(log.weight % 1 == 0 ? 0 : 1)} $unit × ${log.reps}',
  };
}

class ExerciseEditorScreen extends StatefulWidget {
  const ExerciseEditorScreen({
    super.key,
    required this.store,
    this.exercise,
  });

  final AppStore store;
  final CustomExercise? exercise;

  @override
  State<ExerciseEditorScreen> createState() => _ExerciseEditorScreenState();
}

class _ExerciseEditorScreenState extends State<ExerciseEditorScreen> {
  final _page = PageController();
  late final TextEditingController _name;
  late final TextEditingController _aliases;
  late final TextEditingController _notes;
  late final TextEditingController _tags;
  late final TextEditingController _rest;
  late final String _id;
  var _step = 0;
  var _primary = MuscleGroup.other;
  final Set<MuscleGroup> _secondary = {};
  var _equipment = ExerciseEquipment.other;
  var _pattern = MovementPattern.other;
  var _tracking = ExerciseTrackingType.weightReps;
  var _unilateral = UnilateralMode.bilateral;
  String? _unitOverride;
  var _isCompound = false;
  var _warmupEligible = false;
  var _saving = false;
  String? _error;

  static const _titles = [
    'Identity',
    'Muscles',
    'Setup',
    'Tracking',
    'Progression',
    'Review',
  ];

  @override
  void initState() {
    super.initState();
    final exercise = widget.exercise;
    _id = exercise?.id ?? 'custom-${DateTime.now().microsecondsSinceEpoch}';
    _name = TextEditingController(text: exercise?.name ?? '');
    _aliases = TextEditingController(text: exercise?.aliases.join(', ') ?? '');
    _notes = TextEditingController(text: exercise?.notes ?? '');
    _tags = TextEditingController(text: exercise?.tags.join(', ') ?? '');
    _rest = TextEditingController(
      text: exercise?.defaultRestSeconds?.toString() ?? '',
    );
    if (exercise != null) {
      _primary = exercise.primaryMuscle;
      _secondary.addAll(exercise.secondaryMuscles);
      _equipment = exercise.equipment;
      _pattern = exercise.movementPattern;
      _tracking = exercise.trackingType;
      _unilateral = exercise.unilateralMode;
      _unitOverride = exercise.unitOverride;
      _isCompound = exercise.isPrimaryCompound;
      _warmupEligible = exercise.warmupEligible;
    }
  }

  @override
  void dispose() {
    _page.dispose();
    _name.dispose();
    _aliases.dispose();
    _notes.dispose();
    _tags.dispose();
    _rest.dispose();
    super.dispose();
  }

  bool _validateStep() {
    setState(() => _error = null);
    if (_step == 0 && _name.text.trim().isEmpty) {
      setState(() => _error = 'Give the exercise a clear name.');
      return false;
    }
    if (_step == 1 && _primary == MuscleGroup.other) {
      setState(() => _error = 'Choose the primary muscle.');
      return false;
    }
    return true;
  }

  void _next() {
    if (!_validateStep()) return;
    if (_step >= _titles.length - 1) {
      _save();
      return;
    }
    setState(() => _step++);
    _page.animateToPage(
      _step,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  void _back() {
    if (_step == 0) {
      Navigator.pop(context);
      return;
    }
    setState(() {
      _step--;
      _error = null;
    });
    _page.animateToPage(
      _step,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _save() async {
    if (_saving || !_validateStep()) return;
    setState(() => _saving = true);
    final aliases = _csv(_aliases.text);
    final tags = _csv(_tags.text);
    final rest = int.tryParse(_rest.text.trim());
    final old = widget.exercise;
    final value = CustomExercise(
      id: _id,
      name: _name.text.trim(),
      aliases: aliases,
      primaryMuscle: _primary,
      secondaryMuscles: _secondary.where((item) => item != _primary).toList(),
      equipment: _equipment,
      movementPattern: _pattern,
      trackingType: _tracking,
      unilateralMode: _unilateral,
      unitOverride: _unitOverride,
      defaultRestSeconds: rest != null && rest > 0 ? rest : null,
      isPrimaryCompound: _isCompound,
      warmupEligible: _isCompound &&
          _warmupEligible &&
          _tracking == ExerciseTrackingType.weightReps,
      notes: _notes.text.trim(),
      tags: tags,
      mediaReference: old?.mediaReference,
      isFavorite: old?.isFavorite ?? false,
      isArchived: old?.isArchived ?? false,
    );
    try {
      await widget.store.saveCustomExercise(value);
      if (mounted) Navigator.pop(context);
    } on ArgumentError catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = error.message.toString();
          _step = 0;
        });
        _page.jumpToPage(0);
      }
    } on StateError catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = error.message;
          _step = 3;
        });
        _page.jumpToPage(3);
      }
    } on Object {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'The exercise was not saved. Your existing data is unchanged.';
        });
      }
    }
  }

  static List<String> _csv(String value) => value
      .split(',')
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toSet()
      .toList();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.exercise == null ? 'Create Exercise' : 'Edit Exercise'),
      leading: IconButton(
        tooltip: 'Back',
        onPressed: _back,
        icon: const Icon(Icons.arrow_back_rounded),
      ),
    ),
    body: LabSafeScreen(
      bottomAction: Row(
        children: [
          if (_step > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: _saving ? null : _back,
                child: const Text('BACK'),
              ),
            ),
          if (_step > 0) const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: FilledButton(
              onPressed: _saving ? null : _next,
              child: Text(
                _saving
                    ? 'SAVING'
                    : _step == _titles.length - 1
                    ? 'CREATE EXERCISE'
                    : 'CONTINUE',
              ),
            ),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '${_step + 1} OF ${_titles.length}',
                      style: const TextStyle(
                        color: _cyan,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _titles[_step].toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white54,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: (_step + 1) / _titles.length,
                  minHeight: 5,
                  borderRadius: BorderRadius.circular(99),
                  color: _violet,
                  backgroundColor: Colors.white10,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _error!,
                    style: const TextStyle(
                      color: Colors.orangeAccent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: PageView(
              controller: _page,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _IdentityStep(
                  name: _name,
                  aliases: _aliases,
                  notes: _notes,
                  tags: _tags,
                ),
                _MuscleStep(
                  primary: _primary,
                  secondary: _secondary,
                  onPrimary: (value) => setState(() {
                    _primary = value;
                    _secondary.remove(value);
                  }),
                  onSecondary: (value) => setState(() {
                    _secondary.contains(value)
                        ? _secondary.remove(value)
                        : _secondary.add(value);
                  }),
                ),
                _SetupStep(
                  equipment: _equipment,
                  pattern: _pattern,
                  unilateral: _unilateral,
                  onEquipment: (value) => setState(() => _equipment = value),
                  onPattern: (value) => setState(() => _pattern = value),
                  onUnilateral: (value) =>
                      setState(() => _unilateral = value),
                ),
                _TrackingStep(
                  selected: _tracking,
                  onSelected: (value) => setState(() {
                    _tracking = value;
                    if (value != ExerciseTrackingType.weightReps) {
                      _warmupEligible = false;
                    }
                  }),
                ),
                _ProgressionStep(
                  tracking: _tracking,
                  unitOverride: _unitOverride,
                  rest: _rest,
                  isCompound: _isCompound,
                  warmupEligible: _warmupEligible,
                  onUnit: (value) => setState(() => _unitOverride = value),
                  onCompound: (value) => setState(() {
                    _isCompound = value;
                    if (!value) _warmupEligible = false;
                  }),
                  onWarmup: (value) =>
                      setState(() => _warmupEligible = value),
                ),
                _ReviewStep(
                  name: _name.text.trim(),
                  primary: _primary,
                  secondary: _secondary.toList(),
                  equipment: _equipment,
                  pattern: _pattern,
                  tracking: _tracking,
                  unilateral: _unilateral,
                  unitOverride: _unitOverride,
                  compound: _isCompound,
                  warmup: _warmupEligible,
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _IdentityStep extends StatelessWidget {
  const _IdentityStep({
    required this.name,
    required this.aliases,
    required this.notes,
    required this.tags,
  });

  final TextEditingController name;
  final TextEditingController aliases;
  final TextEditingController notes;
  final TextEditingController tags;

  @override
  Widget build(BuildContext context) => LabKeyboardAwareForm(
    children: [
      const _StepIntro(
        title: 'NAME THE MOVEMENT',
        body: 'Use the name you will recognize mid-session. Aliases make imported and abbreviated names easy to find.',
      ),
      const SizedBox(height: 20),
      TextField(
        controller: name,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(
          labelText: 'EXERCISE NAME',
          hintText: 'Example: Meadows Row',
        ),
      ),
      const SizedBox(height: 14),
      TextField(
        controller: aliases,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(
          labelText: 'ALIASES',
          hintText: 'Comma-separated alternate names',
        ),
      ),
      const SizedBox(height: 14),
      TextField(
        controller: tags,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(
          labelText: 'PERSONAL TAGS',
          hintText: 'Home Gym, Rehab, Push Day',
        ),
      ),
      const SizedBox(height: 14),
      TextField(
        controller: notes,
        minLines: 3,
        maxLines: 6,
        decoration: const InputDecoration(
          labelText: 'SETUP & NOTES',
          hintText: 'Optional setup, machine number, or form cues',
        ),
      ),
    ],
  );
}

class _MuscleStep extends StatelessWidget {
  const _MuscleStep({
    required this.primary,
    required this.secondary,
    required this.onPrimary,
    required this.onSecondary,
  });

  final MuscleGroup primary;
  final Set<MuscleGroup> secondary;
  final ValueChanged<MuscleGroup> onPrimary;
  final ValueChanged<MuscleGroup> onSecondary;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
    children: [
      const _StepIntro(
        title: 'MAP THE MUSCLES',
        body: 'Primary muscle drives volume and Lab analysis. Add secondary muscles for better filtering and substitutions.',
      ),
      const SizedBox(height: 20),
      DropdownButtonFormField<MuscleGroup>(
        initialValue: primary == MuscleGroup.other ? null : primary,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'PRIMARY MUSCLE'),
        items: [
          for (final value in MuscleGroup.values)
            if (value != MuscleGroup.other)
              DropdownMenuItem(value: value, child: Text(value.label)),
        ],
        onChanged: (value) {
          if (value != null) onPrimary(value);
        },
      ),
      const SizedBox(height: 20),
      const _SectionTitle('SECONDARY MUSCLES'),
      const SizedBox(height: 10),
      _MultiChoiceWrap<MuscleGroup>(
        values: MuscleGroup.values
            .where((item) => item != MuscleGroup.other && item != primary)
            .toList(),
        selected: secondary,
        label: (value) => value.label,
        onToggle: onSecondary,
      ),
    ],
  );
}

class _SetupStep extends StatelessWidget {
  const _SetupStep({
    required this.equipment,
    required this.pattern,
    required this.unilateral,
    required this.onEquipment,
    required this.onPattern,
    required this.onUnilateral,
  });

  final ExerciseEquipment equipment;
  final MovementPattern pattern;
  final UnilateralMode unilateral;
  final ValueChanged<ExerciseEquipment> onEquipment;
  final ValueChanged<MovementPattern> onPattern;
  final ValueChanged<UnilateralMode> onUnilateral;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
    children: [
      const _StepIntro(
        title: 'DEFINE THE SETUP',
        body: 'Equipment and movement pattern help the app recommend smart substitutes instead of random same-muscle swaps.',
      ),
      const SizedBox(height: 20),
      DropdownButtonFormField<ExerciseEquipment>(
        initialValue: equipment,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'EQUIPMENT'),
        items: [
          for (final value in ExerciseEquipment.values)
            DropdownMenuItem(value: value, child: Text(value.label)),
        ],
        onChanged: (value) {
          if (value != null) onEquipment(value);
        },
      ),
      const SizedBox(height: 14),
      DropdownButtonFormField<MovementPattern>(
        initialValue: pattern,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'MOVEMENT PATTERN'),
        items: [
          for (final value in MovementPattern.values)
            DropdownMenuItem(value: value, child: Text(value.label)),
        ],
        onChanged: (value) {
          if (value != null) onPattern(value);
        },
      ),
      const SizedBox(height: 14),
      DropdownButtonFormField<UnilateralMode>(
        initialValue: unilateral,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'SIDE / REP HANDLING'),
        items: [
          for (final value in UnilateralMode.values)
            DropdownMenuItem(value: value, child: Text(value.label)),
        ],
        onChanged: (value) {
          if (value != null) onUnilateral(value);
        },
      ),
    ],
  );
}

class _TrackingStep extends StatelessWidget {
  const _TrackingStep({required this.selected, required this.onSelected});

  final ExerciseTrackingType selected;
  final ValueChanged<ExerciseTrackingType> onSelected;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
    children: [
      const _StepIntro(
        title: 'CHOOSE WHAT GETS LOGGED',
        body: 'The tracking type controls set fields, PRs, charts, volume, and imports. Bodyweight movements never need a fake weight entry.',
      ),
      const SizedBox(height: 18),
      for (final value in ExerciseTrackingType.values)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _TrackingTypeCard(
            value: value,
            selected: selected == value,
            onTap: () => onSelected(value),
          ),
        ),
    ],
  );
}

class _ProgressionStep extends StatelessWidget {
  const _ProgressionStep({
    required this.tracking,
    required this.unitOverride,
    required this.rest,
    required this.isCompound,
    required this.warmupEligible,
    required this.onUnit,
    required this.onCompound,
    required this.onWarmup,
  });

  final ExerciseTrackingType tracking;
  final String? unitOverride;
  final TextEditingController rest;
  final bool isCompound;
  final bool warmupEligible;
  final ValueChanged<String?> onUnit;
  final ValueChanged<bool> onCompound;
  final ValueChanged<bool> onWarmup;

  @override
  Widget build(BuildContext context) => LabKeyboardAwareForm(
    children: [
      const _StepIntro(
        title: 'SET THE DEFAULTS',
        body: 'Keep it simple now. You can adjust rest and unit preferences later without changing the movement identity.',
      ),
      const SizedBox(height: 20),
      DropdownButtonFormField<String?>(
        initialValue: unitOverride,
        decoration: const InputDecoration(labelText: 'WEIGHT UNIT'),
        items: const [
          DropdownMenuItem<String?>(value: null, child: Text('Use app default')),
          DropdownMenuItem<String?>(value: 'lb', child: Text('Pounds (lb)')),
          DropdownMenuItem<String?>(value: 'kg', child: Text('Kilograms (kg)')),
        ],
        onChanged: onUnit,
      ),
      const SizedBox(height: 14),
      TextField(
        controller: rest,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(
          labelText: 'DEFAULT REST (SECONDS)',
          hintText: 'Optional',
        ),
      ),
      const SizedBox(height: 14),
      SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        value: isCompound,
        onChanged: onCompound,
        title: const Text('Primary compound movement'),
        subtitle: const Text('Used for substitutions and workload context.'),
      ),
      SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        value: warmupEligible,
        onChanged: isCompound && tracking == ExerciseTrackingType.weightReps
            ? onWarmup
            : null,
        title: const Text('Automatic warm-up ramp'),
        subtitle: Text(
          tracking == ExerciseTrackingType.weightReps
              ? 'Use only when percentage-based loading makes sense.'
              : 'Available only for Weight + Reps compound exercises.',
        ),
      ),
    ],
  );
}

class _ReviewStep extends StatelessWidget {
  const _ReviewStep({
    required this.name,
    required this.primary,
    required this.secondary,
    required this.equipment,
    required this.pattern,
    required this.tracking,
    required this.unilateral,
    required this.unitOverride,
    required this.compound,
    required this.warmup,
  });

  final String name;
  final MuscleGroup primary;
  final List<MuscleGroup> secondary;
  final ExerciseEquipment equipment;
  final MovementPattern pattern;
  final ExerciseTrackingType tracking;
  final UnilateralMode unilateral;
  final String? unitOverride;
  final bool compound;
  final bool warmup;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
    children: [
      const _StepIntro(
        title: 'REVIEW THE SETUP',
        body: 'Built, not guessed. Confirm the movement before it enters your library.',
      ),
      const SizedBox(height: 20),
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              _violet.withValues(alpha: .18),
              _cyan.withValues(alpha: .08),
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _violet.withValues(alpha: .35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'CUSTOM EXERCISE',
              style: TextStyle(
                color: _cyan,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              name.isEmpty ? 'Unnamed Exercise' : name,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 18),
            _ReviewRow('Primary', primary.label),
            _ReviewRow(
              'Secondary',
              secondary.isEmpty
                  ? 'None selected'
                  : secondary.map((item) => item.label).join(', '),
            ),
            _ReviewRow('Equipment', equipment.label),
            _ReviewRow('Pattern', pattern.label),
            _ReviewRow('Type', tracking.label),
            _ReviewRow('Sides', unilateral.label),
            _ReviewRow('Unit', unitOverride ?? 'App default'),
            _ReviewRow('Compound', compound ? 'Yes' : 'No'),
            _ReviewRow('Warm-up', warmup ? 'Automatic' : 'Off'),
          ],
        ),
      ),
    ],
  );
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 86,
          child: Text(label, style: const TextStyle(color: Colors.white54)),
        ),
        Expanded(
          child: Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
      ],
    ),
  );
}

class _TrackingTypeCard extends StatelessWidget {
  const _TrackingTypeCard({
    required this.value,
    required this.selected,
    required this.onTap,
  });
  final ExerciseTrackingType value;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? _violet.withValues(alpha: .16) : BrandColors.panel,
    borderRadius: BorderRadius.circular(18),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? _violet.withValues(alpha: .7)
                : Colors.white.withValues(alpha: .08),
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.check_circle_rounded : Icons.circle_outlined,
              color: selected ? _violet : Colors.white38,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value.label, style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 3),
                  Text(
                    _trackingDescription(value),
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );

  static String _trackingDescription(ExerciseTrackingType value) =>
      switch (value) {
        ExerciseTrackingType.weightReps => 'Barbells, dumbbells, cables, and machines.',
        ExerciseTrackingType.bodyweightReps => 'Reps only. No weight field required.',
        ExerciseTrackingType.weightedBodyweight => 'Added weight plus reps or hold time.',
        ExerciseTrackingType.assistedBodyweight => 'Assistance plus reps; less assistance is progress.',
        ExerciseTrackingType.repsOnly => 'Count repetitions without load.',
        ExerciseTrackingType.weightOnly => 'Track the heaviest completed load.',
        ExerciseTrackingType.duration => 'Holds, mobility, and timed work.',
        ExerciseTrackingType.durationWeight => 'Timed loaded carries or holds.',
        ExerciseTrackingType.distanceDuration => 'Cardio distance and elapsed time.',
        ExerciseTrackingType.weightDistance => 'Loaded carries and sled work.',
        ExerciseTrackingType.repsDuration => 'Repetition count and work time.',
        ExerciseTrackingType.repsDistance => 'Repetition count and distance.',
        ExerciseTrackingType.distanceOnly => 'Distance without a required time.',
        ExerciseTrackingType.caloriesDuration => 'Machine calories and elapsed time.',
      };
}

class _ExerciseTile extends StatelessWidget {
  const _ExerciseTile({
    required this.option,
    required this.onTap,
    required this.onFavorite,
  });
  final ExerciseOption option;
  final VoidCallback onTap;
  final VoidCallback? onFavorite;

  @override
  Widget build(BuildContext context) => ListTile(
    onTap: onTap,
    contentPadding: const EdgeInsets.fromLTRB(14, 7, 8, 7),
    leading: CircleAvatar(
      backgroundColor: _cyan.withValues(alpha: .1),
      child: Icon(_muscleIcon(option.primaryMuscle), color: _cyan, size: 20),
    ),
    title: Text(option.name, style: const TextStyle(fontWeight: FontWeight.w800)),
    subtitle: Text(
      '${option.primaryMuscle.label} · ${option.equipment.label}\n${option.trackingType.label}',
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    ),
    isThreeLine: true,
    trailing: IconButton(
      tooltip: option.isFavorite ? 'Remove favorite' : 'Favorite exercise',
      onPressed: onFavorite,
      icon: Icon(
        option.isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
        color: option.isFavorite ? _violet : Colors.white38,
      ),
    ),
  );
}

class _HorizontalExerciseRail extends StatelessWidget {
  const _HorizontalExerciseRail({required this.items, required this.onOpen});
  final List<ExerciseOption> items;
  final ValueChanged<ExerciseOption> onOpen;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 132,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(width: 10),
      itemBuilder: (context, index) {
        final item = items[index];
        return SizedBox(
          width: 190,
          child: Card(
            margin: EdgeInsets.zero,
            child: InkWell(
              onTap: () => onOpen(item),
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.all(15),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(_muscleIcon(item.primaryMuscle), color: _cyan),
                    const Spacer(),
                    Text(
                      item.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.primaryMuscle.label,
                      style: const TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}

class _ExerciseHero extends StatelessWidget {
  const _ExerciseHero({required this.option});
  final ExerciseOption option;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [
          _violet.withValues(alpha: .2),
          _cyan.withValues(alpha: .08),
        ],
      ),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: _violet.withValues(alpha: .34)),
    ),
    child: Row(
      children: [
        Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            color: _cyan.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Icon(_muscleIcon(option.primaryMuscle), color: _cyan, size: 30),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                option.isBuiltIn ? 'BUILT-IN EXERCISE' : 'CUSTOM EXERCISE',
                style: const TextStyle(
                  color: _cyan,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                option.name,
                style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _MetadataPanel extends StatelessWidget {
  const _MetadataPanel({required this.option});
  final ExerciseOption option;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _MetaChip(option.primaryMuscle.label, _cyan),
          for (final muscle in option.secondaryMuscles.take(3))
            _MetaChip(muscle.label, Colors.white54),
          _MetaChip(option.equipment.label, _violet),
          _MetaChip(option.movementPattern.label, Colors.white54),
          _MetaChip(option.trackingType.label, _cyan),
          if (option.isPrimaryCompound)
            const _MetaChip('Compound', _violet),
          if (option.warmupEligible)
            const _MetaChip('Auto Warm-Up', _cyan),
        ],
      ),
    ),
  );
}

class _MetaChip extends StatelessWidget {
  const _MetaChip(this.label, this.color);
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .1),
      borderRadius: BorderRadius.circular(99),
      border: Border.all(color: color.withValues(alpha: .28)),
    ),
    child: Text(
      label,
      style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800),
    ),
  );
}

class _InfoPanel extends StatelessWidget {
  const _InfoPanel({required this.title, required this.body});
  final String title;
  final String body;
  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: _cyan,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          Text(body, style: const TextStyle(color: Colors.white70, height: 1.45)),
        ],
      ),
    ),
  );
}

class _LibraryHeader extends StatelessWidget {
  const _LibraryHeader();
  @override
  Widget build(BuildContext context) => const Row(
    children: [
      LabMark(size: 54),
      SizedBox(width: 14),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'EXERCISE LIBRARY 2.0',
              style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900),
            ),
            SizedBox(height: 3),
            Text(
              '512 movements. Search the signal, not the noise.',
              style: TextStyle(color: Colors.white54),
            ),
          ],
        ),
      ),
    ],
  );
}

class _StepIntro extends StatelessWidget {
  const _StepIntro({required this.title, required this.body});
  final String title;
  final String body;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
      const SizedBox(height: 7),
      Text(body, style: const TextStyle(color: Colors.white60, height: 1.45)),
    ],
  );
}

class _SheetHeading extends StatelessWidget {
  const _SheetHeading({required this.title, required this.subtitle});
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const LabMark(size: 46),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
            const SizedBox(height: 3),
            Text(subtitle, style: const TextStyle(color: Colors.white54)),
          ],
        ),
      ),
    ],
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.label);
  final String label;
  @override
  Widget build(BuildContext context) => Text(
    label,
    style: const TextStyle(
      color: Colors.white54,
      fontSize: 12,
      fontWeight: FontWeight.w900,
      letterSpacing: 1.2,
    ),
  );
}

class _MultiChoiceWrap<T> extends StatelessWidget {
  const _MultiChoiceWrap({
    required this.values,
    required this.selected,
    required this.label,
    required this.onToggle,
  });
  final List<T> values;
  final Set<T> selected;
  final String Function(T value) label;
  final ValueChanged<T> onToggle;
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final value in values)
        FilterChip(
          label: Text(label(value)),
          selected: selected.contains(value),
          onSelected: (_) => onToggle(value),
        ),
    ],
  );
}

class _ActiveFilters extends StatelessWidget {
  const _ActiveFilters({
    required this.muscles,
    required this.equipment,
    required this.tracking,
    required this.favoritesOnly,
    required this.customOnly,
    required this.archivedOnly,
    required this.onClear,
  });
  final Set<MuscleGroup> muscles;
  final Set<ExerciseEquipment> equipment;
  final Set<ExerciseTrackingType> tracking;
  final bool favoritesOnly;
  final bool customOnly;
  final bool archivedOnly;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              if (favoritesOnly) const _MetaChip('Favorites', _violet),
              if (customOnly) const _MetaChip('Custom', _cyan),
              if (archivedOnly) const _MetaChip('Archived', Colors.orangeAccent),
              for (final value in muscles.take(2)) ...[
                const SizedBox(width: 6),
                _MetaChip(value.label, _cyan),
              ],
              for (final value in equipment.take(1)) ...[
                const SizedBox(width: 6),
                _MetaChip(value.label, _violet),
              ],
              for (final value in tracking.take(1)) ...[
                const SizedBox(width: 6),
                _MetaChip(value.label, Colors.white54),
              ],
            ],
          ),
        ),
      ),
      TextButton(onPressed: onClear, child: const Text('CLEAR')),
    ],
  );
}

class _EmptyResults extends StatelessWidget {
  const _EmptyResults({required this.onClear});
  final VoidCallback onClear;
  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(22),
      child: Column(
        children: [
          const Icon(Icons.search_off_rounded, color: Colors.white38, size: 38),
          const SizedBox(height: 10),
          const Text('No exercise matches that setup.', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 5),
          const Text(
            'Clear a filter or create a movement that matches your equipment.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54),
          ),
          const SizedBox(height: 12),
          TextButton(onPressed: onClear, child: const Text('RESET SEARCH')),
        ],
      ),
    ),
  );
}

IconData _muscleIcon(MuscleGroup muscle) => switch (muscle.region) {
  'Abs & Core' => Icons.center_focus_strong_rounded,
  'Chest' => Icons.fitness_center_rounded,
  'Back' => Icons.swap_vert_rounded,
  'Shoulders' => Icons.accessibility_new_rounded,
  'Arms' => Icons.sports_gymnastics_rounded,
  'Lower Body' => Icons.directions_run_rounded,
  'Conditioning' => Icons.monitor_heart_outlined,
  'Mobility' => Icons.self_improvement_rounded,
  _ => Icons.science_outlined,
};
