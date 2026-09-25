import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:progression_lab/brand.dart';
import 'package:progression_lab/program.dart';
import 'package:progression_lab/program_navigator.dart';
import 'package:progression_lab/store.dart';
import 'package:progression_lab/strength_cycle_picker.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('iron_cadence/storage');
  var failWrites = false;
  Completer<void>? writeGate;
  var writes = 0;

  setUp(() {
    failWrites = false;
    writeGate = null;
    writes = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'write') {
            writes++;
            await writeGate?.future;
            if (failWrites) throw PlatformException(code: 'write_failed');
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  Future<void> mount(
    WidgetTester tester,
    Widget child, {
    Size size = const Size(430, 950),
    double scale = 1,
  }) async {
    tester.view.physicalSize = size;
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
        home: Scaffold(body: child),
      ),
    );
    await tester.pumpAndSettle();
  }

  Widget pickerLauncher(AppStore store, ValueChanged<int?> onResult) => Builder(
    builder: (context) => TextButton(
      onPressed: () async =>
          onResult(await showStrengthWorkoutPicker(context, store)),
      child: const Text('Choose workout'),
    ),
  );

  WorkoutRecord record(
    int index,
    WorkoutStatus status, {
    int days = 5,
    int run = 1,
  }) => WorkoutRecord(
    week: 1,
    workoutIndex: index,
    workout: ProgramEngine.week(1, days).workouts[index].name,
    date: DateTime(2026, 9, 25),
    status: status,
    days: days,
    programRun: run,
  );

  testWidgets(
    'picker shows actual status and returns a day without mutating the store',
    (tester) async {
      final store = AppStore()
        ..automaticBackupsEnabled = false
        ..days = 5
        ..workoutIndex = 4
        ..workoutHistory = [
          record(0, WorkoutStatus.completed),
          record(1, WorkoutStatus.partial),
          record(2, WorkoutStatus.skipped),
        ]
        ..drafts = [
          DraftSetInput(
            week: 1,
            workoutIndex: 3,
            workout: ProgramEngine.week(1, 5).workouts[3].name,
            exerciseIndex: 0,
            setNumber: 1,
            sessionId: 'paused-day',
            weight: '45',
            reps: '8',
            notes: 'Saved inputs',
            days: 5,
          ),
        ];
      final before = store.exportState();
      int? selected;
      await mount(tester, pickerLauncher(store, (value) => selected = value));
      await tester.tap(find.text('Choose workout'));
      await tester.pumpAndSettle();

      expect(find.text('Completed'), findsOneWidget);
      expect(find.text('Partial'), findsOneWidget);
      expect(find.text('Skipped'), findsOneWidget);
      expect(find.text('In progress'), findsOneWidget);
      expect(find.text('Ready · Selected'), findsOneWidget);
      expect(find.text('1 of 5 workouts completed'), findsOneWidget);
      for (final index in [0, 1, 2, 4]) {
        expect(
          tester
              .widget<InkWell>(
                find.byKey(ValueKey('strength-workout-choice-$index')),
              )
              .onTap,
          isNull,
        );
      }
      final choice = find.byKey(const ValueKey('strength-workout-choice-3'));
      await tester.ensureVisible(choice);
      await tester.tap(choice);
      await tester.pumpAndSettle();
      expect(selected, 3);
      expect(store.exportState(), before);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'earlier unrecorded day can be chosen without counting other runs or schedules',
    (tester) async {
      final store = AppStore()
        ..days = 3
        ..workoutIndex = 2
        ..workoutHistory = [
          record(0, WorkoutStatus.completed, days: 3, run: 2),
          record(1, WorkoutStatus.completed, days: 5),
        ];
      int? selected;
      await mount(tester, pickerLauncher(store, (value) => selected = value));
      await tester.tap(find.text('Choose workout'));
      await tester.pumpAndSettle();
      expect(find.text('Not logged'), findsNWidgets(2));
      expect(find.text('0 of 3 workouts completed'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('strength-workout-choice-0')));
      await tester.pumpAndSettle();
      expect(selected, 0);
      expect(store.workoutIndex, 2);
      expect(store.workoutHistory, hasLength(2));
    },
  );

  for (final size in [const Size(320, 700), const Size(800, 320)]) {
    testWidgets('picker scrolls to every day at large text on $size', (
      tester,
    ) async {
      final store = AppStore()..days = 5;
      int? selected;
      await mount(
        tester,
        pickerLauncher(store, (value) => selected = value),
        size: size,
        scale: 2,
      );
      await tester.tap(find.text('Choose workout'));
      await tester.pumpAndSettle();
      final choice = find.byKey(const ValueKey('strength-workout-choice-4'));
      await tester.scrollUntilVisible(
        choice,
        200,
        scrollable: find.descendant(
          of: find.byKey(const ValueKey('strength-workout-picker-scroll')),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(choice);
      await tester.pumpAndSettle();
      expect(selected, 4);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('program progress counts records instead of the selected day', (
    tester,
  ) async {
    final store = AppStore()
      ..automaticBackupsEnabled = false
      ..days = 4
      ..workoutIndex = 3;
    await mount(
      tester,
      ProgramNavigatorPage(store: store, onOpenWorkout: (_, _, _) {}),
    );
    expect(find.text('0 of 4 workouts completed this cycle'), findsOneWidget);
    expect(
      tester
          .widget<LinearProgressIndicator>(
            find.byKey(const ValueKey('strength-cycle-progress')),
          )
          .value,
      0,
    );
    final switchButton = find.byKey(const ValueKey('program-switch-workout'));
    await tester.ensureVisible(switchButton);
    await tester.tap(switchButton);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('strength-workout-choice-1')));
    await tester.pumpAndSettle();
    expect(store.workoutIndex, 1);
    expect(store.week, 1);
    expect(store.workoutHistory, isEmpty);
    expect(find.text('0 of 4 workouts completed this cycle'), findsOneWidget);
    expect(
      tester
          .widget<LinearProgressIndicator>(
            find.byKey(const ValueKey('strength-cycle-progress')),
          )
          .value,
      0,
    );
    await store.recordWorkout(
      weekNumber: 1,
      targetWorkoutIndex: 0,
      workout: ProgramEngine.week(1, 4).workouts.first.name,
      sessionId: null,
      status: WorkoutStatus.completed,
      retroactive: true,
    );
    await tester.pumpAndSettle();
    expect(find.text('1 of 4 workouts completed this cycle'), findsOneWidget);
    expect(
      tester
          .widget<LinearProgressIndicator>(
            find.byKey(const ValueKey('strength-cycle-progress')),
          )
          .value,
      .25,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('current cycle card starts an earlier day as a live workout', (
    tester,
  ) async {
    final store = AppStore()
      ..automaticBackupsEnabled = false
      ..days = 3
      ..workoutIndex = 2;
    int? openedWeek;
    int? openedIndex;
    bool? retroactive;
    await mount(
      tester,
      ProgramNavigatorPage(
        store: store,
        onOpenWorkout: (week, index, retro) {
          openedWeek = week.number;
          openedIndex = index;
          retroactive = retro;
        },
      ),
    );
    final weekCard = find.byKey(const ValueKey('week-1'));
    await tester.scrollUntilVisible(weekCard, 300);
    await tester.tap(
      find.descendant(of: weekCard, matching: find.byType(InkWell)).first,
    );
    await tester.pumpAndSettle();
    final start = find.byKey(const ValueKey('start-cycle-workout-0'));
    await tester.ensureVisible(start);
    await tester.pumpAndSettle();
    await tester.tap(start);
    await tester.pumpAndSettle();
    expect(store.workoutIndex, 0);
    expect(store.pendingStrengthWorkoutIndices, containsAll([0, 2]));
    expect(openedWeek, 1);
    expect(openedIndex, 0);
    expect(retroactive, isFalse);
    expect(store.workoutHistory, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'current cycle card blocks duplicate opens and allows retry after a failed save',
    (tester) async {
      final store = AppStore()
        ..automaticBackupsEnabled = false
        ..days = 3
        ..workoutIndex = 2;
      var opened = 0;
      await mount(
        tester,
        ProgramNavigatorPage(
          store: store,
          onOpenWorkout: (_, _, _) => opened++,
        ),
      );
      final weekCard = find.byKey(const ValueKey('week-1'));
      await tester.scrollUntilVisible(weekCard, 300);
      await tester.tap(
        find.descendant(of: weekCard, matching: find.byType(InkWell)).first,
      );
      await tester.pumpAndSettle();
      final start = find.byKey(const ValueKey('start-cycle-workout-0'));
      await tester.ensureVisible(start);
      await tester.pumpAndSettle();

      writeGate = Completer<void>();
      failWrites = true;
      final firstPress = tester.widget<FilledButton>(start).onPressed!;
      firstPress();
      firstPress();
      await tester.pump();
      expect(writes, 1);
      expect(opened, 0);
      expect(tester.widget<FilledButton>(start).onPressed, isNull);
      writeGate!.complete();
      await tester.pumpAndSettle();
      expect(store.workoutIndex, 2);
      expect(opened, 0);
      expect(tester.widget<FilledButton>(start).onPressed, isNotNull);

      writeGate = Completer<void>();
      failWrites = false;
      final retryPress = tester.widget<FilledButton>(start).onPressed!;
      retryPress();
      retryPress();
      await tester.pump();
      expect(writes, 2);
      expect(opened, 0);
      expect(tester.widget<FilledButton>(start).onPressed, isNull);
      writeGate!.complete();
      await tester.pumpAndSettle();
      expect(store.workoutIndex, 0);
      expect(opened, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('program leaves selection unchanged when saving a switch fails', (
    tester,
  ) async {
    final store = AppStore()..automaticBackupsEnabled = false;
    await mount(
      tester,
      ProgramNavigatorPage(store: store, onOpenWorkout: (_, _, _) {}),
    );
    final button = find.byKey(const ValueKey('program-switch-workout'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    failWrites = true;
    await tester.tap(find.byKey(const ValueKey('strength-workout-choice-1')));
    await tester.pumpAndSettle();
    expect(store.workoutIndex, 0);
    expect(
      find.text(
        'Couldn’t switch workouts. Your session is still saved. Try again.',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
