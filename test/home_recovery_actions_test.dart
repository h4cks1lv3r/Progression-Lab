import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:progression_lab/brand.dart';
import 'package:progression_lab/athletic_history.dart';
import 'package:progression_lab/exercise_library_screen.dart';
import 'package:progression_lab/main.dart';
import 'package:progression_lab/open_workout_screen.dart';
import 'package:progression_lab/source_links.dart';
import 'package:progression_lab/store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const storage = MethodChannel('iron_cadence/storage');
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storage, (_) async => null);
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storage, null);
  });

  testWidgets('Home offers the unfinished Open Workout before plan discovery', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = AppStore()..automaticBackupsEnabled = false;
    final original = await store.beginOpenWorkout();
    await tester.pumpWidget(
      MaterialApp(
        theme: ProgressionBrand.theme(),
        home: Scaffold(
          body: TodayPage(
            store: store,
            primaryActionKey: GlobalKey(),
            onOpenPrograms: () {},
            onOpenWorkout: () {},
            onOpenIcons: () {},
            onOpenStrength: () {},
            onOpenFunctional: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final resumeCard = find.byKey(const ValueKey('home-resume-open'));
    expect(resumeCard.hitTestable(), findsOneWidget);
    expect(
      tester.getTopLeft(resumeCard).dy,
      lessThan(
        tester.getTopLeft(find.byKey(const ValueKey('home-open-workout'))).dy,
      ),
    );
    await tester.tap(
      find.descendant(of: resumeCard, matching: find.text('Resume workout')),
    );
    await tester.pumpAndSettle();
    expect(find.byType(OpenWorkoutScreen), findsOneWidget);
    expect(store.openWorkoutDraft!.sessionId, original.sessionId);
    await tester.pumpWidget(const SizedBox());
    store.dispose();
  });

  testWidgets('Home remains usable with invalid drafts loaded from storage', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final seed = AppStore()..automaticBackupsEnabled = false;
    await seed.beginOpenWorkout();
    DraftSetInput strengthDraft(
      String id, {
      int week = 1,
      int days = 4,
      int workoutIndex = 0,
    }) => DraftSetInput(
      sessionId: id,
      week: week,
      days: days,
      workoutIndex: workoutIndex,
      workout: 'Stored workout',
      exerciseIndex: 0,
      setNumber: 0,
      weight: '123',
      reps: '9',
      notes: 'Retain this saved input',
    );
    seed.drafts = [
      strengthDraft('invalid-week', week: 0),
      strengthDraft('invalid-days', days: 99),
      strengthDraft('invalid-index', workoutIndex: 999),
    ];
    seed.athleticDrafts = [
      AthleticSessionDraft(
        sessionId: 'invalid-functional-week',
        programRun: seed.athleticProgramRun,
        week: 13,
        sessionIndex: 0,
        startedAt: DateTime.now(),
      ),
      AthleticSessionDraft(
        sessionId: 'invalid-functional-index',
        programRun: seed.athleticProgramRun,
        week: 1,
        sessionIndex: -1,
        startedAt: DateTime.now(),
      ),
    ];
    final stored = jsonEncode(seed.exportState());
    seed.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          storage,
          (call) async => call.method == 'read' ? stored : null,
        );
    final store = AppStore();
    await store.load();
    expect(store.primaryStateLoaded, isTrue);
    await tester.pumpWidget(
      MaterialApp(
        theme: ProgressionBrand.theme(),
        home: Scaffold(
          body: TodayPage(
            store: store,
            primaryActionKey: GlobalKey(),
            onOpenPrograms: () {},
            onOpenWorkout: () {},
            onOpenIcons: () {},
            onOpenStrength: () {},
            onOpenFunctional: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('home-resume-open')).hitTestable(),
      findsOneWidget,
    );
    for (final id in ['invalid-week', 'invalid-days', 'invalid-index']) {
      expect(find.byKey(ValueKey('home-resume-strength-$id')), findsNothing);
    }
    for (final id in ['invalid-functional-week', 'invalid-functional-index']) {
      expect(find.byKey(ValueKey('home-resume-functional-$id')), findsNothing);
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    store.dispose();
  });

  testWidgets('Abandoning a custom copy does not create an exercise', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = AppStore()..automaticBackupsEnabled = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: ProgressionBrand.theme(),
        home: ExerciseDetailScreen(
          store: store,
          option: store.exerciseOptionForName('Barbell Bench Press')!,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Make a custom copy'));
    await tester.tap(find.text('Make a custom copy'));
    await tester.pumpAndSettle();
    expect(find.byType(ExerciseEditorScreen), findsOneWidget);
    expect(store.customExercises, isEmpty);
    await tester.enterText(find.byType(TextField).first, 'My bench press');
    await tester.pumpWidget(const SizedBox());
    expect(store.customExercises, isEmpty);
    store.dispose();
  });

  test(
    'Source links reject non-web schemes and report a browser failure',
    () async {
      var calls = 0;
      const links = MethodChannel('progression_lab/links');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(links, (call) async {
            calls++;
            expect(call.arguments, {'url': 'https://example.com/source'});
            return false;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(links, null),
      );
      expect(await openSourceUrl('file:///private/data'), isFalse);
      expect(await openSourceUrl('https://example.com/source'), isFalse);
      expect(calls, 1);
    },
  );
}
