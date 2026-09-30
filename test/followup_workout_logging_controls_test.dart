import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:progression_lab/athletic_program.dart';
import 'package:progression_lab/athletic_training.dart';
import 'package:progression_lab/brand.dart';
import 'package:progression_lab/curated_programs.dart';
import 'package:progression_lab/curated_training_screen.dart';
import 'package:progression_lab/main.dart' show WorkoutScreen;
import 'package:progression_lab/open_workout_screen.dart';
import 'package:progression_lab/program.dart';
import 'package:progression_lab/store.dart';
import 'package:progression_lab/workout_logging_controls.dart';

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

  AppStore store() => AppStore()
    ..automaticBackupsEnabled = false
    ..integrationState = {
      'contextualGuides': {'tipsEnabled': false},
    };

  Widget app(Widget screen) => MaterialApp(
    theme: ProgressionBrand.theme(),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(1.4)),
      child: child!,
    ),
    home: screen,
  );

  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
  }

  Future<void> close(WidgetTester tester, AppStore data) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    data.dispose();
  }

  WorkoutScreen strength(
    AppStore data,
    String exercise, {
    bool amrap = false,
  }) => WorkoutScreen(
    store: data,
    week: ProgramEngine.week(1, 4),
    workout: WorkoutPlan('Test workout', [
      ExercisePlan(
        exercise,
        amrap ? 2 : 1,
        amrap ? 'AMRAP + 4' : '5',
        amrap: amrap,
      ),
    ]),
    workoutIndex: 0,
    scheduledDate: DateTime(2026, 9, 30),
  );

  testWidgets(
    'all four workouts keep save controls visible above the keyboard',
    (tester) async {
      phone(tester);
      for (final mode in ['Strength', 'Open', 'Iconic', 'Functional']) {
        final data = store();
        late Widget screen;
        if (mode == 'Strength') {
          screen = strength(data, 'Barbell Bench Press');
        } else if (mode == 'Open') {
          final draft = await data.beginOpenWorkout();
          await data.addOpenWorkoutExercise(
            sessionId: draft.sessionId,
            exerciseId: 'dip',
          );
          screen = OpenWorkoutSessionScreen(
            store: data,
            sessionId: draft.sessionId,
          );
        } else if (mode == 'Iconic') {
          final programId = CuratedPrograms.all.first.id;
          await data.beginCuratedWorkout(programId);
          screen = CuratedSessionScreen(store: data, programId: programId);
        } else {
          screen = AthleticSessionScreen(
            store: data,
            week: AthleticProgram.week(1),
            sessionIndex: 0,
          );
        }
        await tester.pumpWidget(app(screen));
        await tester.pumpAndSettle();
        expect(find.byType(WorkoutActionBar), findsOneWidget, reason: mode);
        expect(find.byType(WorkoutSaveProgress), findsOneWidget, reason: mode);
        final primary = find.descendant(
          of: find.byType(WorkoutActionBar),
          matching: find.byType(FilledButton),
        );
        expect(
          find.descendant(
            of: primary,
            matching: find.text(
              mode == 'Functional' ? 'Finish workout' : 'Log set',
            ),
          ),
          findsOneWidget,
          reason: mode,
        );
        final original = tester.getRect(primary);
        await tester.drag(find.byType(ListView).first, const Offset(0, -400));
        await tester.pumpAndSettle();
        expect(
          tester.getRect(primary),
          original,
          reason: '$mode action must not scroll away',
        );
        tester.view.viewInsets = const FakeViewPadding(bottom: 260);
        await tester.pumpAndSettle();
        expect(
          tester.getRect(primary).bottom,
          lessThanOrEqualTo(640),
          reason: '$mode action must stay above keyboard',
        );
        expect(tester.takeException(), isNull, reason: mode);
        tester.view.resetViewInsets();
        await close(tester, data);
      }
    },
  );

  testWidgets('Open logs saved input even when the form is scrolled away', (
    tester,
  ) async {
    phone(tester);
    final data = store();
    final draft = await data.beginOpenWorkout();
    await data.addOpenWorkoutExercise(
      sessionId: draft.sessionId,
      exerciseId: 'dip',
    );
    await tester.pumpWidget(
      app(OpenWorkoutSessionScreen(store: data, sessionId: draft.sessionId)),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('open-reps')));
    await tester.enterText(find.byKey(const ValueKey('open-reps')), '8');
    await tester.pumpAndSettle();
    for (var index = 0; index < 12; index++) {
      await tester.tap(find.byKey(const ValueKey('open-log-set')));
      await tester.pumpAndSettle();
    }
    await tester.drag(find.byType(ListView).first, const Offset(0, -1500));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('open-log-set')));
    await tester.pumpAndSettle();
    expect(data.logs, hasLength(13));
    expect(data.logs.every((log) => log.reps == 8), isTrue);
    expect(tester.takeException(), isNull);
    await close(tester, data);
  });

  testWidgets(
    'Functional explains drills and its save control opens a workout rating',
    (tester) async {
      phone(tester);
      final data = store();
      await tester.pumpWidget(
        app(
          AthleticSessionScreen(
            store: data,
            week: AthleticProgram.week(1),
            sessionIndex: 0,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('drills complete'), findsOneWidget);
      expect(find.text('Log set'), findsNothing);
      expect(
        find.textContaining('This workout uses a checklist'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('functional-finish-workout')));
      await tester.pumpAndSettle();
      expect(find.text('Workout rating'), findsOneWidget);
      expect(find.text('This session will save as skipped.'), findsOneWidget);
      expect(data.logs, isEmpty);
      expect(tester.takeException(), isNull);
      await close(tester, data);
    },
  );

  testWidgets(
    'plate calculator supports all bars without guessing nonstandard weight',
    (tester) async {
      phone(tester);
      for (final exercise in [
        'Barbell Bench Press',
        'EZ-Bar Curl',
        'Trap-Bar Deadlift',
        'Smith Machine Bench Press',
      ]) {
        final data = store();
        await tester.pumpWidget(app(strength(data, exercise)));
        await tester.pumpAndSettle();
        final calculator = find.widgetWithText(TextButton, 'Plate calculator');
        await tester.scrollUntilVisible(
          calculator,
          250,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(calculator);
        await tester.pumpAndSettle();
        final field = find.byWidgetPredicate(
          (widget) =>
              widget is TextField &&
              widget.decoration?.labelText == 'Bar weight (lb)',
        );
        expect(
          tester.widget<TextField>(field).controller!.text,
          exercise == 'Barbell Bench Press' ? '45' : '',
          reason: exercise,
        );
        if (exercise != 'Barbell Bench Press') {
          expect(
            find.textContaining('do not assume 45 lb or 20 kg'),
            findsOneWidget,
            reason: exercise,
          );
        }
        expect(tester.takeException(), isNull, reason: exercise);
        await close(tester, data);
      }
    },
  );

  testWidgets(
    'AMRAP target explains the second set and e1RM is plain language',
    (tester) async {
      phone(tester);
      final data = store();
      await data.add(
        SetLog(
          exercise: 'Barbell Bench Press',
          weight: 100,
          reps: 5,
          date: DateTime(2026, 9, 29),
          workout: 'Prior workout',
        ),
      );
      await tester.pumpWidget(
        app(strength(data, 'Barbell Bench Press', amrap: true)),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.textContaining('AMRAP means as many reps as possible'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.textContaining('AMRAP means as many reps as possible'),
        findsOneWidget,
      );
      expect(
        find.textContaining('“+ 4” means 4 reps in the second set.'),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(
        find.textContaining('Estimated 1-rep max'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Estimated 1-rep max'), findsOneWidget);
      expect(find.textContaining('e1RM'), findsNothing);
      expect(tester.takeException(), isNull);
      await close(tester, data);
    },
  );
}
