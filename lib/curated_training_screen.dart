import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'brand.dart';
import 'curated_programs.dart';
import 'curated_training.dart';
import 'logged_sets.dart';
import 'workout_logging_controls.dart';
import 'display_format.dart';
import 'store.dart';
import 'source_links.dart';

/// Five-day training adaptations with their evidence visible before starting.
class CuratedProgramsScreen extends StatelessWidget {
  const CuratedProgramsScreen({super.key, required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Iconic Builds'),
      actions: [
        IconButton(
          tooltip: 'Iconic Builds history',
          icon: const Icon(Icons.history_rounded),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => CuratedHistoryScreen(store: store),
            ),
          ),
        ),
      ],
    ),
    body: BrandBackdrop(
      child: AnimatedBuilder(
        animation: store,
        builder: (context, _) => ListView(
          key: const PageStorageKey('curated-programs'),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            const _Intro(),
            const SizedBox(height: 24),
            const BrandSectionLabel('Find your inspiration'),
            const SizedBox(height: 14),
            for (final program in CuratedPrograms.all) ...[
              _ProgramCard(store: store, program: program),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    ),
  );
}

class _Intro extends StatelessWidget {
  const _Intro();

  @override
  Widget build(BuildContext context) => LabPanel(
    accent: BrandColors.cyan,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.bolt_rounded, color: BrandColors.cyan, size: 34),
        const SizedBox(height: 12),
        Text(
          'Your next build\nstarts here',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w900,
            height: 1.05,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Five-day workout plans inspired by screen icons and martial artists. '
          'Pick a plan, follow each session, and make it your own.',
          style: TextStyle(height: 1.5),
        ),
        const SizedBox(height: 12),
        const Text(
          'These plans adapt published training for the app. Results vary from person to person. '
          'Each plan includes its sources and the changes we made. '
          'Your progress here is separate from Year One Strength and Functional Training.',
          style: TextStyle(color: BrandColors.muted, height: 1.5),
        ),
        const SizedBox(height: 14),
        const Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _Badge('5 training days'),
            _Badge('2 recovery days'),
            _Badge('Track every set'),
          ],
        ),
      ],
    ),
  );
}

class _ProgramCard extends StatelessWidget {
  const _ProgramCard({required this.store, required this.program});

  final AppStore store;
  final CuratedProgram program;

  @override
  Widget build(BuildContext context) {
    final progress = store.curatedProgressFor(program.id);
    final draft = store.curatedDraftFor(program.id);
    return LabPanel(
      key: ValueKey('curated-program-${program.id}'),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => CuratedProgramScreen(store: store, program: program),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      program.actor,
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      program.role,
                      style: const TextStyle(color: BrandColors.cyan),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_rounded,
                color: BrandColors.violet,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            program.title,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            program.focus,
            style: const TextStyle(color: BrandColors.muted, height: 1.4),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              const _Badge('5 days / week'),
              if (draft != null)
                _Badge(
                  'Resume · Day ${draft.dayIndex + 1}',
                  accent: BrandColors.cyan,
                )
              else if (progress.completedSessions > 0)
                _Badge('Week ${progress.week} · Day ${progress.dayIndex + 1}'),
            ],
          ),
        ],
      ),
    );
  }
}

class CuratedProgramScreen extends StatefulWidget {
  const CuratedProgramScreen({
    super.key,
    required this.store,
    required this.program,
  });

  final AppStore store;
  final CuratedProgram program;

  @override
  State<CuratedProgramScreen> createState() => _CuratedProgramScreenState();
}

class _CuratedProgramScreenState extends State<CuratedProgramScreen> {
  bool _starting = false;
  String? _error;

  Future<void> _start() async {
    if (_starting) return;
    setState(() {
      _starting = true;
      _error = null;
    });
    try {
      await widget.store.beginCuratedWorkout(widget.program.id);
      if (!mounted) return;
      await Navigator.push<void>(
        context,
        MaterialPageRoute<void>(
          builder: (_) => CuratedSessionScreen(
            store: widget.store,
            programId: widget.program.id,
          ),
        ),
      );
    } on Object {
      if (mounted) {
        setState(() => _error = 'Couldn’t open this workout. Try again.');
      }
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.store,
    builder: (context, _) {
      final program = widget.program;
      final progress = widget.store.curatedProgressFor(program.id);
      final draft = widget.store.curatedDraftFor(program.id);
      final loggedCount = draft == null
          ? 0
          : widget.store.logs
                .where((log) => log.sessionId == draft.sessionId)
                .length;
      final dayIndex = draft?.dayIndex ?? progress.dayIndex;
      return Scaffold(
        appBar: AppBar(title: Text(program.actor)),
        bottomNavigationBar: SafeArea(
          minimum: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: GradientAction(
            key: const ValueKey('curated-start'),
            label: _starting
                ? 'Opening workout…'
                : draft != null
                ? 'Resume day ${dayIndex + 1}'
                : 'Start day ${dayIndex + 1}',
            icon: Icons.play_arrow_rounded,
            onPressed: _starting ? null : _start,
          ),
        ),
        body: BrandBackdrop(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: [
              Text(
                program.role,
                style: const TextStyle(
                  color: BrandColors.cyan,
                  letterSpacing: 1.4,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                program.title,
                style: const TextStyle(
                  fontSize: 29,
                  height: 1.1,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                program.focus,
                style: const TextStyle(color: BrandColors.muted, height: 1.5),
              ),
              const SizedBox(height: 18),
              LabPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const BrandSectionLabel('Your next workout'),
                    const SizedBox(height: 12),
                    Text(
                      'Week ${draft?.week ?? progress.week} · Day ${dayIndex + 1}',
                      style: const TextStyle(color: BrandColors.cyan),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      program.days[dayIndex].title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (draft != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        '$loggedCount of ${draft.steps.length} sets saved. Pick up where you left off.',
                        style: const TextStyle(color: BrandColors.muted),
                      ),
                    ],
                    const SizedBox(height: 10),
                    const Text(
                      'Follow these five workouts each week and fit in two recovery days where they work for you. Save a session to move to the next day.',
                      style: TextStyle(color: BrandColors.muted, height: 1.4),
                    ),
                  ],
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
              const SizedBox(height: 24),
              const BrandSectionLabel('Your five-day plan'),
              const SizedBox(height: 12),
              for (final entry in program.days.asMap().entries)
                _DayOutline(
                  day: entry.value,
                  index: entry.key,
                  isNext: entry.key == dayIndex,
                ),
              const SizedBox(height: 18),
              LabPanel(
                accent: BrandColors.cyan,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const BrandSectionLabel('Behind the plan'),
                    const SizedBox(height: 12),
                    Text(program.evidence, style: const TextStyle(height: 1.5)),
                    const SizedBox(height: 10),
                    Text(
                      program.notes,
                      style: const TextStyle(
                        color: BrandColors.muted,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Sources',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        letterSpacing: 1,
                      ),
                    ),
                    for (final source in program.sources) ...[
                      const SizedBox(height: 12),
                      Text(
                        source.title,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      if (source.url.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        TextButton.icon(
                          onPressed: () async {
                            final messenger = ScaffoldMessenger.of(context);
                            if (!await openSourceUrl(source.url)) {
                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Could not open this source. Try again.',
                                  ),
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.open_in_new, size: 16),
                          label: const Text('Read source'),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => CuratedHistoryScreen(
                      store: widget.store,
                      programId: program.id,
                    ),
                  ),
                ),
                icon: const Icon(Icons.history_rounded),
                label: const Text('View workout history'),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _DayOutline extends StatelessWidget {
  const _DayOutline({
    required this.day,
    required this.index,
    required this.isNext,
  });

  final CuratedDay day;
  final int index;
  final bool isNext;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    clipBehavior: Clip.antiAlias,
    child: ExpansionTile(
      key: ValueKey('curated-day-$index'),
      initiallyExpanded: isNext,
      tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      leading: CircleAvatar(
        backgroundColor: BrandColors.purple.withValues(alpha: .2),
        child: Text(
          '${index + 1}',
          style: const TextStyle(
            color: BrandColors.violet,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      title: Text(
        day.title,
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      subtitle: Text(
        '${day.movements.length} movements · ${day.movements.fold<int>(0, (count, movement) => count + movement.targets.length)} sets',
      ),
      children: [
        if (day.notes.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              day.notes,
              style: const TextStyle(color: BrandColors.muted, height: 1.4),
            ),
          ),
        for (final movement in day.movements)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    movement.name,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _movementTargets(movement),
                    style: const TextStyle(color: BrandColors.cyan),
                  ),
                  if (movement.group != null)
                    Text(
                      'Alternate with: ${day.movements.where((other) => other != movement && other.group == movement.group).map((other) => other.name).join(', ')}',
                      style: const TextStyle(
                        color: BrandColors.muted,
                        fontSize: 12,
                      ),
                    ),
                  const SizedBox(height: 3),
                  Text(
                    movement.instructions,
                    style: const TextStyle(
                      color: BrandColors.muted,
                      height: 1.4,
                    ),
                  ),
                  if (movement.restSeconds > 0)
                    Text(
                      'Rest ${_duration(movement.restSeconds)}',
                      style: const TextStyle(
                        color: BrandColors.muted,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    ),
  );
}

/// The active session saves each actual set before moving to the next target.
class CuratedSessionScreen extends StatefulWidget {
  const CuratedSessionScreen({
    super.key,
    required this.store,
    required this.programId,
  });

  final AppStore store;
  final String programId;

  @override
  State<CuratedSessionScreen> createState() => _CuratedSessionScreenState();
}

class _CuratedSessionScreenState extends State<CuratedSessionScreen>
    with WidgetsBindingObserver {
  final _weight = TextEditingController();
  final _reps = TextEditingController();
  final _seconds = TextEditingController();
  final _meters = TextEditingController();
  final _notes = TextEditingController();
  final _form = GlobalKey<FormState>();
  Future<void> _writes = Future<void>.value();
  Timer? _timer;
  bool _busy = false;
  bool _loading = true;
  bool _canPop = false;
  int _inputWrites = 0;
  String? _error;
  DateTime? _dismissedRest;
  String? _displayedStep;

  CuratedWorkoutDraft? get _draft =>
      widget.store.curatedDraftFor(widget.programId);
  CuratedProgram get _program => CuratedPrograms.byId(widget.programId)!;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.store.addListener(_storeChanged);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _restSeconds > 0) {
        setState(() {});
      }
      // Rebuild once at expiry too so the rest panel disappears automatically.
      else if (mounted &&
          _draft?.restEndsAt != null &&
          _dismissedRest != _draft!.restEndsAt) {
        setState(() => _dismissedRest = _draft!.restEndsAt);
      }
    });
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final draft =
          _draft ?? await widget.store.beginCuratedWorkout(widget.programId);
      if (!mounted) return;
      _restoreInputs(draft);
      setState(() => _loading = false);
    } on Object {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Couldn’t load this workout. Go back and try again.';
        });
      }
    }
  }

  void _restoreInputs(CuratedWorkoutDraft draft) {
    _displayedStep =
        '${draft.sessionId}:${draft.nextStepIndex}:${widget.store.unit}';
    _weight.text = draft.inputs['weight'] ?? '';
    _reps.text = draft.inputs['reps'] ?? '';
    _seconds.text = draft.inputs['seconds'] ?? '';
    _meters.text = draft.inputs['meters'] ?? '';
    _notes.text = draft.inputs['notes'] ?? '';
  }

  void _storeChanged() {
    final draft = _draft;
    if (!mounted || _loading || draft == null) return;
    if (_displayedStep !=
        '${draft.sessionId}:${draft.nextStepIndex}:${widget.store.unit}') {
      _form.currentState?.reset();
      _restoreInputs(draft);
      setState(() {});
    }
  }

  Map<String, String> get _inputs => {
    'weight': _weight.text,
    'reps': _reps.text,
    'seconds': _seconds.text,
    'meters': _meters.text,
    'notes': _notes.text,
  };

  Future<void> _saveInputs() {
    final draft = _draft;
    if (draft == null || draft.nextStepIndex >= draft.steps.length) {
      return Future<void>.value();
    }
    final inputs = _inputs;
    final stepIndex = draft.nextStepIndex;
    final sessionId = draft.sessionId;
    if (mounted) setState(() => _inputWrites++);
    final next = _writes.then(
      (_) => widget.store.saveCuratedInputs(
        programId: widget.programId,
        sessionId: sessionId,
        stepIndex: stepIndex,
        inputs: inputs,
      ),
    );
    _writes = next.then<void>(
      (_) {
        if (mounted) setState(() => _inputWrites--);
      },
      onError: (Object error, StackTrace stack) {
        if (mounted) {
          setState(() {
            _inputWrites--;
            _error =
                'Couldn’t save your entries. Tap Retry save before leaving.';
          });
        }
      },
    );
    return next;
  }

  void _changed(String _) {
    unawaited(_saveInputs().catchError((Object _) {}));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive && !_busy) _changed('');
    if (state == AppLifecycleState.resumed && mounted) setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.store.removeListener(_storeChanged);
    _timer?.cancel();
    for (final controller in [_weight, _reps, _seconds, _meters, _notes]) {
      controller.dispose();
    }
    super.dispose();
  }

  int get _restSeconds {
    final end = _draft?.restEndsAt;
    if (end == null || end == _dismissedRest) return 0;
    final remaining = end.difference(DateTime.now()).inMilliseconds;
    return remaining <= 0 ? 0 : (remaining / 1000).ceil();
  }

  Future<void> _leave() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _saveInputs();
      await _writes;
      if (!mounted) return;
      setState(() => _canPop = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context);
      });
    } on Object {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _log() async {
    if (_busy) return;
    final draft = _draft!;
    final step = draft.steps[draft.nextStepIndex];
    final form = _form.currentState;
    if (form != null && !form.validate()) return;
    if (form == null) {
      final metric = step.movement.metric;
      final invalid =
          (_usesWeight(metric) &&
              _validateNumber(_weight.text, whole: false) != null) ||
          (_usesReps(metric) &&
              _validateNumber(_reps.text, whole: true) != null) ||
          (metric == CuratedMetric.duration &&
              _validateNumber(_seconds.text, whole: true) != null) ||
          (_usesDistance(metric) &&
              _validateNumber(_meters.text, whole: false) != null);
      if (invalid) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Enter your actual result above zero before logging this set.',
            ),
          ),
        );
        return;
      }
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _saveInputs();
      await _writes;
      await widget.store.logCuratedSet(
        programId: widget.programId,
        sessionId: draft.sessionId,
        stepIndex: draft.nextStepIndex,
        weight: _usesWeight(step.movement.metric)
            ? double.parse(_weight.text.trim())
            : null,
        reps: _usesReps(step.movement.metric)
            ? int.parse(_reps.text.trim())
            : null,
        seconds: step.movement.metric == CuratedMetric.duration
            ? int.parse(_seconds.text.trim())
            : null,
        meters: _usesDistance(step.movement.metric)
            ? double.parse(_meters.text.trim())
            : null,
        notes: _notes.text.trim(),
      );
      if (!mounted) return;
      FocusScope.of(context).unfocus();
      _form.currentState?.reset();
      _restoreInputs(_draft!);
      HapticFeedback.lightImpact();
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
    } on Object {
      if (mounted) {
        setState(
          () => _error =
              'Couldn’t save this set. Your entries are still here—try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _finish() async {
    if (_busy) return;
    final draft = _draft!;
    final loggedCount = widget.store.logs
        .where((log) => log.sessionId == draft.sessionId)
        .length;
    final isPartial =
        draft.nextStepIndex < draft.steps.length ||
        loggedCount != draft.steps.length;
    if (loggedCount == 0) return;
    if (isPartial) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Wrap up this workout?'),
          content: Text(
            'You’ve logged $loggedCount of ${draft.steps.length} sets. Save this as a partial workout and move to the next training day?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep training'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save partial'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _writes;
      await widget.store.finishCuratedWorkout(
        programId: widget.programId,
        sessionId: draft.sessionId,
        allowPartial: isPartial,
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          icon: Icon(
            isPartial ? Icons.save_outlined : Icons.check_circle_rounded,
            color: BrandColors.cyan,
            size: 40,
          ),
          title: Text(isPartial ? 'Partial workout saved' : 'Workout complete'),
          content: Text(
            '${_program.actor} · Week ${draft.week}, Day ${draft.dayIndex + 1}\n\n$loggedCount sets saved. Your next training day is ready.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      setState(() => _canPop = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context);
      });
    } on Object {
      if (mounted) {
        setState(() {
          _busy = false;
          _error =
              'Couldn’t finish saving this workout. Your logged sets are safe. Try again.';
        });
      }
    }
  }

  bool _isLogged(CuratedWorkoutDraft draft, int index) => widget.store.logs.any(
    (log) =>
        log.sessionId == draft.sessionId &&
        log.sourceId == '${draft.sessionId}:step:$index',
  );

  Future<void> _selectStep(int index) async {
    if (_busy) return;
    final draft = _draft!;
    setState(() => _busy = true);
    try {
      await _saveInputs();
      await _writes;
      await widget.store.selectCuratedStep(
        programId: widget.programId,
        sessionId: draft.sessionId,
        stepIndex: index,
      );
    } on Object {
      if (mounted) {
        setState(
          () => _error =
              'Could not change exercise. Your entries are still here. Try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _chooseExercise() async {
    final draft = _draft!;
    final index = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose your next exercise'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final entry in draft.day.movements.asMap().entries)
                Builder(
                  builder: (context) {
                    final remaining = [
                      for (var i = 0; i < draft.steps.length; i++)
                        if (draft.steps[i].movementIndex == entry.key &&
                            !_isLogged(draft, i))
                          i,
                    ];
                    return ListTile(
                      title: Text(entry.value.name),
                      subtitle: Text(
                        remaining.isEmpty
                            ? 'All sets saved'
                            : '${remaining.length} sets remaining',
                      ),
                      enabled: remaining.isNotEmpty,
                      onTap: remaining.isEmpty
                          ? null
                          : () => Navigator.pop(context, remaining.first),
                    );
                  },
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Keep current exercise'),
          ),
        ],
      ),
    );
    if (index != null && mounted) await _selectStep(index);
  }

  Future<void> _doLater() async {
    final draft = _draft!;
    final current = draft.steps[draft.nextStepIndex].movementIndex;
    final candidates =
        [
          for (var offset = 1; offset < draft.steps.length; offset++)
            (draft.nextStepIndex + offset) % draft.steps.length,
        ].where(
          (index) =>
              draft.steps[index].movementIndex != current &&
              !_isLogged(draft, index),
        );
    if (candidates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This is the last remaining exercise. You can save a partial workout or discard it.',
          ),
        ),
      );
      return;
    }
    await _selectStep(candidates.first);
  }

  Future<void> _discard({bool skip = false}) async {
    if (_busy) return;
    final draft = _draft!;
    final count = widget.store.logs
        .where((log) => log.sessionId == draft.sessionId)
        .length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(skip ? 'Skip this training day?' : 'Discard this workout?'),
        content: Text(
          skip
              ? 'This records the day as skipped and moves to the next day. It will not count as a completed workout.'
              : count == 0
              ? 'This removes the unfinished workout. You can restart the same training day later.'
              : 'This removes the unfinished workout and its $count saved sets. You can restart the same training day later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep training'),
          ),
          FilledButton(
            key: ValueKey(
              skip ? 'curated-skip-confirm' : 'curated-discard-confirm',
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(skip ? 'Skip day' : 'Discard workout'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await _writes;
      if (skip) {
        await widget.store.skipCuratedWorkout(
          programId: widget.programId,
          sessionId: draft.sessionId,
        );
      } else {
        await widget.store.discardCuratedWorkout(
          programId: widget.programId,
          sessionId: draft.sessionId,
        );
      }
      if (!mounted) return;
      setState(() => _canPop = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context);
      });
    } on Object {
      if (mounted) {
        setState(() {
          _busy = false;
          _error =
              'Could not save that change. Your workout is still here. Try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope<void>(
    canPop: _canPop,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) unawaited(_leave());
    },
    child: Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: _busy ? null : _leave),
        title: Text(_program.actor),
        actions: [
          TextButton(
            key: const ValueKey('curated-discard-workout'),
            onPressed: _busy || _draft == null ? null : () => _discard(),
            child: const Text('Discard'),
          ),
        ],
      ),
      bottomNavigationBar: AnimatedBuilder(
        animation: widget.store,
        builder: (context, _) {
          final draft = _draft;
          if (_loading || draft == null) return const SizedBox.shrink();
          final complete = draft.nextStepIndex >= draft.steps.length;
          final count = widget.store.logs
              .where((log) => log.sessionId == draft.sessionId)
              .length;
          return WorkoutActionBar(
            primaryKey: ValueKey(
              complete ? 'curated-finish' : 'curated-log-set',
            ),
            primaryLabel: _busy
                ? complete
                      ? 'Saving workout…'
                      : 'Saving set…'
                : complete
                ? 'Finish workout'
                : 'Log set',
            primaryIcon: complete
                ? Icons.check_circle_rounded
                : Icons.add_task_rounded,
            onPrimary: _busy || (complete && count == 0)
                ? null
                : complete
                ? _finish
                : _log,
            finishKey: complete
                ? null
                : const ValueKey('curated-finish-partial'),
            onFinish: complete || _busy || count == 0 ? null : _finish,
          );
        },
      ),
      body: BrandBackdrop(
        child: AnimatedBuilder(
          animation: widget.store,
          builder: (context, _) {
            final draft = _draft;
            if (_loading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (draft == null) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(_error ?? 'Workout saved.'),
                ),
              );
            }
            final complete = draft.nextStepIndex >= draft.steps.length;
            final loggedCount = widget.store.logs
                .where((log) => log.sessionId == draft.sessionId)
                .length;
            final step = complete ? null : draft.steps[draft.nextStepIndex];
            final day = draft.day;
            return ListView(
              key: const ValueKey('curated-session-scroll'),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                Text(
                  'Week ${draft.week} · Day ${draft.dayIndex + 1}',
                  style: const TextStyle(
                    color: BrandColors.cyan,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  day.title,
                  style: const TextStyle(
                    fontSize: 27,
                    height: 1.1,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 16),
                WorkoutSaveProgress(
                  countLabel:
                      '$loggedCount of ${draft.steps.length} sets saved',
                  countKey: const ValueKey('curated-saved-count'),
                  progress: draft.steps.isEmpty
                      ? 0
                      : loggedCount / draft.steps.length,
                  saving: _inputWrites > 0 || _busy,
                  failed: _error != null,
                ),
                const SizedBox(height: 18),
                if (!complete) ...[
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        key: const ValueKey('curated-choose-exercise'),
                        onPressed: _busy ? null : _chooseExercise,
                        icon: const Icon(Icons.swap_horiz),
                        label: const Text('Choose exercise'),
                      ),
                      TextButton(
                        key: const ValueKey('curated-do-later'),
                        onPressed: _busy ? null : _doLater,
                        child: const Text('Do this later'),
                      ),
                      if (loggedCount == 0)
                        TextButton(
                          key: const ValueKey('curated-skip-workout'),
                          onPressed: _busy ? null : () => _discard(skip: true),
                          child: const Text('Skip this day'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
                if (_restSeconds > 0) ...[
                  LabPanel(
                    key: const ValueKey('curated-rest'),
                    accent: BrandColors.cyan,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.timer_outlined,
                          color: BrandColors.cyan,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Rest · ${_duration(_restSeconds)}',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () =>
                              setState(() => _dismissedRest = draft.restEndsAt),
                          child: const Text('Skip rest'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                if (step != null) _setForm(step, draft),
                if (complete)
                  LabPanel(
                    accent: BrandColors.cyan,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.check_circle_outline,
                          color: BrandColors.cyan,
                          size: 36,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          loggedCount == draft.steps.length
                              ? 'All sets logged'
                              : 'Some logged sets were removed',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          loggedCount == draft.steps.length
                              ? 'Finish this workout to save it and move to your next day.'
                              : loggedCount > 0
                              ? 'Save the sets you’ve logged as a partial workout to move to your next day.'
                              : 'Log at least one set before saving this workout.',
                          style: const TextStyle(
                            color: BrandColors.muted,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    key: const ValueKey('curated-error'),
                    style: const TextStyle(color: BrandColors.error),
                  ),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () async {
                            try {
                              await _saveInputs();
                              if (mounted) setState(() => _error = null);
                            } on Object {
                              /* The inline error stays visible. */
                            }
                          },
                    child: const Text('Retry save'),
                  ),
                ],
                const SizedBox(height: 16),
                if (loggedCount > 0) ...[
                  const SizedBox(height: 20),
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: const Text('Your logged sets'),
                    children: [
                      LoggedSetsEditor(
                        store: widget.store,
                        predicate: (log) => log.sessionId == draft.sessionId,
                        emptyMessage: 'No sets logged.',
                        compact: true,
                      ),
                    ],
                  ),
                ],
              ],
            );
          },
        ),
      ),
    ),
  );

  Widget _setForm(CuratedStep step, CuratedWorkoutDraft draft) {
    final metric = step.movement.metric;
    return LabPanel(
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _Badge(
                  'Set ${step.targetIndex + 1} of ${step.movement.targets.length}',
                ),
                if (step.movement.group != null)
                  _Badge(
                    'Alternate exercises · Round ${step.targetIndex + 1}',
                    accent: BrandColors.cyan,
                  ),
                if (metric == CuratedMetric.reps)
                  const _Badge(
                    'Bodyweight · reps only',
                    accent: BrandColors.cyan,
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              step.movement.name,
              key: const ValueKey('curated-current-movement'),
              style: const TextStyle(
                fontSize: 25,
                height: 1.15,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Target · ${_targetText(step.target)}',
              style: const TextStyle(
                color: BrandColors.cyan,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              step.movement.instructions,
              style: const TextStyle(color: BrandColors.muted, height: 1.5),
            ),
            const SizedBox(height: 20),
            const Text(
              'Log your set',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 10),
            if (_usesWeight(metric)) ...[
              _numberField(
                'weight',
                _weight,
                'Weight (${widget.store.unit})',
                whole: false,
              ),
              const SizedBox(height: 12),
            ],
            if (_usesReps(metric))
              _numberField('reps', _reps, 'Reps', whole: true),
            if (metric == CuratedMetric.duration)
              _numberField('seconds', _seconds, 'Time (seconds)', whole: true),
            if (_usesDistance(metric))
              _numberField(
                'meters',
                _meters,
                'Distance (meters)',
                whole: false,
              ),
            const SizedBox(height: 12),
            TextFormField(
              key: const ValueKey('curated-notes'),
              controller: _notes,
              enabled: !_busy,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Notes (optional)'),
              onChanged: _changed,
            ),
            const SizedBox(height: 18),
          ],
        ),
      ),
    );
  }

  String? _validateNumber(String value, {required bool whole}) {
    final parsed = whole
        ? int.tryParse(value.trim())
        : double.tryParse(value.trim());
    if (parsed == null || !parsed.isFinite || parsed <= 0) {
      return whole
          ? 'Enter a whole number above zero.'
          : 'Enter a number above zero.';
    }
    return null;
  }

  Widget _numberField(
    String key,
    TextEditingController controller,
    String label, {
    required bool whole,
  }) => TextFormField(
    key: ValueKey('curated-$key'),
    controller: controller,
    enabled: !_busy,
    keyboardType: TextInputType.numberWithOptions(decimal: !whole),
    inputFormatters: [
      FilteringTextInputFormatter.allow(
        whole ? RegExp(r'[0-9]') : RegExp(r'[0-9.]'),
      ),
    ],
    decoration: InputDecoration(labelText: label),
    onChanged: _changed,
    validator: (value) => _validateNumber(value ?? '', whole: whole),
  );
}

class CuratedHistoryScreen extends StatelessWidget {
  const CuratedHistoryScreen({super.key, required this.store, this.programId});

  final AppStore store;
  final String? programId;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Iconic Builds history')),
    body: BrandBackdrop(
      child: AnimatedBuilder(
        animation: store,
        builder: (context, _) {
          final history =
              store.curatedHistory
                  .where(
                    (record) =>
                        programId == null || record.programId == programId,
                  )
                  .toList()
                ..sort((a, b) => b.completedAt.compareTo(a.completedAt));
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              const BrandSectionLabel('Your workouts'),
              const SizedBox(height: 14),
              if (history.isEmpty)
                const LabPanel(
                  child: Text(
                    'Your Iconic Builds workouts will appear here. Pick a plan to start your first session.',
                  ),
                ),
              for (final record in history) ...[
                LabPanel(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => CuratedSessionHistoryScreen(
                        store: store,
                        record: record,
                      ),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        CuratedPrograms.byId(record.programId)?.actor ??
                            record.programId,
                        style: const TextStyle(color: BrandColors.cyan),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        record.title,
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${_date(record.completedAt)} · Week ${record.week}, Day ${record.dayIndex + 1}',
                        style: const TextStyle(color: BrandColors.muted),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${record.setCount}/${record.totalSteps} sets · ${record.status == 'completed'
                            ? 'Completed'
                            : record.status == 'skipped'
                            ? 'Skipped'
                            : 'Partial'}',
                        style: const TextStyle(color: BrandColors.muted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ],
          );
        },
      ),
    ),
  );
}

class CuratedSessionHistoryScreen extends StatelessWidget {
  const CuratedSessionHistoryScreen({
    super.key,
    required this.store,
    required this.record,
  });
  final AppStore store;
  final CuratedSessionRecord record;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(record.title)),
    body: BrandBackdrop(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          Text(
            'Week ${record.week} · Day ${record.dayIndex + 1} · ${_date(record.completedAt)}',
            style: const TextStyle(color: BrandColors.cyan),
          ),
          const SizedBox(height: 10),
          const Text(
            'Logged sets',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 16),
          LoggedSetsEditor(
            store: store,
            predicate: (log) => log.sessionId == record.sessionId,
            emptyMessage: 'This workout has no logged sets.',
          ),
        ],
      ),
    ),
  );
}

class _Badge extends StatelessWidget {
  const _Badge(this.label, {this.accent = BrandColors.violet});
  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: accent.withValues(alpha: .1),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: accent.withValues(alpha: .2)),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: accent,
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

bool _usesWeight(CuratedMetric metric) =>
    metric == CuratedMetric.loadedReps ||
    metric == CuratedMetric.loadedDistance;
bool _usesReps(CuratedMetric metric) =>
    metric == CuratedMetric.reps || metric == CuratedMetric.loadedReps;
bool _usesDistance(CuratedMetric metric) =>
    metric == CuratedMetric.distance || metric == CuratedMetric.loadedDistance;

String _duration(int seconds) => seconds >= 60
    ? '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}'
    : '${seconds}s';
String _date(DateTime date) => formatAppDate(date);

String _targetText(CuratedSetTarget target) => [
  if (target.reps != null) '${target.reps} reps',
  if (target.seconds != null) '${target.seconds} seconds',
  if (target.meters != null)
    '${target.meters!.toStringAsFixed(target.meters! % 1 == 0 ? 0 : 1)} m',
  if (target.note.isNotEmpty) target.note,
].join(' · ');

String _movementTargets(CuratedMovement movement) {
  final targets = movement.targets.map(_targetText).toList();
  if (targets.toSet().length == 1) {
    return '${targets.length} × ${targets.first}';
  }
  return targets
      .asMap()
      .entries
      .map((entry) => '${entry.key + 1}: ${entry.value}')
      .join(' / ');
}
