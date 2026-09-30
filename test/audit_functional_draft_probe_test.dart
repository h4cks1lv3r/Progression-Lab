// Regression cases recovered from the independent audit.
// Storage is mocked. These are Flutter widget/model tests, not device tests.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:progression_lab/athletic_program.dart';
import 'package:progression_lab/athletic_training.dart';
import 'package:progression_lab/brand.dart';
import 'package:progression_lab/curated_programs.dart';
import 'package:progression_lab/main.dart' show WorkoutScreen;
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

  testWidgets('opening another functional day preserves the first day draft', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = AppStore()..automaticBackupsEnabled = false;
    final week = AthleticProgram.week(1);
    await tester.pumpWidget(
      MaterialApp(
        theme: ProgressionBrand.theme(),
        home: AthleticSessionScreen(store: store, week: week, sessionIndex: 0),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.circle_outlined).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.circle_outlined).first);
    await tester.pumpAndSettle();
    final originalSessionId = store.athleticDraft!.sessionId;
    expect(store.athleticDraft!.completedDrills, [0, 1]);
    expect(
      find.text('2 of ${week.sessions.first.drills.length} drills complete'),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();

    await store.setAthleticProgramPosition(
      weekNumber: 1,
      sessionIndex: 1,
      nextSessionDate: DateTime(2026, 9, 30),
      startNewRun: false,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: ProgressionBrand.theme(),
        home: AthleticSessionScreen(store: store, week: week, sessionIndex: 1),
      ),
    );
    await tester.pumpAndSettle();
    expect(store.athleticDraft!.sessionIndex, 1);
    expect(store.athleticDraft!.sessionId, isNot(originalSessionId));
    expect(store.athleticDraft!.completedDrills, isEmpty);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await store.setAthleticProgramPosition(
      weekNumber: 1,
      sessionIndex: 0,
      nextSessionDate: DateTime(2026, 9, 30),
      startNewRun: false,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: ProgressionBrand.theme(),
        home: AthleticSessionScreen(store: store, week: week, sessionIndex: 0),
      ),
    );
    await tester.pumpAndSettle();
    expect(store.athleticDraft!.sessionIndex, 0);
    expect(store.athleticDraft!.sessionId, originalSessionId);
    expect(store.athleticDraft!.completedDrills, [0, 1]);
    expect(
      find.text('2 of ${week.sessions.first.drills.length} drills complete'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    store.dispose();
  });

  test(
    'legacy functional session excludes a full day away from active duration',
    () async {
      final store = AppStore()..automaticBackupsEnabled = false;
      final start = DateTime.now().subtract(const Duration(hours: 24));
      await store.completeAthleticSession(
        effort: 6,
        notes: '',
        sessionId: 'audit-paused',
        completedDrills: const [0],
        startedAt: start,
        partial: true,
      );
      expect(
        store.athleticHistory.single.durationSeconds,
        lessThan(24 * 60 * 60),
      );
      store.dispose();
    },
  );

  test(
    'empty iconic session can be discarded and a fresh session begun',
    () async {
      final store = AppStore()..automaticBackupsEnabled = false;
      final programId = CuratedPrograms.all.first.id;
      final first = await store.beginCuratedWorkout(programId);
      await store.discardCuratedWorkout(
        programId: programId,
        sessionId: first.sessionId,
      );
      expect(store.curatedDraftFor(programId), isNull);
      final reopened = await store.beginCuratedWorkout(programId);
      expect(reopened.sessionId, isNot(first.sessionId));
      expect(reopened.dayIndex, 0);
      expect(reopened.nextStepIndex, 0);
      expect(store.curatedProgressFor(programId).completedSessions, 0);
      store.dispose();
    },
  );

  testWidgets(
    'changing strength exercise preserves typed entries per exercise',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = AppStore()
        ..automaticBackupsEnabled = false
        ..integrationState = {
          'contextualGuides': {'tipsEnabled': false},
        };
      const workout = WorkoutPlan('Audit draft entry', [
        ExercisePlan('Barbell Bench Press', 3, '8-12'),
        ExercisePlan('Lat Pulldown', 3, '8-12'),
      ]);
      const week = ProgramWeek(
        number: 1,
        phase: 1,
        microcycle: 1,
        kind: WeekKind.build,
        workouts: [workout],
      );
      Finder field(String label) => find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.labelText == label,
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: ProgressionBrand.theme(),
          home: WorkoutScreen(
            store: store,
            week: week,
            workout: workout,
            workoutIndex: 0,
            scheduledDate: DateTime(2026, 9, 30),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(field('WEIGHT (lb)'), '123');
      await tester.enterText(field('Reps'), '9');
      await tester.enterText(field('Set notes'), 'Return to this bench');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(store.draft!.weight, '123');
      expect(store.draft!.notes, 'Return to this bench');

      await tester.tap(find.byType(DropdownButtonFormField<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('2. Lat Pulldown').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('1. Barbell Bench Press').last);
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(field('WEIGHT (lb)')).controller!.text,
        '123',
      );
      expect(tester.widget<TextField>(field('Reps')).controller!.text, '9');
      expect(
        tester.widget<TextField>(field('Set notes')).controller!.text,
        'Return to this bench',
      );
      expect(store.draft!.weight, '123');
      expect(store.draft!.notes, 'Return to this bench');
      expect(store.logs, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      store.dispose();
    },
  );
}
