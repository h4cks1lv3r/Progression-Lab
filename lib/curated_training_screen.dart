import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'brand.dart';
import 'curated_programs.dart';
import 'curated_training.dart';
import 'logged_sets.dart';
import 'store.dart';

/// Five-day training adaptations with their evidence visible before starting.
class CuratedProgramsScreen extends StatelessWidget {
  const CuratedProgramsScreen({super.key, required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Actor-inspired programs'),
      actions: [
        IconButton(
          tooltip: 'Actor-inspired workout history',
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
            const BrandSectionLabel('Choose your inspiration'),
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
          'TRAIN WITH\nA NEW PURPOSE',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w900,
            height: 1.05,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Explore five-day plans inspired by screen heroes and martial artists. '
          'Follow each session, log your actual work, and build your own progress.',
          style: TextStyle(height: 1.5),
        ),
        const SizedBox(height: 12),
        const Text(
          'These are training adaptations, not promises of an actor’s physique. '
          'Source strength and changes are shown with each plan. '
          'Your Strength and Athletic program positions stay separate.',
          style: TextStyle(color: BrandColors.muted, height: 1.5),
        ),
        const SizedBox(height: 14),
        const Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _Badge('5 training days'),
            _Badge('2 recovery days'),
            _Badge('Actual set logging'),
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
        setState(
          () => _error = 'The workout could not be opened. Please try again.',
        );
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
                ? 'OPENING WORKOUT…'
                : draft != null
                ? 'RESUME DAY ${dayIndex + 1}'
                : 'START DAY ${dayIndex + 1}',
            icon: Icons.play_arrow_rounded,
            onPressed: _starting ? null : _start,
          ),
        ),
        body: BrandBackdrop(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: [
              Text(
                program.role.toUpperCase(),
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
                        '$loggedCount of ${draft.steps.length} sets saved. Resume where you stopped.',
                        style: const TextStyle(color: BrandColors.muted),
                      ),
                    ],
                    const SizedBox(height: 10),
                    const Text(
                      'Repeat the five sessions each week. Place two recovery days where you need them; days do not advance until you save a session.',
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
              const BrandSectionLabel('Five-day outline'),
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
                    const BrandSectionLabel('Evidence & adaptations'),
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
                      'SOURCE REFERENCES',
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
                        SelectableText(
                          source.url,
                          style: const TextStyle(
                            color: BrandColors.cyan,
                            fontSize: 12,
                          ),
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
                label: const Text('VIEW WORKOUT HISTORY'),
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
                      'Alternating group: ${movement.group}',
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
          _error = 'This workout could not be loaded. Go back and try again.';
        });
      }
    }
  }

  void _restoreInputs(CuratedWorkoutDraft draft) {
    _displayedStep = '${draft.sessionId}:${draft.nextStepIndex}';
    _weight.text = draft.inputs['weight'] ?? '';
    _reps.text = draft.inputs['reps'] ?? '';
    _seconds.text = draft.inputs['seconds'] ?? '';
    _meters.text = draft.inputs['meters'] ?? '';
    _notes.text = draft.inputs['notes'] ?? '';
  }

  void _storeChanged() {
    final draft = _draft;
    if (!mounted || _loading || draft == null) return;
    if (_displayedStep != '${draft.sessionId}:${draft.nextStepIndex}') {
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
            _error = 'Input could not be saved. Tap Retry before leaving.';
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
    if (_busy || !(_form.currentState?.validate() ?? false)) return;
    final draft = _draft!;
    final step = draft.steps[draft.nextStepIndex];
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
    } on Object {
      if (mounted) {
        setState(
          () => _error =
              'The set was not saved. Your entries are still here. Please retry.',
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
          title: const Text('Finish a partial workout?'),
          content: Text(
            '$loggedCount of ${draft.steps.length} sets are logged. Save these sets as a partial session and move to the next training day?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('KEEP TRAINING'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('SAVE PARTIAL'),
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
            '${_program.actor} · Week ${draft.week}, Day ${draft.dayIndex + 1}\n\n$loggedCount actual sets saved. Your next training day is ready.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('DONE'),
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
              'The session could not be saved. Your logged sets are kept. Please retry.';
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
                  'WEEK ${draft.week} · DAY ${draft.dayIndex + 1}',
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
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: draft.steps.isEmpty
                        ? 0
                        : loggedCount / draft.steps.length,
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$loggedCount of ${draft.steps.length} sets saved',
                  key: const ValueKey('curated-saved-count'),
                  style: const TextStyle(color: BrandColors.muted),
                ),
                const SizedBox(height: 4),
                Text(
                  _inputWrites > 0
                      ? 'Saving input…'
                      : _error != null
                      ? 'Save needs attention · Retry below'
                      : 'Progress saved · Leave and resume anytime',
                  style: const TextStyle(
                    color: BrandColors.muted,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 18),
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
                          child: const Text('SKIP'),
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
                              ? 'Finish the workout to save the session and unlock your next day.'
                              : loggedCount > 0
                              ? 'Save the remaining sets as a partial workout to move to your next day.'
                              : 'No recorded sets remain. This session cannot count as a completed workout.',
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
                    child: const Text('RETRY SAVE'),
                  ),
                ],
                const SizedBox(height: 16),
                if (complete)
                  GradientAction(
                    key: const ValueKey('curated-finish'),
                    label: _busy
                        ? 'SAVING…'
                        : loggedCount < draft.steps.length
                        ? 'SAVE PARTIAL WORKOUT'
                        : 'FINISH WORKOUT',
                    icon: Icons.check_rounded,
                    onPressed: _busy || loggedCount == 0 ? null : _finish,
                  )
                else if (loggedCount > 0)
                  OutlinedButton(
                    key: const ValueKey('curated-finish-partial'),
                    onPressed: _busy ? null : _finish,
                    child: const Text('FINISH AS PARTIAL'),
                  ),
                if (loggedCount > 0) ...[
                  const SizedBox(height: 20),
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: const Text('Review logged sets'),
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
                    'Round ${step.targetIndex + 1} · ${step.movement.group}',
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
              'TARGET · ${_targetText(step.target)}',
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
              'LOG WHAT YOU DID',
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
                'Actual weight (${widget.store.unit})',
                whole: false,
              ),
              const SizedBox(height: 12),
            ],
            if (_usesReps(metric))
              _numberField('reps', _reps, 'Actual reps', whole: true),
            if (metric == CuratedMetric.duration)
              _numberField(
                'seconds',
                _seconds,
                'Actual duration (seconds)',
                whole: true,
              ),
            if (_usesDistance(metric))
              _numberField(
                'meters',
                _meters,
                'Actual distance (meters)',
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
            GradientAction(
              key: const ValueKey('curated-log-set'),
              label: _busy ? 'SAVING SET…' : 'LOG SET',
              icon: Icons.add_task_rounded,
              onPressed: _busy ? null : _log,
            ),
          ],
        ),
      ),
    );
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
    validator: (value) {
      final parsed = whole
          ? int.tryParse(value?.trim() ?? '')
          : double.tryParse(value?.trim() ?? '');
      if (parsed == null || !parsed.isFinite || parsed <= 0) {
        return whole
            ? 'Enter a whole number greater than zero.'
            : 'Enter a number greater than zero.';
      }
      return null;
    },
  );
}

class CuratedHistoryScreen extends StatelessWidget {
  const CuratedHistoryScreen({super.key, required this.store, this.programId});

  final AppStore store;
  final String? programId;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Actor-inspired history')),
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
              const BrandSectionLabel('Your actual training'),
              const SizedBox(height: 14),
              if (history.isEmpty)
                const LabPanel(
                  child: Text(
                    'No actor-inspired workouts saved yet. Choose a plan and log your first session.',
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
                        '${record.setCount}/${record.totalSteps} sets · ${record.status == 'completed' ? 'Completed' : 'Partial'}',
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
            'Recorded sets',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 16),
          LoggedSetsEditor(
            store: store,
            predicate: (log) => log.sessionId == record.sessionId,
            emptyMessage: 'No recorded sets remain for this session.',
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
String _date(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

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
