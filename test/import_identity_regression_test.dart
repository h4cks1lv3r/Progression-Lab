import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:progression_lab/brand.dart';
import 'package:progression_lab/data_portability_core.dart';
import 'package:progression_lab/exercise_library.dart';
import 'package:progression_lab/progress_dashboard.dart';
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

  Future<void> importCsv(
    AppStore app,
    String csv, {
    Map<String, String> mappings = const {},
  }) async {
    final bytes = Uint8List.fromList(utf8.encode(csv));
    final inspection = WorkoutCsvImporter.inspect(
      bytes,
      fileName: 'history.csv',
    );
    final plan = WorkoutCsvImporter.buildPlan(
      inspection: inspection,
      mapping: inspection.suggestedMapping!,
      fileName: 'history.csv',
      fileBytes: bytes,
      targetUnit: app.unit,
      defaultSourceWeightUnit: 'lb',
      knownSignatures: app.knownImportSignatures,
      knownExercises: app.knownExerciseNames,
    );
    await app.applyImport(plan, exerciseMappings: mappings);
  }

  SetLog bench(double weight, {String? id}) => SetLog(
    exercise: 'Barbell Bench Press',
    exerciseId: id,
    weight: weight,
    reps: 5,
    date: DateTime(2026, 9, 29),
    workout: 'Upper',
  );

  test(
    'old name-only lifting history remains a PR benchmark after live logging',
    () async {
      final app = AppStore()..automaticBackupsEnabled = false;
      app.logs = [bench(200), bench(100, id: 'barbell_bench_press')];
      expect(app.isPr(bench(150, id: 'barbell_bench_press')), isFalse);
      expect(app.best('Barbell Bench Press')!.weight, 200);
      expect(app.exerciseHistoryKey(app.logs.first), 'barbell_bench_press');
      // A separately reviewed identity is never reassigned by its display name.
      final distinct = bench(300, id: 'custom-reviewed-bench');
      expect(app.exerciseHistoryKey(distinct), 'custom-reviewed-bench');
    },
  );

  test(
    'import mapping uses reviewed catalog identity and retains original measurements',
    () async {
      final app = AppStore()..automaticBackupsEnabled = false;
      await importCsv(
        app,
        'Date,Workout Name,Exercise Name,Weight,Weight Unit,Reps\n'
        '2026-09-29,Upper,My bench,200,lb,5\n',
        mappings: {'My bench': 'barbell_bench_press'},
      );
      final log = app.logs.single;
      expect(log.exerciseId, 'barbell_bench_press');
      expect(log.exercise, 'Barbell Bench Press');
      expect(log.weight, 200);
      expect(log.reps, 5);
      expect(log.date, DateTime(2026, 9, 29));
      expect(log.loggedAt, isNotNull);
      expect(await app.add(bench(150, id: 'barbell_bench_press')), isFalse);
    },
  );

  test(
    'bodyweight, assistance, added load, timed and distance imports keep distinct metrics',
    () async {
      final app = AppStore()..automaticBackupsEnabled = false;
      await importCsv(
        app,
        'Date,Workout Name,Exercise Name,Weight,Weight Unit,Reps,Set Duration,Distance,Distance Unit\n'
        '2026-09-29,Mixed,Push-Up,0,lb,12,,,\n'
        '2026-09-29,Mixed,Assisted Pull-Up,40,lb,6,,,\n'
        '2026-09-29,Mixed,Weighted Pull-Up,20,lb,5,,,\n'
        '2026-09-29,Mixed,Front Plank,0,lb,,45,,\n'
        '2026-09-29,Mixed,Evening run,0,lb,,600,2,km\n',
      );
      expect(app.logs.map((log) => log.resolvedTrackingType), [
        ExerciseTrackingType.bodyweightReps,
        ExerciseTrackingType.assistedBodyweight,
        ExerciseTrackingType.weightedBodyweight,
        ExerciseTrackingType.duration,
        ExerciseTrackingType.distanceDuration,
      ]);
      expect(app.logs[1].weight, 40);
      expect(app.logs[2].weight, 20);
      expect(app.logs[3].durationSeconds, 45);
      expect(app.logs[4].distanceInMeters, 2000);
      expect(app.logs[4].durationSeconds, 600);
      expect(
        app.customExercises.single.trackingType,
        ExerciseTrackingType.distanceDuration,
      );
    },
  );

  test(
    'legacy import repair preserves explicit native tracking and unknown reviewed IDs',
    () async {
      final app = AppStore()..automaticBackupsEnabled = false;
      Map<String, dynamic> plank({String? source, String? id}) => SetLog(
        exercise: 'Front Plank',
        weight: 0,
        reps: 0,
        durationSeconds: 45,
        date: DateTime(2026, 9, 29),
        workout: 'Core',
        trackingType: 'weightReps',
        sourceApp: source,
        exerciseId: id,
      ).toJson();
      final state = app.exportState()
        ..['logs'] = [
          plank(source: 'CSV'),
          plank(),
          plank(source: 'CSV', id: 'reviewed-plank'),
        ]
        ..['labDataDomains'] = <String>[];
      await app.restoreState(state);
      expect(app.logs[0].exerciseId, 'front_plank');
      expect(app.logs[0].resolvedTrackingType, ExerciseTrackingType.duration);
      expect(app.logs[0].durationSeconds, 45);
      expect(app.logs[1].trackingType, 'weightReps');
      expect(app.logs[2].exerciseId, 'reviewed-plank');
      expect(app.labDataDomains, isEmpty);
      await app.restoreState(app.exportState());
      expect(app.labDataDomains, isEmpty);
    },
  );

  test(
    'ambiguous legacy alias does not merge separately reviewed movements',
    () {
      final app = AppStore();
      app.customExercises = [
        const CustomExercise(
          id: 'variation-a',
          name: 'Bench A',
          aliases: ['Old bench'],
        ),
        const CustomExercise(
          id: 'variation-b',
          name: 'Bench B',
          aliases: ['Old bench'],
        ),
      ];
      final old = SetLog(
        exercise: 'Old bench',
        weight: 200,
        reps: 5,
        date: DateTime(2026, 9, 29),
        workout: 'Upper',
      );
      expect(app.exerciseHistoryKey(old), 'name:old bench');
      expect(
        app.exerciseHistoryKey(old.copyWith(exerciseId: 'variation-a')),
        'variation-a',
      );
    },
  );

  test('portable Strength dates use performed time instead of entry time', () {
    final app = AppStore();
    final performed = DateTime(2026, 9, 25, 18, 30);
    final entered = DateTime(2026, 9, 30, 12);
    app.workoutHistory = [
      WorkoutRecord(
        week: 1,
        workoutIndex: 0,
        workout: 'Upper',
        date: performed,
        loggedAt: entered,
        status: WorkoutStatus.completed,
        sessionId: 'past-workout',
        retroactive: true,
      ),
    ];
    final files = ProgressionCsvExport.portableFiles(app.exportState());
    final rows = CsvCodec.decode(utf8.decode(files['workouts.csv']!));
    final startIndex = rows.first.indexOf('started_at');
    final sourceDateIndex = rows.first.indexOf('source_started_at_raw');
    expect(rows[1][startIndex], performed.toIso8601String());
    expect(rows[1][sourceDateIndex], performed.toIso8601String());
    expect(app.workoutHistory.single.loggedAt, entered);
  });

  testWidgets(
    'same-time chart dots and recent-set list select the displayed set',
    (tester) async {
      final app = AppStore()..automaticBackupsEnabled = false;
      app.logs = [bench(100), bench(150), bench(200)];
      await tester.pumpWidget(
        MaterialApp(
          theme: ProgressionBrand.theme(),
          home: Scaffold(body: ProgressDashboard(store: app)),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('All').first);
      await tester.pumpAndSettle();
      final chart = find.byWidgetPredicate(
        (widget) => widget is SizedBox && widget.height == 150,
      );
      await tester.ensureVisible(chart);
      await tester.pumpAndSettle();
      final origin = tester.getTopLeft(chart), size = tester.getSize(chart);
      await tester.tapAt(origin + Offset(size.width - 10, 10));
      await tester.pumpAndSettle();
      expect(find.text('9/29/2026 · 200 lb · 5 reps'), findsOneWidget);
      final recent = find.widgetWithText(ListTile, '100 lb · 5 reps').first;
      await tester.ensureVisible(recent);
      await tester.tap(recent);
      await tester.pumpAndSettle();
      expect(find.text('9/29/2026 · 100 lb · 5 reps'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
