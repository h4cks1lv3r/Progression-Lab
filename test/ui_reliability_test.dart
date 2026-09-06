import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:progression_lab/athletic_history.dart';
import 'package:progression_lab/athletic_program.dart';
import 'package:progression_lab/athletic_training.dart';
import 'package:progression_lab/brand.dart';
import 'package:progression_lab/daily_inputs.dart';
import 'package:progression_lab/daily_inputs_screen.dart';
import 'package:progression_lab/exercise_metrics.dart';
import 'package:progression_lab/exercise_models.dart';
import 'package:progression_lab/lab_experiments.dart';
import 'package:progression_lab/main.dart';
import 'package:progression_lab/plate_calculator.dart';
import 'package:progression_lab/program.dart';
import 'package:progression_lab/share_card.dart';
import 'package:progression_lab/share_options.dart';
import 'package:progression_lab/store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('iron_cadence/storage');
  String? saved;
  bool fail = false;
  Completer<void>? pendingSet;
  setUp(() {
    saved = null;
    fail = false;
    pendingSet = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'read') return saved;
          if (call.method == 'write') {
            if (fail) throw PlatformException(code: 'disk_full');
            final value = call.arguments as String;
            if (pendingSet != null &&
                ((jsonDecode(value) as Map)['logs'] as List).isNotEmpty)
              await pendingSet!.future;
            saved = value;
          }
          return null;
        });
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );
  AppStore store() => AppStore()
    ..automaticBackupsEnabled = false
    ..integrationState = {
      'contextualGuides': {'tipsEnabled': false},
    };
  SetLog log({
    String? session,
    double weight = 100,
    int reps = 8,
    String type = 'weightReps',
  }) => SetLog(
    exercise: 'Bench Press',
    weight: weight,
    reps: reps,
    trackingType: type,
    date: DateTime.now(),
    workout: 'Upper',
    sessionId: session,
  );
  DraftSetInput draft(DateTime start) => DraftSetInput(
    week: 1,
    workoutIndex: 0,
    workout: 'Upper',
    exerciseIndex: 0,
    setNumber: 1,
    sessionId: 'strength',
    weight: '100',
    reps: '8',
    notes: '',
    startedAt: start,
    restEndsAt: start.add(const Duration(hours: 1)),
  );

  test(
    'legacy share values preserve hours, thousands, metric units, and drills',
    () {
      final data = WorkoutShareData(
        program: 'Athletic',
        title: 'Session',
        contextLine: '',
        completedAt: DateTime(2026),
        metrics: const [
          ShareMetric('Duration', '1 HR 15 MIN'),
          ShareMetric('Volume', '12.5K kg'),
          ShareMetric('Drills', '6'),
          ShareMetric('Effort', '7/10'),
        ],
        highlightLabel: '',
        highlightValue: '',
      );
      final value = WorkoutShareCardGenerator.toSnapshot(data);
      expect(value.duration, const Duration(minutes: 75));
      expect(value.volume, 12500);
      expect(value.volumeUnit, 'kg');
      expect(value.drills, 6);
      expect(value.effort, 7);
    },
  );

  for (final template in WorkoutShareTemplate.values) {
    testWidgets('hidden weights never reach ${template.name} renderer', (
      tester,
    ) async {
      final private = ShareWorkoutSnapshot(
        program: 'Strength',
        workout: 'Upper',
        completedAt: DateTime(2026),
        duration: const Duration(minutes: 75),
        sets: 18,
        exercises: 6,
        volume: 12500,
        volumeUnit: 'kg',
        highlights: const [
          ShareHighlight(
            'Top set',
            'Bench · 185 kg × 8',
            sensitiveWeight: true,
          ),
        ],
      );
      final prefs = WorkoutSharePreferences(
        template: template,
        aspect: WorkoutShareAspect.square,
        privacy: const WorkoutSharePrivacy(showExactWeights: false),
      );
      final safe = SharePrivacy.apply(private, prefs.privacy);
      expect(safe.highlights, isEmpty);
      expect(safe.volume, isNull);
      final a = await tester.runAsync(
        () => AdvancedWorkoutShareCardGenerator.generate(private, prefs),
      );
      final b = await tester.runAsync(
        () => AdvancedWorkoutShareCardGenerator.generate(safe, prefs),
      );
      expect(a, orderedEquals(b!));
    });
  }

  test(
    'privacy is available after loading without opening Connections',
    () async {
      final s = store();
      await s.setSharePreferences(
        const WorkoutSharePreferences(
          privacy: WorkoutSharePrivacy(
            completionOnly: true,
            showExactWeights: false,
          ),
        ),
      );
      final restored = store();
      await restored.load();
      expect(restored.sharePreferences.privacy.completionOnly, isTrue);
      expect(restored.sharePreferences.privacy.showExactWeights, isFalse);
      s.dispose();
      restored.dispose();
    },
  );

  test('metrics respect tracking types and distance units', () {
    expect(metricsFor(ExerciseTrackingType.bodyweightReps), [
      ExerciseMetric.reps,
    ]);
    expect(metricsFor(ExerciseTrackingType.assistedBodyweight), [
      ExerciseMetric.assistance,
      ExerciseMetric.reps,
    ]);
    expect(
      metricsFor(ExerciseTrackingType.weightedBodyweight),
      isNot(contains(ExerciseMetric.estimatedOneRepMax)),
    );
    final run = SetLog(
      exercise: 'Run',
      weight: 0,
      reps: 0,
      date: DateTime.now(),
      workout: 'Cardio',
      trackingType: 'distanceDuration',
      distance: 1,
      distanceUnit: 'mi',
      durationSeconds: 600,
    );
    expect(ExerciseMetric.distance.value(run), closeTo(1609.344, .0001));
    expect(ExerciseMetric.speed.value(run), closeTo(2.68224, .0001));
    expect(supportsStrengthEstimate(log(type: 'assistedBodyweight')), isFalse);
    expect(metricNumber(double.infinity), '—');
  });

  test('draft timestamps survive storage and a weight-unit change', () async {
    final s = store();
    final start = DateTime.now().subtract(const Duration(minutes: 40));
    await s.setDraft(draft(start));
    await s.setUnit('kg');
    final restored = store();
    await restored.load();
    expect(restored.draft!.startedAt, start);
    expect(restored.draft!.restEndsAt, start.add(const Duration(hours: 1)));
    expect(double.parse(restored.draft!.weight), closeTo(45.36, .01));
    s.dispose();
    restored.dispose();
  });

  test('failed set write rolls back and the next write can succeed', () async {
    final s = store();
    fail = true;
    await expectLater(s.add(log()), throwsA(isA<PlatformException>()));
    expect(s.logs, isEmpty);
    fail = false;
    await s.add(log());
    expect(s.logs, hasLength(1));
    expect(jsonDecode(saved!)['logs'], hasLength(1));
    s.dispose();
  });

  test(
    'partial strength finish is durable and retry does not advance twice',
    () async {
      final s = store();
      await s.recordWorkout(
        weekNumber: 1,
        targetWorkoutIndex: 0,
        workout: 'Upper',
        status: WorkoutStatus.partial,
        sessionId: 'partial',
        elapsedSeconds: 300,
        startedAt: DateTime.now().subtract(const Duration(minutes: 5)),
      );
      await s.recordWorkout(
        weekNumber: 1,
        targetWorkoutIndex: 0,
        workout: 'Upper',
        status: WorkoutStatus.partial,
        sessionId: 'partial',
      );
      expect(s.workoutHistory, hasLength(1));
      expect(s.workoutIndex, 1);
      expect(s.strengthCompletion, 0);
      final restored = store();
      await restored.load();
      expect(restored.workoutHistory.single.status, WorkoutStatus.partial);
      expect(restored.workoutHistory.single.elapsedSeconds, 300);
      s.dispose();
      restored.dispose();
    },
  );

  test(
    'athletic partial completion preserves checked drills and excludes full-session totals',
    () async {
      final s = store();
      final start = DateTime.now().subtract(const Duration(minutes: 15));
      await s.saveAthleticDraft(
        AthleticSessionDraft(
          sessionId: 'a',
          programRun: 1,
          week: 1,
          sessionIndex: 0,
          startedAt: start,
          completedDrills: [0, 2],
        ),
      );
      fail = true;
      await expectLater(
        s.completeAthleticSession(
          effort: 5,
          notes: '',
          sessionId: 'a',
          completedDrills: [0, 2],
          startedAt: start,
          partial: true,
        ),
        throwsA(isA<PlatformException>()),
      );
      expect(s.athleticDraft!.completedDrills, [0, 2]);
      expect(s.athleticSessionIndex, 0);
      fail = false;
      await s.completeAthleticSession(
        effort: 5,
        notes: '',
        sessionId: 'a',
        completedDrills: [0, 2],
        startedAt: start,
        partial: true,
      );
      expect(s.athleticHistory.single.status, 'partial');
      expect(s.athleticCompletedSessions, 0);
      expect(s.athleticDraft, isNull);
      expect(s.athleticSessionIndex, 1);
      final restored = store();
      await restored.load();
      expect(restored.athleticHistory.single.completedDrills, [0, 2]);
      s.dispose();
      restored.dispose();
    },
  );

  test(
    'weekly review excludes skipped and partial sessions and calculates PRs',
    () async {
      final s = store();
      await s.add(log(session: 'c'));
      for (final status in WorkoutStatus.values)
        await s.recordWorkout(
          weekNumber: 1,
          targetWorkoutIndex: s.workoutIndex,
          workout: 'Upper',
          status: status,
          sessionId: status.name,
        );
      final result = LabExperimentAnalyzer.weeklyReview(s.exportState());
      expect(result.completedStrengthWorkouts, 1);
      expect(result.personalRecords, 1);
      s.dispose();
    },
  );

  test('plate pairs include the bar and never exceed the target', () {
    expect(platesPerSide(225, 45, 'lb'), [45, 45]);
    expect(
      platesPerSide(100, 20, 'kg').fold<double>(20, (a, b) => a + b * 2),
      100,
    );
    expect(
      platesPerSide(101, 20, 'kg').fold<double>(20, (a, b) => a + b * 2),
      100,
    );
  });

  testWidgets('rapid log taps save one set and Undo restores the exercise', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final s = store();
    final week = ProgramEngine.week(1, 4);
    await tester.pumpWidget(
      MaterialApp(
        theme: ProgressionBrand.theme(),
        home: WorkoutScreen(
          store: s,
          week: week,
          workout: week.workouts.first,
          workoutIndex: 0,
          scheduledDate: DateTime.now(),
        ),
      ),
    );
    await tester.pump();
    await tester.enterText(find.byType(TextField).first, '100');
    await tester.pump(const Duration(milliseconds: 300));
    pendingSet = Completer<void>();
    await tester.tap(find.text('Log set'));
    await tester.tap(find.text('Log set'));
    await tester.pump();
    expect(s.logs, hasLength(1));
    pendingSet!.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(s.logs, hasLength(1));
    await tester.tap(find.text('Undo'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(s.logs, isEmpty);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    s.dispose();
  });

  testWidgets('athletic drill checks resume when the screen reopens', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final s = store();
    Widget screen() => MaterialApp(
      theme: ProgressionBrand.theme(),
      home: AthleticSessionScreen(
        store: s,
        week: AthleticProgram.week(1),
        sessionIndex: 0,
      ),
    );
    await tester.pumpWidget(screen());
    await tester.pump();
    await tester.tap(find.byIcon(Icons.circle_outlined).first);
    await tester.pumpAndSettle();
    expect(s.athleticDraft!.completedDrills, [0]);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    final restored = store();
    await restored.load();
    await tester.pumpWidget(
      MaterialApp(
        theme: ProgressionBrand.theme(),
        home: AthleticSessionScreen(
          store: restored,
          week: AthleticProgram.week(1),
          sessionIndex: 0,
        ),
      ),
    );
    await tester.pump();
    expect(find.textContaining('1 OF '), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    s.dispose();
    restored.dispose();
  });

  testWidgets('editing recovery on a past date does not move it to today', (
    tester,
  ) async {
    final s = store();
    final past = DateUtils.dateOnly(
      DateTime.now().subtract(const Duration(days: 4)),
    );
    final record = RecoveryCheckIn(
      id: 'past',
      localDate: past,
      sleepHours: 7,
      createdAt: past,
      updatedAt: past,
    );
    await s.saveRecoveryCheckIn(record);
    await tester.pumpWidget(
      MaterialApp(
        theme: ProgressionBrand.theme(),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () =>
                  showRecoveryCheckInSheet(context, s, existing: record),
              child: const Text('Edit'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    final save = find.text('SAVE');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(s.recoveryForDay(past), isNotNull);
    expect(s.recoveryForDay(DateTime.now()), isNull);
    await tester.pumpWidget(const SizedBox());
    s.dispose();
  });
}
