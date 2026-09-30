import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:progression_lab/body_progress.dart';
import 'package:progression_lab/brand.dart';
import 'package:progression_lab/comprehensive_export.dart';
import 'package:progression_lab/daily_inputs.dart';
import 'package:progression_lab/daily_inputs_screen.dart';
import 'package:progression_lab/lab_analysis.dart';
import 'package:progression_lab/lab_data.dart';
import 'package:progression_lab/lab_experiments.dart';
import 'package:progression_lab/lab_screen.dart';
import 'package:progression_lab/store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const storage = MethodChannel('iron_cadence/storage');
  const portability = MethodChannel('progression_lab/data_portability');
  setUp(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(storage, (_) async => null);
    messenger.setMockMethodCallHandler(portability, (_) async => null);
  });
  tearDown(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(storage, null);
    messenger.setMockMethodCallHandler(portability, null);
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'Lab evidence remains readable at 320px and text scale $scale',
      (tester) async {
        tester.view.physicalSize = const Size(320, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            theme: ProgressionBrand.theme(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: Scaffold(
              body: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      for (final confidence in LabConfidence.values)
                        LabEvidenceCard(
                          evidence: LabEvidence(
                            id: confidence.name,
                            title: 'Pre-workout meals and supplement timing',
                            finding: 'More comparable sessions are needed.',
                            metric: 'Estimated strength',
                            comparison: 'Logged before training',
                            sampleLabel: '3 with · 2 without',
                            confidence: confidence,
                            confounders: const [
                              'Missing entries',
                              'Workout difficulty',
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('More data needed'), findsOneWidget);
        expect(find.text('Stronger evidence'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  test(
    'past legacy sets join the performed day rather than the entry time',
    () {
      final sessions = labCompletedSessions({
        'workoutHistory': [
          {
            'workout': 'Upper',
            'status': 'completed',
            'date': '2026-09-01T18:00:00',
            'startedAt': '2026-09-30T10:00:00',
          },
        ],
        'logs': [
          {
            'e': 'Bench',
            'w': 100,
            'r': 5,
            'o': 'Upper',
            'd': '2026-09-01T18:00:00',
          },
          {
            'e': 'Bench',
            'w': 200,
            'r': 5,
            'o': 'Upper',
            'd': '2026-09-30T10:00:00',
          },
        ],
      });
      expect(sessions.single.occurredAt, DateTime(2026, 9, 1, 18));
      expect(sessions.single.logs.single['w'], 100);
    },
  );

  test('habit windows use the workout start rather than its finish', () {
    final store = AppStore();
    addTearDown(store.dispose);
    for (var i = 0; i < 6; i++) {
      final start = DateTime(2026, 9, 10 + i, 18);
      final finish = start.add(const Duration(hours: 3, minutes: 30));
      final withHabits = i < 3;
      store.workoutHistory.add(
        WorkoutRecord(
          week: 1,
          workoutIndex: 0,
          workout: 'Upper',
          date: finish,
          startedAt: start,
          status: WorkoutStatus.completed,
          sessionId: 's$i',
        ),
      );
      store.logs.add(
        SetLog(
          exercise: 'Bench',
          exerciseId: 'bench',
          weight: withHabits ? 120 : 100,
          reps: 5,
          date: start.add(const Duration(minutes: 10)),
          workout: 'Upper',
          sessionId: 's$i',
        ),
      );
      if (withHabits) {
        store.supplementEvents.add(
          SupplementEvent(
            id: 'coffee$i',
            name: 'Coffee',
            dose: 1,
            unit: 'serving',
            caffeineMg: 180,
            takenAt: start.subtract(const Duration(hours: 1)),
            createdAt: start,
            updatedAt: start,
          ),
        );
        store.mealEvents.add(
          MealEvent(
            id: 'meal$i',
            name: 'Lunch',
            occurredAt: start.subtract(const Duration(hours: 3)),
            createdAt: start,
            updatedAt: start,
          ),
        );
      }
    }
    final report = const LabAnalysisEngine().build(
      store,
      now: DateTime(2026, 9, 30),
    );
    final caffeine = report.evidence.singleWhere(
      (item) => item.id == 'caffeine',
    );
    final meals = report.evidence.singleWhere(
      (item) => item.id == 'meal-timing',
    );
    expect(caffeine.sampleLabel, '3 with · 3 without');
    expect(meals.sampleLabel, '3 with · 3 without');
    expect(caffeine.effectPercent, closeTo(20, .00001));
    expect(meals.effectPercent, closeTo(20, .00001));
  });

  testWidgets('an explicit middle rating saves only that answer', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = AppStore()..automaticBackupsEnabled = false;
    addTearDown(store.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: ProgressionBrand.theme(),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showRecoveryCheckInSheet(context, store),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byWidgetPredicate(
        (widget) =>
            widget is ChoiceChip &&
            widget.tooltip == 'Sleep quality: 3 out of 5',
      ),
    );
    await tester.ensureVisible(find.text('Save'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(store.recoveryCheckIns.single.sleepQuality, 3);
    expect(store.recoveryCheckIns.single.stress, isNull);
    expect(store.recoveryCheckIns.single.soreness, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'focused hydration entry closes after saving without disposing early',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = AppStore()..automaticBackupsEnabled = false;
      addTearDown(store.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: ProgressionBrand.theme(),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showHydrationEntrySheet(context, store),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byWidgetPredicate(
          (widget) =>
              widget is TextField &&
              widget.decoration?.labelText == 'Amount (mL)',
        ),
        '750',
      );
      await tester.ensureVisible(find.text('Save'));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(store.hydrationEvents.single.amountMl, 750);
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'current daily Body readings win over legacy weights with explicit units',
    () {
      final state = <String, dynamic>{
        'unit': 'kg',
        'bodyMeasurements': [
          BodyMeasurement(
            id: 'current',
            metric: BodyMetric.weight,
            value: 90,
            date: '2026-09-29',
            recordedAt: DateTime(2026, 9, 29, 8),
          ).toJson(),
          BodyMeasurement(
            id: 'preferred',
            metric: BodyMetric.weight,
            value: 89,
            date: '2026-09-29',
            recordedAt: DateTime(2026, 9, 29, 9),
            preferred: true,
          ).toJson(),
        ],
        'recoveryCheckIns': [
          {
            'id': 'old-duplicate',
            'localDate': '2026-09-29',
            'bodyWeight': 200,
            'weightUnit': 'lb',
          },
          {
            'id': 'old-day',
            'localDate': '2026-09-28',
            'bodyWeight': 200,
            'weightUnit': 'lb',
          },
        ],
      };
      final weights = labDailyWeights(state);
      expect(weights, hasLength(2));
      expect(weights.first.value, closeTo(90.718474, .000001));
      expect(weights.last.value, 89);
      final csv = utf8.decode(
        ComprehensivePortableExport.portableFiles(state)['body_metrics.csv']!,
      );
      expect(csv, contains('preferred,2026-09-29,89.0,kg'));
      expect(csv, contains('old-day,2026-09-28,90.718474,kg'));
      expect(csv, isNot(contains('old-duplicate')));
    },
  );

  test(
    'Body source preference selects the same reading for Lab and export',
    () {
      final state = <String, dynamic>{
        'unit': 'lb',
        'bodySettings': {'weightSource': 'health'},
        'bodyMeasurements': [
          BodyMeasurement(
            id: 'health',
            metric: BodyMetric.weight,
            value: 80,
            date: '2026-09-29',
            recordedAt: DateTime(2026, 9, 29),
            source: 'health',
          ).toJson(),
          BodyMeasurement(
            id: 'manual',
            metric: BodyMetric.weight,
            value: 85,
            date: '2026-09-29',
            recordedAt: DateTime(2026, 9, 29),
          ).toJson(),
        ],
      };
      expect(labDailyWeights(state).single.id, 'health');
      final csv = utf8.decode(
        ComprehensivePortableExport.portableFiles(state)['body_metrics.csv']!,
      );
      expect(csv, contains('health,2026-09-29,'));
      expect(csv, isNot(contains('manual,2026-09-29,')));
      expect(
        labDailyWeights(state).single.displayValue('lb', 'cm'),
        closeTo(176.36981, .00001),
      );
    },
  );

  Map<String, dynamic> sessionState({bool unrelated = false}) {
    final dates = [
      for (var i = 0; i < 6; i++) DateTime.utc(2026, 9, 10 + i, 18),
    ];
    return {
      'openWorkout': {
        'history': [
          for (var i = 0; i < 3; i++)
            {
              'sessionId': 's$i',
              'startedAt': dates[i].toIso8601String(),
              'completedAt': dates[i]
                  .add(const Duration(hours: 1))
                  .toIso8601String(),
            },
        ],
      },
      'curatedTraining': {
        'history': [
          for (var i = 3; i < 6; i++)
            {
              'sessionId': 's$i',
              'title': 'Iconic Upper',
              'status': 'completed',
              'startedAt': dates[i].toIso8601String(),
              'completedAt': dates[i]
                  .add(const Duration(hours: 1))
                  .toIso8601String(),
            },
          {
            'sessionId': 'partial',
            'title': 'Iconic Upper',
            'status': 'partial',
            'startedAt': dates.first.toIso8601String(),
          },
        ],
      },
      'logs': [
        for (var i = 0; i < 6; i++)
          {
            's': 's$i',
            'e': unrelated && i >= 3 ? 'Squat' : 'Bench',
            'exerciseId': unrelated && i >= 3 ? 'squat' : 'bench',
            'w': i < 3 ? 120 : 100,
            'r': 5,
            'trackingType': 'weightReps',
            'd': dates[i].toIso8601String(),
            'o': 'Workout',
          },
      ],
      'supplementEvents': [
        for (var i = 0; i < 3; i++)
          {
            'name': 'Coffee',
            'caffeineMg': 180,
            'takenAt': dates[i]
                .subtract(const Duration(hours: 1))
                .toIso8601String(),
          },
      ],
      'recoveryCheckIns': [],
    };
  }

  test(
    'standalone imports contribute without a program assignment or double count',
    () {
      final state = sessionState();
      state.remove('openWorkout');
      state.remove('curatedTraining');
      state['importedWorkouts'] = [
        for (var i = 0; i < 6; i++)
          {
            'id': 'import$i',
            'sessionId': 's$i',
            'name': 'Upper',
            'startedAt': DateTime.utc(2026, 9, 10 + i, 18).toIso8601String(),
          },
      ];
      state['workoutHistory'] = [
        {
          'importedWorkoutId': 'import0',
          'sessionId': 's0',
          'workout': 'Upper',
          'status': 'completed',
          'date': '2026-09-10T18:00:00Z',
        },
        {
          'importedWorkoutId': 'import1',
          'sessionId': 's1',
          'workout': 'Upper',
          'status': 'partial',
          'date': '2026-09-11T18:00:00Z',
        },
      ];
      final sessions = labCompletedSessions(state);
      expect(sessions, hasLength(5));
      expect(sessions.where((item) => item.id == 's0'), hasLength(1));
      expect(sessions.any((item) => item.id == 's1'), isFalse);
      final result = LabExperimentAnalyzer.analyze(
        LabExperimentTemplates.caffeineTiming(start: DateTime.utc(2026, 9, 1)),
        state,
      );
      expect(result.samplesA, hasLength(2));
      expect(result.samplesB, hasLength(3));
      state['labDataDomains'] = ['supplements'];
      expect(labCompletedSessions(selectedLabState(state)), isEmpty);
    },
  );

  test(
    'completed Open and Iconic workouts form a comparable experiment cohort',
    () {
      final experiment = LabExperimentTemplates.caffeineTiming(
        start: DateTime.utc(2026, 9, 1),
      );
      final state = sessionState();
      expect(labCompletedSessions(state), hasLength(6));
      final result = LabExperimentAnalyzer.analyze(experiment, state);
      expect(result.samplesA, hasLength(3));
      expect(result.samplesB, hasLength(3));
      expect(result.percentDifference, closeTo(20, .00001));
      expect(result.excludedSessions, 0);
    },
  );

  test(
    'unrelated exercise cohorts cannot become a habit performance conclusion',
    () {
      final experiment = LabExperimentTemplates.caffeineTiming(
        start: DateTime.utc(2026, 9, 1),
      );
      final result = LabExperimentAnalyzer.analyze(
        experiment,
        sessionState(unrelated: true),
      );
      expect(result.confidence, LabExperimentConfidence.insufficient);
      expect(result.samplesA.isEmpty || result.samplesB.isEmpty, isTrue);
      expect(result.percentDifference, isNull);
      expect(result.excludedSessions, 3);
      expect(result.summary, contains('different exercises were excluded'));
    },
  );

  test(
    'workout exclusion removes all modes from experiments and weekly review',
    () {
      final state = sessionState()
        ..['labDataDomains'] = ['supplements', 'recovery'];
      final result = LabExperimentAnalyzer.analyze(
        LabExperimentTemplates.caffeineTiming(start: DateTime.utc(2026, 9, 1)),
        state,
      );
      expect(result.samplesA, isEmpty);
      expect(result.samplesB, isEmpty);
      final review = LabExperimentAnalyzer.weeklyReview(
        state,
        ending: DateTime.utc(2026, 9, 17),
      );
      expect(review.completedStrengthWorkouts, 0);
      expect(review.workingSets, 0);
      expect(review.personalRecords, 0);
      final none = selectedLabState({...state, 'labDataDomains': []});
      expect(labCompletedSessions(none), isEmpty);
      expect(labMaps(none['supplementEvents']), isEmpty);
    },
  );
}
