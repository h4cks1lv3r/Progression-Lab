import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:progression_lab/brand.dart';
import 'package:progression_lab/logged_sets.dart';
import 'package:progression_lab/main.dart';
import 'package:progression_lab/program.dart';
import 'package:progression_lab/store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const storage = MethodChannel('iron_cadence/storage');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storage, (_) async => null);
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storage, null);
  });

  AppStore newStore() => AppStore()
    ..automaticBackupsEnabled = false
    ..integrationState = {
      'contextualGuides': {'tipsEnabled': false},
    };

  Future<void> openWorkout(
    WidgetTester tester,
    AppStore store,
    String exercise, {
    bool accessibleNavigation = false,
  }) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final workout = WorkoutPlan('Logging regression', [
      ExercisePlan(exercise, 4, '8–12'),
    ]);
    final week = ProgramWeek(
      number: 1,
      phase: 1,
      microcycle: 1,
      kind: WeekKind.build,
      workouts: [workout],
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: ProgressionBrand.theme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(accessibleNavigation: accessibleNavigation),
          child: child!,
        ),
        home: WorkoutScreen(
          store: store,
          week: week,
          workout: workout,
          workoutIndex: 0,
          scheduledDate: DateTime(2026, 9, 19),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> saveSet(WidgetTester tester) async {
    await tester.tap(find.text('Log set'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
  }

  Future<void> close(WidgetTester tester, AppStore store) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    store.dispose();
  }

  Finder weightField(String label) => find.byWidgetPredicate(
    (widget) =>
        widget is TextField && widget.decoration?.labelText == '$label (lb)',
  );

  for (final exercise in ['Dip', 'Bench Dip', 'Triceps Dip', 'Dead Bug']) {
    testWidgets('$exercise logs repetitions without a weight input', (
      tester,
    ) async {
      final store = newStore();
      final previous = SetLog(
        exercise: exercise,
        exerciseId: 'legacy-exercise',
        weight: 35,
        reps: 6,
        date: DateTime(2026, 8, 1),
        workout: 'Previous imported workout',
        sourceApp: 'Prior app',
      );
      store.logs.add(previous);
      await openWorkout(tester, store, exercise);
      expect(weightField('WEIGHT'), findsNothing);
      await saveSet(tester);
      expect(store.logs, hasLength(2));
      expect(store.logs.last.weight, 0);
      expect(store.logs.last.reps, 8);
      expect(store.logs.last.trackingType, 'bodyweightReps');
      expect(store.logs.first, same(previous));
      expect(store.logs.first.weight, 35);
      expect(store.logs.first.trackingType, 'weightReps');
      await close(tester, store);
    });
  }

  testWidgets(
    'Weighted Dip accepts blank added load but rejects invalid load',
    (tester) async {
      final store = newStore();
      await openWorkout(tester, store, 'Weighted Dip');
      final input = weightField('ADDED WEIGHT');
      expect(input, findsOneWidget);
      await tester.enterText(input, 'invalid');
      await saveSet(tester);
      expect(store.logs, isEmpty);
      await tester.enterText(input, '-10');
      await saveSet(tester);
      expect(store.logs, isEmpty);
      await tester.enterText(input, '');
      await saveSet(tester);
      expect(store.logs, hasLength(1));
      expect(store.logs.single.weight, 0);
      expect(store.logs.single.reps, 8);
      expect(store.logs.single.trackingType, 'weightedBodyweight');
      await close(tester, store);
    },
  );

  testWidgets('assisted dips require explicit nonnegative assistance', (
    tester,
  ) async {
    final store = newStore();
    await openWorkout(tester, store, 'Assisted Dip');
    final input = weightField('ASSISTANCE');
    expect(input, findsOneWidget);
    await saveSet(tester);
    expect(store.logs, isEmpty);
    await tester.enterText(input, '-10');
    await saveSet(tester);
    expect(store.logs, isEmpty);
    await tester.enterText(input, '25');
    await saveSet(tester);
    expect(store.logs.single.weight, 25);
    expect(store.logs.single.trackingType, 'assistedBodyweight');
    await close(tester, store);
  });

  testWidgets('external-weight exercises still require a weight', (
    tester,
  ) async {
    final store = newStore();
    await openWorkout(tester, store, 'Barbell Bench Press');
    await saveSet(tester);
    expect(store.logs, isEmpty);
    await tester.enterText(weightField('WEIGHT'), '0');
    await saveSet(tester);
    expect(store.logs, isEmpty);
    await tester.enterText(weightField('WEIGHT'), '100');
    await saveSet(tester);
    expect(store.logs.single.weight, 100);
    await close(tester, store);
  });

  for (final accessibleNavigation in [false, true]) {
    testWidgets(
      'set confirmation expires with accessibleNavigation=$accessibleNavigation',
      (tester) async {
        final store = newStore();
        await openWorkout(
          tester,
          store,
          'Dip',
          accessibleNavigation: accessibleNavigation,
        );
        await saveSet(tester);
        expect(find.byType(SnackBar), findsOneWidget);
        expect(find.text('Undo'), findsOneWidget);
        await tester.pump(const Duration(seconds: 4));
        await tester.pump(const Duration(milliseconds: 350));
        expect(find.byType(SnackBar), findsNothing);
        expect(store.logs, hasLength(1));
        await close(tester, store);
      },
    );
  }

  testWidgets(
    'new set feedback clears queued notices and still supports Undo',
    (tester) async {
      final store = newStore();
      await openWorkout(tester, store, 'Dip');
      final messenger = ScaffoldMessenger.of(
        tester.element(find.byType(WorkoutScreen)),
      );
      messenger.showSnackBar(const SnackBar(content: Text('Old notice one')));
      messenger.showSnackBar(const SnackBar(content: Text('Old notice two')));
      await tester.pump(const Duration(milliseconds: 350));
      await saveSet(tester);
      await tester.pump(const Duration(milliseconds: 350));
      await saveSet(tester);
      await tester.pump(const Duration(milliseconds: 350));
      expect(store.logs, hasLength(2));
      expect(find.text('Old notice one'), findsNothing);
      expect(find.text('Old notice two'), findsNothing);
      await tester.tap(find.text('Undo'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(store.logs, hasLength(1));
      await tester.pump(const Duration(seconds: 10));
      expect(find.byType(SnackBar), findsNothing);
      await close(tester, store);
    },
  );

  testWidgets('set feedback keeps controls usable above a phone keyboard', (
    tester,
  ) async {
    final store = newStore();
    await openWorkout(tester, store, 'Dip');
    tester.view.physicalSize = const Size(430, 900);
    tester.view.viewInsets = const FakeViewPadding(bottom: 320);
    addTearDown(tester.view.resetViewInsets);
    await tester.pump();
    final button = find.ancestor(
      of: find.text('Log set'),
      matching: find.byType(FilledButton),
    );
    expect(tester.getRect(button).bottom, lessThanOrEqualTo(580));
    await saveSet(tester);
    expect(
      tester.getRect(find.byType(SnackBar)).bottom,
      lessThan(tester.getRect(button).top),
    );
    await saveSet(tester);
    expect(store.logs, hasLength(2));
    expect(tester.takeException(), isNull);
    await close(tester, store);
  });

  testWidgets(
    'editing added load to blank saves zero and preserves import IDs',
    (tester) async {
      final store = newStore();
      store.logs.add(
        SetLog(
          exercise: 'Weighted Dip',
          exerciseId: 'weighted_dip',
          weight: 20,
          reps: 8,
          date: DateTime(2026, 8, 1),
          workout: 'Imported workout',
          trackingType: 'weightedBodyweight',
          sourceApp: 'Prior app',
          sourceId: 'source-set-1',
          importBatchId: 'import-1',
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: ProgressionBrand.theme(),
          home: Scaffold(
            body: LoggedSetsEditor(
              store: store,
              predicate: (_) => true,
              emptyMessage: 'No sets',
            ),
          ),
        ),
      );
      await tester.enterText(weightField('ADDED WEIGHT'), '');
      await tester.tap(find.text('Save set'));
      await tester.pumpAndSettle();
      expect(find.text('Saved'), findsOneWidget);
      expect(store.logs.single.weight, 0);
      expect(store.logs.single.trackingType, 'weightedBodyweight');
      expect(store.logs.single.sourceId, 'source-set-1');
      expect(store.logs.single.importBatchId, 'import-1');
      await close(tester, store);
    },
  );
}
