import 'package:flutter/material.dart';

import 'brand.dart';
import 'exercise_library.dart';
import 'logged_sets.dart';
import 'open_workout.dart';
import 'safe_layout.dart';
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
                    title: Text(
                      MaterialLocalizations.of(
                        context,
                      ).formatMediumDate(record.startedAt),
                    ),
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
      return Scaffold(
        appBar: AppBar(title: const Text('Open Workout')),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              Text(
                _summary(widget.store, draft.sessionId),
                style: const TextStyle(color: BrandColors.muted),
              ),
              const SizedBox(height: 8),
              const Text(
                'Sets save as you go. Come back anytime to keep training.',
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                key: const ValueKey('open-add-exercise'),
                onPressed: _busy ? null : _addExercise,
                icon: const Icon(Icons.add),
                label: const Text('Add exercise'),
              ),
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
                                () => widget.store.selectOpenWorkoutExercise(
                                  sessionId: draft.sessionId,
                                  exerciseIndex: entry.key,
                                ),
                              ),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                _OpenSetEntry(
                  key: ValueKey(
                    '${draft.sessionId}:${draft.selectedIndex}:${widget.store.unit}',
                  ),
                  store: widget.store,
                  draft: draft,
                  disabled: _busy,
                  onRun: _run,
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
        bottomNavigationBar: LabSafeBottomAction(
          child: FilledButton.icon(
            key: const ValueKey('open-finish-workout'),
            onPressed: _busy || count == 0 ? null : _finish,
            icon: const Icon(Icons.check_rounded),
            label: const Text('Finish workout'),
          ),
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
    required this.onRun,
    required this.onSaveError,
  });
  final AppStore store;
  final OpenWorkoutDraft draft;
  final bool disabled;
  final Future<void> Function(Future<void> Function()) onRun;
  final VoidCallback onSaveError;

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
    widget.store
        .saveOpenWorkoutInputs(
          sessionId: draft.sessionId,
          exerciseIndex: draft.selectedIndex,
          setSequence: draft.nextSetSequence,
          inputs: {
            for (final entry in _fields.entries) entry.key: entry.value.text,
          },
        )
        .catchError((Object _) {
          if (mounted) widget.onSaveError();
        });
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

  Future<void> _log() => widget.onRun(() async {
    final draft = widget.draft;
    final type = draft.selectedExercise!.trackingType;
    final weight = type.parseWeightInput(_fields['weight']!.text);
    if (type.usesWeight && weight == null) {
      throw ArgumentError('Enter a valid weight.');
    }
    await widget.store.logOpenWorkoutSet(
      sessionId: draft.sessionId,
      exerciseIndex: draft.selectedIndex,
      setSequence: draft.nextSetSequence,
      weight: weight,
      reps: int.tryParse(_fields['reps']!.text.trim()),
      seconds: int.tryParse(_fields['seconds']!.text.trim()),
      meters: double.tryParse(_fields['meters']!.text.trim()),
      calories: double.tryParse(_fields['calories']!.text.trim()),
      notes: _fields['notes']!.text,
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
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            key: const ValueKey('open-log-set'),
            onPressed: widget.disabled ? null : _log,
            icon: const Icon(Icons.add_task_rounded),
            label: const Text('Log set'),
          ),
        ),
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
  @override
  Widget build(BuildContext context) {
    final results = ExerciseLibrary.search(
      custom: widget.store.customExercises,
      favoriteBuiltInIds: widget.store.favoriteBuiltInExerciseIds,
      query: _query,
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Choose an exercise')),
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
            Expanded(
              child: results.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Text(
                          'No matches. Try another exercise name or add a custom exercise in the exercise library.',
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
                MaterialLocalizations.of(
                  context,
                ).formatFullDate(record.startedAt),
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
