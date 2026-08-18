import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:progression_lab/exercise_library_screen.dart';
import 'package:progression_lab/logged_sets.dart';
import 'package:progression_lab/program_navigator.dart';
import 'package:progression_lab/progress_dashboard.dart';
import 'package:progression_lab/store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const storageChannel = MethodChannel('iron_cadence/storage');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storageChannel, (call) async {
          if (call.method == 'write') return null;
          if (call.method == 'read') return null;
          throw PlatformException(code: 'unknown_method');
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storageChannel, null);
  });

  testWidgets('cadence sheet preserves cycle and accepts an exact next workout', (
    tester,
  ) async {
    final store = AppStore()
      ..days = 4
      ..week = 19
      ..workoutIndex = 1;

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
        home: Scaffold(
          body: ProgramNavigatorPage(store: store, onOpenWorkout: (_, _, _) {}),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('P2 · M3'), findsOneWidget);
    await tester.tap(find.text('5 DAYS').first);
    await tester.pumpAndSettle();

    expect(find.text('CHANGE CADENCE'), findsOneWidget);
    expect(
      find.text(
        'Phase 2 · Microcycle 3 is preserved. Only the weekly cadence and next workout change.',
        findRichText: true,
      ),
      findsOneWidget,
    );

    final upperBodyC = find.text('Upper Body C');
    await tester.scrollUntilVisible(
      upperBodyC,
      250,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey('cadence-options-scroll')),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.tap(upperBodyC);
    await tester.pump();

    final confirm = find.text('SWITCH TO 5 DAYS');
    await tester.ensureVisible(confirm);
    await tester.tap(confirm);
    await tester.pumpAndSettle();

    expect(store.days, 5);
    expect(store.week, 19);
    expect(store.workoutIndex, 4);
    expect(find.text('CHANGE CADENCE'), findsNothing);
  });

  testWidgets('progress dashboard never needs fake data for an empty history', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
        home: Scaffold(body: ProgressDashboard(store: AppStore())),
      ),
    );
    await tester.pump();

    expect(find.text('Strength signal'), findsOneWidget);
    expect(find.text('Your progress starts with a set'), findsOneWidget);
    expect(find.text('No exercises logged'), findsOneWidget);
  });

  testWidgets('progress dashboard selects one exercise and metric at a time', (
    tester,
  ) async {
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
        SetLog(
          exercise: 'Barbell Back Squat',
          weight: 275,
          reps: 5,
          date: now.subtract(const Duration(days: 1)),
          workout: 'Legs & Calves',
        ),
      ];

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
        home: Scaffold(body: ProgressDashboard(store: store)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Barbell Bench Press').last);
    await tester.pumpAndSettle();

    expect(find.text('Barbell Bench Press'), findsWidgets);
    expect(find.textContaining('185 lb × 6'), findsWidgets);
    await tester.tap(find.text('Weight'));
    await tester.pumpAndSettle();
    expect(find.text('WORKING WEIGHT'), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);
  });

  testWidgets('logged set edits require the explicit save button', (
    tester,
  ) async {
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
        theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
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
    expect(find.text('SAVED'), findsOneWidget);
  });

  testWidgets('library CRUD is exposed only for custom exercises', (
    tester,
  ) async {
    final store = AppStore();
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
        home: ExerciseLibraryScreen(store: store),
      ),
    );

    expect(find.text('Barbell Bench Press'), findsOneWidget);
    expect(find.byType(PopupMenuButton<String>), findsNothing);

    await tester.tap(find.text('ADD EXERCISE'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Belt Squat');
    await tester.tap(find.text('SAVE'));
    await tester.pumpAndSettle();

    expect(find.text('Belt Squat'), findsOneWidget);
    expect(find.byType(PopupMenuButton<String>), findsOneWidget);

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('EDIT'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Cable Pull-Through');
    await tester.tap(find.text('SAVE'));
    await tester.pumpAndSettle();
    expect(find.text('Cable Pull-Through'), findsOneWidget);

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('DELETE'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('DELETE').last);
    await tester.pumpAndSettle();

    expect(find.text('Cable Pull-Through'), findsNothing);
    expect(store.customExercises.single.isArchived, isTrue);
    expect(find.text('Barbell Bench Press'), findsOneWidget);
  });

  testWidgets('week browser renders the active cadence workout slots', (
    tester,
  ) async {
    for (final days in [3, 4, 5]) {
      final store = AppStore()
        ..days = days
        ..week = 2
        ..workoutIndex = 0
        ..programStartDate = DateTime(2026, 1, 5);
      await tester.pumpWidget(
        MaterialApp(
          key: ValueKey('cadence-$days'),
          theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
          home: Scaffold(
            body: ProgramNavigatorPage(
              store: store,
              onOpenWorkout: (_, _, _) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
      await tester.pumpAndSettle();
      await tester.tap(find.text('WEEK 1'));
      await tester.pumpAndSettle();

      for (var index = 0; index < days; index++) {
        expect(find.byKey(ValueKey('workout-1-$index')), findsOneWidget);
      }
      expect(find.byKey(ValueKey('workout-1-$days')), findsNothing);
    }
  });

  testWidgets('week states and logged history use the performed substitution', (
    tester,
  ) async {
    final loggedAt = DateTime(2026, 1, 20, 18, 30);
    final store = AppStore()
      ..days = 4
      ..week = 2
      ..workoutIndex = 0
      ..programStartDate = DateTime(2026, 1, 5)
      ..logs = [
        SetLog(
          exercise: 'Trap Bar Shrug',
          weight: 80,
          reps: 10,
          date: loggedAt,
          workout: 'Upper Body A',
          sessionId: 'completed-substitution',
          exerciseIndex: 0,
        ),
      ]
      ..workoutHistory = [
        WorkoutRecord(
          week: 1,
          workoutIndex: 0,
          workout: 'Upper Body A',
          date: loggedAt,
          status: WorkoutStatus.completed,
          days: 4,
          scheduledDate: DateTime(2026, 1, 5),
          loggedAt: loggedAt,
          sessionId: 'completed-substitution',
          substitutions: const {0: 'Trap Bar Shrug'},
        ),
        WorkoutRecord(
          week: 1,
          workoutIndex: 1,
          workout: 'Pull & Calves',
          date: loggedAt,
          status: WorkoutStatus.skipped,
          days: 4,
          scheduledDate: DateTime(2026, 1, 6),
          loggedAt: loggedAt,
        ),
        WorkoutRecord(
          week: 1,
          workoutIndex: 2,
          workout: 'Upper Body B',
          date: loggedAt,
          status: WorkoutStatus.completed,
          days: 4,
          scheduledDate: DateTime(2026, 1, 8),
          loggedAt: loggedAt,
          retroactive: true,
          sessionId: 'retro-session',
        ),
      ];
    int? openedIndex;
    bool? openedRetroactively;

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
        home: Scaffold(
          body: ProgramNavigatorPage(
            store: store,
            onOpenWorkout: (_, index, retroactive) {
              openedIndex = index;
              openedRetroactively = retroactive;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
    await tester.pumpAndSettle();
    await tester.tap(find.text('WEEK 1'));
    await tester.pumpAndSettle();

    expect(find.text('COMPLETED'), findsOneWidget);
    expect(find.text('SKIPPED'), findsOneWidget);
    expect(find.text('RETRO FILLED'), findsOneWidget);
    final fillPast = find.text('FILL PAST WORKOUT');
    await tester.ensureVisible(fillPast);
    await tester.pumpAndSettle();
    await tester.tap(fillPast);
    expect(openedIndex, 3);
    expect(openedRetroactively, isTrue);

    final viewLogged = find.text('VIEW LOGGED WORKOUT').first;
    await tester.ensureVisible(viewLogged);
    await tester.pumpAndSettle();
    await tester.tap(viewLogged);
    await tester.pumpAndSettle();
    expect(find.text('TRAP BAR SHRUG'), findsOneWidget);
    expect(find.text('Barbell Bench Press'), findsNothing);
  });
}
