import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:progression_lab/brand.dart';
import 'package:progression_lab/curated_programs.dart';
import 'package:progression_lab/curated_training.dart';
import 'package:progression_lab/curated_training_screen.dart';
import 'package:progression_lab/store.dart';
import 'package:progression_lab/program.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const storage = MethodChannel('iron_cadence/storage');
  setUp(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storage, (_) async => null),
  );
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storage, null),
  );
  AppStore store() => AppStore()..automaticBackupsEnabled = false;

  test('linked imported completion survives deletion and Undo', () async {
    final app = store();
    app.workoutHistory = [
      WorkoutRecord(
        week: 1,
        workoutIndex: 0,
        workout: 'Upper',
        date: DateTime(2026, 9, 10),
        status: WorkoutStatus.completed,
        sessionId: 'imported',
        importedWorkoutId: 'source-import',
      ),
    ];
    final plan = ProgramEngine.week(1, 4).workouts.first;
    app.logs.add(
      SetLog(
        exercise: 'Extra movement',
        weight: 20,
        reps: 5,
        date: DateTime(2026, 9, 10),
        workout: 'Upper',
        sessionId: 'imported',
        exerciseIndex: 0,
        sourceId: 'extra',
      ),
    );
    for (final exercise in plan.exercises.asMap().entries) {
      for (var set = 0; set < exercise.value.sets; set++) {
        app.logs.add(
          SetLog(
            exercise: exercise.value.name,
            weight: 100,
            reps: 5,
            date: DateTime(2026, 9, 10),
            workout: 'Upper',
            sessionId: 'imported',
            exerciseIndex: exercise.key + 1,
            sourceId: 'external-${exercise.key}-$set',
          ),
        );
      }
    }
    final log = app.logs[1];
    await app.removeSet(log);
    expect(app.workoutHistory.single.status, WorkoutStatus.partial);
    await app.restoreSet(log);
    expect(app.workoutHistory.single.status, WorkoutStatus.completed);
  });

  test('deleting, switching units and Undo preserves physical load', () async {
    final app = store();
    final draft = await app.beginOpenWorkout();
    await app.addOpenWorkoutExercise(
      sessionId: draft.sessionId,
      exerciseId: 'barbell_bench_press',
    );
    await app.logOpenWorkoutSet(
      sessionId: draft.sessionId,
      exerciseIndex: 0,
      setSequence: 0,
      weight: 100,
      reps: 5,
    );
    final removed = app.logs.single;
    await app.removeSet(removed);
    await app.setUnit('kg');
    await app.restoreSet(removed);
    expect(app.logs.single.weight, closeTo(45.359237, .000001));
  });

  test('exercise Undo converts both saved sets and pending entries', () async {
    final app = store();
    final draft = await app.beginOpenWorkout();
    await app.addOpenWorkoutExercise(
      sessionId: draft.sessionId,
      exerciseId: 'barbell_bench_press',
    );
    await app.logOpenWorkoutSet(
      sessionId: draft.sessionId,
      exerciseIndex: 0,
      setSequence: 0,
      weight: 100,
      reps: 5,
    );
    await app.saveOpenWorkoutInputs(
      sessionId: draft.sessionId,
      exerciseIndex: 0,
      setSequence: 1,
      inputs: {'weight': '100', 'reps': '8'},
    );
    final exercise = app.openWorkoutDraft!.selectedExercise!;
    final sets = List<SetLog>.of(app.logs);
    final inputs = Map<String, String>.of(app.openWorkoutDraft!.inputs);
    await app.removeOpenWorkoutExercise(
      sessionId: draft.sessionId,
      exerciseIndex: 0,
    );
    await app.setUnit('kg');
    await app.restoreOpenWorkoutExercise(
      sessionId: draft.sessionId,
      exercise: exercise,
      inputs: inputs,
      sets: sets,
    );
    expect(app.logs.single.weight, closeTo(45.359237, .000001));
    expect(
      double.parse(app.openWorkoutDraft!.inputs['weight']!),
      closeTo(45.36, .001),
    );
  });

  testWidgets('mounted Iconic form displays converted pending load', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final app = store();
    final id = CuratedPrograms.all.first.id;
    final draft = CuratedWorkoutDraft(
      programId: id,
      sessionId: 'unit-review',
      week: 1,
      dayIndex: 0,
      run: 1,
      startedAt: DateTime(2026, 9, 30),
      inputs: {'weight': '100', 'reps': '8'},
      day: const CuratedDay(
        title: 'Upper',
        movements: [
          CuratedMovement(
            name: 'Bench',
            metric: CuratedMetric.loadedReps,
            targets: [CuratedSetTarget(reps: '8')],
          ),
        ],
      ),
    );
    app.curatedTraining = CuratedTrainingState(drafts: {id: draft});
    await tester.pumpWidget(
      MaterialApp(
        theme: ProgressionBrand.theme(),
        home: CuratedSessionScreen(store: app, programId: id),
      ),
    );
    await tester.pumpAndSettle();
    await app.setUnit('kg');
    await tester.pumpAndSettle();
    final field = tester.widget<TextFormField>(
      find.byKey(const ValueKey('curated-weight')),
    );
    expect(double.parse(field.controller!.text), closeTo(45.36, .001));
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
