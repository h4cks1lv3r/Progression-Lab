import 'package:flutter/material.dart';

import 'logged_sets.dart';
import 'program.dart';
import 'store.dart';

typedef OpenProgramWorkout =
    void Function(ProgramWeek week, int workoutIndex, bool retroactive);

const _ink = Color(0xFF070A0F);
const _surface = Color(0xFF101722);
const _surfaceRaised = Color(0xFF172131);
const _acid = Color(0xFFC7FF45);
const _electric = Color(0xFF4DE5FF);
const _violet = Color(0xFFA878FF);
const _amber = Color(0xFFFFB84D);

/// Opens the shared cadence-change flow.
///
/// The user's phase and microcycle do not change. The user must choose the
/// exact workout that becomes the next workout before the cadence is saved.
Future<void> showCadenceSwitchSheet(
  BuildContext context,
  AppStore store, {
  int? requestedDays,
}) async {
  final originalDays = store.days;
  final originalWorkoutIndex = store.workoutIndex;
  final currentWeek = ProgramEngine.week(
    _normalizedWeek(store.week),
    originalDays,
  );
  var targetDays =
      requestedDays != null && ProgramEngine.isSupportedDays(requestedDays)
      ? requestedDays
      : originalDays;
  var selectedWorkout = _mappedWorkoutIndex(
    oldDays: originalDays,
    newDays: targetDays,
    oldIndex: originalWorkoutIndex,
    weekNumber: currentWeek.number,
  );
  var saving = false;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: .76),
    builder: (sheetContext) => StatefulBuilder(
      builder: (context, setSheetState) {
        final targetWeek = ProgramEngine.week(currentWeek.number, targetDays);
        selectedWorkout = selectedWorkout
            .clamp(0, targetWeek.workouts.length - 1)
            .toInt();

        Future<void> commit() async {
          if (saving) return;
          setSheetState(() => saving = true);
          try {
            await store.setDays(targetDays, nextWorkoutIndex: selectedWorkout);
            if (sheetContext.mounted) Navigator.of(sheetContext).pop();
          } catch (_) {
            if (!sheetContext.mounted) return;
            setSheetState(() => saving = false);
            ScaffoldMessenger.of(sheetContext).showSnackBar(
              const SnackBar(
                content: Text('The cadence could not be changed. Try again.'),
              ),
            );
          }
        }

        return DraggableScrollableSheet(
          initialChildSize: .88,
          minChildSize: .58,
          maxChildSize: .96,
          expand: false,
          builder: (context, controller) => Material(
            color: _surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                Expanded(
                  child: ListView(
                    key: const ValueKey('cadence-options-scroll'),
                    controller: controller,
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: _acid.withValues(alpha: .12),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: _acid.withValues(alpha: .38),
                              ),
                            ),
                            child: const Icon(
                              Icons.swap_horiz_rounded,
                              color: _acid,
                            ),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'CHANGE CADENCE',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: .4,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Choose the schedule that fits your life now.',
                                  style: TextStyle(color: Colors.white60),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Close',
                            onPressed: saving
                                ? null
                                : () => Navigator.of(sheetContext).pop(),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              _electric.withValues(alpha: .13),
                              _violet.withValues(alpha: .08),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _electric.withValues(alpha: .28),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.lock_clock_rounded,
                              color: _electric,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text.rich(
                                TextSpan(
                                  children: [
                                    TextSpan(
                                      text:
                                          'Phase ${currentWeek.phase} · Microcycle ${currentWeek.microcycle} ',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    const TextSpan(
                                      text:
                                          'is preserved. Only the weekly cadence and next workout change.',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        height: 1.35,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),
                      const _Eyebrow('DAYS PER WEEK'),
                      const SizedBox(height: 10),
                      _DaySelector(
                        selected: targetDays,
                        onSelected: saving
                            ? null
                            : (days) {
                                setSheetState(() {
                                  targetDays = days;
                                  selectedWorkout = _mappedWorkoutIndex(
                                    oldDays: originalDays,
                                    newDays: days,
                                    oldIndex: originalWorkoutIndex,
                                    weekNumber: currentWeek.number,
                                  );
                                });
                              },
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          const Expanded(
                            child: _Eyebrow('CHOOSE NEXT WORKOUT'),
                          ),
                          Text(
                            '${targetWeek.workouts.length} sessions',
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      const Text(
                        'The closest match is selected. Change it if another workout should come next.',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 13,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 12),
                      for (final entry in targetWeek.workouts.asMap().entries)
                        _NextWorkoutOption(
                          workout: entry.value,
                          index: entry.key,
                          selected: selectedWorkout == entry.key,
                          onTap: saving
                              ? null
                              : () => setSheetState(
                                  () => selectedWorkout = entry.key,
                                ),
                        ),
                    ],
                  ),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: _ink,
                    border: Border(
                      top: BorderSide(
                        color: Colors.white.withValues(alpha: .08),
                      ),
                    ),
                  ),
                  child: SafeArea(
                    top: false,
                    minimum: const EdgeInsets.fromLTRB(20, 14, 20, 16),
                    child: SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: FilledButton.icon(
                        onPressed: saving ? null : commit,
                        style: FilledButton.styleFrom(
                          backgroundColor: _acid,
                          foregroundColor: _ink,
                          disabledBackgroundColor: _acid.withValues(alpha: .45),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(17),
                          ),
                        ),
                        icon: saving
                            ? const SizedBox.square(
                                dimension: 19,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: _ink,
                                ),
                              )
                            : const Icon(Icons.check_rounded),
                        label: Text(
                          saving
                              ? 'SAVING'
                              : targetDays == originalDays
                              ? 'KEEP $targetDays-DAY CADENCE'
                              : 'SWITCH TO $targetDays DAYS',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            letterSpacing: .5,
                          ),
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
    ),
  );
}

class ProgramNavigatorPage extends StatefulWidget {
  const ProgramNavigatorPage({
    super.key,
    required this.store,
    required this.onOpenWorkout,
  });

  final AppStore store;
  final OpenProgramWorkout onOpenWorkout;

  @override
  State<ProgramNavigatorPage> createState() => _ProgramNavigatorPageState();
}

class _ProgramNavigatorPageState extends State<ProgramNavigatorPage> {
  late int _phase;
  late Set<WeekKind> _visibleKinds;
  var _phaseWasChosen = false;

  @override
  void initState() {
    super.initState();
    _phase = _currentWeek.phase;
    _visibleKinds = WeekKind.values.toSet();
  }

  ProgramWeek get _currentWeek =>
      ProgramEngine.week(_normalizedWeek(widget.store.week), widget.store.days);

  void _showPhase(int phase) {
    if (phase == _phase) return;
    setState(() {
      _phase = phase;
      _phaseWasChosen = true;
    });
  }

  void _showCurrentPhase(int phase) {
    setState(() {
      _phase = phase;
      _phaseWasChosen = false;
    });
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.store,
    builder: (context, _) {
      final current = _currentWeek;
      if (!_phaseWasChosen && _phase != current.phase) {
        _phase = current.phase;
      }
      final weeks = List.generate(
        ProgramEngine.weeksPerPhase,
        (index) => ProgramEngine.week(
          ((_phase - 1) * ProgramEngine.weeksPerPhase) + index + 1,
          widget.store.days,
        ),
      ).where((week) => _visibleKinds.contains(week.kind)).toList();

      return ColoredBox(
        color: _ink,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 980),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'PROGRAM',
                                    style: TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -.6,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Your complete training map',
                                    style: TextStyle(color: Colors.white54),
                                  ),
                                ],
                              ),
                            ),
                            _CurrentBadge(
                              phase: current.phase,
                              microcycle: current.microcycle,
                            ),
                          ],
                        ),
                        const SizedBox(height: 22),
                        _CadencePanel(
                          days: widget.store.days,
                          onSelected: (days) => showCadenceSwitchSheet(
                            context,
                            widget.store,
                            requestedDays: days,
                          ),
                        ),
                        const SizedBox(height: 22),
                        _PositionPanel(
                          current: current,
                          workoutIndex: widget.store.workoutIndex,
                          selectedPhase: _phase,
                          onJumpToCurrent: () =>
                              _showCurrentPhase(current.phase),
                        ),
                        const SizedBox(height: 24),
                        const _Eyebrow('PHASE NAVIGATOR'),
                        const SizedBox(height: 10),
                        _PhaseSelector(
                          selected: _phase,
                          current: current.phase,
                          onSelected: _showPhase,
                        ),
                        const SizedBox(height: 22),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'PHASE $_phase',
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    '${ProgramEngine.weeksPerPhase} microcycles · ${widget.store.days}-day cadence',
                                    style: const TextStyle(
                                      color: Colors.white54,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (_phase != current.phase)
                              TextButton.icon(
                                onPressed: () =>
                                    _showCurrentPhase(current.phase),
                                icon: const Icon(
                                  Icons.my_location_rounded,
                                  size: 17,
                                ),
                                label: const Text('CURRENT'),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _KindFilters(
                          selected: _visibleKinds,
                          onChanged: (next) =>
                              setState(() => _visibleKinds = next),
                        ),
                        const SizedBox(height: 18),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 980),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 360),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (child, animation) {
                        final offset = Tween<Offset>(
                          begin: const Offset(.055, 0),
                          end: Offset.zero,
                        ).animate(animation);
                        return FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: offset,
                            child: child,
                          ),
                        );
                      },
                      child: _WeekGrid(
                        key: ValueKey(
                          'phase-$_phase-${_visibleKinds.hashCode}',
                        ),
                        weeks: weeks,
                        currentWeek: current.number,
                        currentWorkout: widget.store.workoutIndex,
                        store: widget.store,
                        onOpenWorkout: widget.onOpenWorkout,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _CadencePanel extends StatelessWidget {
  const _CadencePanel({required this.days, required this.onSelected});

  final int days;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [_surfaceRaised, Color(0xFF111824)],
      ),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: Colors.white.withValues(alpha: .08)),
      boxShadow: [
        BoxShadow(
          color: _electric.withValues(alpha: .04),
          blurRadius: 28,
          offset: const Offset(0, 12),
        ),
      ],
    ),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 610;
        final heading = Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _acid.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Icon(Icons.calendar_view_week_rounded, color: _acid),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TRAINING CADENCE',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      letterSpacing: .6,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Switch without losing your place',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        );
        final selector = _DaySelector(
          selected: days,
          onSelected: onSelected,
          compact: true,
        );
        if (compact) {
          return Column(
            children: [heading, const SizedBox(height: 16), selector],
          );
        }
        return Row(
          children: [
            Expanded(child: heading),
            const SizedBox(width: 24),
            SizedBox(width: 310, child: selector),
          ],
        );
      },
    ),
  );
}

class _DaySelector extends StatelessWidget {
  const _DaySelector({
    required this.selected,
    required this.onSelected,
    this.compact = false,
  });

  final int selected;
  final ValueChanged<int>? onSelected;
  final bool compact;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: _ink.withValues(alpha: .72),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.white.withValues(alpha: .07)),
    ),
    child: Row(
      children: [
        for (final day in const [3, 4, 5])
          Expanded(
            child: Semantics(
              button: true,
              selected: selected == day,
              label: '$day training days per week',
              child: InkWell(
                onTap: onSelected == null ? null : () => onSelected!(day),
                borderRadius: BorderRadius.circular(12),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 190),
                  curve: Curves.easeOut,
                  height: compact ? 43 : 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected == day ? _acid : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: selected == day
                        ? [
                            BoxShadow(
                              color: _acid.withValues(alpha: .18),
                              blurRadius: 14,
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    '$day DAYS',
                    style: TextStyle(
                      color: selected == day ? _ink : Colors.white60,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: .4,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

class _PositionPanel extends StatelessWidget {
  const _PositionPanel({
    required this.current,
    required this.workoutIndex,
    required this.selectedPhase,
    required this.onJumpToCurrent,
  });

  final ProgramWeek current;
  final int workoutIndex;
  final int selectedPhase;
  final VoidCallback onJumpToCurrent;

  @override
  Widget build(BuildContext context) {
    final workout = current
        .workouts[workoutIndex.clamp(0, current.workouts.length - 1).toInt()];
    final completedFraction = workoutIndex / current.workouts.length;
    final phaseProgress =
        ((current.microcycle - 1) + completedFraction) /
        ProgramEngine.weeksPerPhase;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _electric.withValues(alpha: .18)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 9,
                height: 42,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [_electric, _violet],
                  ),
                  borderRadius: BorderRadius.circular(99),
                  boxShadow: [
                    BoxShadow(
                      color: _electric.withValues(alpha: .28),
                      blurRadius: 14,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'CURRENT POSITION',
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Phase ${current.phase} · Microcycle ${current.microcycle} · ${workout.name}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
              if (selectedPhase != current.phase)
                IconButton.filledTonal(
                  tooltip: 'Jump to current phase',
                  onPressed: onJumpToCurrent,
                  icon: const Icon(Icons.my_location_rounded, size: 19),
                ),
            ],
          ),
          const SizedBox(height: 15),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: phaseProgress.clamp(0.0, 1.0).toDouble(),
              minHeight: 6,
              backgroundColor: Colors.white.withValues(alpha: .07),
              valueColor: const AlwaysStoppedAnimation(_electric),
            ),
          ),
        ],
      ),
    );
  }
}

class _PhaseSelector extends StatelessWidget {
  const _PhaseSelector({
    required this.selected,
    required this.current,
    required this.onSelected,
  });

  final int selected;
  final int current;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Row(
      children: [
        for (var phase = 1; phase <= ProgramEngine.phaseCount; phase++) ...[
          if (phase > 1) const SizedBox(width: 8),
          Expanded(
            child: Semantics(
              button: true,
              selected: selected == phase,
              label: 'Phase $phase${current == phase ? ', current phase' : ''}',
              child: InkWell(
                onTap: () => onSelected(phase),
                borderRadius: BorderRadius.circular(18),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 230),
                  height: constraints.maxWidth < 420 ? 70 : 76,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: selected == phase ? _surfaceRaised : _surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: selected == phase
                          ? _electric.withValues(alpha: .58)
                          : Colors.white.withValues(alpha: .07),
                    ),
                    boxShadow: selected == phase
                        ? [
                            BoxShadow(
                              color: _electric.withValues(alpha: .08),
                              blurRadius: 18,
                            ),
                          ]
                        : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '0$phase',
                        style: TextStyle(
                          color: selected == phase ? _electric : Colors.white54,
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'PHASE',
                            style: TextStyle(
                              color: selected == phase
                                  ? Colors.white
                                  : Colors.white38,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              letterSpacing: .8,
                            ),
                          ),
                          if (current == phase) ...[
                            const SizedBox(width: 4),
                            Container(
                              width: 5,
                              height: 5,
                              decoration: const BoxDecoration(
                                color: _acid,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    ),
  );
}

class _KindFilters extends StatelessWidget {
  const _KindFilters({required this.selected, required this.onChanged});

  final Set<WeekKind> selected;
  final ValueChanged<Set<WeekKind>> onChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          const Expanded(child: _Eyebrow('WEEK TYPE')),
          TextButton(
            onPressed: () => onChanged(WeekKind.values.toSet()),
            child: Text(
              selected.length == WeekKind.values.length
                  ? 'ALL ACTIVE'
                  : 'SHOW ALL',
              style: TextStyle(
                color: selected.length == WeekKind.values.length
                    ? _acid
                    : _electric,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 6),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final kind in WeekKind.values)
            _KindChip(
              kind: kind,
              selected: selected.contains(kind),
              onTap: () {
                final next = {...selected};
                if (!next.remove(kind)) next.add(kind);
                onChanged(next);
              },
            ),
        ],
      ),
    ],
  );
}

class _KindChip extends StatelessWidget {
  const _KindChip({
    required this.kind,
    required this.selected,
    required this.onTap,
  });

  final WeekKind kind;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final meta = _kindMeta(kind);
    return FilterChip(
      selected: selected,
      onSelected: (_) => onTap(),
      showCheckmark: false,
      avatar: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: selected ? meta.color : meta.color.withValues(alpha: .4),
          shape: BoxShape.circle,
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: meta.color.withValues(alpha: .4),
                    blurRadius: 7,
                  ),
                ]
              : null,
        ),
      ),
      label: Text(meta.shortLabel),
      labelStyle: TextStyle(
        color: selected ? Colors.white : Colors.white38,
        fontSize: 11,
        fontWeight: FontWeight.w800,
      ),
      backgroundColor: _surface,
      selectedColor: meta.color.withValues(alpha: .13),
      side: BorderSide(
        color: selected
            ? meta.color.withValues(alpha: .38)
            : Colors.white.withValues(alpha: .06),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
    );
  }
}

class _WeekGrid extends StatelessWidget {
  const _WeekGrid({
    super.key,
    required this.weeks,
    required this.currentWeek,
    required this.currentWorkout,
    required this.store,
    required this.onOpenWorkout,
  });

  final List<ProgramWeek> weeks;
  final int currentWeek;
  final int currentWorkout;
  final AppStore store;
  final OpenProgramWorkout onOpenWorkout;

  @override
  Widget build(BuildContext context) {
    if (weeks.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 44),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withValues(alpha: .06)),
        ),
        child: const Column(
          children: [
            Icon(Icons.filter_alt_off_rounded, color: Colors.white38, size: 32),
            SizedBox(height: 12),
            Text(
              'No week types selected',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            SizedBox(height: 4),
            Text(
              'Use Show all or select a week type above.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final twoColumns = constraints.maxWidth >= 760;
        final cardWidth = twoColumns
            ? (constraints.maxWidth - 12) / 2
            : constraints.maxWidth;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final week in weeks)
              SizedBox(
                width: cardWidth,
                child: _MicrocycleCard(
                  key: ValueKey('week-${week.number}'),
                  week: week,
                  current: week.number == currentWeek,
                  currentWorkout: week.number == currentWeek
                      ? currentWorkout
                      : null,
                  store: store,
                  onOpenWorkout: onOpenWorkout,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _MicrocycleCard extends StatefulWidget {
  const _MicrocycleCard({
    super.key,
    required this.week,
    required this.current,
    required this.currentWorkout,
    required this.store,
    required this.onOpenWorkout,
  });

  final ProgramWeek week;
  final bool current;
  final int? currentWorkout;
  final AppStore store;
  final OpenProgramWorkout onOpenWorkout;

  @override
  State<_MicrocycleCard> createState() => _MicrocycleCardState();
}

class _MicrocycleCardState extends State<_MicrocycleCard> {
  var _expanded = false;

  @override
  Widget build(BuildContext context) {
    final meta = _kindMeta(widget.week.kind);
    return Container(
      decoration: BoxDecoration(
        color: widget.current ? _surfaceRaised : _surface,
        borderRadius: BorderRadius.circular(21),
        border: Border.all(
          color: widget.current
              ? _acid.withValues(alpha: .7)
              : Colors.white.withValues(alpha: .07),
        ),
        boxShadow: widget.current
            ? [
                BoxShadow(
                  color: _acid.withValues(alpha: .07),
                  blurRadius: 24,
                  offset: const Offset(0, 9),
                ),
              ]
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: widget.current
                          ? _acid
                          : meta.color.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Text(
                      widget.week.number.toString().padLeft(2, '0'),
                      style: TextStyle(
                        color: widget.current ? _ink : meta.color,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                'WEEK ${widget.week.number}',
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: .25,
                                ),
                              ),
                            ),
                            if (widget.current) ...[
                              const SizedBox(width: 7),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: _acid.withValues(alpha: .13),
                                  borderRadius: BorderRadius.circular(99),
                                ),
                                child: const Text(
                                  'NOW',
                                  style: TextStyle(
                                    color: _acid,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: meta.color,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              meta.label,
                              style: TextStyle(
                                color: meta.color,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: .65,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '· MC ${widget.week.microcycle} · ${widget.week.workouts.length} workouts',
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white38,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: _expanded ? .5 : 0,
                    duration: const Duration(milliseconds: 240),
                    child: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Colors.white54,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: _expanded
                ? Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(12, 2, 12, 12),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: Colors.white.withValues(alpha: .06),
                        ),
                      ),
                    ),
                    child: Column(
                      children: [
                        for (final entry
                            in widget.week.workouts.asMap().entries)
                          _WorkoutDetailCard(
                            week: widget.week,
                            workoutIndex: entry.key,
                            workout: entry.value,
                            current:
                                widget.current &&
                                widget.currentWorkout == entry.key,
                            store: widget.store,
                            onOpenWorkout: widget.onOpenWorkout,
                          ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _WorkoutDetailCard extends StatelessWidget {
  const _WorkoutDetailCard({
    required this.week,
    required this.workoutIndex,
    required this.workout,
    required this.current,
    required this.store,
    required this.onOpenWorkout,
  });

  final ProgramWeek week;
  final int workoutIndex;
  final WorkoutPlan workout;
  final bool current;
  final AppStore store;
  final OpenProgramWorkout onOpenWorkout;

  @override
  Widget build(BuildContext context) {
    final records = store.recordsForSlot(week.number, workoutIndex);
    final record = records.isEmpty ? null : records.first;
    final past = store.isPastSlot(week.number, workoutIndex);
    final completed = records.any(
      (item) => item.status == WorkoutStatus.completed,
    );
    final status = record == null
        ? null
        : record.retroactive
        ? 'RETRO FILLED'
        : record.status == WorkoutStatus.skipped
        ? 'SKIPPED'
        : 'COMPLETED';
    return Container(
      key: ValueKey('workout-${week.number}-$workoutIndex'),
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: current
            ? _acid.withValues(alpha: .075)
            : _ink.withValues(alpha: .62),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: current
              ? _acid.withValues(alpha: .32)
              : Colors.white.withValues(alpha: .05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  workout.name.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .7,
                  ),
                ),
              ),
              if (current)
                const Text(
                  'NEXT',
                  style: TextStyle(
                    color: _acid,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .7,
                  ),
                ),
              if (status != null) ...[
                const SizedBox(width: 8),
                Text(
                  status,
                  style: TextStyle(
                    color: record!.status == WorkoutStatus.skipped
                        ? Colors.white54
                        : _acid,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .7,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 3),
          Text(
            _formatDate(store.dateForSlot(week.number, workoutIndex)),
            style: const TextStyle(color: Colors.white38, fontSize: 11),
          ),
          const SizedBox(height: 10),
          for (final entry in workout.exercises.asMap().entries) ...[
            if (entry.key > 0)
              Divider(height: 14, color: Colors.white.withValues(alpha: .055)),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 22,
                  child: Text(
                    '${entry.key + 1}'.padLeft(2, '0'),
                    style: const TextStyle(
                      color: Colors.white24,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    entry.value.name,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: .78),
                      fontSize: 13,
                      height: 1.25,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: entry.value.primary
                        ? _electric.withValues(alpha: .1)
                        : Colors.white.withValues(alpha: .045),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${entry.value.sets} × ${entry.value.reps}',
                    style: TextStyle(
                      color: entry.value.primary ? _electric : Colors.white60,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (record != null) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        LoggedWorkoutScreen(store: store, record: record),
                  ),
                ),
                icon: const Icon(Icons.history_rounded, size: 17),
                label: const Text('VIEW LOGGED WORKOUT'),
              ),
            ),
          ],
          if (past && !completed) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => onOpenWorkout(week, workoutIndex, true),
                icon: const Icon(Icons.add_task_rounded, size: 17),
                label: Text(
                  record == null ? 'FILL PAST WORKOUT' : 'FILL SKIPPED WORKOUT',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

String _formatDate(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/'
    '${value.month.toString().padLeft(2, '0')}/${value.year}';

class _NextWorkoutOption extends StatelessWidget {
  const _NextWorkoutOption({
    required this.workout,
    required this.index,
    required this.selected,
    required this.onTap,
  });

  final WorkoutPlan workout;
  final int index;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 9),
    child: Semantics(
      selected: selected,
      button: true,
      label: '${workout.name}, workout ${index + 1}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected
                ? _acid.withValues(alpha: .09)
                : _ink.withValues(alpha: .62),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected
                  ? _acid.withValues(alpha: .62)
                  : Colors.white.withValues(alpha: .07),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? _acid : Colors.white.withValues(alpha: .06),
                  shape: BoxShape.circle,
                ),
                child: selected
                    ? const Icon(Icons.check_rounded, color: _ink, size: 18)
                    : Text(
                        '${index + 1}',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      workout.name,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      workout.exercises
                          .map(
                            (exercise) =>
                                '${exercise.name}  ${exercise.sets}×${exercise.reps}',
                          )
                          .join('  ·  '),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _CurrentBadge extends StatelessWidget {
  const _CurrentBadge({required this.phase, required this.microcycle});

  final int phase;
  final int microcycle;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
    decoration: BoxDecoration(
      color: _acid.withValues(alpha: .1),
      borderRadius: BorderRadius.circular(13),
      border: Border.all(color: _acid.withValues(alpha: .28)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const Text(
          'CURRENT',
          style: TextStyle(
            color: _acid,
            fontSize: 9,
            fontWeight: FontWeight.w900,
            letterSpacing: .8,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'P$phase · M$microcycle',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
        ),
      ],
    ),
  );
}

class _Eyebrow extends StatelessWidget {
  const _Eyebrow(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      color: Colors.white38,
      fontSize: 11,
      fontWeight: FontWeight.w900,
      letterSpacing: 1.2,
    ),
  );
}

class _KindMeta {
  const _KindMeta(this.label, this.shortLabel, this.color);

  final String label;
  final String shortLabel;
  final Color color;
}

_KindMeta _kindMeta(WeekKind kind) => switch (kind) {
  WeekKind.build => const _KindMeta('BUILD', 'Build', _electric),
  WeekKind.volumeDeload => const _KindMeta(
    'VOLUME DELOAD',
    'Volume deload',
    _violet,
  ),
  WeekKind.strength => const _KindMeta('STRENGTH WEEK', 'Strength', _amber),
  WeekKind.fullDeload => const _KindMeta('FULL DELOAD', 'Full deload', _acid),
};

int _normalizedWeek(int week) {
  final safeWeek = week < 1 ? 1 : week;
  return ((safeWeek - 1) % ProgramEngine.totalWeeks) + 1;
}

int _mappedWorkoutIndex({
  required int oldDays,
  required int newDays,
  required int oldIndex,
  required int weekNumber,
}) {
  final mapped = ProgramEngine.defaultWorkoutIndexForCadenceSwitch(
    week: weekNumber,
    fromDays: oldDays,
    toDays: newDays,
    currentWorkoutIndex: oldIndex,
  );
  final workoutCount = ProgramEngine.week(weekNumber, newDays).workouts.length;
  return mapped.clamp(0, workoutCount - 1).toInt();
}
