import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_tour.dart';
import 'athletic_program.dart';
import 'athletic_training.dart';
import 'brand.dart';
import 'daily_inputs_screen.dart';
import 'exercise_library_screen.dart';
import 'lab_screen.dart';
import 'logged_sets.dart';
import 'program.dart';
import 'program_navigator.dart';
import 'progress_dashboard.dart';
import 'share_card.dart';
import 'store.dart';
import 'warmup.dart';

void main() => runApp(const ProgressionLabApp());

const ink = BrandColors.ink;
const panel = BrandColors.panel;
const lime = BrandColors.violet;
const cyan = BrandColors.cyan;
const violet = BrandColors.purple;
const muted = BrandColors.muted;

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
      theme: ProgressionBrand.theme(),
      builder: (context, child) => Material(
        type: MaterialType.transparency,
        textStyle: Theme.of(context).textTheme.bodyMedium,
        child: child ?? const SizedBox.shrink(),
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
  static const _tourVersion = 1;

  final _homePrimaryKey = GlobalKey(debugLabel: 'home-primary');
  final _programsOverviewKey = GlobalKey(debugLabel: 'programs-overview');
  final _progressNavKey = GlobalKey(debugLabel: 'progress-nav');
  final _moreNavKey = GlobalKey(debugLabel: 'more-nav');
  final _helpGuidesKey = GlobalKey(debugLabel: 'help-guides');

  int index = 0;
  int? _tourStep;
  bool _autoTourHandled = false;

  List<NavigationDestination> get _destinations => [
    const NavigationDestination(
      icon: Icon(Icons.home_rounded),
      label: 'Home',
    ),
    const NavigationDestination(
      icon: Icon(Icons.dashboard_customize_rounded),
      label: 'Programs',
    ),
    NavigationDestination(
      icon: KeyedSubtree(
        key: _progressNavKey,
        child: const Icon(Icons.query_stats_rounded),
      ),
      label: 'Progress',
    ),
    NavigationDestination(
      icon: KeyedSubtree(
        key: _moreNavKey,
        child: const Icon(Icons.more_horiz_rounded),
      ),
      label: 'More',
    ),
  ];

  List<AppTourStep> get _tourSteps => [
    AppTourStep(
      targetKey: _homePrimaryKey,
      title: 'Start with the next session',
      body:
          'Home keeps one clear action in front of you. Switch between Strength and Athletic only when you need to.',
    ),
    AppTourStep(
      targetKey: _programsOverviewKey,
      title: 'Both programs live together',
      body:
          'Programs contains the 48-week Strength plan and 12-week Athletic plan. Each keeps its own progress.',
    ),
    AppTourStep(
      targetKey: _progressNavKey,
      title: 'See what is changing',
      body:
          'Progress brings together logged sets, records, workout history, charts, and Athletic field assessments.',
    ),
    AppTourStep(
      targetKey: _moreNavKey,
      title: 'Tools stay out of the way',
      body:
          'More contains setup, the exercise library, help, and advanced controls so Home stays focused.',
    ),
    AppTourStep(
      targetKey: _helpGuidesKey,
      title: 'Replay this tour anytime',
      body:
          'Open More → Help & Guides → App Tour whenever you want this walkthrough again.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    widget.store.addListener(_maybeStartAutomaticTour);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeStartAutomaticTour();
    });
  }

  @override
  void didUpdateWidget(covariant Shell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.store != widget.store) {
      oldWidget.store.removeListener(_maybeStartAutomaticTour);
      widget.store.addListener(_maybeStartAutomaticTour);
      _autoTourHandled = false;
      _maybeStartAutomaticTour();
    }
  }

  @override
  void dispose() {
    widget.store.removeListener(_maybeStartAutomaticTour);
    super.dispose();
  }

  void _maybeStartAutomaticTour() {
    if (!mounted || _autoTourHandled || !widget.store.isLoaded) return;
    _autoTourHandled = true;
    if (widget.store.onboardingVersionSeen < _tourVersion) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _startTour();
      });
    }
  }

  void _startTour() {
    setState(() {
      index = 0;
      _tourStep = 0;
    });
  }

  void _showTourStep(int step) {
    final page = switch (step) {
      0 => 0,
      1 => 1,
      2 => 2,
      _ => 3,
    };
    setState(() {
      index = page;
      _tourStep = step;
    });
  }

  void _nextTourStep() {
    final current = _tourStep;
    if (current == null) return;
    if (current >= _tourSteps.length - 1) {
      unawaited(_closeTour(skipped: false));
    } else {
      _showTourStep(current + 1);
    }
  }

  void _previousTourStep() {
    final current = _tourStep;
    if (current == null || current == 0) return;
    _showTourStep(current - 1);
  }

  Future<void> _closeTour({required bool skipped}) async {
    setState(() => _tourStep = null);
    try {
      await widget.store.markOnboardingSeen(_tourVersion);
    } on Object {
      // The tour remains dismissible even if local persistence is unavailable.
    }
    if (!mounted || !skipped) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Tour skipped. Replay it from More → Help & Guides.'),
      ),
    );
  }

  void _openStrengthProgram() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProgramNavigatorPage(
          store: widget.store,
          onOpenWorkout: _openStrengthWorkout,
        ),
      ),
    );
  }

  void _openStrengthWorkout(
    ProgramWeek week,
    int workoutIndex,
    bool retroactive,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WorkoutScreen(
          store: widget.store,
          week: week,
          workout: week.workouts[workoutIndex],
          workoutIndex: workoutIndex,
          retroactive: retroactive,
          scheduledDate: widget.store.dateForSlot(week.number, workoutIndex),
        ),
      ),
    );
  }

  void _openAthleticProgram() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AthleticTrainingPage(store: widget.store),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      TodayPage(
        store: widget.store,
        primaryActionKey: _homePrimaryKey,
        onOpenPrograms: () => setState(() => index = 1),
      ),
      ProgramsHubPage(
        store: widget.store,
        overviewKey: _programsOverviewKey,
        onOpenStrength: _openStrengthProgram,
        onOpenAthletic: _openAthleticProgram,
      ),
      ProgressDashboard(store: widget.store),
      SettingsPage(
        store: widget.store,
        helpGuidesKey: _helpGuidesKey,
        onReplayTour: _startTour,
      ),
    ];
    final body = BrandBackdrop(
      child: SafeArea(
        child: IndexedStack(index: index, children: pages),
      ),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 760;
        final destinations = _destinations;
        final scaffold = wide
            ? Scaffold(
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
                        destinations: destinations
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
              )
            : Scaffold(
                body: body,
                bottomNavigationBar: NavigationBar(
                  selectedIndex: index,
                  onDestinationSelected: (value) =>
                      setState(() => index = value),
                  destinations: destinations,
                ),
              );
        return Stack(
          children: [
            scaffold,
            if (_tourStep case final int step)
              AppTourOverlay(
                steps: _tourSteps,
                stepIndex: step,
                onNext: _nextTourStep,
                onBack: step == 0 ? null : _previousTourStep,
                onSkip: () => unawaited(_closeTour(skipped: true)),
              ),
          ],
        );
      },
    );
  }
}

class TodayPage extends StatelessWidget {
  const TodayPage({
    super.key,
    required this.store,
    required this.primaryActionKey,
    required this.onOpenPrograms,
  });

  final AppStore store;
  final GlobalKey primaryActionKey;
  final VoidCallback onOpenPrograms;

  @override
  Widget build(BuildContext context) {
    final strengthWeek = ProgramEngine.week(store.week, store.days);
    final strengthWorkout =
        strengthWeek.workouts[store.workoutIndex
            .clamp(0, strengthWeek.workouts.length - 1)
            .toInt()];
    final athleticWeek = AthleticProgram.week(store.athleticWeek);
    final athleticSession = athleticWeek.sessions[store.athleticSessionIndex];
    final strengthDoneThisWeek = store.workoutHistory
        .where(
          (record) =>
              record.programRun == store.strengthProgramRun &&
              record.week == store.week &&
              record.days == store.days &&
              record.status == WorkoutStatus.completed,
        )
        .length;
    final athleticDoneThisWeek = store.athleticHistory
        .where(
          (record) =>
              record.programRun == store.athleticProgramRun &&
              record.week == store.athleticWeek,
        )
        .length;

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
                      BrandWordmark(compact: true),
                      SizedBox(height: 4),
                      Text(
                        'TEST · TRAIN · TRANSFORM',
                        style: TextStyle(
                          color: BrandColors.muted,
                          fontSize: 9,
                          letterSpacing: 1.35,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Quick help',
                  onPressed: () => showModalBottomSheet(
                    context: context,
                    useSafeArea: true,
                    builder: (_) => const _QuickHelp(),
                  ),
                  icon: const Icon(Icons.help_outline_rounded),
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          sliver: SliverList.list(
            children: [
              const BrandSectionLabel('Next session'),
              const SizedBox(height: 14),
              SegmentedButton<TrainingTrack>(
                segments: const [
                  ButtonSegment(
                    value: TrainingTrack.strength,
                    icon: Icon(Icons.fitness_center_rounded),
                    label: Text('STRENGTH'),
                  ),
                  ButtonSegment(
                    value: TrainingTrack.athletic,
                    icon: Icon(Icons.directions_run_rounded),
                    label: Text('ATHLETIC'),
                  ),
                ],
                selected: {store.preferredTrack},
                onSelectionChanged: (selection) {
                  unawaited(
                    store
                        .setPreferredTrack(selection.first)
                        .catchError((Object _) {}),
                  );
                },
              ),
              const SizedBox(height: 14),
              KeyedSubtree(
                key: primaryActionKey,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 260),
                  child: store.preferredTrack == TrainingTrack.strength
                      ? _StrengthHomeCard(
                          key: const ValueKey('strength-home-card'),
                          store: store,
                          week: strengthWeek,
                          workout: strengthWorkout,
                        )
                      : _AthleticHomeCard(
                          key: const ValueKey('athletic-home-card'),
                          store: store,
                          week: athleticWeek,
                          session: athleticSession,
                        ),
                ),
              ),
              const SizedBox(height: 18),
              TodayInputsCard(store: store),
              const SizedBox(height: 24),
              BrandSectionLabel(
                'This week',
                trailing: TextButton(
                  onPressed: onOpenPrograms,
                  child: const Text('VIEW PROGRAMS'),
                ),
              ),
              const SizedBox(height: 10),
              LabPanel(
                accent: BrandColors.cyan,
                child: Row(
                  children: [
                    Expanded(
                      child: _HomeSummaryMetric(
                        icon: Icons.fitness_center_rounded,
                        value: '$strengthDoneThisWeek/${store.days}',
                        label: 'STRENGTH',
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 54,
                      color: BrandColors.line,
                    ),
                    Expanded(
                      child: _HomeSummaryMetric(
                        icon: Icons.directions_run_rounded,
                        value:
                            '$athleticDoneThisWeek/${AthleticProgram.sessionsPerWeek}',
                        label: 'ATHLETIC',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              LabPanel(
                accent: BrandColors.violet,
                onTap: onOpenPrograms,
                child: const Row(
                  children: [
                    Icon(Icons.dashboard_customize_rounded,
                        color: BrandColors.violet),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'PROGRAMS',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              letterSpacing: .8,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Browse cycles, weeks, schedules, and past sessions.',
                            style: TextStyle(
                              color: BrandColors.muted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.arrow_forward_rounded,
                        color: BrandColors.muted),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StrengthHomeCard extends StatelessWidget {
  const _StrengthHomeCard({
    super.key,
    required this.store,
    required this.week,
    required this.workout,
  });

  final AppStore store;
  final ProgramWeek week;
  final WorkoutPlan workout;

  @override
  Widget build(BuildContext context) {
    final resuming =
        store.draftFor(
          weekNumber: store.week,
          targetWorkoutIndex: store.workoutIndex,
          cadence: store.days,
          retroactive: false,
        ) !=
        null;
    final totalSets = workout.exercises.fold<int>(
      0,
      (sum, exercise) => sum + exercise.sets,
    );
    return LabPanel(
      accent: BrandColors.violet,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bolt_rounded, color: BrandColors.violet),
              const SizedBox(width: 8),
              Text(
                'WEEK ${week.number} · PHASE ${week.phase}',
                style: const TextStyle(
                  color: BrandColors.cyan,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
              const Spacer(),
              Text(
                resuming ? 'IN PROGRESS' : 'READY',
                style: const TextStyle(
                  color: BrandColors.violet,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            workout.name.toUpperCase(),
            style: const TextStyle(
              fontSize: 31,
              height: 1,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${workout.exercises.length} exercises · $totalSets working sets · ${store.days}-day cadence',
            style: const TextStyle(color: BrandColors.muted),
          ),
          const SizedBox(height: 18),
          GradientAction(
            label: resuming ? 'RESUME STRENGTH WORKOUT' : 'START STRENGTH WORKOUT',
            icon: resuming ? Icons.play_arrow_rounded : Icons.bolt_rounded,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => WorkoutScreen(
                  store: store,
                  week: week,
                  workout: workout,
                  workoutIndex: store.workoutIndex,
                  scheduledDate: store.dateForSlot(
                    week.number,
                    store.workoutIndex,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              title: const Text(
                'SESSION PREVIEW',
                style: TextStyle(
                  color: BrandColors.muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .8,
                ),
              ),
              children: [
                for (final exercise in workout.exercises)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.fiber_manual_record,
                          size: 7,
                          color: BrandColors.cyan,
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: Text(exercise.name)),
                        Text(
                          '${exercise.sets} × ${exercise.reps}',
                          style: const TextStyle(color: BrandColors.muted),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AthleticHomeCard extends StatelessWidget {
  const _AthleticHomeCard({
    super.key,
    required this.store,
    required this.week,
    required this.session,
  });

  final AppStore store;
  final AthleticWeek week;
  final AthleticSession session;

  @override
  Widget build(BuildContext context) => LabPanel(
    accent: BrandColors.cyan,
    padding: const EdgeInsets.all(20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.directions_run_rounded, color: BrandColors.cyan),
            const SizedBox(width: 8),
            Text(
              'WEEK ${week.number} · SESSION ${store.athleticSessionIndex + 1}',
              style: const TextStyle(
                color: BrandColors.cyan,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
              ),
            ),
            const Spacer(),
            Text(
              '${(store.athleticProgress * 100).round()}%',
              style: const TextStyle(
                color: BrandColors.violet,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          session.name.toUpperCase(),
          style: const TextStyle(
            fontSize: 31,
            height: 1,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${week.cycleName} · ${session.durationMinutes} min · ${session.drills.length} coached drills',
          style: const TextStyle(color: BrandColors.muted),
        ),
        const SizedBox(height: 18),
        GradientAction(
          label: 'START ATHLETIC SESSION',
          icon: Icons.play_arrow_rounded,
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AthleticSessionScreen(
                store: store,
                week: week,
                sessionIndex: store.athleticSessionIndex,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: EdgeInsets.zero,
            title: const Text(
              'SESSION PREVIEW',
              style: TextStyle(
                color: BrandColors.muted,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: .8,
              ),
            ),
            children: [
              for (final drill in session.drills.take(5))
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.fiber_manual_record,
                        size: 7,
                        color: BrandColors.violet,
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(drill.name)),
                      Text(
                        drill.prescription,
                        style: const TextStyle(
                          color: BrandColors.muted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _HomeSummaryMetric extends StatelessWidget {
  const _HomeSummaryMetric({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Icon(icon, color: BrandColors.cyan, size: 20),
      const SizedBox(height: 7),
      Text(
        value,
        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
      ),
      Text(
        label,
        style: const TextStyle(
          color: BrandColors.muted,
          fontSize: 9,
          fontWeight: FontWeight.w900,
          letterSpacing: 1,
        ),
      ),
    ],
  );
}

class ProgramsHubPage extends StatelessWidget {
  const ProgramsHubPage({
    super.key,
    required this.store,
    required this.overviewKey,
    required this.onOpenStrength,
    required this.onOpenAthletic,
  });

  final AppStore store;
  final GlobalKey overviewKey;
  final VoidCallback onOpenStrength;
  final VoidCallback onOpenAthletic;

  @override
  Widget build(BuildContext context) {
    final strengthWeek = ProgramEngine.week(store.week, store.days);
    final athleticWeek = AthleticProgram.week(store.athleticWeek);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 34),
      children: [
        const Row(
          children: [
            LabMark(size: 54),
            SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'PROGRAMS',
                    style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Two systems. Independent progress.',
                    style: TextStyle(color: BrandColors.muted),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        KeyedSubtree(
          key: overviewKey,
          child: const LabPanel(
            accent: BrandColors.cyan,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.route_rounded, color: BrandColors.cyan),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Strength and Athletic Functional Training advance separately. Train either track without moving the other one.',
                    style: TextStyle(color: BrandColors.muted, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        _ProgramTrackCard(
          accent: BrandColors.violet,
          icon: Icons.fitness_center_rounded,
          eyebrow: '48-WEEK STRENGTH SYSTEM',
          title: 'Strength Program',
          description:
              'Periodized strength and hypertrophy with build, strength, and deload weeks.',
          progress: store.week / ProgramEngine.totalWeeks,
          position:
              'Week ${store.week} · Phase ${strengthWeek.phase} · ${store.days} days/week',
          actionLabel: 'OPEN STRENGTH PROGRAM',
          onTap: onOpenStrength,
        ),
        const SizedBox(height: 14),
        _ProgramTrackCard(
          accent: BrandColors.cyan,
          icon: Icons.directions_run_rounded,
          eyebrow: '12-WEEK ATHLETIC SYSTEM',
          title: 'Athletic Functional Training',
          description:
              'Gait, unilateral strength, rotation, elastic work, speed, and change of direction.',
          progress: store.athleticProgress,
          position:
              'Week ${store.athleticWeek} · ${athleticWeek.cycleName} · Session ${store.athleticSessionIndex + 1}',
          actionLabel: 'OPEN ATHLETIC PROGRAM',
          onTap: onOpenAthletic,
        ),
      ],
    );
  }
}

class _ProgramTrackCard extends StatelessWidget {
  const _ProgramTrackCard({
    required this.accent,
    required this.icon,
    required this.eyebrow,
    required this.title,
    required this.description,
    required this.progress,
    required this.position,
    required this.actionLabel,
    required this.onTap,
  });

  final Color accent;
  final IconData icon;
  final String eyebrow;
  final String title;
  final String description;
  final double progress;
  final String position;
  final String actionLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => LabPanel(
    accent: accent,
    padding: const EdgeInsets.all(20),
    onTap: onTap,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: .13),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(icon, color: accent),
            ),
            const Spacer(),
            Text(
              '${(progress.clamp(0.0, 1.0).toDouble() * 100).round()}%',
              style: TextStyle(
                color: accent,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 15),
        Text(
          eyebrow,
          style: TextStyle(
            color: accent,
            fontSize: 9,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          title,
          style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        Text(
          description,
          style: const TextStyle(color: BrandColors.muted, height: 1.42),
        ),
        const SizedBox(height: 14),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0).toDouble(),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          position,
          style: const TextStyle(
            color: BrandColors.muted,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Text(
              actionLabel,
              style: TextStyle(
                color: accent,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: .65,
              ),
            ),
            const Spacer(),
            Icon(Icons.arrow_forward_rounded, color: accent),
          ],
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
    required this.workoutIndex,
    required this.scheduledDate,
    this.retroactive = false,
  });
  final AppStore store;
  final ProgramWeek week;
  final WorkoutPlan workout;
  final int workoutIndex;
  final DateTime scheduledDate;
  final bool retroactive;
  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen>
    with WidgetsBindingObserver {
  int exercise = 0;
  int set = 1;
  int elapsed = 0;
  int rest = 0;
  int loggedSets = 0;
  Timer? timer;
  Timer? draftTimer;
  final weight = TextEditingController();
  final reps = TextEditingController();
  final notes = TextEditingController();
  late final String sessionId;
  final Map<int, String> substitutions = {};
  bool lastPr = false;
  bool sessionHadPr = false;
  bool finishing = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final draft = widget.store.draftFor(
      weekNumber: widget.week.number,
      targetWorkoutIndex: widget.workoutIndex,
      cadence: widget.store.days,
      retroactive: widget.retroactive,
    );
    final canRestore =
        draft != null &&
        draft.week == widget.week.number &&
        draft.workoutIndex == widget.workoutIndex &&
        draft.workout == widget.workout.name &&
        draft.days == widget.store.days &&
        draft.retroactive == widget.retroactive &&
        draft.exerciseIndex >= 0 &&
        draft.exerciseIndex < widget.workout.exercises.length &&
        draft.setNumber > 0 &&
        draft.setNumber <= widget.workout.exercises[draft.exerciseIndex].sets;
    if (canRestore) {
      exercise = draft.exerciseIndex;
      set = draft.setNumber;
      sessionId = draft.sessionId;
      substitutions.addAll(draft.substitutions);
      weight.text = draft.weight;
      reps.text = draft.reps;
      notes.text = draft.notes;
    } else {
      sessionId = DateTime.now().microsecondsSinceEpoch.toString();
      _seed();
    }
    loggedSets = widget.store.logs
        .where((log) => log.sessionId == sessionId)
        .length;
    weight.addListener(_draftChanged);
    reps.addListener(_draftChanged);
    notes.addListener(_draftChanged);
    _startTimer();
    unawaited(_persistDraft());
  }

  void _startTimer() {
    timer?.cancel();
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          elapsed++;
          if (rest > 0) rest--;
        });
      }
    });
  }

  void _seed({bool preserveWeight = false}) {
    final e = _exercisePlan(exercise);
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
    notes.clear();
  }

  void _draftChanged() {
    draftTimer?.cancel();
    draftTimer = Timer(const Duration(milliseconds: 250), () {
      unawaited(_persistDraft());
    });
  }

  Future<void> _persistDraft() async {
    if (finishing) return;
    final value = DraftSetInput(
      week: widget.week.number,
      workoutIndex: widget.workoutIndex,
      workout: widget.workout.name,
      exerciseIndex: exercise,
      setNumber: set,
      sessionId: sessionId,
      weight: weight.text,
      reps: reps.text,
      notes: notes.text,
      programRun: widget.store.strengthProgramRun,
      days: widget.store.days,
      retroactive: widget.retroactive,
      scheduledDate: widget.scheduledDate,
      substitutions: Map.unmodifiable(substitutions),
    );
    try {
      await widget.store.setDraft(value);
    } on Object {
      // Keep the live input usable and retry on the next edit/lifecycle event.
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      draftTimer?.cancel();
      unawaited(_persistDraft());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    timer?.cancel();
    draftTimer?.cancel();
    weight.removeListener(_draftChanged);
    reps.removeListener(_draftChanged);
    notes.removeListener(_draftChanged);
    unawaited(_persistDraft());
    weight.dispose();
    reps.dispose();
    notes.dispose();
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
    final e = _exercisePlan(exercise);
    if (_setsForExercise(exercise) >= e.sets) return;
    final pr = await widget.store.add(
      SetLog(
        exercise: e.name,
        weight: w,
        reps: r,
        date: DateTime.now(),
        workout: widget.workout.name,
        notes: notes.text,
        sessionId: sessionId,
        exerciseIndex: exercise,
      ),
    );
    if (!mounted) return;
    var workoutComplete = false;
    setState(() {
      lastPr = pr;
      sessionHadPr = sessionHadPr || pr;
      loggedSets++;
      rest = e.primary ? 180 : 120;
      final exerciseSets = _setsForExercise(exercise);
      if (exerciseSets < e.sets) {
        set++;
        if (e.amrap) {
          _seed(preserveWeight: true);
        } else {
          notes.clear();
        }
      } else if (exercise < widget.workout.exercises.length - 1) {
        exercise++;
        set = 1;
        lastPr = false;
        _seed();
      } else {
        workoutComplete = true;
      }
    });
    if (!workoutComplete) unawaited(_persistDraft());
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
    await _commitWorkout(WorkoutStatus.completed);
  }

  Future<void> _skipWorkout() async {
    if (finishing || widget.retroactive) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Skip this workout?'),
        content: const Text(
          'The workout will be marked skipped and the program will advance. Any sets already logged stay in history.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('KEEP TRAINING'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('SKIP WORKOUT'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await _commitWorkout(WorkoutStatus.skipped);
    }
  }

  Future<void> _commitWorkout(WorkoutStatus status) async {
    setState(() => finishing = true);
    timer?.cancel();
    timer = null;
    draftTimer?.cancel();
    try {
      await widget.store.recordWorkout(
        weekNumber: widget.week.number,
        targetWorkoutIndex: widget.workoutIndex,
        workout: widget.workout.name,
        status: status,
        sessionId: sessionId,
        substitutions: substitutions,
        retroactive: widget.retroactive,
        scheduledDate: widget.scheduledDate,
      );
      if (status == WorkoutStatus.completed && mounted) {
        await showWorkoutResponseSheet(
          context,
          widget.store,
          sessionId: sessionId,
          track: 'strength',
        );
      }
      if (status == WorkoutStatus.completed && mounted) {
        await showWorkoutCompleteSheet(context, _shareData());
      }
      if (mounted) Navigator.pop(context);
    } on Object {
      if (!mounted) return;
      setState(() => finishing = false);
      _startTimer();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save the workout. Try again.')),
      );
    }
  }

  WorkoutShareData _shareData() {
    final sessionLogs = widget.store.logs
        .where((log) => log.sessionId == sessionId)
        .toList();
    final totalVolume = sessionLogs.fold<double>(
      0,
      (sum, log) => sum + log.weight * log.reps,
    );
    SetLog? topSet;
    for (final log in sessionLogs) {
      if (topSet == null || log.e1rm > topSet.e1rm) topSet = log;
    }
    final exerciseCount = sessionLogs.map((log) => log.exercise).toSet().length;
    final topValue = topSet == null
        ? 'Workout completed'
        : '${topSet.exercise} · ${_shareWeight(topSet.weight)} ${widget.store.unit} × ${topSet.reps}';
    return WorkoutShareData(
      program: 'Strength Program',
      title: widget.workout.name,
      contextLine:
          'Week ${widget.week.number} · Phase ${widget.week.phase} · ${widget.week.label}',
      completedAt: DateTime.now(),
      achievementLabel: sessionHadPr ? 'New personal record' : null,
      metrics: [
        ShareMetric('Duration', formatShareDuration(Duration(seconds: elapsed))),
        ShareMetric('Sets', '${sessionLogs.length}'),
        ShareMetric(
          'Volume',
          '${_compactNumber(totalVolume)} ${widget.store.unit}',
        ),
        ShareMetric('Exercises', '$exerciseCount'),
      ],
      highlightLabel: topSet == null ? 'Session' : 'Top set',
      highlightValue: topValue,
    );
  }

  String _shareWeight(double value) => value == value.roundToDouble()
      ? value.round().toString()
      : value.toStringAsFixed(1);

  String _compactNumber(double value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
    return value.round().toString();
  }

  @override
  Widget build(BuildContext context) {
    final e = _exercisePlan(exercise);
    final activeLogs = widget.store.logs
        .where((log) => log.sessionId == sessionId && log.exercise == e.name)
        .length;
    final progress =
        (exercise + ((set - 1) / e.sets)) / widget.workout.exercises.length;
    final exerciseComplete = _setsForExercise(exercise) >= e.sets;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(
          '${_clock(elapsed)}  •  ${widget.workout.name}'
          '${widget.retroactive ? '  •  RETRO' : ''}',
        ),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Workout actions',
            enabled: !finishing,
            onSelected: (value) {
              if (value == 'skip') unawaited(_skipWorkout());
            },
            itemBuilder: (_) => widget.retroactive
                ? const []
                : const [
                    PopupMenuItem(value: 'skip', child: Text('SKIP WORKOUT')),
                  ],
          ),
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
              IconButton(
                tooltip: 'Substitute exercise',
                onPressed: _setsForExercise(exercise) == 0 && !finishing
                    ? () => _chooseSubstitution(exercise)
                    : null,
                icon: const Icon(Icons.swap_horiz_rounded),
              ),
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
          if (substitutions.containsKey(exercise)) ...[
            const SizedBox(height: 5),
            Text(
              'SUBSTITUTED FOR ${widget.workout.exercises[exercise].name.toUpperCase()}',
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (e.primary &&
              WarmupCalculator.supports(e.name) &&
              _setsForExercise(exercise) == 0)
            ListenableBuilder(
              listenable: Listenable.merge([weight, reps]),
              builder: (context, _) {
                final recommendation = WarmupCalculator.calculate(
                  exercise: e.name,
                  isPrimary: e.primary,
                  workingWeight: double.tryParse(weight.text),
                  workingReps: int.tryParse(reps.text),
                  unit: widget.store.unit,
                );
                if (recommendation == null) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 18),
                  child: _WarmupCard(recommendation: recommendation),
                );
              },
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
          const SizedBox(height: 12),
          TextField(
            controller: notes,
            minLines: 1,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'SET NOTES',
              hintText: 'Optional notes for this set',
            ),
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
              onPressed: finishing || exerciseComplete ? null : _log,
              style: FilledButton.styleFrom(
                backgroundColor: lime,
                foregroundColor: Colors.white,
              ),
              child: Text(
                exerciseComplete ? 'EXERCISE COMPLETE' : 'LOG SET',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Card(
            margin: EdgeInsets.zero,
            child: ExpansionTile(
              leading: const Icon(Icons.history_rounded, color: cyan),
              title: Text(
                'LOGGED SETS ($activeLogs)',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text('Saved for ${e.name} in this workout'),
              childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              children: [
                LoggedSetsEditor(
                  store: widget.store,
                  predicate: (log) =>
                      log.sessionId == sessionId && log.exercise == e.name,
                  emptyMessage: 'No sets logged for this exercise yet.',
                  compact: true,
                ),
              ],
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
          ...widget.workout.exercises.asMap().entries.map((x) {
            final exercisePlan = _exercisePlan(x.key);
            final loggedForSlot = _setsForExercise(x.key);
            final done = x.key < exercise;
            return ListTile(
              contentPadding: EdgeInsets.zero,
              selected: x.key == exercise,
              leading: CircleAvatar(
                backgroundColor: done ? lime : Colors.white10,
                child: Icon(
                  done ? Icons.check : Icons.fitness_center,
                  color: done ? ink : Colors.white54,
                  size: 18,
                ),
              ),
              title: Text(exercisePlan.name),
              subtitle: substitutions.containsKey(x.key)
                  ? Text('For ${x.value.name}')
                  : null,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${exercisePlan.sets} × ${exercisePlan.reps}',
                    style: const TextStyle(color: Colors.white54),
                  ),
                  IconButton(
                    tooltip: 'Substitute ${x.value.name}',
                    onPressed: loggedForSlot == 0 && !finishing
                        ? () => _chooseSubstitution(x.key)
                        : null,
                    icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  String _clock(int s) =>
      '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

  ExercisePlan _exercisePlan(int index) {
    final prescribed = widget.workout.exercises[index];
    final replacement = substitutions[index];
    if (replacement == null) return prescribed;
    return ExercisePlan(
      replacement,
      prescribed.sets,
      prescribed.reps,
      primary: prescribed.primary,
      amrap: prescribed.amrap,
    );
  }

  int _setsForExercise(int index) {
    final name = _exercisePlan(index).name;
    return widget.store.logs
        .where(
          (log) =>
              log.sessionId == sessionId &&
              (log.exerciseIndex == index ||
                  (log.exerciseIndex == null && log.exercise == name)),
        )
        .length;
  }

  Future<void> _chooseSubstitution(int index) async {
    if (_setsForExercise(index) > 0) return;
    final prescribed = widget.workout.exercises[index];
    final alternatives = widget.store.selectableExercises
        .where((item) => item.name != prescribed.name)
        .toList();
    var selected = substitutions[index] ?? prescribed.name;
    final choice = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            22,
            20,
            20 + MediaQuery.viewInsetsOf(sheetContext).bottom,
          ),
          child: StatefulBuilder(
            builder: (context, setSheetState) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'SUBSTITUTE EXERCISE',
                  style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 5),
                Text(
                  '${prescribed.name} • this session only',
                  style: const TextStyle(color: Colors.white54),
                ),
                const SizedBox(height: 18),
                DropdownButtonFormField<String>(
                  initialValue: selected,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'EXERCISE'),
                  items: [
                    DropdownMenuItem(
                      value: prescribed.name,
                      child: Text('${prescribed.name} (prescribed)'),
                    ),
                    for (final item in alternatives)
                      DropdownMenuItem(
                        value: item.name,
                        child: Text(
                          '${item.name}${item.isBuiltIn ? '' : ' • Custom'}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setSheetState(() => selected = value);
                    }
                  },
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(sheetContext, selected),
                    child: const Text('APPLY TO SESSION'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (choice == null || !mounted) return;
    setState(() {
      if (choice == prescribed.name) {
        substitutions.remove(index);
      } else {
        substitutions[index] = choice;
      }
      if (exercise == index) _seed();
    });
    await _persistDraft();
  }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    required this.store,
    required this.onReplayTour,
    required this.helpGuidesKey,
  });

  final AppStore store;
  final VoidCallback onReplayTour;
  final GlobalKey helpGuidesKey;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 24, 20, 30),
    children: [
      const Row(
        children: [
          LabMark(size: 54),
          SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'MORE & SETUP',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
                ),
                SizedBox(height: 4),
                Text(
                  'Program controls and training tools',
                  style: TextStyle(color: BrandColors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 24),
      const BrandSectionLabel('Help & Guides'),
      const SizedBox(height: 8),
      _Setting(
        key: helpGuidesKey,
        icon: Icons.route_rounded,
        title: 'App Tour',
        subtitle: 'Replay the guided walkthrough of Home, Programs, and tools',
        available: true,
        badge: 'REPLAY',
        onTap: onReplayTour,
      ),
      _Setting(
        icon: Icons.lightbulb_outline_rounded,
        title: 'How progression works',
        subtitle: 'Review the core strength progression rules',
        available: true,
        badge: 'GUIDE',
        onTap: () => showModalBottomSheet(
          context: context,
          useSafeArea: true,
          builder: (_) => const _QuickHelp(),
        ),
      ),
      const SizedBox(height: 22),
      const BrandSectionLabel('Tracking & Intelligence'),
      const SizedBox(height: 8),
      _Setting(
        icon: Icons.science_rounded,
        title: 'Supplements & Daily Inputs',
        subtitle: 'Creatine, caffeine, meals, hydration, sleep, and recovery',
        available: true,
        badge: 'TRACK',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => DailyInputsScreen(store: store)),
        ),
      ),
      _Setting(
        icon: Icons.auto_awesome_rounded,
        title: 'The Lab',
        subtitle: 'Evidence-first insights with optional on-device Gemini Nano',
        available: true,
        badge: store.aiAnalysisEnabled ? 'AI ON' : 'AI OFF',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => LabScreen(store: store)),
        ),
      ),
      _Setting(
        icon: Icons.insights_rounded,
        title: 'Inputs & Performance',
        subtitle: 'Compare logged inputs with matched workout outcomes',
        available: true,
        badge: 'LAB CORE',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => InputsPerformanceScreen(store: store),
          ),
        ),
      ),
      const SizedBox(height: 22),
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
            showCadenceSwitchSheet(context, store, requestedDays: requested);
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
      _Setting(
        icon: Icons.fitness_center_rounded,
        title: 'Exercise library',
        subtitle: 'Browse built-ins or manage custom exercises',
        available: true,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ExerciseLibraryScreen(store: store),
          ),
        ),
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
  Widget build(BuildContext context) => const LabMark(size: 44);
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

class _WarmupCard extends StatelessWidget {
  const _WarmupCard({required this.recommendation});

  final WarmupRecommendation recommendation;

  String _weight(double value) => value == value.roundToDouble()
      ? value.round().toString()
      : value.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(17),
    decoration: BoxDecoration(
      color: cyan.withValues(alpha: .08),
      borderRadius: BorderRadius.circular(19),
      border: Border.all(color: cyan.withValues(alpha: .34)),
      boxShadow: [
        BoxShadow(
          color: cyan.withValues(alpha: .08),
          blurRadius: 22,
          spreadRadius: -8,
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: cyan.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.local_fire_department_rounded, color: cyan),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'AUTOMATIC WARM-UP',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      letterSpacing: .9,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Based on ${_weight(recommendation.workingWeight)} '
                    '${recommendation.unit} × ${recommendation.workingReps}',
                    style: const TextStyle(
                      color: BrandColors.muted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Text(
              'RAMP',
              style: TextStyle(
                color: cyan,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 15),
        Row(
          children: [
            for (var i = 0; i < recommendation.sets.length; i++) ...[
              if (i > 0) const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .045),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'WARM-UP ${i + 1} · ${recommendation.sets[i].percentage}%',
                        style: const TextStyle(
                          color: BrandColors.muted,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: .65,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '${_weight(recommendation.sets[i].weight)} '
                        '${recommendation.unit} × '
                        '${recommendation.sets[i].reps}',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 11),
        const Text(
          'Rest about 60 seconds between ramp sets. These do not count as working sets.',
          style: TextStyle(
            color: BrandColors.muted,
            fontSize: 11,
            height: 1.35,
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

class _Setting extends StatelessWidget {
  const _Setting({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.available,
    this.badge,
    this.onTap,
  });
  final IconData icon;
  final String title, subtitle;
  final bool available;
  final String? badge;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: ListTile(
      onTap: onTap,
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
          badge ?? (available ? 'ACTIVE' : 'PLANNED'),
          style: TextStyle(
            color: available ? lime : Colors.white38,
            fontSize: 9,
            fontWeight: FontWeight.w900,
            letterSpacing: .8,
          ),
        ),
      ),
    ),
  );
}

class _QuickHelp extends StatelessWidget {
  const _QuickHelp();
  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    minimum: const EdgeInsets.only(bottom: 8),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
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
    ),
  );
}

extension _WeightDisplay on double {
  String get g => toStringAsFixed(this % 1 == 0 ? 0 : 1);
}
