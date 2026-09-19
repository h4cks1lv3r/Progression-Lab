import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:progression_lab/brand.dart';
import 'package:progression_lab/data_portability_core.dart';
import 'package:progression_lab/program.dart';
import 'package:progression_lab/program_navigator.dart';
import 'package:progression_lab/store.dart';
import 'package:progression_lab/strength_history_backfill.dart';
import 'package:progression_lab/strength_history_review.dart';

void addImported(
  AppStore store,
  String id,
  DateTime date,
  WorkoutPlan plan, {
  bool partial = false,
  bool warmupsOnly = false,
  String? signature,
}) {
  store.importedWorkouts.add(
    ImportedWorkoutRecord(
      id: id,
      sessionId: id,
      source: 'Strong',
      name: 'Previous $id',
      startedAt: date,
      sourceTimestamp: date.toIso8601String(),
      signature: signature ?? id,
      importBatchId: 'batch',
      durationSeconds: 1800,
      notes: 'Original session notes',
    ),
  );
  for (final exercise in plan.exercises) {
    for (var i = 0; i < (partial ? 1 : exercise.sets); i++) {
      store.logs.add(
        SetLog(
          exercise: exercise.name,
          weight: 125,
          reps: 8,
          date: date,
          workout: 'Previous $id',
          sessionId: id,
          setOrder: i + 1,
          setType: warmupsOnly ? 'warmup' : 'normal',
          importBatchId: 'batch',
          notes: 'Original set notes',
        ),
      );
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('iron_cadence/storage');
  String? saved;
  var failWrites = false;
  final nextDate = DateTime(2026, 9, 14);

  setUp(() {
    saved = null;
    failWrites = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'read') return saved;
          if (call.method == 'write') {
            if (failWrites) throw PlatformException(code: 'write_failed');
            saved = call.arguments as String;
          }
          return null;
        });
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );

  StrengthHistoryPreview preview(
    AppStore store, {
    int target = 3,
    int days = 4,
    int index = 0,
    bool newRun = false,
  }) => store.previewStrengthHistory(
    targetWeek: target,
    cadence: days,
    nextWorkoutIndex: index,
    nextWorkoutDate: nextDate,
    startNewRun: newRun,
  );

  Future<void> apply(
    AppStore store,
    StrengthHistoryPreview plan,
    Map<String, String> selected, {
    int target = 3,
    int days = 4,
    int index = 0,
    bool newRun = false,
  }) => store.setStrengthProgramPosition(
    phase: ProgramEngine.phaseForWeek(target),
    microcycle: ProgramEngine.microcycleForWeek(target),
    cadence: days,
    nextWorkoutIndex: index,
    nextWorkoutDate: nextDate,
    startNewRun: newRun,
    historyBackfill: StrengthHistorySelection(plan, selected),
  );

  test(
    'all phases and cadences allow entry with no fabricated earlier history',
    () async {
      for (final days in [3, 4, 5]) {
        for (final target in [1, 16, 17, 32, 33, 48]) {
          final store = AppStore()..automaticBackupsEnabled = false;
          final plan = preview(
            store,
            target: target,
            days: days,
            index: days - 1,
          );
          expect(plan.slots.length, (target - 1) * days + days - 1);
          expect(plan.suggest(), isEmpty);
          await apply(
            store,
            plan,
            {},
            target: target,
            days: days,
            index: days - 1,
          );
          expect(store.week, target);
          expect(store.days, days);
          expect(store.workoutIndex, days - 1);
          expect(store.workoutHistory, isEmpty);
          expect(store.dateForSlot(target, days - 1), nextDate);
        }
      }
    },
  );

  test(
    'matches all prior sessions, preserves gaps, excludes unrelated and future sessions',
    () {
      for (final days in [3, 4, 5]) {
        final store = AppStore();
        final slots = preview(store, days: days).slots;
        for (final slot in slots) {
          if (slot.week == 1 && slot.workoutIndex == 1) continue;
          addImported(store, slot.id, slot.date, slot.workout);
        }
        addImported(store, 'future', nextDate, slots.first.workout);
        addImported(
          store,
          'warmups',
          slots[1].date,
          slots[1].workout,
          warmupsOnly: true,
        );
        addImported(
          store,
          'unrelated',
          slots[1].date,
          const WorkoutPlan('Run', [
            ExercisePlan('Unknown running exercise', 3, '8'),
          ]),
        );
        final plan = preview(store, days: days);
        final matches = plan.suggest();
        expect(matches.length, slots.length - 1);
        for (final entry in matches.entries) {
          expect(entry.key, entry.value);
        }
        expect(matches.containsKey('1:1'), isFalse);
        expect(matches.values.toSet().length, matches.length);
        plan.validate(matches);
      }
    },
  );

  test(
    'applying and reloading links original sets once and preserves source data',
    () async {
      final store = AppStore()..automaticBackupsEnabled = false;
      final slots = preview(store).slots;
      addImported(store, 'full', slots[0].date, slots[0].workout);
      addImported(
        store,
        'partial',
        slots[1].date,
        slots[1].workout,
        partial: true,
      );
      final originalLogs = jsonEncode(
        store.logs.map((e) => e.toJson()).toList(),
      );
      final originalImports = jsonEncode(
        store.importedWorkouts.map((e) => e.toJson()).toList(),
      );
      final plan = preview(store);
      await apply(store, plan, plan.suggest());
      expect(store.week, 3);
      expect(store.workoutHistory.length, 2);
      expect(store.workoutHistory[0].status, WorkoutStatus.completed);
      expect(store.workoutHistory[1].status, WorkoutStatus.partial);
      expect(store.workoutHistory[0].date, slots[0].date);
      expect(store.workoutHistory[0].importedWorkoutId, 'full');
      expect(store.recordsForSlot(1, 0).single.sessionId, 'full');
      expect(
        jsonEncode(store.logs.map((e) => e.toJson()).toList()),
        originalLogs,
      );
      expect(
        jsonEncode(store.importedWorkouts.map((e) => e.toJson()).toList()),
        originalImports,
      );
      final restored = AppStore();
      await restored.load();
      expect(restored.workoutHistory[0].importedWorkoutId, 'full');
      expect(restored.logs.length, store.logs.length);
      expect(preview(restored).sessions, isEmpty);
      // Linking never adds duplicate workout or set rows to portable export.
      final files = ProgressionCsvExport.portableFiles(store.exportState());
      final rows = CsvCodec.decode(utf8.decode(files['workouts.csv']!));
      expect(rows.length, 3);
    },
  );

  test(
    'prevents duplicate, occupied, future-slot and stale assignments',
    () async {
      final store = AppStore()..automaticBackupsEnabled = false;
      final slot = preview(store).slots.first;
      addImported(store, 'a', slot.date, slot.workout);
      addImported(store, 'duplicate', slot.date, slot.workout, signature: 'a');
      final plan = preview(store);
      expect(plan.sessions.length, 1);
      expect(() => plan.validate({'1:0': 'a', '2:0': 'a'}), throwsStateError);
      expect(() => plan.validate({'3:0': 'a'}), throwsStateError);
      store.workoutHistory.add(
        WorkoutRecord(
          week: 1,
          workoutIndex: 0,
          workout: slot.workout.name,
          date: slot.date,
          status: WorkoutStatus.skipped,
        ),
      );
      expect(preview(store).slots.first.blocked, isTrue);
      expect(() => preview(store).validate({'1:0': 'a'}), throwsStateError);
      await expectLater(apply(store, plan, {'1:0': 'a'}), throwsStateError);
      expect(store.week, 1);
    },
  );

  test(
    'manual matches may use older history but cannot reverse chronological order',
    () {
      final store = AppStore();
      final slot = preview(store).slots.first;
      addImported(store, 'old', DateTime(2020), slot.workout);
      addImported(store, 'new', slot.date, slot.workout);
      final plan = preview(store);
      expect(
        () => plan.validate({'1:0': 'old', '2:0': 'new'}),
        returnsNormally,
      );
      expect(
        () => plan.validate({'1:0': 'new', '2:0': 'old'}),
        throwsStateError,
      );
      expect(plan.suggest().values, isNot(contains('old')));
    },
  );

  test(
    'phase-three entry includes earlier workouts in its selected microcycle',
    () async {
      final store = AppStore()..automaticBackupsEnabled = false;
      final old = WorkoutRecord(
        week: 47,
        workoutIndex: 0,
        workout: 'Old run',
        date: DateTime(2025),
        status: WorkoutStatus.completed,
        days: 5,
      );
      store.workoutHistory.add(old);
      final initial = preview(
        store,
        target: 48,
        days: 5,
        index: 4,
        newRun: true,
      );
      for (final slot in initial.slots.where((s) => s.week >= 47)) {
        addImported(store, slot.id, slot.date, slot.workout);
      }
      final plan = preview(store, target: 48, days: 5, index: 4, newRun: true);
      expect(plan.suggest().length, 9);
      await apply(
        store,
        plan,
        plan.suggest(),
        target: 48,
        days: 5,
        index: 4,
        newRun: true,
      );
      expect(store.strengthProgramRun, 2);
      expect(store.workoutHistory.first, same(old));
      expect(store.recordsForSlot(48, 3).single.importedWorkoutId, '48:3');
      expect(store.recordsForSlot(48, 4), isEmpty);
      expect(store.workoutIndex, 4);
    },
  );

  test(
    'draft slots stay unfilled and edits invalidate a reviewed source',
    () async {
      final store = AppStore()..automaticBackupsEnabled = false;
      final slot = preview(store).slots.first;
      addImported(store, 'a', slot.date, slot.workout);
      store.drafts.add(
        DraftSetInput(
          week: 1,
          workoutIndex: 0,
          workout: slot.workout.name,
          exerciseIndex: 0,
          setNumber: 1,
          sessionId: 'draft',
          weight: '100',
          reps: '8',
          notes: '',
          retroactive: true,
        ),
      );
      final plan = preview(store);
      expect(plan.slots.first.blocked, isTrue);
      expect(plan.suggest().containsKey('1:0'), isFalse);
      store.drafts.clear();
      final fresh = preview(store);
      store.logs[0] = store.logs[0].copyWith(weight: 150);
      await expectLater(apply(store, fresh, fresh.suggest()), throwsStateError);
      expect(store.workoutHistory, isEmpty);
    },
  );

  test(
    'save failure rolls back position, history and drafts together',
    () async {
      final store = AppStore()..automaticBackupsEnabled = false;
      final slot = preview(store).slots.first;
      addImported(store, 'a', slot.date, slot.workout);
      final plan = preview(store, newRun: true);
      final before = jsonEncode(store.exportState());
      failWrites = true;
      await expectLater(
        apply(store, plan, plan.suggest(), newRun: true),
        throwsA(isA<PlatformException>()),
      );
      expect(jsonEncode(store.exportState()), before);
    },
  );

  test(
    'unlink and undo-import clear program links while preserving position',
    () async {
      final store = AppStore()..automaticBackupsEnabled = false;
      final slots = preview(store).slots;
      addImported(store, 'a', slots[0].date, slots[0].workout);
      addImported(store, 'b', slots[1].date, slots[1].workout);
      final plan = preview(store);
      await apply(store, plan, plan.suggest());
      final count = store.logs.length;
      await store.unlinkStrengthHistory(store.workoutHistory.first);
      expect(store.workoutHistory.length, 1);
      expect(store.logs.length, count);
      expect(store.importedWorkouts.length, 2);
      store.importHistory.add(
        DataImportBatch(
          id: 'batch',
          source: 'Strong',
          fileName: 'history.csv',
          fileHash: 'hash',
          importedAt: nextDate,
          workoutIds: ['a', 'b'],
          sessionIds: ['a', 'b'],
          createdExerciseIds: [],
          signatures: ['a', 'b'],
          workoutCount: 2,
          setCount: count,
        ),
      );
      failWrites = true;
      await expectLater(
        store.undoLastImport(),
        throwsA(isA<PlatformException>()),
      );
      expect(store.workoutHistory.length, 1);
      expect(store.logs.length, count);
      failWrites = false;
      await store.undoLastImport();
      expect(store.workoutHistory, isEmpty);
      expect(store.logs, isEmpty);
      expect(store.importedWorkouts, isEmpty);
      expect(store.week, 3);
    },
  );

  testWidgets(
    'phone review can clear suggestions and return an explicit selection',
    (tester) async {
      tester.view.physicalSize = const Size(430, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = AppStore();
      final slot = preview(store).slots.first;
      addImported(store, 'a', slot.date, slot.workout);
      StrengthHistorySelection? result;
      await tester.pumpWidget(
        MaterialApp(
          theme: ProgressionBrand.theme(),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await Navigator.push<StrengthHistorySelection>(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          StrengthHistoryReviewScreen(preview: preview(store)),
                    ),
                  );
                },
                child: const Text('Review'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Review'));
      await tester.pumpAndSettle();
      expect(find.text('1 matched · 7 empty'), findsOneWidget);
      await tester.tap(find.text('Clear matches'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('confirm-history-matches')));
      await tester.pumpAndSettle();
      expect(result, isNotNull);
      expect(result!.assignments, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'starting point requires match review and cancellation changes nothing',
    (tester) async {
      tester.view.physicalSize = const Size(430, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = AppStore()..week = 3;
      final slot = preview(store).slots.first;
      addImported(store, 'a', slot.date, slot.workout);
      await tester.pumpWidget(
        MaterialApp(
          theme: ProgressionBrand.theme(),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showProgramPositionSheet(context, store),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      final toggle = find.byKey(const ValueKey('fill-imported-history'));
      await tester.scrollUntilVisible(
        toggle,
        350,
        scrollable: find
            .descendant(
              of: find.byKey(const ValueKey('program-position-scroll')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('review-imported-history')),
        findsOneWidget,
      );
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton).last).onPressed,
        isNull,
      );
      Navigator.of(tester.element(toggle)).pop();
      await tester.pumpAndSettle();
      expect(store.week, 3);
      expect(store.workoutHistory, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
}
