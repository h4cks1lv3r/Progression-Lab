import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:progression_lab/athletic_training.dart';
import 'package:progression_lab/brand.dart';
import 'package:progression_lab/exercise_library_screen.dart';
import 'package:progression_lab/logged_sets.dart';
import 'package:progression_lab/main.dart';
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

  test('cadence changes preserve the active cycle and exact next workout', () async {
    final store = AppStore()
      ..days = 4
      ..week = 19
      ..workoutIndex = 1;

    await store.setDays(5, nextWorkoutIndex: 4);

    expect(store.days, 5);
    expect(store.week, 19);
    expect(store.workoutIndex, 4);
  });

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
    await tester.tap(find.text('CHANGE STARTING POINT'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('program-position-scroll')), findsOneWidget);
    expect(find.text('MOVE CURRENT POSITION'), findsOneWidget);
    expect(find.text('START A NEW PROGRAM RUN'), findsOneWidget);
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
    await tester.tap(find.text('CHANGE STARTING POINT'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('athletic-position-scroll')), findsOneWidget);
    expect(find.text('MOVE CURRENT RUN'), findsOneWidget);
    expect(find.text('START A NEW ATHLETIC RUN'), findsOneWidget);
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

    expect(find.text('Strength signal'), findsOneWidget);
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

    await tester.tap(find.text('SAVE SET'));
    await tester.pumpAndSettle();

    expect(store.logs.single.weight, 190);
    expect(store.logs.single.reps, 6);
    expect(store.logs.single.notes, 'Paused reps');
  });

  testWidgets('exercise library searches built-ins and custom exercises', (
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

    expect(find.text('CREATE EXERCISE'), findsOneWidget);
    final search = find.byType(TextField).first;
    await tester.enterText(search, 'Barbell Bench Press');
    await tester.pump();
    expect(find.text('Barbell Bench Press'), findsWidgets);

    await store.addCustomExercise('Researcher Offset Row');
    await tester.enterText(search, 'Researcher Offset Row');
    await tester.pump();
    expect(find.text('Researcher Offset Row'), findsWidgets);
    expect(store.customExercises.single.name, 'Researcher Offset Row');
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

    expect(find.text('WEEK 5 OF 12'), findsOneWidget);
    expect(find.text('LOADED GAIT & UNILATERAL STRENGTH'), findsOneWidget);
    await tester.tap(find.text('START SESSION'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Foot Rocker'), findsOneWidget);
  });

  testWidgets('primary navigation and replayable tour remain available', (
    tester,
  ) async {
    usePhoneSurface(tester);
    final store = AppStore()
      ..isLoaded = true
      ..onboardingVersionSeen = 1;

    await tester.pumpWidget(
      MaterialApp(theme: ProgressionBrand.theme(), home: Shell(store: store)),
    );
    await tester.pumpAndSettle();

    final navigation = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(navigation.destinations, hasLength(4));
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Programs'), findsOneWidget);
    expect(find.text('Progress'), findsOneWidget);
    expect(find.text('More'), findsOneWidget);

    await tester.tap(find.text('Programs'));
    await tester.pumpAndSettle();
    expect(find.text('Strength Program'), findsOneWidget);
    expect(find.text('Athletic Functional Training'), findsOneWidget);

    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('App Tour'));
    await tester.pumpAndSettle();
    expect(find.text('SKIP TOUR'), findsOneWidget);
    await tester.tap(find.text('SKIP TOUR'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Replay it from More'), findsOneWidget);
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
