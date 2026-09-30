import 'package:flutter/material.dart';

import 'brand.dart';
import 'display_format.dart';
import 'exercise_library.dart';
import 'logged_sets.dart';
import 'open_workout.dart';
import 'workout_logging_controls.dart';
import 'store.dart';

class OpenWorkoutScreen extends StatefulWidget {
  const OpenWorkoutScreen({super.key, required this.store});
  final AppStore store;

  @override
  State<OpenWorkoutScreen> createState() => _OpenWorkoutScreenState();
}

class _OpenWorkoutScreenState extends State<OpenWorkoutScreen> {
  bool _busy = false;
  String? _error;

  Future<void> _start() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final draft = await widget.store.beginOpenWorkout();
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => OpenWorkoutSessionScreen(
            store: widget.store,
            sessionId: draft.sessionId,
          ),
        ),
      );
    } on Object {
      if (mounted) {
        setState(() => _error = 'Could not open your workout. Try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.store,
    builder: (context, _) {
      final history = widget.store.openWorkoutHistory.reversed.toList();
      return Scaffold(
        appBar: AppBar(title: const Text('Open Workout')),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'Your workout. Your way.',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 12),
              const Text(
                'Pick your exercises and log sets as you go. Train freely alongside any program.',
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                key: const ValueKey('open-workout-start'),
                onPressed: _busy ? null : _start,
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text(
                  widget.store.openWorkoutDraft == null
                      ? 'Start workout'
                      : 'Resume workout',
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: BrandColors.error),
                  ),
                ),
              const SizedBox(height: 32),
              Text(
                'Recent workouts',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              if (history.isEmpty)
                const Text('Your saved Open Workouts will appear here.'),
              for (final record in history)
                Card(
                  child: ListTile(
                    title: Text(formatAppDate(record.startedAt)),
                    subtitle: Text(_summary(widget.store, record.sessionId)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => OpenWorkoutHistoryScreen(
                          store: widget.store,
                          record: record,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}

class OpenWorkoutSessionScreen extends StatefulWidget {
  const OpenWorkoutSessionScreen({
    super.key,
    required this.store,
    required this.sessionId,
  });
  final AppStore store;
  final String sessionId;

  @override
  State<OpenWorkoutSessionScreen> createState() =>
      _OpenWorkoutSessionScreenState();
}

class _OpenWorkoutSessionScreenState extends State<OpenWorkoutSessionScreen> {
  final _entryKeys = <String, GlobalKey<_OpenSetEntryState>>{};
  int _pendingInputWrites = 0;
  bool _busy = false;
  String? _error;

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on ArgumentError catch (error) {
      if (mounted) setState(() => _error = '${error.message}');
    } on StateError catch (error) {
      if (mounted) setState(() => _error = error.message);
    } on Object {
      if (mounted) {
        setState(
          () => _error =
              'Could not save that change. Your workout is still here. Try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addExercise() async {
    final exercise = await Navigator.push<ExerciseOption>(
      context,
      MaterialPageRoute(
        builder: (_) => _OpenExercisePicker(store: widget.store),
      ),
    );
    if (exercise == null || !mounted) return;
    await _run(
      () => widget.store.addOpenWorkoutExercise(
        sessionId: widget.sessionId,
        exerciseId: exercise.id,
      ),
    );
  }

  Future<void> _log() async {
    final draft = widget.store.openWorkoutDraft;
    if (draft == null || draft.selectedExercise == null || _busy) return;
    final key =
        '${draft.sessionId}:${draft.selectedIndex}:${widget.store.unit}';
    // Logging still works when the entry form has scrolled out of the lazy list.
    final inputs = _entryKeys[key]?.currentState?.inputs ?? draft.inputs;
    await _run(() async {
      final type = draft.selectedExercise!.trackingType;
      final weight = type.parseWeightInput(inputs['weight'] ?? '');
      if (type.usesWeight && weight == null) {
        throw ArgumentError('Enter a valid weight.');
      }
      await widget.store.logOpenWorkoutSet(
        sessionId: draft.sessionId,
        exerciseIndex: draft.selectedIndex,
        setSequence: draft.nextSetSequence,
        weight: weight,
        reps: int.tryParse((inputs['reps'] ?? '').trim()),
        seconds: int.tryParse((inputs['seconds'] ?? '').trim()),
        meters: double.tryParse((inputs['meters'] ?? '').trim()),
        calories: double.tryParse((inputs['calories'] ?? '').trim()),
        notes: inputs['notes'] ?? '',
      );
      if (!mounted) return;
      FocusScope.of(context).unfocus();
      final messenger = ScaffoldMessenger.of(context);
      messenger.clearSnackBars();
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Set saved'),
          duration: Duration(seconds: 3),
          persist: false,
          showCloseIcon: true,
        ),
      );
    });
  }

  Future<void> _finish() => _run(() async {
    await widget.store.finishOpenWorkout(widget.sessionId);
    if (!mounted) return;
    final record = widget.store.openWorkoutHistory.firstWhere(
      (value) => value.sessionId == widget.sessionId,
    );
    Navigator.pushReplacement(
      context,
      MaterialPageRoute<void>(
        builder: (_) =>
            OpenWorkoutHistoryScreen(store: widget.store, record: record),
      ),
    );
  });

  Future<void> _discard() async {
    final count = widget.store.logs
        .where((log) => log.sessionId == widget.sessionId)
        .length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard this workout?'),
        content: Text(
          count == 0
              ? 'This removes the unfinished workout. Your saved workout history stays.'
              : 'This removes this unfinished workout and its $count saved sets. Your other workouts stay.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep workout'),
          ),
          FilledButton(
            key: const ValueKey('open-discard-confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard workout'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _run(() async {
      await widget.store.discardOpenWorkout(widget.sessionId);
      if (mounted) Navigator.pop(context);
    });
  }

  Future<void> _removeExercise() async {
    final draft = widget.store.openWorkoutDraft;
    if (draft == null || draft.selectedExercise == null) return;
    final exercise = draft.selectedExercise!;
    final sets = widget.store.logs
        .where(
          (log) =>
              log.sessionId == draft.sessionId &&
              log.exerciseIndex == draft.selectedIndex,
        )
        .toList();
    final inputs = Map<String, String>.of(draft.inputs);
    final originalUnit = widget.store.unit;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove ${exercise.name}?'),
        content: Text(
          sets.isEmpty
              ? 'This removes the exercise and its unfinished entries from this workout.'
              : 'This also removes its ${sets.length} saved sets from this workout and progress. You can undo after removing.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep exercise'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove exercise'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    await _run(() async {
      await widget.store.removeOpenWorkoutExercise(
        sessionId: draft.sessionId,
        exerciseIndex: draft.selectedIndex,
      );
      messenger.showSnackBar(
        SnackBar(
          content: Text('${exercise.name} removed'),
          duration: const Duration(seconds: 8),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () async {
              try {
                await widget.store.restoreOpenWorkoutExercise(
                  sessionId: draft.sessionId,
                  exercise: exercise,
                  inputs: inputs,
                  sets: sets,
                  originalUnit: originalUnit,
                );
              } on Object {
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Could not restore this exercise. The workout may have changed.',
                    ),
                  ),
                );
              }
            },
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.store,
    builder: (context, _) {
      final draft = widget.store.openWorkoutDraft;
      if (draft == null || draft.sessionId != widget.sessionId) {
        return Scaffold(
          appBar: AppBar(title: const Text('Open Workout')),
          body: const Center(child: Text('Workout saved.')),
        );
      }
      final count = widget.store.logs
          .where((value) => value.sessionId == draft.sessionId)
          .length;
      final entryKey = _entryKeys.putIfAbsent(
        '${draft.sessionId}:${draft.selectedIndex}:${widget.store.unit}',
        () => GlobalKey<_OpenSetEntryState>(),
      );
      return Scaffold(
        appBar: AppBar(
          title: const Text('Open Workout'),
          actions: [
            TextButton(
              key: const ValueKey('open-discard-workout'),
              onPressed: _busy ? null : _discard,
              child: const Text('Discard'),
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              if (draft.exercises.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      key: const ValueKey('open-add-exercise'),
                      onPressed: _busy ? null : _addExercise,
                      icon: const Icon(Icons.add),
                      label: const Text('Choose exercise'),
                    ),
                  ),
                ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  children: [
                    WorkoutSaveProgress(
                      countLabel:
                          '$count sets saved · ${draft.exercises.length} exercises',
                      saving: _busy || _pendingInputWrites > 0,
                      failed: _error != null,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Choose an exercise, enter your result, then tap Log set.',
                    ),
                    const SizedBox(height: 16),
                    if (draft.exercises.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final entry in draft.exercises.asMap().entries)
                            ChoiceChip(
                              label: Text(entry.value.name),
                              selected: draft.selectedIndex == entry.key,
                              onSelected: _busy
                                  ? null
                                  : (_) => _run(
                                      () => widget.store
                                          .selectOpenWorkoutExercise(
                                            sessionId: draft.sessionId,
                                            exerciseIndex: entry.key,
                                          ),
                                    ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      TextButton.icon(
                        key: const ValueKey('open-remove-exercise'),
                        onPressed: _busy ? null : _removeExercise,
                        icon: const Icon(Icons.remove_circle_outline),
                        label: const Text('Remove selected exercise'),
                      ),
                      _OpenSetEntry(
                        key: entryKey,
                        store: widget.store,
                        draft: draft,
                        disabled: _busy,
                        onSavePending: (change) {
                          if (mounted)
                            setState(() => _pendingInputWrites += change);
                        },
                        onSaveError: () {
                          if (mounted) {
                            setState(
                              () => _error =
                                  'Your latest entry could not be saved. Keep this workout open and try logging the set again.',
                            );
                          }
                        },
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Saved sets',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      LoggedSetsEditor(
                        store: widget.store,
                        predicate: (log) =>
                            log.sessionId == draft.sessionId &&
                            log.exerciseIndex == draft.selectedIndex,
                        emptyMessage: 'Log your first set for this exercise.',
                      ),
                    ] else ...[
                      const SizedBox(height: 24),
                      const Text(
                        'Start with one exercise. You can add more whenever you like.',
                      ),
                    ],
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Text(
                          _error!,
                          style: const TextStyle(color: BrandColors.error),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: WorkoutActionBar(
          primaryKey: draft.selectedExercise == null
              ? const ValueKey('open-add-exercise')
              : const ValueKey('open-log-set'),
          primaryLabel: _busy
              ? 'Saving progress…'
              : draft.selectedExercise == null
              ? 'Choose exercise'
              : 'Log set',
          primaryIcon: draft.selectedExercise == null
              ? Icons.add_rounded
              : Icons.add_task_rounded,
          onPrimary: _busy
              ? null
              : draft.selectedExercise == null
              ? _addExercise
              : _log,
          finishKey: const ValueKey('open-finish-workout'),
          onFinish: _busy || count == 0 ? null : _finish,
          hint: count == 0
              ? 'Log at least one set to finish, or discard this workout.'
              : null,
        ),
      );
    },
  );
}

class _OpenSetEntry extends StatefulWidget {
  const _OpenSetEntry({
    super.key,
    required this.store,
    required this.draft,
    required this.disabled,
    required this.onSaveError,
    required this.onSavePending,
  });
  final AppStore store;
  final OpenWorkoutDraft draft;
  final bool disabled;
  final VoidCallback onSaveError;
  final ValueChanged<int> onSavePending;

  @override
  State<_OpenSetEntry> createState() => _OpenSetEntryState();
}

class _OpenSetEntryState extends State<_OpenSetEntry> {
  late final Map<String, TextEditingController> _fields = {
    for (final key in [
      'weight',
      'reps',
      'seconds',
      'meters',
      'calories',
      'notes',
    ])
      key: TextEditingController(text: widget.draft.inputs[key] ?? ''),
  };

  @override
  void dispose() {
    for (final field in _fields.values) {
      field.dispose();
    }
    super.dispose();
  }

  void _saveInputs() {
    final draft = widget.draft;
    final onSaveError = widget.onSaveError;
    final onSavePending = widget.onSavePending;
    onSavePending(1);
    widget.store
        .saveOpenWorkoutInputs(
          sessionId: draft.sessionId,
          exerciseIndex: draft.selectedIndex,
          setSequence: draft.nextSetSequence,
          inputs: {
            for (final entry in _fields.entries) entry.key: entry.value.text,
          },
        )
        .catchError((Object _) => onSaveError())
        .whenComplete(() => onSavePending(-1));
  }

  Widget _field(String key, String label, {String? hint}) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      key: ValueKey('open-$key'),
      controller: _fields[key],
      enabled: !widget.disabled,
      keyboardType: key == 'notes'
          ? TextInputType.text
          : TextInputType.numberWithOptions(
              decimal: key != 'reps' && key != 'seconds',
            ),
      decoration: InputDecoration(labelText: label, helperText: hint),
      onChanged: (_) => _saveInputs(),
    ),
  );

  Map<String, String> get inputs => {
    for (final field in _fields.entries) field.key: field.value.text,
  };

  @override
  Widget build(BuildContext context) {
    final exercise = widget.draft.selectedExercise!;
    final type = exercise.trackingType;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(exercise.name, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        if (type.usesWeight)
          _field(
            'weight',
            '${type == ExerciseTrackingType.weightedBodyweight
                ? 'Added weight'
                : type == ExerciseTrackingType.assistedBodyweight
                ? 'Assistance'
                : 'Weight'} (${widget.store.unit})',
            hint: type == ExerciseTrackingType.weightedBodyweight
                ? 'Leave blank for bodyweight only.'
                : null,
          ),
        if (type.usesReps) _field('reps', 'Reps'),
        if (type.usesDuration) _field('seconds', 'Time (seconds)'),
        if (type.usesDistance) _field('meters', 'Distance (meters)'),
        if (type.usesCalories) _field('calories', 'Calories (kcal)'),
        _field('notes', 'Notes (optional)'),
      ],
    );
  }
}

class _OpenExercisePicker extends StatefulWidget {
  const _OpenExercisePicker({required this.store});
  final AppStore store;
  @override
  State<_OpenExercisePicker> createState() => _OpenExercisePickerState();
}

class _OpenExercisePickerState extends State<_OpenExercisePicker> {
  String _query = '';
  String _filter = 'All';
  @override
  Widget build(BuildContext context) {
    final recentIds = widget.store.recentExercises
        .map((exercise) => exercise.id)
        .toSet();
    final results =
        ExerciseLibrary.search(
              custom: widget.store.customExercises,
              favoriteBuiltInIds: widget.store.favoriteBuiltInExerciseIds,
              query: _query,
            )
            .where(
              (exercise) =>
                  _filter == 'All' ||
                  (_filter == 'Favorites' && exercise.isFavorite) ||
                  (_filter == 'Recent' && recentIds.contains(exercise.id)),
            )
            .toList();
    if (_filter == 'All' && _query.trim().isEmpty) {
      results.sort((a, b) {
        final aRank = recentIds.contains(a.id)
            ? 0
            : a.isFavorite
            ? 1
            : 2;
        final bRank = recentIds.contains(b.id)
            ? 0
            : b.isFavorite
            ? 1
            : 2;
        return aRank == bRank
            ? a.name.compareTo(b.name)
            : aRank.compareTo(bRank);
      });
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Choose exercise')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                key: const ValueKey('open-exercise-search'),
                decoration: const InputDecoration(
                  labelText: 'Search exercises',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (value) => setState(() => _query = value),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 8,
                children: [
                  for (final filter in ['All', 'Recent', 'Favorites'])
                    ChoiceChip(
                      label: Text(filter),
                      selected: _filter == filter,
                      onSelected: (_) => setState(() => _filter = filter),
                    ),
                ],
              ),
            ),
            Expanded(
              child: results.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text(
                          _filter == 'Recent'
                              ? 'Exercises you log will appear here. Choose All to browse your library.'
                              : _filter == 'Favorites'
                              ? 'Mark favorites in the exercise library, or choose All to browse.'
                              : 'No matches. Try another exercise name or add a custom exercise in the exercise library.',
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: results.length,
                      itemBuilder: (context, index) {
                        final exercise = results[index];
                        return ListTile(
                          key: ValueKey('open-choose-${exercise.id}'),
                          title: Text(exercise.name),
                          subtitle: Text(
                            '${exercise.equipment.label} · ${exercise.trackingType.label}',
                          ),
                          trailing: const Icon(Icons.add),
                          onTap: () => Navigator.pop(context, exercise),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class OpenWorkoutHistoryScreen extends StatelessWidget {
  const OpenWorkoutHistoryScreen({
    super.key,
    required this.store,
    required this.record,
  });
  final AppStore store;
  final OpenWorkoutRecord record;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: store,
    builder: (context, _) {
      final exercises = {
        for (final log in store.logs.where(
          (log) => log.sessionId == record.sessionId,
        ))
          log.exerciseIndex: log.exercise,
      };
      return Scaffold(
        appBar: AppBar(title: const Text('Open Workout')),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                formatAppDate(record.startedAt),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(_summary(store, record.sessionId)),
              const SizedBox(height: 24),
              if (exercises.isEmpty)
                const Text('There are no saved sets in this workout.'),
              for (final exercise in exercises.entries) ...[
                Text(
                  exercise.value,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                LoggedSetsEditor(
                  store: store,
                  predicate: (log) =>
                      log.sessionId == record.sessionId &&
                      log.exerciseIndex == exercise.key,
                  emptyMessage: 'There are no saved sets for this exercise.',
                ),
                const SizedBox(height: 24),
              ],
            ],
          ),
        ),
      );
    },
  );
}

String _summary(AppStore store, String sessionId) {
  final sets = store.logs.where((log) => log.sessionId == sessionId).toList();
  final exerciseCount = sets.map((log) => log.exerciseIndex).toSet().length;
  return '$exerciseCount ${exerciseCount == 1 ? 'exercise' : 'exercises'} · ${sets.length} ${sets.length == 1 ? 'set' : 'sets'} saved';
}
