import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:progression_lab/athletic_training.dart';
import 'package:progression_lab/brand.dart';
import 'package:progression_lab/exercise_library_screen.dart';
import 'package:progression_lab/logged_sets.dart';
import 'package:progression_lab/main.dart';
import 'package:progression_lab/app_navigation.dart';
import 'package:progression_lab/curated_training_screen.dart';
import 'package:progression_lab/open_workout_screen.dart';
import 'package:progression_lab/progress_hub.dart';
import 'package:progression_lab/program_navigator.dart';
import 'package:progression_lab/progress_dashboard.dart';
import 'package:progression_lab/safe_layout.dart';
import 'package:progression_lab/share_card.dart';
import 'package:progression_lab/store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const storageChannel = MethodChannel('iron_cadence/storage');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storageChannel, (call) async {
          if (call.method == 'write' || call.method == 'read') return null;
          throw PlatformException(code: 'unknown_method');
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storageChannel, null);
  });

  void usePhoneSurface(
    WidgetTester tester, {
    Size size = const Size(430, 900),
  }) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  test(
    'cadence changes preserve the active cycle and exact next workout',
    () async {
      final store = AppStore()
        ..days = 4
        ..week = 19
        ..workoutIndex = 1;

      await store.setDays(5, nextWorkoutIndex: 4);

      expect(store.days, 5);
      expect(store.week, 19);
      expect(store.workoutIndex, 4);
    },
  );

  testWidgets('strength and Athletic programs expose selectable starts', (
    tester,
  ) async {
    usePhoneSurface(tester, size: const Size(1080, 1920));
    final strengthStore = AppStore()
      ..days = 4
      ..week = 19
      ..workoutIndex = 1;

    await tester.pumpWidget(
      MaterialApp(
        theme: ProgressionBrand.theme(),
        home: ProgramNavigatorPage(
          store: strengthStore,
          onOpenWorkout: (_, _, _) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Change starting point'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('program-position-scroll')),
      findsOneWidget,
    );
    expect(find.text('Move within this run'), findsOneWidget);
    expect(find.text('Start a new run'), findsOneWidget);
    Navigator.of(
      tester.element(find.byKey(const ValueKey('program-position-scroll'))),
    ).pop();
    await tester.pumpAndSettle();

    final athleticStore = AppStore()
      ..athleticWeek = 6
      ..athleticSessionIndex = 2;
    await tester.pumpWidget(
      MaterialApp(
        theme: ProgressionBrand.theme(),
        home: AthleticTrainingPage(store: athleticStore),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Change starting point'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('athletic-position-scroll')),
      findsOneWidget,
    );
    expect(find.text('Move within this run'), findsOneWidget);
    expect(find.text('Start a new run'), findsOneWidget);
  });

  testWidgets('progress dashboard renders honest empty and populated states', (
    tester,
  ) async {
    usePhoneSurface(tester, size: const Size(1080, 1920));
    await tester.pumpWidget(
      MaterialApp(
        theme: ProgressionBrand.theme(),
        home: ProgressDashboard(store: AppStore()),
      ),
    );
    await tester.pump();

    expect(find.text('Your strength progress'), findsOneWidget);
    expect(find.text('Your progress starts with a set'), findsOneWidget);
    expect(find.text('No exercises logged'), findsOneWidget);

    final now = DateTime.now();
    final store = AppStore()
      ..logs = [
        SetLog(
          exercise: 'Barbell Bench Press',
          weight: 180,
          reps: 6,
          date: now.subtract(const Duration(days: 20)),
          workout: 'Upper Body A',
        ),
        SetLog(
          exercise: 'Barbell Bench Press',
          weight: 185,
          reps: 6,
          date: now.subtract(const Duration(days: 2)),
          workout: 'Upper Body A',
        ),
      ];
    await tester.pumpWidget(
      MaterialApp(
        theme: ProgressionBrand.theme(),
        home: ProgressDashboard(store: store),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Barbell Bench Press'), findsWidgets);
    expect(find.byType(CustomPaint), findsWidgets);
  });

  testWidgets('logged sets change only after explicit save', (tester) async {
    final log = SetLog(
      exercise: 'Barbell Bench Press',
      weight: 185,
      reps: 5,
      date: DateTime(2026, 8, 17),
      workout: 'Upper Body A',
    );
    final store = AppStore()..logs = [log];
    await tester.pumpWidget(
      MaterialApp(
        theme: ProgressionBrand.theme(),
        home: LoggedSetsScreen(store: store, exercise: 'Barbell Bench Press'),
      ),
    );

    await tester.enterText(find.byType(TextField).at(0), '190');
    await tester.enterText(find.byType(TextField).at(1), '6');
    await tester.enterText(find.byType(TextField).at(2), 'Paused reps');
    expect(store.logs.single.weight, 185);
    expect(store.logs.single.notes, isEmpty);

    await tester.tap(find.text('Save set'));
    await tester.pumpAndSettle();

    expect(store.logs.single.weight, 190);
    expect(store.logs.single.reps, 6);
    expect(store.logs.single.notes, 'Paused reps');
  });

  testWidgets('exercise library searches the expanded built-in catalog', (
    tester,
  ) async {
    usePhoneSurface(tester, size: const Size(1080, 1920));
    final store = AppStore();
    await tester.pumpWidget(
      MaterialApp(
        theme: ProgressionBrand.theme(),
        home: ExerciseLibraryScreen(store: store),
      ),
    );
    await tester.pump();

    expect(find.text('Create exercise'), findsOneWidget);
    final search = find.byType(TextField).first;
    await tester.enterText(search, 'Barbell Bench Press');
    await tester.pump();
    expect(find.text('Barbell Bench Press'), findsWidgets);

    await tester.enterText(search, 'Captain’s Chair Leg Lift');
    await tester.pump();
    expect(find.text('Captain’s Chair Leg Lift'), findsWidgets);
  });

  testWidgets('Athletic training opens the current coached session', (
    tester,
  ) async {
    usePhoneSurface(tester, size: const Size(1080, 1920));
    final store = AppStore()
      ..athleticWeek = 5
      ..athleticSessionIndex = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: ProgressionBrand.theme(),
        home: AthleticTrainingPage(store: store),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Week 5 of 12'), findsOneWidget);
    expect(find.text('LOADED STEPS & SINGLE-LEG STRENGTH'), findsOneWidget);
    await tester.tap(find.text('Start session'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Foot Rocker'), findsOneWidget);
  });

  AppStore readyStore() => AppStore()
    ..isLoaded = true
    ..dataOnboardingVersionSeen = 1
    ..onboardingVersionSeen = 2
    ..automaticBackupsEnabled = false
    ..integrationState = {
      'contextualGuides': {'tipsEnabled': false},
    };

  testWidgets('left menu reaches workouts, Lab, settings and replayable tour', (
    tester,
  ) async {
    usePhoneSurface(tester);
    final store = readyStore();
    await tester.pumpWidget(
      MaterialApp(
        theme: ProgressionBrand.theme(),
        home: Shell(store: store),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsNothing);
    await tester.tap(find.byTooltip('Open menu'));
    await tester.pumpAndSettle();
    expect(find.byType(AppNavigation), findsOneWidget);
    expect(tester.getTopLeft(find.byType(Drawer)).dx, 0);
    await tester.tap(find.byKey(const ValueKey('menu-page-1')));
    await tester.pumpAndSettle();
    expect(find.text('Year One Strength'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Functional Training'),
      300,
      scrollable: find.descendant(
        of: find.byType(ProgramsHubPage),
        matching: find.byType(Scrollable),
      ),
    );
    expect(find.text('Functional Training'), findsOneWidget);

    await tester.tap(find.byTooltip('Open menu'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('menu-page-4')));
    await tester.tap(find.byKey(const ValueKey('menu-page-4')));
    await tester.pumpAndSettle();
    expect(find.byType(LabHub), findsOneWidget);

    await tester.tap(find.byTooltip('Open menu'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('menu-page-5')),
      300,
      scrollable: find.descendant(
        of: find.byType(AppNavigation),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('menu-page-5')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('App tour'));
    await tester.tap(find.text('App tour'));
    await tester.pumpAndSettle();
    expect(find.text('Choose how you train'), findsOneWidget);
    for (var step = 0; step < 7; step++) {
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
    }
    expect(find.text('Keep your history with you'), findsOneWidget);
    await tester.tap(find.text('Skip tour'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Replay it from Settings'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    store.dispose();
  });

  testWidgets(
    'all four home choices open real screens without moving program progress',
    (tester) async {
      usePhoneSurface(tester);
      final store = readyStore()
        ..week = 19
        ..workoutIndex = 1;
      await tester.pumpWidget(
        MaterialApp(
          theme: ProgressionBrand.theme(),
          home: Shell(store: store),
        ),
      );
      await tester.pumpAndSettle();
      final choices = <String, Type>{
        'home-open-workout': OpenWorkoutScreen,
        'home-iconic-builds': CuratedProgramsScreen,
        'home-year-one-strength': ProgramNavigatorPage,
        'home-functional-training': AthleticTrainingPage,
      };
      for (final choice in choices.entries) {
        final card = find.byKey(ValueKey(choice.key));
        // Every entry is visible before any scrolling on a typical phone.
        expect(card.hitTestable(), findsOneWidget);
        await tester.tap(card);
        await tester.pumpAndSettle();
        expect(find.byType(choice.value), findsOneWidget);
        expect(store.week, 19);
        expect(store.workoutIndex, 1);
        expect(store.logs, isEmpty);
        Navigator.of(tester.element(find.byType(choice.value))).pop();
        await tester.pumpAndSettle();
      }
      await tester.pumpWidget(const SizedBox());
      store.dispose();
    },
  );

  testWidgets('home and left menu fit a narrow phone with large text', (
    tester,
  ) async {
    usePhoneSurface(tester, size: const Size(320, 700));
    final store = readyStore()..preferredTrack = TrainingTrack.athletic;
    await tester.pumpWidget(
      MaterialApp(
        theme: ProgressionBrand.theme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(1.8)),
          child: child!,
        ),
        home: Shell(store: store),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(
      find.byKey(const ValueKey('home-functional-training')),
    );
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
      find.text('Start functional workout'),
      250,
      scrollable: find.descendant(
        of: find.byType(TodayPage),
        matching: find.byType(Scrollable),
      ),
    );
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Open menu'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('menu-page-5')),
      300,
      scrollable: find.descendant(
        of: find.byType(AppNavigation),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('menu-page-5')));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsPage), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    store.dispose();
  });

  testWidgets('wide screen keeps the left menu visible', (tester) async {
    usePhoneSurface(tester, size: const Size(1280, 900));
    final store = readyStore();
    await tester.pumpWidget(
      MaterialApp(
        theme: ProgressionBrand.theme(),
        home: Shell(store: store),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(AppNavigation), findsOneWidget);
    expect(find.byType(Drawer), findsNothing);
    expect(tester.getTopLeft(find.byType(AppNavigation)).dx, 0);
    await tester.tap(find.byKey(const ValueKey('menu-page-4')));
    await tester.pumpAndSettle();
    expect(find.byType(LabHub), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    store.dispose();
  });

  testWidgets('safe bottom actions clear a simulated system navigation inset', (
    tester,
  ) async {
    usePhoneSurface(tester, size: const Size(430, 900));
    const actionKey = ValueKey('safe-primary-action');

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            padding: const EdgeInsets.only(bottom: 48),
            viewPadding: const EdgeInsets.only(bottom: 48),
          ),
          child: child!,
        ),
        home: LabSafeScreen(
          child: const SizedBox.expand(),
          bottomAction: SizedBox(
            height: 56,
            child: FilledButton(
              key: actionKey,
              onPressed: _noop,
              child: const Text('FINISH WORKOUT'),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final buttonBottom = tester.getBottomRight(find.byKey(actionKey)).dy;
    expect(buttonBottom, lessThanOrEqualTo(900 - 48));
    expect(find.text('FINISH WORKOUT'), findsOneWidget);
  });

  testWidgets('workout story cards render branded PNG data', (tester) async {
    final data = WorkoutShareData(
      program: 'Strength Program',
      title: 'Upper Body A',
      contextLine: 'Week 4 · Phase 1 · Build',
      completedAt: DateTime(2026, 8, 19),
      achievementLabel: 'New personal record',
      metrics: const [
        ShareMetric('Duration', '42 MIN'),
        ShareMetric('Sets', '18'),
        ShareMetric('Volume', '8.4K LB'),
        ShareMetric('Exercises', '4'),
      ],
      highlightLabel: 'Top set',
      highlightValue: 'Barbell Bench Press · 185 lb × 6',
    );

    final bytes = await tester.runAsync(
      () => WorkoutShareCardGenerator.generate(data),
    );

    expect(bytes, isNotNull);
    expect(bytes!.length, greaterThan(10000));
    expect(bytes.take(8).toList(), [137, 80, 78, 71, 13, 10, 26, 10]);
  });
}

void _noop() {}
