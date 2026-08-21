import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:progression_lab/brand.dart';
import 'package:progression_lab/daily_inputs.dart';
import 'package:progression_lab/daily_inputs_screen.dart';
import 'package:progression_lab/lab_analysis.dart';
import 'package:progression_lab/lab_screen.dart';
import 'package:progression_lab/store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const storageChannel = MethodChannel('iron_cadence/storage');
  String? storedValue;

  setUp(() {
    storedValue = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storageChannel, (call) async {
          switch (call.method) {
            case 'read':
              return storedValue;
            case 'write':
              storedValue = call.arguments as String;
              return null;
            default:
              throw PlatformException(code: 'unknown_method');
          }
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storageChannel, null);
  });

  group('daily inputs persistence', () {
    test('seeds useful presets and does not double-count embedded caffeine', () async {
      final store = AppStore();
      final coffee = store.supplementPresets.singleWhere(
        (preset) => preset.id == 'preset-coffee',
      );
      final preWorkout = store.supplementPresets.singleWhere(
        (preset) => preset.id == 'preset-preworkout',
      );
      final takenAt = DateTime(2026, 8, 20, 8, 30);

      await store.logSupplementPreset(coffee, takenAt: takenAt);
      await store.logSupplementPreset(
        preWorkout,
        takenAt: takenAt.add(const Duration(hours: 4)),
      );

      expect(store.supplementEventsForDay(takenAt), hasLength(2));
      expect(store.caffeineForDay(takenAt), 430);
      final saved = jsonDecode(storedValue!) as Map<String, dynamic>;
      expect(saved['supplementEvents'], hasLength(2));
      expect(saved['schemaVersion'], AppStore.schemaVersion);
    });

    test('schema eight migrates additively to the current schema with AI disabled by default', () async {
      storedValue = jsonEncode({
        'schemaVersion': 8,
        'days': 4,
        'week': 1,
        'workout': 0,
        'unit': 'lb',
        'logs': <Object>[],
      });
      final store = AppStore();

      await store.load();

      expect(store.supplementPresets, isNotEmpty);
      expect(store.supplementEvents, isEmpty);
      expect(store.aiAnalysisEnabled, isFalse);
      expect(store.labDataDomains, containsAll(LabDataDomain.values));
      final migrated = jsonDecode(storedValue!) as Map<String, dynamic>;
      expect(migrated['schemaVersion'], AppStore.schemaVersion);
      expect(migrated['aiAnalysisEnabled'], isFalse);
      expect(migrated['labDataDomains'], hasLength(LabDataDomain.values.length));
    });

    test('recovery, workout response, and AI preferences round-trip', () async {
      final now = DateTime(2026, 8, 20, 19);
      final store = AppStore();
      await store.saveRecoveryCheckIn(
        RecoveryCheckIn(
          id: 'recovery-1',
          localDate: now,
          sleepHours: 7.5,
          sleepQuality: 4,
          stress: 2,
          soreness: 3,
          bodyWeight: 205,
          weightUnit: 'lb',
          createdAt: now,
          updatedAt: now,
        ),
      );
      await store.saveWorkoutResponse(
        WorkoutResponse(
          id: 'response-1',
          workoutSessionId: 'session-1',
          recordedAt: now,
          energy: 4,
          focus: 5,
          pump: 4,
          effort: 4,
          discomfort: 1,
          createdAt: now,
          updatedAt: now,
        ),
      );
      await store.setAiAnalysisEnabled(true);
      await store.setLabDataDomain(LabDataDomain.meals, false);

      final restored = AppStore();
      await restored.load();

      expect(restored.recoveryForDay(now)?.sleepHours, 7.5);
      expect(restored.responseForSession('session-1')?.focus, 5);
      expect(restored.aiAnalysisEnabled, isTrue);
      expect(restored.labDataDomains, isNot(contains(LabDataDomain.meals)));
    });
  });

  group('Lab Core analysis', () {
    test('returns honest insufficient-data evidence for a new user', () {
      final report = const LabAnalysisEngine().build(
        AppStore(),
        now: DateTime(2026, 8, 20, 12),
      );

      expect(report.evidence, isNotEmpty);
      expect(report.supportedEvidence, isEmpty);
      expect(
        report.evidence.every(
          (evidence) => evidence.confidence == LabConfidence.insufficient,
        ),
        isTrue,
      );
      expect(report.toPromptPacket(), contains('Describe associations, never causation.'));
    });

    test('detects a preliminary caffeine association from matched sessions', () {
      final now = DateTime(2026, 8, 20, 20);
      final store = AppStore();
      final records = <WorkoutRecord>[];
      final logs = <SetLog>[];
      final supplements = <SupplementEvent>[];

      for (var index = 0; index < 6; index++) {
        final start = now.subtract(Duration(days: 42 - index * 6));
        final withCaffeine = index.isEven;
        final sessionId = 'matched-$index';
        records.add(
          WorkoutRecord(
            week: 1,
            workoutIndex: 0,
            workout: 'Upper Body A',
            date: start,
            loggedAt: start.add(const Duration(hours: 1)),
            scheduledDate: start,
            status: WorkoutStatus.completed,
            sessionId: sessionId,
          ),
        );
        logs.add(
          SetLog(
            exercise: 'Barbell Bench Press',
            weight: withCaffeine ? 120 : 100,
            reps: 5,
            date: start,
            workout: 'Upper Body A',
            sessionId: sessionId,
            exerciseIndex: 0,
          ),
        );
        if (withCaffeine) {
          supplements.add(
            SupplementEvent(
              id: 'caffeine-$index',
              name: 'Coffee',
              dose: 1,
              unit: 'serving',
              caffeineMg: 180,
              takenAt: start.subtract(const Duration(minutes: 60)),
              createdAt: start,
              updatedAt: start,
            ),
          );
        }
      }
      store
        ..workoutHistory = records
        ..logs = logs
        ..supplementEvents = supplements;

      final report = const LabAnalysisEngine().build(store, now: now);
      final caffeine = report.evidence.singleWhere(
        (evidence) => evidence.id == 'caffeine',
      );

      expect(caffeine.confidence, LabConfidence.preliminary);
      expect(caffeine.effectPercent, isNotNull);
      expect(caffeine.effectPercent!, greaterThan(10));
      expect(caffeine.sampleLabel, contains('3 with'));
      expect(caffeine.sampleLabel, contains('3 without'));
    });
  });

  testWidgets('daily inputs and Lab Core screens render with AI off', (tester) async {
    final store = AppStore();

    await tester.pumpWidget(
      MaterialApp(
        theme: ProgressionBrand.theme(),
        home: DailyInputsScreen(store: store),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('DAILY INPUTS & RECOVERY'), findsOneWidget);
    expect(find.text('TODAY AT A GLANCE'), findsOneWidget);
    expect(find.text('QUICK ADD'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        theme: ProgressionBrand.theme(),
        home: LabScreen(store: store),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('THE LAB'), findsOneWidget);
    expect(find.text('WHAT IS MOVING THE NEEDLE?'), findsOneWidget);
    expect(find.text('Use AI Analysis'), findsOneWidget);
    expect(find.text('EXPLAIN THESE RESULTS WITH GEMINI'), findsNothing);
  });
}
