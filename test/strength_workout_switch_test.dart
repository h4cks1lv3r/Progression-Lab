import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:progression_lab/brand.dart';
import 'package:progression_lab/main.dart';
import 'package:progression_lab/program.dart';
import 'package:progression_lab/store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const storage = MethodChannel('iron_cadence/storage');
  bool failWrites = false;
  int? failSelection;
  Completer<void>? pendingDraftWrite;
  var blockedWrites = 0;
  final savedDraftTargets = <(int, int?)>[];

  setUp(() {
    failWrites = false;
    failSelection = null;
    pendingDraftWrite = null;
    blockedWrites = 0;
    savedDraftTargets.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storage, (call) async {
          if (call.method == 'write') {
            final data = jsonDecode(call.arguments as String) as Map;
            if (failWrites || data['workout'] == failSelection) {
              throw PlatformException(code: 'write_failed');
            }
            if (pendingDraftWrite != null && data['workout'] == 0) {
              blockedWrites++;
              await pendingDraftWrite!.future;
            }
            savedDraftTargets.add((
              data['workout'] as int,
              (data['draft'] as Map?)?['workoutIndex'] as int?,
            ));
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storage, null);
  });

  Finder field(String label) => find
      .byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.labelText == label,
      )
      .first;

  Future<AppStore> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(430, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = AppStore()
      ..automaticBackupsEnabled = false
      ..integrationState = {
        'contextualGuides': {'tipsEnabled': false},
      };
    final week = ProgramEngine.week(1, 4);
    await tester.pumpWidget(
      MaterialApp(
        theme: ProgressionBrand.theme(),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => WorkoutScreen(
                    store: store,
                    week: week,
                    workout: week.workouts.first,
                    workoutIndex: 0,
                    scheduledDate: store.dateForSlot(1, 0),
                  ),
                ),
              ),
              child: const Text('Open strength'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open strength'));
    await tester.pumpAndSettle();
    return store;
  }

  Future<void> switchTo(WidgetTester tester, int index) async {
    final button = find.byKey(
      const ValueKey('session-switch-strength-workout'),
    );
    final workoutScroll = find
        .descendant(
          of: find.byType(WorkoutScreen),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(button, -300, scrollable: workoutScroll);
    await tester.tap(button);
    await tester.pumpAndSettle();
    final choice = find.byKey(ValueKey('strength-workout-choice-$index'));
    final pickerScroll = find.descendant(
      of: find.byKey(const ValueKey('strength-workout-picker-scroll')),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(choice, 200, scrollable: pickerScroll);
    await tester.tap(choice);
    await tester.pumpAndSettle();
  }

  Future<void> close(WidgetTester tester, AppStore store) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    store.dispose();
  }

  testWidgets(
    'switching away and back retains sets, inputs and session identity',
    (tester) async {
      final store = await open(tester);
      final firstSession = store.draft!.sessionId;
      final start = store.programStartDate;
      await tester.enterText(field('WEIGHT (lb)'), '135');
      await tester.enterText(field('Reps'), '8');
      await tester.tap(find.text('Log set'));
      await tester.pumpAndSettle();
      expect(store.logs, hasLength(1));
      await tester.enterText(field('WEIGHT (lb)'), '145');
      await tester.enterText(field('Reps'), '7');

      await switchTo(tester, 1);
      expect(store.week, 1);
      expect(store.workoutIndex, 1);
      expect(store.draft!.workoutIndex, 1);
      final secondSession = store.draft!.sessionId;
      expect(secondSession, isNot(firstSession));
      await tester.enterText(field('WEIGHT (lb)'), '185');
      await switchTo(tester, 0);

      expect(store.week, 1);
      expect(store.workoutIndex, 0);
      expect(store.programStartDate, start);
      expect(store.workoutHistory, isEmpty);
      expect(store.strengthCompletedWorkouts(1), 0);
      expect(store.pendingStrengthWorkoutIndices, [0, 1, 2, 3]);
      expect(store.logs.single.sessionId, firstSession);
      expect(store.logs.single.weight, 135);
      expect(store.draft!.sessionId, firstSession);
      expect(store.draft!.setNumber, 2);
      expect(
        tester.widget<TextField>(field('WEIGHT (lb)')).controller!.text,
        '145',
      );
      expect(tester.widget<TextField>(field('Reps')).controller!.text, '7');
      final savedSecond = store.draftFor(
        weekNumber: 1,
        targetWorkoutIndex: 1,
        cadence: 4,
        retroactive: false,
      )!;
      expect(savedSecond.sessionId, secondSession);
      expect(savedSecond.weight, '185');
      expect(tester.takeException(), isNull);
      await close(tester, store);
    },
  );

  testWidgets(
    'phone pause during a slow switch cannot restore the old active draft',
    (tester) async {
      final store = await open(tester);
      final oldSession = store.draft!.sessionId;
      await tester.enterText(field('WEIGHT (lb)'), '165');
      await tester.tap(
        find.byKey(const ValueKey('session-switch-strength-workout')),
      );
      await tester.pumpAndSettle();
      final writesBeforeSwitch = savedDraftTargets.length;
      final blocked = Completer<void>();
      pendingDraftWrite = blocked;
      await tester.tap(find.byKey(const ValueKey('strength-workout-choice-1')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(blockedWrites, 1);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      pendingDraftWrite = null;
      blocked.complete();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(store.workoutIndex, 1);
      expect(store.draft!.workoutIndex, 1);
      expect(store.draft!.sessionId, isNot(oldSession));
      expect(
        store
            .draftFor(
              weekNumber: 1,
              targetWorkoutIndex: 0,
              cadence: 4,
              retroactive: false,
            )!
            .weight,
        '165',
      );
      final writes = savedDraftTargets.skip(writesBeforeSwitch).toList();
      expect(writes.where((target) => target.$2 == 0), hasLength(1));
      expect(writes.any((target) => target.$1 == 1 && target.$2 == 0), isFalse);
      expect(savedDraftTargets.last, (1, 1));
      expect(tester.takeException(), isNull);
      await close(tester, store);
    },
  );

  for (final failure in ['draft', 'selection']) {
    testWidgets(
      '$failure save failure keeps the current workout open for retry',
      (tester) async {
        final store = await open(tester);
        final session = store.draft!.sessionId;
        await tester.enterText(field('WEIGHT (lb)'), '155');
        failWrites = failure == 'draft';
        failSelection = failure == 'selection' ? 1 : null;
        await switchTo(tester, 1);
        expect(store.workoutIndex, 0);
        expect(store.week, 1);
        expect(store.workoutHistory, isEmpty);
        expect(store.draft!.sessionId, session);
        expect(
          find.text(
            'Couldn’t switch workouts. Your current workout is still open. Try again.',
          ),
          findsOneWidget,
        );
        expect(
          tester.widget<TextField>(field('WEIGHT (lb)')).controller!.text,
          '155',
        );
        failWrites = false;
        failSelection = null;
        await switchTo(tester, 1);
        expect(store.workoutIndex, 1);
        expect(store.draft!.workoutIndex, 1);
        expect(
          store
              .draftFor(
                weekNumber: 1,
                targetWorkoutIndex: 0,
                cadence: 4,
                retroactive: false,
              )!
              .weight,
          '155',
        );
        expect(tester.takeException(), isNull);
        await close(tester, store);
      },
    );
  }
}
