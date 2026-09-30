import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:progression_lab/athletic_program.dart';
import 'package:progression_lab/athletic_training.dart';
import 'package:progression_lab/brand.dart';
import 'package:progression_lab/main.dart' show WorkoutScreen;
import 'package:progression_lab/program.dart';
import 'package:progression_lab/store.dart';
import 'package:progression_lab/workout_logging_controls.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const storage = MethodChannel('iron_cadence/storage');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late List<Completer<void>> pending;
  late List<Map<String, dynamic>> snapshots;
  var holdWrites = false;

  setUp(() {
    pending = [];
    snapshots = [];
    holdWrites = false;
    messenger.setMockMethodCallHandler(storage, (call) async {
      if (call.method == 'write' && holdWrites) {
        snapshots.add(
          jsonDecode(call.arguments as String) as Map<String, dynamic>,
        );
        final gate = Completer<void>();
        pending.add(gate);
        await gate.future;
      }
      return null;
    });
  });
  tearDown(() {
    holdWrites = false;
    for (final gate in pending) {
      if (!gate.isCompleted) gate.complete();
    }
    messenger.setMockMethodCallHandler(storage, null);
  });

  AppStore data() => AppStore()
    ..automaticBackupsEnabled = false
    ..integrationState = {
      'contextualGuides': {'tipsEnabled': false},
    };

  Future<void> open(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(430, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(theme: ProgressionBrand.theme(), home: screen),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Progress saved on this device. Come back anytime.'),
      findsOneWidget,
    );
    holdWrites = true;
  }

  Future<void> flushUntil(WidgetTester tester, bool Function() ready) async {
    for (var attempt = 0; attempt < 25 && !ready(); attempt++) {
      await tester.pump();
    }
    expect(
      ready(),
      isTrue,
      reason: 'The controlled persistence operation must reach its next state.',
    );
    await tester.pump();
  }

  void saving(WidgetTester tester) {
    expect(
      tester
          .widget<WorkoutSaveProgress>(find.byType(WorkoutSaveProgress))
          .saving,
      isTrue,
    );
    expect(find.text('Saving progress…'), findsOneWidget);
    expect(
      find.text('Progress saved on this device. Come back anytime.'),
      findsNothing,
    );
  }

  Future<void> close(WidgetTester tester, AppStore store) async {
    holdWrites = false;
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    store.dispose();
  }

  testWidgets('Strength says Saving until both queued input snapshots finish', (
    tester,
  ) async {
    final store = data();
    final week = ProgramEngine.week(1, 4);
    await open(
      tester,
      WorkoutScreen(
        store: store,
        week: week,
        workout: week.workouts.first,
        workoutIndex: 0,
        scheduledDate: DateTime(2026, 9, 30),
      ),
    );
    final weight = find.byWidgetPredicate(
      (widget) =>
          widget is TextField && widget.decoration?.labelText == 'Weight (lb)',
    );
    await tester.enterText(weight, '135');
    await tester.pump(const Duration(milliseconds: 260));
    await flushUntil(tester, () => pending.length == 1);
    await tester.enterText(weight, '145');
    await tester.pump(const Duration(milliseconds: 260));
    expect(
      pending,
      hasLength(1),
      reason: 'The second draft is queued behind the first native write.',
    );
    saving(tester);
    pending.first.complete();
    await flushUntil(tester, () => pending.length == 2);
    expect((snapshots[0]['draft'] as Map)['weight'], '135');
    expect((snapshots[1]['draft'] as Map)['weight'], '145');
    saving(tester);
    pending[1].complete();
    await flushUntil(
      tester,
      () => !tester
          .widget<WorkoutSaveProgress>(find.byType(WorkoutSaveProgress))
          .saving,
    );
    expect(
      find.text('Progress saved on this device. Come back anytime.'),
      findsOneWidget,
    );
    expect(store.draft!.weight, '145');
    expect(tester.takeException(), isNull);
    await close(tester, store);
  });

  testWidgets(
    'Functional says Saving until both queued drill snapshots finish',
    (tester) async {
      final store = data();
      await open(
        tester,
        AthleticSessionScreen(
          store: store,
          week: AthleticProgram.week(1),
          sessionIndex: 0,
        ),
      );
      await tester.tap(find.byIcon(Icons.circle_outlined).first);
      await tester.pump();
      await flushUntil(tester, () => pending.length == 1);
      await tester.tap(find.byIcon(Icons.circle_outlined).first);
      await tester.pump();
      expect(
        pending,
        hasLength(1),
        reason:
            'The second drill snapshot is queued behind the first native write.',
      );
      saving(tester);
      pending.first.complete();
      await flushUntil(tester, () => pending.length == 2);
      expect((snapshots[0]['athleticDraft'] as Map)['completedDrills'], [0]);
      expect((snapshots[1]['athleticDraft'] as Map)['completedDrills'], [0, 1]);
      saving(tester);
      pending[1].complete();
      await flushUntil(
        tester,
        () => !tester
            .widget<WorkoutSaveProgress>(find.byType(WorkoutSaveProgress))
            .saving,
      );
      expect(
        find.text('Progress saved on this device. Come back anytime.'),
        findsOneWidget,
      );
      expect(store.athleticDraft!.completedDrills, [0, 1]);
      expect(tester.takeException(), isNull);
      await close(tester, store);
    },
  );
}
