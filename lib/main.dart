import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_tour.dart';
import 'athletic_program.dart';
import 'athletic_training.dart';
import 'brand.dart';
import 'daily_inputs_screen.dart';
import 'data_management_screen.dart';
import 'exercise_library.dart';
import 'exercise_library_screen.dart';
import 'first_launch_data_flow.dart';
import 'logged_sets.dart';
import 'program.dart';
import 'program_navigator.dart';
import 'progress_hub.dart';
import 'body_progress_screen.dart';
import 'share_card.dart';
import 'share_options.dart';
import 'exercise_metrics.dart';
import 'plate_calculator.dart';
import 'safe_layout.dart';
import 'store.dart';
import 'contextual_guides.dart';
import 'warmup.dart';

import 'integrations_hub.dart';
import 'cloud_sync.dart';

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
  CloudBackupSyncService? _automaticCloudSync;

  final store = AppStore();
  @override
  void initState() {
    super.initState();
    _automaticCloudSync = CloudBackupSyncService.shared(store);
    unawaited(_load());
  }

  Future<void> _load() async {
    await store.load();
    await _automaticCloudSync!.initialize();
  }

  @override
  void dispose() {
    _automaticCloudSync?.dispose();
    store.dispose();
    super.dispose();
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
      home: store.isLoaded
          ? Shell(store: store)
          : const Scaffold(body: Center(child: CircularProgressIndicator())),
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
  bool _startupDataFlowHandled = false;

  List<NavigationDestination> get _destinations => [
    const NavigationDestination(icon: Icon(Icons.home_rounded), label: 'Home'),
    const NavigationDestination(
      icon: Icon(Icons.dashboard_customize_rounded),
      label: 'Programs',
    ),
    const NavigationDestination(
      icon: Icon(Icons.add_circle_outline_rounded),
      label: 'Track',
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
          'Track holds daily inputs. More holds preferences, connections, sharing defaults, backup, and help.',
    ),
    AppTourStep(
      targetKey: _helpGuidesKey,
      title: 'Replay this tour anytime',
      body:
          'Open More → Help & Guides → App Tour whenever you want this walkthrough again.',
    ),
  ];

  static const _bodyLaunch = MethodChannel('progression_lab/body_launch');
  void _openBodyProgress() {
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BodyProgressScreen(store: widget.store),
      ),
    );
  }

  Future<void> _checkBodyLaunch() async {
    try {
      if (await _bodyLaunch.invokeMethod<bool>('consumeLaunch') == true)
        _openBodyProgress();
    } on MissingPluginException {
      /* Android notification route. */
    }
  }

  @override
  void initState() {
    super.initState();
    _bodyLaunch.setMethodCallHandler((call) async {
      if (call.method == 'openBody') _openBodyProgress();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkBodyLaunch());
    widget.store.addListener(_maybeStartStartupDataFlow);
    widget.store.addListener(_maybeStartAutomaticTour);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeStartStartupDataFlow();
      _maybeStartAutomaticTour();
    });
  }

  @override
  void didUpdateWidget(covariant Shell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.store != widget.store) {
      oldWidget.store.removeListener(_maybeStartStartupDataFlow);
      oldWidget.store.removeListener(_maybeStartAutomaticTour);
      widget.store.addListener(_maybeStartStartupDataFlow);
      widget.store.addListener(_maybeStartAutomaticTour);
      _startupDataFlowHandled = false;
      _autoTourHandled = false;
      _maybeStartStartupDataFlow();
      _maybeStartAutomaticTour();
    }
  }

  @override
  void dispose() {
    widget.store.removeListener(_maybeStartStartupDataFlow);
    widget.store.removeListener(_maybeStartAutomaticTour);
    _bodyLaunch.setMethodCallHandler(null);
    super.dispose();
  }

  void _maybeStartStartupDataFlow() {
    if (!mounted || _startupDataFlowHandled || !widget.store.isLoaded) return;
    _startupDataFlowHandled = true;
    if (widget.store.dataOnboardingVersionSeen >= FirstLaunchDataFlow.version) {
      _maybeStartAutomaticTour();
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await FirstLaunchDataFlow.present(context, widget.store);
      if (mounted) _maybeStartAutomaticTour();
    });
  }

  void _maybeStartAutomaticTour() {
    if (!mounted ||
        _autoTourHandled ||
        !widget.store.isLoaded ||
        widget.store.dataOnboardingVersionSeen < FirstLaunchDataFlow.version) {
      return;
    }
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
      2 => 3,
      _ => 4,
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
      DailyInputsScreen(store: widget.store, embedded: true),
      ProgressHub(store: widget.store),
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
    final today = DateUtils.dateOnly(DateTime.now());
    final weekStart = today.subtract(Duration(days: today.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 7));
    final strengthDoneThisWeek = store.workoutHistory
        .where(
          (record) =>
              record.status == WorkoutStatus.completed &&
              !record.date.isBefore(weekStart) &&
              record.date.isBefore(weekEnd),
        )
        .length;
    final athleticDoneThisWeek = store.athleticHistory
        .where(
          (record) =>
              record.isComplete &&
              !record.completedAt.isBefore(weekStart) &&
              record.completedAt.isBefore(weekEnd),
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
                          fontSize: 12,
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
                direction: MediaQuery.textScalerOf(context).scale(14) > 21
                    ? Axis.vertical
                    : Axis.horizontal,
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: TrainingTrack.strength,
                    icon: Icon(Icons.fitness_center_rounded),
                    label: Text('Strength'),
                  ),
                  ButtonSegment(
                    value: TrainingTrack.athletic,
                    icon: Icon(Icons.directions_run_rounded),
                    label: Text('Athletic'),
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
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 260),
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
                    Container(width: 1, height: 54, color: BrandColors.line),
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
                    Icon(
                      Icons.dashboard_customize_rounded,
                      color: BrandColors.violet,
                    ),
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
                    Icon(Icons.arrow_forward_rounded, color: BrandColors.muted),
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
              Expanded(
                child: Text(
                  'WEEK ${week.number} · PHASE ${week.phase}',
                  style: const TextStyle(
                    color: BrandColors.cyan,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (MediaQuery.textScalerOf(context).scale(14) <= 21)
                Text(
                  resuming ? 'IN PROGRESS' : 'READY',
                  style: const TextStyle(
                    color: BrandColors.violet,
                    fontSize: 12,
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
            label: resuming ? 'Resume workout' : 'Start workout',
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
                  fontSize: 12,
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
                fontSize: 12,
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
          label:
              store.athleticDraft?.week == week.number &&
                  store.athleticDraft?.sessionIndex ==
                      store.athleticSessionIndex &&
                  store.athleticDraft?.programRun == store.athleticProgramRun
              ? 'Resume Athletic session'
              : 'Start Athletic session',
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
                fontSize: 12,
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
                          fontSize: 12,
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
          fontSize: 12,
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
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.fitness_center_outlined),
          title: const Text('Exercise library'),
          subtitle: const Text('Search movements and manage custom exercises'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ExerciseLibraryScreen(store: store),
            ),
          ),
        ),
        const SizedBox(height: 12),
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
          progress: store.strengthCompletion,
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
            fontSize: 12,
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
            fontSize: 12,
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
                fontSize: 12,
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
  final duration = TextEditingController();
  final distance = TextEditingController();
  final calories = TextEditingController();
  final notes = TextEditingController();
  late final String sessionId;
  final Map<int, String> substitutions = {};
  bool lastPr = false;
  bool sessionHadPr = false;
  bool finishing = false;
  bool logging = false;
  bool draftSaving = false;
  bool draftFailed = false;
  Future<void> _draftWrites = Future.value();
  late DateTime startedAt;
  DateTime? restEndsAt;

  List<TextEditingController> get _draftControllers => [
    weight,
    reps,
    duration,
    distance,
    calories,
    notes,
  ];

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
        draft.programRun == widget.store.strengthProgramRun &&
        draft.exerciseIndex >= 0 &&
        draft.exerciseIndex < widget.workout.exercises.length &&
        draft.setNumber > 0 &&
        draft.setNumber <=
            widget.workout.exercises[draft.exerciseIndex].sets + 1;
    if (canRestore) {
      exercise = draft.exerciseIndex;
      set = draft.setNumber;
      sessionId = draft.sessionId;
      startedAt = draft.startedAt ?? DateTime.now();
      restEndsAt = draft.restEndsAt;
      substitutions.addAll(draft.substitutions);
      weight.text = draft.weight;
      reps.text = draft.reps;
      duration.text = draft.duration;
      distance.text = draft.distance;
      calories.text = draft.calories;
      notes.text = draft.notes;
    } else {
      startedAt = DateTime.now();
      sessionId = startedAt.microsecondsSinceEpoch.toString();
      _seed();
    }
    loggedSets = widget.store.logs
        .where((log) => log.sessionId == sessionId)
        .length;
    for (final controller in _draftControllers) {
      controller.addListener(_draftChanged);
    }
    _startTimer();
    unawaited(_persistDraft());
  }

  void _updateClock() {
    final now = DateTime.now();
    elapsed = now.difference(startedAt).inSeconds.clamp(0, 864000);
    rest = restEndsAt == null
        ? 0
        : restEndsAt!.difference(now).inSeconds.clamp(0, 3600);
  }

  void _startTimer() {
    timer?.cancel();
    _updateClock();
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(_updateClock);
    });
  }

  ExerciseOption _optionForIndex(int index) {
    final plan = _exercisePlan(index);
    final descriptor = ExerciseLibrary.descriptorFor(
      name: plan.name,
      customExercises: widget.store.customExercises,
    );
    if (descriptor != null) {
      return ExerciseLibrary.optionForDescriptor(
        descriptor,
        favoriteBuiltInIds: widget.store.favoriteBuiltInExerciseIds,
      );
    }
    return ExerciseOption(
      id: 'legacy-${ExerciseLibrary.normalize(plan.name).replaceAll(' ', '-')}',
      name: plan.name,
      primaryMuscle: MuscleGroup.other,
      secondaryMuscles: const [],
      equipment: ExerciseEquipment.other,
      movementPattern: MovementPattern.other,
      trackingType: ExerciseTrackingType.weightReps,
      unilateralMode: UnilateralMode.bilateral,
      isPrimaryCompound: plan.primary,
      warmupEligible: plan.primary && WarmupCalculator.supports(plan.name),
    );
  }

  void _seed({bool preserveWeight = false}) {
    final plan = _exercisePlan(exercise);
    final option = _optionForIndex(exercise);
    final type = option.trackingType;
    final best = widget.store.lastSet(
      plan.name,
      excludingSession: sessionId,
      type: type,
    );
    if (type.usesWeight && !preserveWeight) {
      weight.text =
          best == null ||
              best.resolvedTrackingType != type ||
              (type == ExerciseTrackingType.assistedBodyweight &&
                  best.weight <= 0)
          ? ''
          : _formatInputNumber(best.weight);
    } else if (!type.usesWeight) {
      weight.clear();
    }
    if (type.usesReps) {
      reps.text = plan.amrap && set == 1
          ? ''
          : plan.amrap && set == 2
          ? '4'
          : _targetRepsSeed(plan.reps);
    } else {
      reps.clear();
    }
    if (type.usesDuration) {
      duration.text = best?.durationSeconds == null
          ? ''
          : '${best!.durationSeconds}';
    } else {
      duration.clear();
    }
    if (type.usesDistance) {
      distance.text = best?.distance == null
          ? ''
          : _formatInputNumber(best!.distance!);
    } else {
      distance.clear();
    }
    if (type.usesCalories) {
      calories.text = best?.calories == null
          ? ''
          : _formatInputNumber(best!.calories!);
    } else {
      calories.clear();
    }
    notes.clear();
  }

  String _targetRepsSeed(String target) {
    final match = RegExp(r'\d+').firstMatch(target);
    return match?.group(0) ?? '';
  }

  String _formatInputNumber(double value) => value == value.roundToDouble()
      ? value.round().toString()
      : value.toStringAsFixed(1);

  void _draftChanged() {
    draftTimer?.cancel();
    draftTimer = Timer(const Duration(milliseconds: 250), () {
      unawaited(_persistDraft());
    });
  }

  Future<void> _persistDraft({bool updateUi = true}) async {
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
      duration: duration.text,
      distance: distance.text,
      calories: calories.text,
      notes: notes.text,
      programRun: widget.store.strengthProgramRun,
      days: widget.store.days,
      retroactive: widget.retroactive,
      scheduledDate: widget.scheduledDate,
      substitutions: Map.unmodifiable(substitutions),
      startedAt: startedAt,
      restEndsAt: restEndsAt,
    );
    if (mounted && updateUi) setState(() => draftSaving = true);
    _draftWrites = _draftWrites.then((_) async {
      try {
        await widget.store.setDraft(value);
        if (mounted)
          setState(() {
            draftSaving = false;
            draftFailed = false;
          });
      } on Object {
        if (mounted)
          setState(() {
            draftSaving = false;
            draftFailed = true;
          });
      }
    });
    await _draftWrites;
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
    unawaited(_persistDraft(updateUi: false));
    for (final controller in _draftControllers) {
      controller.removeListener(_draftChanged);
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _log() async {
    if (logging || finishing) return;
    final plan = _exercisePlan(exercise);
    final option = _optionForIndex(exercise);
    final type = option.trackingType;
    if (_setsForExercise(exercise) >= plan.sets) return;

    final parsedWeight = type.usesWeight
        ? double.tryParse(weight.text.trim())
        : 0.0;
    final parsedReps = type.usesReps ? int.tryParse(reps.text.trim()) : 0;
    final parsedDuration = type.usesDuration
        ? _parseDuration(duration.text)
        : null;
    final parsedDistance = type.usesDistance
        ? double.tryParse(distance.text.trim())
        : null;
    final parsedCalories = type.usesCalories
        ? double.tryParse(calories.text.trim())
        : null;

    final validation = _validateSet(
      type: type,
      weightValue: parsedWeight,
      repsValue: parsedReps,
      durationValue: parsedDuration,
      distanceValue: parsedDistance,
      caloriesValue: parsedCalories,
    );
    if (validation != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(validation)));
      return;
    }

    final loggedExercise = exercise;
    final log = SetLog(
      exercise: plan.name,
      exerciseId: option.id,
      trackingType: type.name,
      weight: parsedWeight ?? 0,
      reps: parsedReps ?? 0,
      durationSeconds: parsedDuration,
      distance: parsedDistance,
      distanceUnit: type.usesDistance ? _defaultDistanceUnit : null,
      calories: parsedCalories,
      date: DateTime.now(),
      workout: widget.workout.name,
      notes: notes.text.trim(),
      sessionId: sessionId,
      exerciseIndex: exercise,
      setOrder: _setsForExercise(exercise) + 1,
      restSeconds: plan.primary ? 180 : 120,
    );
    setState(() => logging = true);
    late bool pr;
    try {
      await _draftWrites;
      pr = await widget.store.add(log);
    } on Object {
      if (mounted) {
        setState(() => logging = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Set could not be saved. Your inputs are ready to retry.',
            ),
            action: SnackBarAction(label: 'Retry', onPressed: _log),
          ),
        );
      }
      return;
    }
    if (!mounted) return;
    var workoutComplete = false;
    setState(() {
      logging = false;
      lastPr = pr;
      sessionHadPr = sessionHadPr || pr;
      loggedSets++;
      rest = plan.primary ? 180 : 120;
      restEndsAt = DateTime.now().add(Duration(seconds: rest));
      final exerciseSets = _setsForExercise(exercise);
      if (exerciseSets < plan.sets) {
        set++;
        if (plan.amrap) {
          _seed(preserveWeight: true);
        } else {
          notes.clear();
        }
      } else {
        final remaining = widget.workout.exercises
            .asMap()
            .keys
            .where((i) => _setsForExercise(i) < _exercisePlan(i).sets)
            .toList();
        if (remaining.isEmpty) {
          workoutComplete = true;
        } else {
          exercise = remaining.firstWhere(
            (i) => i > exercise,
            orElse: () => remaining.first,
          );
          set = _setsForExercise(exercise) + 1;
          lastPr = false;
          _seed();
        }
      }
    });
    await _persistDraft();
    if (!mounted) return;
    HapticFeedback.selectionClick();
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          workoutComplete
              ? 'All sets saved. Finish when you are ready.'
              : pr
              ? 'Set saved · New personal best'
              : 'Set saved',
        ),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            if (finishing || logging) return;
            setState(() => logging = true);
            try {
              await widget.store.removeSet(log);
              if (!mounted) return;
              setState(() {
                logging = false;
                loggedSets = widget.store.logs
                    .where((l) => l.sessionId == sessionId)
                    .length;
                exercise = loggedExercise;
                set = _setsForExercise(exercise) + 1;
                lastPr = false;
                _seed();
              });
              await _persistDraft();
            } on Object {
              if (!mounted) return;
              setState(() => logging = false);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Could not undo. The set is still saved.'),
                ),
              );
            }
          },
        ),
      ),
    );
  }

  String? _validateSet({
    required ExerciseTrackingType type,
    required double? weightValue,
    required int? repsValue,
    required int? durationValue,
    required double? distanceValue,
    required double? caloriesValue,
  }) {
    if (type.usesWeight) {
      if (weightValue == null || !weightValue.isFinite) {
        return type == ExerciseTrackingType.assistedBodyweight
            ? 'Enter the assistance used.'
            : type == ExerciseTrackingType.weightedBodyweight
            ? 'Enter the added weight. Use 0 for an unweighted set.'
            : 'Enter a valid weight.';
      }
      if (type.requiresPositiveWeight && weightValue <= 0) {
        return 'Enter a weight above zero.';
      }
      if (!type.requiresPositiveWeight && weightValue < 0) {
        return 'The value cannot be negative.';
      }
    }
    if (type.usesReps && (repsValue == null || repsValue <= 0)) {
      return 'Enter a repetition count above zero.';
    }
    if (type.usesDuration && (durationValue == null || durationValue <= 0)) {
      return 'Enter a duration above zero. Use seconds or mm:ss.';
    }
    if (type.usesDistance &&
        (distanceValue == null ||
            !distanceValue.isFinite ||
            distanceValue <= 0)) {
      return 'Enter a distance above zero.';
    }
    if (type.usesCalories &&
        (caloriesValue == null ||
            !caloriesValue.isFinite ||
            caloriesValue <= 0)) {
      return 'Enter calories above zero.';
    }
    return null;
  }

  int? _parseDuration(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    if (!trimmed.contains(':')) return int.tryParse(trimmed);
    final parts = trimmed.split(':');
    if (parts.length != 2) return null;
    final minutes = int.tryParse(parts[0]);
    final seconds = int.tryParse(parts[1]);
    if (minutes == null || seconds == null || seconds < 0 || seconds >= 60) {
      return null;
    }
    return minutes * 60 + seconds;
  }

  String get _defaultDistanceUnit => widget.store.unit == 'kg' ? 'km' : 'mi';

  Future<void> _finish({bool completedAutomatically = false}) async {
    if (finishing || logging) return;
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
            '${loggedSets == 0 ? 'This will be marked skipped' : 'This will be marked partial'}. $loggedSets of $plannedSets sets are saved. The program advances.',
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
    await _commitWorkout(
      loggedSets >= plannedSets
          ? WorkoutStatus.completed
          : loggedSets == 0
          ? WorkoutStatus.skipped
          : WorkoutStatus.partial,
    );
  }

  Future<void> _skipWorkout() async {
    if (finishing || widget.retroactive) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Skip this workout?'),
        content: const Text(
          'The program advances. Any sets already logged stay in history.',
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
    await _draftWrites;
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
        startedAt: startedAt,
        elapsedSeconds: elapsed,
      );
    } on Object {
      if (!mounted) return;
      setState(() => finishing = false);
      _startTimer();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Workout could not be finished. Your saved sets and draft are available to retry.',
          ),
        ),
      );
      return;
    }
    if (mounted && status != WorkoutStatus.skipped) {
      await showWorkoutCompleteSheet(
        context,
        _shareData(partial: status == WorkoutStatus.partial),
        store: widget.store,
        sessionId: sessionId,
      );
    }
    if (mounted) Navigator.pop(context);
  }

  WorkoutShareData _shareData({bool partial = false}) {
    final sessionLogs = widget.store.logs
        .where((log) => log.sessionId == sessionId)
        .toList();
    final totalVolume = sessionLogs.fold<double>(
      0,
      (sum, log) => sum + log.standardVolume,
    );
    SetLog? highlight;
    for (final log in sessionLogs) {
      if (highlight == null ||
          _sharePerformanceScore(log) > _sharePerformanceScore(highlight)) {
        highlight = log;
      }
    }
    final exerciseCount = sessionLogs.map((log) => log.exercise).toSet().length;
    return WorkoutShareData(
      snapshot: ShareWorkoutSnapshot(
        program: 'Strength Program',
        status: partial ? 'partial' : 'completed',
        workout: widget.workout.name,
        completedAt: DateTime.now(),
        duration: Duration(seconds: elapsed),
        sets: sessionLogs.length,
        exercises: exerciseCount,
        volume: totalVolume > 0 ? totalVolume : null,
        volumeUnit: widget.store.unit,
        phaseLabel:
            'Week ${widget.week.number} · ${partial ? 'Partial session' : widget.week.label}',
        achievement: !partial && sessionHadPr ? 'New personal best' : '',
        highlights: [
          if (highlight != null)
            ShareHighlight(
              'Top result',
              '${highlight.exercise} · ${setDescription(highlight, widget.store.unit)}',
              sensitiveWeight: highlight.resolvedTrackingType.usesWeight,
            ),
        ],
      ),
      program: 'Strength Program',
      title: widget.workout.name,
      contextLine:
          'Run ${widget.store.strengthProgramRun} · Week ${widget.week.number} · Phase ${widget.week.phase}',
      completedAt: DateTime.now(),
      achievementLabel: sessionHadPr ? 'New personal best' : null,
      metrics: [
        ShareMetric(
          'Duration',
          formatShareDuration(Duration(seconds: elapsed)),
        ),
        ShareMetric('Sets', '${sessionLogs.length}'),
        if (totalVolume > 0)
          ShareMetric(
            'Volume',
            '${_compactNumber(totalVolume)} ${widget.store.unit}',
          ),
        ShareMetric('Exercises', '$exerciseCount'),
      ],
      highlightLabel: highlight == null ? 'Session' : 'Top result',
      highlightValue: highlight == null
          ? 'Workout completed'
          : _shareSetDescription(highlight),
    );
  }

  double _sharePerformanceScore(SetLog log) =>
      switch (log.resolvedTrackingType) {
        ExerciseTrackingType.assistedBodyweight =>
          log.reps * 100000 - log.weight,
        ExerciseTrackingType.bodyweightReps ||
        ExerciseTrackingType.repsOnly => log.reps.toDouble(),
        ExerciseTrackingType.duration => (log.durationSeconds ?? 0).toDouble(),
        ExerciseTrackingType.distanceOnly ||
        ExerciseTrackingType.distanceDuration => log.distance ?? 0,
        _ => log.e1rm,
      };

  String _shareSetDescription(SetLog log) {
    final type = log.resolvedTrackingType;
    return switch (type) {
      ExerciseTrackingType.bodyweightReps ||
      ExerciseTrackingType.repsOnly => '${log.exercise} · ${log.reps} reps',
      ExerciseTrackingType.weightedBodyweight =>
        '${log.exercise} · +${_shareWeight(log.weight)} ${widget.store.unit} × ${log.reps}',
      ExerciseTrackingType.assistedBodyweight =>
        '${log.exercise} · ${_shareWeight(log.weight)} ${widget.store.unit} assistance × ${log.reps}',
      ExerciseTrackingType.duration =>
        '${log.exercise} · ${_clock(log.durationSeconds ?? 0)}',
      ExerciseTrackingType.distanceDuration =>
        '${log.exercise} · ${_shareWeight(log.distance ?? 0)} ${log.distanceUnit ?? _defaultDistanceUnit} in ${_clock(log.durationSeconds ?? 0)}',
      ExerciseTrackingType.distanceOnly =>
        '${log.exercise} · ${_shareWeight(log.distance ?? 0)} ${log.distanceUnit ?? _defaultDistanceUnit}',
      _ =>
        '${log.exercise} · ${_shareWeight(log.weight)} ${widget.store.unit} × ${log.reps}',
    };
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
    final plan = _exercisePlan(exercise);
    final option = _optionForIndex(exercise);
    final type = option.trackingType;
    final activeLogs = widget.store.logs
        .where((log) => log.sessionId == sessionId && log.exercise == plan.name)
        .length;
    final progress =
        loggedSets /
        widget.workout.exercises.fold<int>(0, (sum, item) => sum + item.sets);
    final exerciseComplete = _setsForExercise(exercise) >= plan.sets;
    final target = _targetLabel(plan, type);
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
      body: LabSafeScreen(
        top: false,
        bottomAction: SizedBox(
          width: double.infinity,
          height: 58,
          child: FilledButton.icon(
            onPressed: finishing || logging || exerciseComplete ? null : _log,
            style: FilledButton.styleFrom(
              backgroundColor: BrandColors.purple,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.add_task_rounded),
            label: Text(
              logging
                  ? 'Saving set…'
                  : exerciseComplete
                  ? 'Exercise complete'
                  : 'Log set',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
            ),
          ),
        ),
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
          children: [
            FeatureTip(
              store: widget.store,
              id: ContextualGuideId.strengthWorkout,
              message:
                  'Choose any exercise above the inputs. Each set saves immediately. Use Finish to review a complete or partial session.',
            ),
            LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white10,
              color: lime,
              borderRadius: BorderRadius.circular(8),
              minHeight: 6,
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    draftFailed
                        ? 'Draft could not be saved'
                        : draftSaving
                        ? 'Saving draft…'
                        : 'Draft saved on this device',
                    style: TextStyle(
                      color: draftFailed ? BrandColors.error : muted,
                      fontSize: 12,
                    ),
                  ),
                ),
                if (draftFailed)
                  TextButton(
                    onPressed: _persistDraft,
                    child: const Text('Retry'),
                  ),
              ],
            ),
            DropdownButtonFormField<int>(
              initialValue: exercise,
              key: ValueKey(exercise),
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Exercise · tap to jump',
              ),
              items: [
                for (final entry in widget.workout.exercises.asMap().entries)
                  DropdownMenuItem(
                    value: entry.key,
                    child: Text(
                      '${entry.key + 1}. ${_exercisePlan(entry.key).name}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: logging || finishing
                  ? null
                  : (value) {
                      if (value != null) _jumpToExercise(value);
                    },
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Text(
                    plan.name,
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
                  tooltip: 'Find a substitute',
                  onPressed: _setsForExercise(exercise) == 0 && !finishing
                      ? () => _chooseSubstitution(exercise)
                      : null,
                  icon: const Icon(Icons.swap_horiz_rounded),
                ),
              ],
            ),
            const SizedBox(height: 7),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                _WorkoutMetaChip(option.primaryMuscle.label, cyan),
                _WorkoutMetaChip(option.equipment.label, violet),
                _WorkoutMetaChip(type.label, Colors.white70),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'SET $set OF ${plan.sets}  •  $target',
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
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            if (plan.primary &&
                type == ExerciseTrackingType.weightReps &&
                option.warmupEligible &&
                _setsForExercise(exercise) == 0)
              ListenableBuilder(
                listenable: Listenable.merge([weight, reps]),
                builder: (context, _) {
                  final recommendation = WarmupCalculator.calculate(
                    exercise: plan.name,
                    isPrimary: plan.primary,
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
            _Previous(
              best: widget.store.lastSet(
                plan.name,
                excludingSession: sessionId,
              ),
              unit: widget.store.unit,
            ),
            const SizedBox(height: 24),
            _buildInputFields(type),
            if (type.usesWeight) ...[
              const SizedBox(height: 8),
              Text(
                'Starting load uses your last saved session for this movement. When you own the top of the prescribed rep range, add the smallest practical increment. Adjust for readiness and deloads.',
                style: const TextStyle(color: muted, fontSize: 13),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => showPlateCalculator(
                    context,
                    unit: widget.store.unit,
                    target: double.tryParse(weight.text),
                  ),
                  icon: const Icon(Icons.calculate_outlined),
                  label: const Text('Plate calculator'),
                ),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: notes,
              minLines: 1,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'SET NOTES',
                hintText: 'Optional. Keep it useful.',
              ),
            ),
            if (rest > 0) ...[
              const SizedBox(height: 16),
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
                      onPressed: () {
                        setState(() {
                          rest = 0;
                          restEndsAt = null;
                        });
                        unawaited(_persistDraft());
                      },
                      child: const Text('SKIP'),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            Card(
              margin: EdgeInsets.zero,
              child: ExpansionTile(
                initiallyExpanded: true,
                leading: const Icon(Icons.history_rounded, color: cyan),
                title: Text(
                  'LOGGED SETS ($activeLogs)',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text('Saved for ${plan.name} in this workout'),
                childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                children: [
                  LoggedSetsEditor(
                    store: widget.store,
                    predicate: (log) =>
                        log.sessionId == sessionId && log.exercise == plan.name,
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
            ...widget.workout.exercises.asMap().entries.map((entry) {
              final exercisePlan = _exercisePlan(entry.key);
              final exerciseOption = _optionForIndex(entry.key);
              final loggedForSlot = _setsForExercise(entry.key);
              final done = loggedForSlot >= exercisePlan.sets;
              return ListTile(
                onTap: finishing || logging
                    ? null
                    : () => _jumpToExercise(entry.key),
                contentPadding: EdgeInsets.zero,
                selected: entry.key == exercise,
                leading: CircleAvatar(
                  backgroundColor: done ? lime : Colors.white10,
                  child: Icon(
                    done ? Icons.check : Icons.fitness_center,
                    color: done ? ink : Colors.white54,
                    size: 18,
                  ),
                ),
                title: Text(exercisePlan.name),
                subtitle: Text(
                  substitutions.containsKey(entry.key)
                      ? 'For ${entry.value.name} · ${exerciseOption.trackingType.label}'
                      : exerciseOption.trackingType.label,
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${exercisePlan.sets} × ${exercisePlan.reps}',
                      style: const TextStyle(color: Colors.white54),
                    ),
                    IconButton(
                      tooltip: 'Substitute ${entry.value.name}',
                      onPressed: loggedForSlot == 0 && !finishing
                          ? () => _chooseSubstitution(entry.key)
                          : null,
                      icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  void _jumpToExercise(int index) {
    setState(() {
      exercise = index;
      set = _setsForExercise(index) + 1;
      lastPr = false;
      _seed();
    });
    unawaited(_persistDraft());
  }

  Widget _buildInputFields(ExerciseTrackingType type) {
    final fields = <Widget>[];
    if (type.usesWeight) {
      fields.add(
        _WorkoutInput(
          controller: weight,
          label: '${type.weightLabel} (${widget.store.unit})',
          decimal: true,
        ),
      );
    }
    if (type.usesReps) {
      fields.add(
        _WorkoutInput(controller: reps, label: 'REPS', decimal: false),
      );
    }
    if (type.usesDuration) {
      fields.add(
        _WorkoutInput(
          controller: duration,
          label: 'DURATION',
          hint: 'seconds or mm:ss',
          decimal: false,
        ),
      );
    }
    if (type.usesDistance) {
      fields.add(
        _WorkoutInput(
          controller: distance,
          label: 'DISTANCE ($_defaultDistanceUnit)',
          decimal: true,
        ),
      );
    }
    if (type.usesCalories) {
      fields.add(
        _WorkoutInput(controller: calories, label: 'CALORIES', decimal: true),
      );
    }
    if (fields.length == 1) return fields.single;
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 540;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final field in fields)
              SizedBox(
                width: wide
                    ? (constraints.maxWidth - 12) / 2
                    : fields.length == 2
                    ? (constraints.maxWidth - 12) / 2
                    : constraints.maxWidth,
                child: field,
              ),
          ],
        );
      },
    );
  }

  String _targetLabel(ExercisePlan plan, ExerciseTrackingType type) =>
      switch (type) {
        ExerciseTrackingType.duration ||
        ExerciseTrackingType.durationWeight => 'TARGET ${plan.reps}',
        ExerciseTrackingType.distanceDuration ||
        ExerciseTrackingType.weightDistance ||
        ExerciseTrackingType.repsDistance ||
        ExerciseTrackingType.distanceOnly => 'TARGET ${plan.reps}',
        _ => 'TARGET ${plan.reps} REPS',
      };

  String _clock(int seconds) =>
      '${(seconds ~/ 60).toString().padLeft(2, '0')}:'
      '${(seconds % 60).toString().padLeft(2, '0')}';

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
    final target = ExerciseLibrary.descriptorFor(
      name: prescribed.name,
      customExercises: widget.store.customExercises,
    );
    if (target == null) return;
    final ranked = ExerciseLibrary.rankedSubstitutions(
      target: target,
      custom: widget.store.customExercises,
      favoriteBuiltInIds: widget.store.favoriteBuiltInExerciseIds,
      limit: 60,
    );
    final searchController = TextEditingController();
    var query = '';
    String? selected = substitutions[index];
    final choice = await showLabBottomSheet<String>(
      context: context,
      builder: (sheetContext) => DraggableScrollableSheet(
        initialChildSize: .88,
        minChildSize: .55,
        maxChildSize: .96,
        expand: false,
        builder: (context, scrollController) => LabSafeBottomSheet(
          padding: EdgeInsets.zero,
          child: StatefulBuilder(
            builder: (context, setSheetState) {
              final shown = query.trim().isEmpty
                  ? ranked
                  : ExerciseLibrary.search(
                      custom: widget.store.customExercises,
                      favoriteBuiltInIds:
                          widget.store.favoriteBuiltInExerciseIds,
                      query: query,
                    ).where((item) => item.name != prescribed.name).toList();
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 12, 10),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'FIND A SUBSTITUTE',
                                style: TextStyle(
                                  fontSize: 21,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              SizedBox(height: 3),
                              Text(
                                'Same role first. Everything else stays searchable.',
                                style: TextStyle(color: BrandColors.muted),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                    child: TextField(
                      controller: searchController,
                      onChanged: (value) => setSheetState(() => query = value),
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search_rounded),
                        hintText: 'Search name, muscle, equipment, or alias',
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: FeatureTip(
                      store: widget.store,
                      id: ContextualGuideId.exerciseSubstitution,
                      message:
                          'Choose a substitute before logging sets for that exercise. Tracking fields follow the selected movement.',
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(12, 2, 12, 16),
                      itemCount: shown.length + 1,
                      itemBuilder: (context, itemIndex) {
                        if (itemIndex == 0) {
                          return RadioListTile<String>(
                            value: prescribed.name,
                            groupValue: selected,
                            title: Text('${prescribed.name} · prescribed'),
                            subtitle: const Text('Remove the substitution'),
                            onChanged: (value) {
                              setSheetState(() => selected = value);
                              Navigator.pop(sheetContext, value);
                            },
                          );
                        }
                        final item = shown[itemIndex - 1];
                        return RadioListTile<String>(
                          value: item.name,
                          groupValue: selected,
                          title: Text(item.name),
                          subtitle: Text(
                            '${item.primaryMuscle.label} · ${item.equipment.label} · ${item.trackingType.label}',
                          ),
                          secondary: item.isFavorite
                              ? const Icon(Icons.star_rounded, color: violet)
                              : null,
                          onChanged: (value) {
                            setSheetState(() => selected = value);
                            Navigator.pop(sheetContext, value);
                          },
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
    searchController.dispose();
    if (!mounted || choice == null) return;
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

class _WorkoutInput extends StatelessWidget {
  const _WorkoutInput({
    required this.controller,
    required this.label,
    required this.decimal,
    this.hint,
  });

  final TextEditingController controller;
  final String label;
  final bool decimal;
  final String? hint;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    keyboardType: decimal
        ? const TextInputType.numberWithOptions(decimal: true)
        : TextInputType.number,
    style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w800),
    decoration: InputDecoration(labelText: label, hintText: hint),
  );
}

class _WorkoutMetaChip extends StatelessWidget {
  const _WorkoutMetaChip(this.label, this.color);

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .10),
      borderRadius: BorderRadius.circular(99),
      border: Border.all(color: color.withValues(alpha: .28)),
    ),
    child: Text(
      label,
      style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w800),
    ),
  );
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    required this.store,
    required this.helpGuidesKey,
    required this.onReplayTour,
  });
  final AppStore store;
  final GlobalKey helpGuidesKey;
  final VoidCallback onReplayTour;
  @override
  Widget build(BuildContext context) {
    void open(Widget screen) =>
        Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      children: [
        Text('More', style: Theme.of(context).textTheme.headlineLarge),
        const SizedBox(height: 6),
        const Text(
          'Preferences, connections, and your data',
          style: TextStyle(color: muted),
        ),
        const SizedBox(height: 28),
        const BrandSectionLabel('Preferences'),
        const SizedBox(height: 12),
        const Text('Weight unit'),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'lb', label: Text('Pounds')),
            ButtonSegment(value: 'kg', label: Text('Kilograms')),
          ],
          selected: {store.unit},
          onSelectionChanged: (v) async {
            try {
              await store.setUnit(v.first);
            } on Object {
              if (context.mounted)
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Could not save the unit.')),
                );
            }
          },
        ),
        const SizedBox(height: 16),
        _Setting(
          icon: Icons.share_outlined,
          title: 'Sharing defaults',
          subtitle: 'Format, caption, and privacy',
          available: true,
          onTap: () => open(
            IntegrationsHubScreen(
              store: store,
              section: IntegrationSection.sharing,
            ),
          ),
        ),
        _Setting(
          icon: Icons.hub_outlined,
          title: 'Connections',
          subtitle: 'Health, wearables, and activity imports',
          available: true,
          onTap: () => open(IntegrationsHubScreen(store: store)),
        ),
        _Setting(
          icon: Icons.backup_outlined,
          title: 'Backup & data',
          subtitle: 'Backup, restore, export, and cloud sync',
          available: true,
          onTap: () => open(DataManagementScreen(store: store)),
        ),
        const SizedBox(height: 28),
        const BrandSectionLabel('Help & Guides'),
        _Setting(
          key: helpGuidesKey,
          icon: Icons.route_outlined,
          title: 'App Tour',
          subtitle: 'Find your way around all five tabs',
          available: true,
          onTap: onReplayTour,
        ),
        _Setting(
          icon: Icons.lightbulb_outline,
          title: 'Feature tips',
          subtitle: 'Show or reset contextual help',
          available: true,
          onTap: () => open(
            IntegrationsHubScreen(
              store: store,
              section: IntegrationSection.help,
            ),
          ),
        ),
        _Setting(
          icon: Icons.help_outline,
          title: 'How progression works',
          subtitle: 'The Strength program and its rep targets',
          available: true,
          onTap: () => showModalBottomSheet(
            context: context,
            useSafeArea: true,
            builder: (_) => const _QuickHelp(),
          ),
        ),
        const SizedBox(height: 24),
        const Text('Progression Lab 2.3.0', style: TextStyle(color: muted)),
      ],
    );
  }
}

class _Mark extends StatelessWidget {
  const _Mark();

  @override
  Widget build(BuildContext context) => const LabMark(size: 44);
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
              child: const Icon(
                Icons.local_fire_department_rounded,
                color: cyan,
              ),
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
                fontSize: 12,
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
                          fontSize: 12,
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
            fontSize: 12,
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
  Widget build(BuildContext context) {
    final log = best;
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: panel,
        borderRadius: BorderRadius.circular(17),
      ),
      child: Row(
        children: [
          const Icon(Icons.history, color: Colors.white38),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              log == null ? 'No previous sets' : _summary(log),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          if (log != null) ...[
            const SizedBox(width: 10),
            Text(
              _metric(log),
              style: const TextStyle(color: lime, fontWeight: FontWeight.w800),
            ),
          ],
        ],
      ),
    );
  }

  String _summary(SetLog log) => switch (log.resolvedTrackingType) {
    ExerciseTrackingType.bodyweightReps ||
    ExerciseTrackingType.repsOnly => 'Last session  ${log.reps} reps',
    ExerciseTrackingType.weightedBodyweight =>
      'Last session  +${log.weight.g} $unit × ${log.reps}',
    ExerciseTrackingType.assistedBodyweight =>
      'Last session  ${log.weight.g} $unit assistance × ${log.reps}',
    ExerciseTrackingType.duration =>
      'Last session  ${_durationLabel(log.durationSeconds ?? 0)}',
    ExerciseTrackingType.durationWeight =>
      'Last session  ${log.weight.g} $unit · ${_durationLabel(log.durationSeconds ?? 0)}',
    ExerciseTrackingType.distanceDuration =>
      'Last session  ${(log.distance ?? 0).g} ${log.distanceUnit ?? ''} · ${_durationLabel(log.durationSeconds ?? 0)}',
    ExerciseTrackingType.weightDistance =>
      'Last session  ${log.weight.g} $unit · ${(log.distance ?? 0).g} ${log.distanceUnit ?? ''}',
    ExerciseTrackingType.repsDuration =>
      'Last session  ${log.reps} reps · ${_durationLabel(log.durationSeconds ?? 0)}',
    ExerciseTrackingType.repsDistance =>
      'Last session  ${log.reps} reps · ${(log.distance ?? 0).g} ${log.distanceUnit ?? ''}',
    ExerciseTrackingType.distanceOnly =>
      'Last session  ${(log.distance ?? 0).g} ${log.distanceUnit ?? ''}',
    ExerciseTrackingType.caloriesDuration =>
      'Last session  ${(log.calories ?? 0).g} cal · ${_durationLabel(log.durationSeconds ?? 0)}',
    ExerciseTrackingType.weightOnly => 'Last session  ${log.weight.g} $unit',
    ExerciseTrackingType.weightReps =>
      'Last session  ${log.weight.g} $unit × ${log.reps}',
  };

  String _metric(SetLog log) => switch (log.resolvedTrackingType) {
    ExerciseTrackingType.weightReps ||
    ExerciseTrackingType.weightedBodyweight => 'e1RM ${log.e1rm.round()}',
    ExerciseTrackingType.assistedBodyweight => 'LESS IS MORE',
    ExerciseTrackingType.bodyweightReps ||
    ExerciseTrackingType.repsOnly => 'REP PR',
    ExerciseTrackingType.duration ||
    ExerciseTrackingType.durationWeight => 'TIME PR',
    ExerciseTrackingType.distanceDuration ||
    ExerciseTrackingType.weightDistance ||
    ExerciseTrackingType.repsDistance ||
    ExerciseTrackingType.distanceOnly => 'DISTANCE PR',
    ExerciseTrackingType.caloriesDuration => 'OUTPUT PR',
    ExerciseTrackingType.repsDuration => 'WORK PR',
    ExerciseTrackingType.weightOnly => 'LOAD PR',
  };

  String _durationLabel(int seconds) =>
      '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
}

class _Setting extends StatelessWidget {
  const _Setting({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.available,
    this.onTap,
  });
  final IconData icon;
  final String title, subtitle;
  final bool available;
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
      trailing: const Icon(Icons.chevron_right_rounded),
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
