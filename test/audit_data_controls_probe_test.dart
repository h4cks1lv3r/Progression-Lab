import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:progression_lab/brand.dart';
import 'package:progression_lab/daily_inputs.dart';
import 'package:progression_lab/daily_inputs_screen.dart';
import 'package:progression_lab/lab_analysis.dart';
import 'package:progression_lab/store.dart';

// Regression cases recovered from the independent audit.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const storage = MethodChannel('iron_cadence/storage');
  const portability = MethodChannel('progression_lab/data_portability');
  setUp(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(storage, (call) async => null);
    messenger.setMockMethodCallHandler(portability, (call) async => null);
  });
  tearDown(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(storage, null);
    messenger.setMockMethodCallHandler(portability, null);
  });

  testWidgets('entering sleep only leaves untouched ratings unanswered', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final app = AppStore()..automaticBackupsEnabled = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: ProgressionBrand.theme(),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showRecoveryCheckInSheet(context, app),
              child: const Text('Open recovery'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open recovery'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.labelText == 'Sleep hours',
      ),
      '7.5',
    );
    // No rating slider is touched.
    await tester.ensureVisible(find.text('Save'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    final saved = app.recoveryCheckIns.single;
    expect(saved.sleepHours, 7.5);
    expect(
      [saved.sleepQuality, saved.stress, saved.soreness],
      [null, null, null],
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    app.dispose();
  });

  test(
    'Workouts switched off excludes derived comparisons and AI packet data',
    () async {
      final app = AppStore()..automaticBackupsEnabled = false;
      final now = DateTime.now();
      for (var index = 0; index < 6; index++) {
        final start = now.subtract(Duration(days: 9 - index));
        final withCaffeine = index.isEven;
        final sessionId = 'completed-$index';
        app.workoutHistory.add(
          WorkoutRecord(
            week: 1,
            workoutIndex: 0,
            workout: 'Upper',
            date: start,
            status: WorkoutStatus.completed,
            sessionId: sessionId,
          ),
        );
        app.logs.add(
          SetLog(
            exercise: 'Barbell Bench Press',
            exerciseId: 'barbell_bench_press',
            weight: 150,
            reps: 5,
            date: start,
            workout: 'Upper',
            sessionId: sessionId,
          ),
        );
        if (withCaffeine)
          app.supplementEvents.add(
            SupplementEvent(
              id: 'coffee-$index',
              name: 'Coffee',
              dose: 1,
              unit: 'serving',
              caffeineMg: 180,
              takenAt: start.subtract(const Duration(hours: 1)),
              createdAt: start,
              updatedAt: start,
            ),
          );
        await app.saveRecoveryCheckIn(
          RecoveryCheckIn(
            id: 'sleep-$index',
            localDate: start,
            sleepHours: withCaffeine ? 8 : 6,
            createdAt: start,
            updatedAt: start,
          ),
        );
      }
      await app.setLabDataDomain(LabDataDomain.workouts, false);
      final report = const LabAnalysisEngine().build(app, now: now);
      expect(
        report.evidence.any((item) => item.id == 'strength-trend'),
        isFalse,
      );
      expect(report.evidence.any((item) => item.id == 'caffeine'), isFalse);
      expect(report.evidence.any((item) => item.id == 'sleep'), isFalse);
      final packet = jsonDecode(report.toPromptPacket()) as Map;
      expect((packet['dataSummary'] as Map)['strengthSessions'] ?? 0, 0);
      expect((packet['dataSummary'] as Map)['strengthSets'] ?? 0, 0);
      app.dispose();
    },
  );
}
