import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:progression_lab/body_progress.dart';
import 'package:progression_lab/brand.dart';
import 'package:progression_lab/cloud_sync.dart';
import 'package:progression_lab/data_portability_core.dart';
import 'package:progression_lab/lab_analysis.dart';
import 'package:progression_lab/progress_dashboard.dart';
import 'package:progression_lab/store.dart';

// Regression cases recovered from the independent audit; storage channels are mocked.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const storage = MethodChannel('iron_cadence/storage');
  const portability = MethodChannel('progression_lab/data_portability');
  const cloudChannel = MethodChannel('progression_lab/audit_cloud');
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storage, (call) async => null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(portability, (call) async => null);
  });
  tearDown(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(storage, null);
    messenger.setMockMethodCallHandler(portability, null);
    messenger.setMockMethodCallHandler(cloudChannel, null);
  });

  AppStore store() => AppStore()..automaticBackupsEnabled = false;

  Future<void> importCsv(AppStore app, String csv) async {
    final bytes = Uint8List.fromList(utf8.encode(csv));
    final inspection = WorkoutCsvImporter.inspect(bytes, fileName: 'audit.csv');
    final plan = WorkoutCsvImporter.buildPlan(
      inspection: inspection,
      mapping: inspection.suggestedMapping!,
      fileName: 'audit.csv',
      fileBytes: bytes,
      targetUnit: app.unit,
      defaultSourceWeightUnit: 'lb',
      knownSignatures: app.knownImportSignatures,
      knownExercises: app.knownExerciseNames,
    );
    await app.applyImport(plan);
  }

  test('three saved Body weights contribute to the Lab trend', () async {
    final app = store();
    final now = DateTime(2026, 9, 30, 18);
    await app.saveBodyMeasurements([
      for (var i = 0; i < 3; i++)
        BodyMeasurement(
          id: 'weigh-in-$i',
          metric: BodyMetric.weight,
          value: 93 - i.toDouble(),
          date: bodyDay(now.subtract(Duration(days: 2 - i))),
          recordedAt: now.subtract(Duration(days: 2 - i)),
        ),
    ]);
    expect(app.bodyWeightForDay(now)!.displayValue('kg', 'cm'), 91);
    final card = const LabAnalysisEngine()
        .build(app, now: now)
        .evidence
        .singleWhere((item) => item.id == 'bodyweight');
    expect(card.sampleLabel, '3 entries');
    expect(card.effectPercent, closeTo(-200 / 93, .01));
    expect(
      card.finding,
      isNot('More bodyweight entries are needed to establish a trend.'),
    );
  });

  testWidgets('imported and new sets of one exercise share a progress series', (
    tester,
  ) async {
    final app = store();
    await importCsv(
      app,
      'Date,Workout Name,Exercise Name,Weight,Weight Unit,Reps\n'
      '2026-09-29 18:00,Upper,Barbell Bench Press,180,lb,5\n',
    );
    final draft = await app.beginOpenWorkout();
    await app.addOpenWorkoutExercise(
      sessionId: draft.sessionId,
      exerciseId: 'barbell_bench_press',
    );
    await app.logOpenWorkoutSet(
      sessionId: draft.sessionId,
      exerciseIndex: 0,
      setSequence: 0,
      weight: 185,
      reps: 5,
    );
    expect(app.logs.map((log) => log.exercise).toSet(), {
      'Barbell Bench Press',
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: ProgressionBrand.theme(),
        home: Scaffold(body: ProgressDashboard(store: app)),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining(RegExp(r'1 exercises? · 2 logged sets')),
      findsOneWidget,
    );
    expect(app.logs.map((log) => log.exerciseId).toSet(), {
      'barbell_bench_press',
    });
  });

  testWidgets('a duration-only imported plank exposes duration metrics', (
    tester,
  ) async {
    final app = store();
    await importCsv(
      app,
      'Date,Workout Name,Exercise Name,Set Duration\n'
      '2026-09-29 18:00,Core,Front Plank,45\n',
    );
    expect(app.logs.single.durationSeconds, 45);
    await tester.pumpWidget(
      MaterialApp(
        theme: ProgressionBrand.theme(),
        home: Scaffold(body: ProgressDashboard(store: app)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Estimated 1RM'), findsNothing);
    expect(find.text('Duration'), findsWidgets);
  });

  test(
    'personal-best comparison retains stronger imported performance',
    () async {
      final app = store();
      await importCsv(
        app,
        'Date,Workout Name,Exercise Name,Weight,Weight Unit,Reps\n'
        '2026-09-29 18:00,Upper,Barbell Bench Press,200,lb,5\n',
      );
      SetLog liveSet(double weight) => SetLog(
        exercise: 'Barbell Bench Press',
        exerciseId: 'barbell_bench_press',
        weight: weight,
        reps: 5,
        date: DateTime.now(),
        workout: 'Upper',
      );
      expect(await app.add(liveSet(100)), isFalse);
      expect(await app.add(liveSet(150)), isFalse);
      expect(app.best('Barbell Bench Press')!.weight, 200);
    },
  );

  testWidgets(
    'tap on last chart point selects that set despite identical timestamps',
    (tester) async {
      final app = store();
      await importCsv(
        app,
        'Date,Workout Name,Exercise Name,Weight,Weight Unit,Reps\n'
        '2026-09-29 18:00,Upper,Barbell Bench Press,100,lb,5\n'
        '2026-09-29 18:00,Upper,Barbell Bench Press,150,lb,5\n'
        '2026-09-29 18:00,Upper,Barbell Bench Press,200,lb,5\n',
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: ProgressionBrand.theme(),
          home: Scaffold(body: ProgressDashboard(store: app)),
        ),
      );
      await tester.pumpAndSettle();
      // Keep the historical audit fixture selectable after the default 90-day window.
      await tester.ensureVisible(find.text('All'));
      await tester.tap(find.text('All'));
      await tester.pumpAndSettle();
      expect(find.text('9/29/2026 · 200 lb · 5 reps'), findsOneWidget);
      final chart = find.byWidgetPredicate(
        (widget) => widget is SizedBox && widget.height == 150,
      );
      expect(chart, findsOneWidget);
      await tester.ensureVisible(chart);
      await tester.pumpAndSettle();
      final origin = tester.getTopLeft(chart);
      final size = tester.getSize(chart);
      await tester.tapAt(origin + Offset(12, size.height / 2));
      await tester.pumpAndSettle();
      expect(find.text('9/29/2026 · 100 lb · 5 reps'), findsOneWidget);
      await tester.tapAt(origin + Offset(size.width - 12, size.height / 2));
      await tester.pumpAndSettle();
      expect(find.text('9/29/2026 · 200 lb · 5 reps'), findsOneWidget);
      expect(find.text('9/29/2026 · 100 lb · 5 reps'), findsNothing);
    },
  );

  test('completed Open Workout contributes to Lab strength sessions', () async {
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
      weight: 185,
      reps: 5,
    );
    await app.finishOpenWorkout(draft.sessionId);
    expect(app.openWorkoutHistory, hasLength(1));
    final report = const LabAnalysisEngine().build(app);
    expect(report.dataSummary['strengthSessions'], 1);
    expect(
      report.evidence.singleWhere((item) => item.id == 'caffeine').confidence,
      LabConfidence.insufficient,
    );
  });

  test('blank new phone with an older cloud backup offers restore', () async {
    final old = DateTime.now().toUtc().subtract(const Duration(days: 1));
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(cloudChannel, (call) async {
          if (call.method == 'listBackups') {
            return [
              {
                'name': 'Old-phone-full-history.plab',
                'modifiedAt': old.toIso8601String(),
                'createdAt': old.toIso8601String(),
                'size': 1000,
              },
            ];
          }
          return null;
        });
    final service = CloudBackupSyncService(
      store: store(),
      channel: cloudChannel,
    );
    final preview = await service.preview();
    expect(preview.direction, CloudSyncDirection.download);
    expect(preview.remote!.name, 'Old-phone-full-history.plab');
    service.dispose();
  });
}
