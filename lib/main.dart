import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'program.dart';
import 'program_navigator.dart';
import 'progress_dashboard.dart';
import 'store.dart';

void main() => runApp(const ProgressionLabApp());

const ink = Color(0xFF090C10);
const panel = Color(0xFF121821);
const lime = Color(0xFFB9FF3B);
const cyan = Color(0xFF37D7FF);
const violet = Color(0xFF8B5CF6);
const muted = Color(0xFF8A97A8);

class ProgressionLabApp extends StatefulWidget {
  const ProgressionLabApp({super.key});
  @override
  State<ProgressionLabApp> createState() => _ProgressionLabAppState();
}

class _ProgressionLabAppState extends State<ProgressionLabApp> {
  final store = AppStore();
  @override
  void initState() {
    super.initState();
    store.load();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: store,
    builder: (context, _) => MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Progression Lab',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: ink,
        colorScheme: const ColorScheme.dark(
          primary: lime,
          onPrimary: ink,
          secondary: cyan,
          onSecondary: ink,
          tertiary: violet,
          surface: panel,
          onSurface: Color(0xFFF5F7FA),
          error: Color(0xFFFF5D73),
        ),
        fontFamily: 'Roboto',
        useMaterial3: true,
        splashFactory: InkSparkle.splashFactory,
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
          },
        ),
        appBarTheme: const AppBarTheme(
          elevation: 0,
          scrolledUnderElevation: 0,
          backgroundColor: Colors.transparent,
          foregroundColor: Color(0xFFF5F7FA),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: const Color(0xF20D1219),
          indicatorColor: lime.withValues(alpha: .16),
          labelTextStyle: WidgetStateProperty.resolveWith(
            (states) => TextStyle(
              color: states.contains(WidgetState.selected)
                  ? Colors.white
                  : muted,
              fontSize: 11,
              fontWeight: states.contains(WidgetState.selected)
                  ? FontWeight.w800
                  : FontWeight.w600,
            ),
          ),
        ),
        navigationRailTheme: NavigationRailThemeData(
          backgroundColor: const Color(0xFF0D1219),
          indicatorColor: lime.withValues(alpha: .16),
          selectedIconTheme: const IconThemeData(color: lime),
          unselectedIconTheme: const IconThemeData(color: muted),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size(48, 52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            textStyle: const TextStyle(
              fontWeight: FontWeight.w900,
              letterSpacing: .5,
            ),
          ),
        ),
        cardTheme: CardThemeData(
          color: panel,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: BorderSide(color: Colors.white.withValues(alpha: .06)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white.withValues(alpha: .055),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      home: Shell(store: store),
    ),
  );
}

class Shell extends StatefulWidget {
  const Shell({super.key, required this.store});
  final AppStore store;
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int index = 0;

  static const _destinations = [
    NavigationDestination(icon: Icon(Icons.bolt_rounded), label: 'Today'),
    NavigationDestination(
      icon: Icon(Icons.view_timeline_rounded),
      label: 'Program',
    ),
    NavigationDestination(
      icon: Icon(Icons.query_stats_rounded),
      label: 'Progress',
    ),
    NavigationDestination(icon: Icon(Icons.tune_rounded), label: 'Setup'),
  ];

  @override
  Widget build(BuildContext context) {
    final pages = [
      TodayPage(
        store: widget.store,
        onOpenProgram: () => setState(() => index = 1),
      ),
      ProgramNavigatorPage(store: widget.store),
      ProgressDashboard(store: widget.store),
      SettingsPage(store: widget.store),
    ];
    final body = SafeArea(
      child: IndexedStack(index: index, children: pages),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 760;
        if (!wide) {
          return Scaffold(
            body: body,
            bottomNavigationBar: NavigationBar(
              selectedIndex: index,
              onDestinationSelected: (value) => setState(() => index = value),
              destinations: _destinations,
            ),
          );
        }
        return Scaffold(
          body: Row(
            children: [
              SafeArea(
                child: NavigationRail(
                  selectedIndex: index,
                  onDestinationSelected: (value) =>
                      setState(() => index = value),
                  labelType: NavigationRailLabelType.all,
                  leading: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 18),
                    child: _Mark(),
                  ),
                  destinations: _destinations
                      .map(
                        (destination) => NavigationRailDestination(
                          icon: destination.icon,
                          selectedIcon: destination.selectedIcon,
                          label: Text(destination.label),
                        ),
                      )
                      .toList(),
                ),
              ),
              const VerticalDivider(width: 1, color: Colors.white10),
              Expanded(child: body),
            ],
          ),
        );
      },
    );
  }
}

class TodayPage extends StatelessWidget {
  const TodayPage({
    super.key,
    required this.store,
    required this.onOpenProgram,
  });
  final AppStore store;
  final VoidCallback onOpenProgram;
  @override
  Widget build(BuildContext context) {
    final week = ProgramEngine.week(store.week, store.days);
    final workout = week.workouts[
      store.workoutIndex.clamp(0, week.workouts.length - 1).toInt()
    ];
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
          sliver: SliverToBoxAdapter(
            child: Row(
              children: [
                const _Mark(),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PROGRESSION LAB',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.8,
                          fontSize: 18,
                        ),
                      ),
                      Text(
                        'TRAIN WITH INTENT',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 11,
                          letterSpacing: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                Tooltip(
                  message: 'Change training cadence',
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => showCadenceSwitchSheet(context, store),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: cyan.withValues(alpha: .09),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: cyan.withValues(alpha: .22),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${store.days}D',
                            style: const TextStyle(
                              color: cyan,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(width: 3),
                          const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: cyan,
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Open cycle navigator',
                  onPressed: onOpenProgram,
                  icon: const Icon(Icons.hub_rounded),
                ),
                IconButton(
                  onPressed: () => showModalBottomSheet(
                    context: context,
                    showDragHandle: true,
                    builder: (_) => const _QuickHelp(),
                  ),
                  icon: const Icon(Icons.help_outline_rounded),
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.all(20),
          sliver: SliverList.list(
            children: [
              Row(
                children: [
                  _Pill('WEEK ${store.week}', lime),
                  const SizedBox(width: 8),
                  _Pill('PHASE ${week.phase}', cyan),
                  const SizedBox(width: 8),
                  _Pill('MC ${week.microcycle}', Colors.white70),
                ],
              ),
              const SizedBox(height: 15),
              _CycleNavigatorCard(
                week: week,
                onOpenProgram: onOpenProgram,
              ),
              const SizedBox(height: 18),
              Text(
                week.label,
                style: TextStyle(
                  color: week.kind == WeekKind.build ? lime : cyan,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.6,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                workout.name.toUpperCase(),
                style: const TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${workout.exercises.length} exercises  •  ${workout.exercises.fold(0, (n, e) => n + e.sets)} working sets',
                style: const TextStyle(color: Colors.white60),
              ),
              const SizedBox(height: 22),
              _HeroCard(
                workout: workout,
                onStart: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => WorkoutScreen(
                      store: store,
                      week: week,
                      workout: workout,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const _SectionTitle('UP NEXT'),
              const SizedBox(height: 10),
              ...workout.exercises.map(
                (e) => _ExercisePreview(
                  e: e,
                  best: store.best(e.name),
                  unit: store.unit,
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: _Metric(
                      value: '${store.logs.length}',
                      label: 'SETS LOGGED',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _Metric(
                      value:
                          '${store.logs.map((e) => e.exercise).toSet().length}',
                      label: 'LIFTS TRACKED',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
            ],
          ),
        ),
      ],
    );
  }
}

class _CycleNavigatorCard extends StatelessWidget {
  const _CycleNavigatorCard({
    required this.week,
    required this.onOpenProgram,
  });

  final ProgramWeek week;
  final VoidCallback onOpenProgram;

  @override
  Widget build(BuildContext context) {
    final cycleProgress = week.number / ProgramEngine.totalWeeks;
    return Semantics(
      button: true,
      label:
          'Open phase menu. Current position phase ${week.phase}, microcycle ${week.microcycle}',
      child: InkWell(
        onTap: onOpenProgram,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.fromLTRB(16, 14, 14, 15),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF151E2A), Color(0xFF10151D)],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: .07)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(Icons.route_rounded, color: violet, size: 20),
                  const SizedBox(width: 9),
                  const Text(
                    'PHASE MENU',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.3,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${(cycleProgress * 100).round()}% OF CYCLE',
                    style: const TextStyle(
                      color: muted,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: .7,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    color: Colors.white38,
                    size: 17,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  for (var phase = 1; phase <= ProgramEngine.phaseCount; phase++)
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                          right: phase == ProgramEngine.phaseCount ? 0 : 7,
                        ),
                        child: _PhaseSegment(
                          phase: phase,
                          currentPhase: week.phase,
                          microcycle: week.microcycle,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhaseSegment extends StatelessWidget {
  const _PhaseSegment({
    required this.phase,
    required this.currentPhase,
    required this.microcycle,
  });

  final int phase;
  final int currentPhase;
  final int microcycle;

  @override
  Widget build(BuildContext context) {
    final complete = phase < currentPhase;
    final current = phase == currentPhase;
    final color = current ? lime : (complete ? cyan : Colors.white24);
    final progress = complete
        ? 1.0
        : current
        ? microcycle / ProgramEngine.weeksPerPhase
        : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'P$phase',
              style: TextStyle(
                color: current ? Colors.white : muted,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
            const Spacer(),
            if (complete)
              const Icon(Icons.check_rounded, color: cyan, size: 14)
            else if (current)
              Text(
                '$microcycle/${ProgramEngine.weeksPerPhase}',
                style: const TextStyle(
                  color: lime,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 5,
            color: color,
            backgroundColor: Colors.white.withValues(alpha: .07),
          ),
        ),
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.workout, required this.onStart});
  final WorkoutPlan workout;
  final VoidCallback onStart;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF1B2635), Color(0xFF101720)],
      ),
      borderRadius: BorderRadius.circular(26),
      border: Border.all(color: Colors.white10),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: lime,
                borderRadius: BorderRadius.circular(15),
              ),
              child: const Icon(Icons.fitness_center_rounded, color: ink),
            ),
            const Spacer(),
            const Text(
              'READY',
              style: TextStyle(
                color: lime,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.4,
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),
        Text(
          workout.exercises.first.name,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 21),
        ),
        Text(
          '${workout.exercises.first.sets} sets × ${workout.exercises.first.reps}',
          style: const TextStyle(color: Colors.white60),
        ),
        const SizedBox(height: 22),
        SizedBox(
          width: double.infinity,
          height: 54,
          child: FilledButton(
            onPressed: onStart,
            style: FilledButton.styleFrom(
              backgroundColor: lime,
              foregroundColor: ink,
              textStyle: const TextStyle(
                fontWeight: FontWeight.w900,
                letterSpacing: .8,
              ),
            ),
            child: const Text('START WORKOUT  →'),
          ),
        ),
      ],
    ),
  );
}

class WorkoutScreen extends StatefulWidget {
  const WorkoutScreen({
    super.key,
    required this.store,
    required this.week,
    required this.workout,
  });
  final AppStore store;
  final ProgramWeek week;
  final WorkoutPlan workout;
  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> {
  int exercise = 0;
  int set = 1;
  int elapsed = 0;
  int rest = 0;
  int loggedSets = 0;
  Timer? timer;
  final weight = TextEditingController();
  final reps = TextEditingController();
  bool lastPr = false;
  bool finishing = false;
  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          elapsed++;
          if (rest > 0) rest--;
        });
      }
    });
    _seed();
  }

  void _seed({bool preserveWeight = false}) {
    final e = widget.workout.exercises[exercise];
    if (!preserveWeight) {
      final best = widget.store.best(e.name);
      weight.text =
          best?.weight.toStringAsFixed(best.weight % 1 == 0 ? 0 : 1) ?? '';
    }
    reps.text = e.amrap && set == 1
        ? ''
        : e.amrap && set == 2
        ? '4'
        : e.reps.split(RegExp('[– +]')).first;
  }

  @override
  void dispose() {
    timer?.cancel();
    weight.dispose();
    reps.dispose();
    super.dispose();
  }

  Future<void> _log() async {
    final w = double.tryParse(weight.text);
    final r = int.tryParse(reps.text);
    if (w == null || r == null || w <= 0 || r <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a weight and a repetition count above zero.'),
        ),
      );
      return;
    }
    final e = widget.workout.exercises[exercise];
    final pr = await widget.store.add(
      SetLog(
        exercise: e.name,
        weight: w,
        reps: r,
        date: DateTime.now(),
        workout: widget.workout.name,
      ),
    );
    if (!mounted) return;
    var workoutComplete = false;
    setState(() {
      lastPr = pr;
      loggedSets++;
      rest = e.primary ? 180 : 120;
      if (set < e.sets) {
        set++;
        if (e.amrap) _seed(preserveWeight: true);
      } else if (exercise < widget.workout.exercises.length - 1) {
        exercise++;
        set = 1;
        lastPr = false;
        _seed();
      } else {
        workoutComplete = true;
      }
    });
    HapticFeedback.selectionClick();
    if (pr && mounted) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('NEW PERSONAL RECORD'),
          backgroundColor: lime,
        ),
      );
    }
    if (workoutComplete) {
      await _finish(completedAutomatically: true);
    }
  }

  Future<void> _finish({bool completedAutomatically = false}) async {
    if (finishing) return;
    final plannedSets = widget.workout.exercises.fold<int>(
      0,
      (total, item) => total + item.sets,
    );
    if (!completedAutomatically && loggedSets < plannedSets) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Finish this workout?'),
          content: Text(
            '${plannedSets - loggedSets} planned sets remain. Your logged sets stay in history, but this workout will advance.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('KEEP TRAINING'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('FINISH EARLY'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    setState(() => finishing = true);
    await widget.store.complete(widget.week.workouts.length);
    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.workout.exercises[exercise];
    final progress =
        (exercise + (set / e.sets)) / widget.workout.exercises.length;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text('${_clock(elapsed)}  •  ${widget.workout.name}'),
        actions: [
          TextButton(
            onPressed: finishing ? null : () => _finish(),
            child: Text(finishing ? 'SAVING' : 'FINISH'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.white10,
            color: lime,
            borderRadius: BorderRadius.circular(8),
            minHeight: 6,
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              Expanded(
                child: Text(
                  e.name,
                  style: const TextStyle(
                    fontSize: 29,
                    fontWeight: FontWeight.w900,
                    height: 1.05,
                  ),
                ),
              ),
              if (lastPr)
                const Icon(Icons.emoji_events_rounded, color: lime, size: 34),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'SET $set OF ${e.sets}  •  TARGET ${e.reps} REPS',
            style: const TextStyle(
              color: cyan,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 24),
          _Previous(best: widget.store.best(e.name), unit: widget.store.unit),
          const SizedBox(height: 26),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: weight,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                  decoration: InputDecoration(
                    labelText: 'WEIGHT (${widget.store.unit})',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: reps,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                  decoration: const InputDecoration(labelText: 'REPS'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (rest > 0)
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: cyan.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  const Icon(Icons.timer_outlined, color: cyan),
                  const SizedBox(width: 12),
                  Text(
                    'REST  ${_clock(rest)}',
                    style: const TextStyle(
                      color: cyan,
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => setState(() => rest = 0),
                    child: const Text('SKIP'),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 18),
          SizedBox(
            height: 60,
            child: FilledButton(
              onPressed: finishing ? null : _log,
              style: FilledButton.styleFrom(
                backgroundColor: lime,
                foregroundColor: ink,
              ),
              child: const Text(
                'LOG SET',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
              ),
            ),
          ),
          const SizedBox(height: 28),
          const Text(
            'SESSION',
            style: TextStyle(
              color: Colors.white38,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          ...widget.workout.exercises.asMap().entries.map(
            (x) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: x.key < exercise ? lime : Colors.white10,
                child: Icon(
                  x.key < exercise ? Icons.check : Icons.fitness_center,
                  color: x.key < exercise ? ink : Colors.white54,
                  size: 18,
                ),
              ),
              title: Text(x.value.name),
              trailing: Text(
                '${x.value.sets} × ${x.value.reps}',
                style: const TextStyle(color: Colors.white54),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _clock(int s) =>
      '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.store});
  final AppStore store;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 24, 20, 30),
    children: [
      const Text(
        'SETUP',
        style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900),
      ),
      const SizedBox(height: 5),
      const Text(
        'Control your cadence without losing your place.',
        style: TextStyle(color: Colors.white54),
      ),
      const SizedBox(height: 24),
      const _SectionTitle('TRAINING DAYS'),
      const SizedBox(height: 10),
      SegmentedButton<int>(
        segments: const [
          ButtonSegment(value: 3, label: Text('3 DAYS')),
          ButtonSegment(value: 4, label: Text('4 DAYS')),
          ButtonSegment(value: 5, label: Text('5 DAYS')),
        ],
        selected: {store.days},
        onSelectionChanged: (selection) {
          final requested = selection.first;
          if (requested != store.days) {
            showCadenceSwitchSheet(
              context,
              store,
              requestedDays: requested,
            );
          }
        },
      ),
      const SizedBox(height: 11),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cyan.withValues(alpha: .07),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cyan.withValues(alpha: .16)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.shield_outlined, color: cyan, size: 19),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Switching keeps Week ${store.week}, Phase ${ProgramEngine.week(store.week, store.days).phase}, and Microcycle ${ProgramEngine.week(store.week, store.days).microcycle}. You choose the exact next workout before anything changes.',
                style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 26),
      const _SectionTitle('WEIGHT UNIT'),
      const SizedBox(height: 10),
      SegmentedButton<String>(
        segments: const [
          ButtonSegment(value: 'lb', label: Text('POUNDS')),
          ButtonSegment(value: 'kg', label: Text('KILOGRAMS')),
        ],
        selected: {store.unit},
        onSelectionChanged: (selection) async {
          try {
            await store.setUnit(selection.first);
          } on Object {
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('The weight unit could not be saved.'),
              ),
            );
          }
        },
      ),
      const SizedBox(height: 28),
      const _Setting(
        icon: Icons.swap_horiz_rounded,
        title: 'Exercise substitutions',
        subtitle: 'Planned for the durable workout-engine update',
        available: false,
      ),
      const _Setting(
        icon: Icons.calculate_rounded,
        title: 'Plate calculator',
        subtitle: 'Planned for the target-load update',
        available: false,
      ),
      const _Setting(
        icon: Icons.backup_rounded,
        title: 'Local-first history',
        subtitle: 'Working now; export and restore are not yet available',
        available: true,
      ),
      const _Setting(
        icon: Icons.monitor_heart_outlined,
        title: 'Recovery check-in',
        subtitle: 'Planned; no readiness score is being inferred',
        available: false,
      ),
      const SizedBox(height: 22),
      const Text(
        'PROGRAM LOGIC',
        style: TextStyle(
          color: lime,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.4,
        ),
      ),
      const SizedBox(height: 10),
      const Text(
        'The included templates follow the 16-microcycle cadence reconstructed from your supplied material. Training recommendations are educational and should be adjusted for injuries, experience, and medical guidance.',
        style: TextStyle(color: Colors.white54, height: 1.45),
      ),
    ],
  );
}

class _Mark extends StatelessWidget {
  const _Mark();
  @override
  Widget build(BuildContext context) => Container(
    width: 42,
    height: 42,
    decoration: BoxDecoration(
      color: lime,
      borderRadius: BorderRadius.circular(12),
    ),
    child: const Icon(Icons.bolt_rounded, color: ink, size: 29),
  );
}

class _Pill extends StatelessWidget {
  const _Pill(this.text, this.color);
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      text,
      style: TextStyle(
        color: color,
        fontWeight: FontWeight.w800,
        fontSize: 10,
        letterSpacing: 1,
      ),
    ),
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      fontWeight: FontWeight.w900,
      letterSpacing: 1.5,
      fontSize: 13,
    ),
  );
}

class _ExercisePreview extends StatelessWidget {
  const _ExercisePreview({
    required this.e,
    required this.best,
    required this.unit,
  });
  final ExercisePlan e;
  final SetLog? best;
  final String unit;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 9),
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: panel,
      borderRadius: BorderRadius.circular(17),
    ),
    child: Row(
      children: [
        Container(
          width: 41,
          height: 41,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .06),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            e.primary ? Icons.bolt : Icons.fitness_center,
            color: e.primary ? lime : Colors.white54,
            size: 20,
          ),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(e.name, style: const TextStyle(fontWeight: FontWeight.w700)),
              Text(
                '${e.sets} × ${e.reps}${best == null ? '' : '  •  Best ${best!.weight.g} $unit'}',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
        ),
        const Icon(Icons.chevron_right, color: Colors.white24),
      ],
    ),
  );
}

class _Metric extends StatelessWidget {
  const _Metric({required this.value, required this.label});
  final String value, label;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: panel,
      borderRadius: BorderRadius.circular(18),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 27,
            fontWeight: FontWeight.w900,
            color: lime,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white38,
            fontWeight: FontWeight.w800,
            fontSize: 10,
            letterSpacing: 1,
          ),
        ),
      ],
    ),
  );
}

class _Previous extends StatelessWidget {
  const _Previous({required this.best, required this.unit});
  final SetLog? best;
  final String unit;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(17),
    decoration: BoxDecoration(
      color: panel,
      borderRadius: BorderRadius.circular(17),
    ),
    child: Row(
      children: [
        const Icon(Icons.history, color: Colors.white38),
        const SizedBox(width: 12),
        Text(
          best == null
              ? 'No previous sets'
              : 'Best  ${best!.weight.g} $unit × ${best!.reps}',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const Spacer(),
        if (best != null)
          Text(
            'e1RM ${best!.e1rm.round()}',
            style: const TextStyle(color: lime),
          ),
      ],
    ),
  );
}

class _PrTile extends StatelessWidget {
  const _PrTile({required this.log, required this.unit});
  final SetLog log;
  final String unit;
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: const CircleAvatar(
      backgroundColor: lime,
      foregroundColor: ink,
      child: Icon(Icons.emoji_events_rounded),
    ),
    title: Text(
      log.exercise,
      style: const TextStyle(fontWeight: FontWeight.w700),
    ),
    subtitle: Text('Estimated 1RM ${log.e1rm.round()} $unit'),
    trailing: Text(
      '${log.weight.g} × ${log.reps}',
      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
    ),
  );
}

class _Empty extends StatelessWidget {
  const _Empty();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(25),
    decoration: BoxDecoration(
      color: panel,
      borderRadius: BorderRadius.circular(18),
    ),
    child: const Text(
      'Your first PR appears after you log a working set.',
      style: TextStyle(color: Colors.white54),
    ),
  );
}

class _Setting extends StatelessWidget {
  const _Setting({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.available,
  });
  final IconData icon;
  final String title, subtitle;
  final bool available;
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: CircleAvatar(
      backgroundColor: Colors.white10,
      child: Icon(icon, color: available ? cyan : Colors.white38),
    ),
    title: Text(title),
    subtitle: Text(subtitle),
    trailing: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: (available ? lime : Colors.white38).withValues(alpha: .1),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        available ? 'ACTIVE' : 'PLANNED',
        style: TextStyle(
          color: available ? lime : Colors.white38,
          fontSize: 9,
          fontWeight: FontWeight.w900,
          letterSpacing: .8,
        ),
      ),
    ),
  );
}

class _QuickHelp extends StatelessWidget {
  const _QuickHelp();
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'HOW PROGRESSION WORKS',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 14),
        const Text(
          'Hit the prescribed reps with clean form and 1–2 reps in reserve. When you own the top of a rep range, add the smallest practical weight next time. Deload weeks reduce fatigue automatically.',
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('GOT IT'),
          ),
        ),
      ],
    ),
  );
}

extension _WeightDisplay on double {
  String get g => toStringAsFixed(this % 1 == 0 ? 0 : 1);
}
