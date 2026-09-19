import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:progression_lab/brand.dart';
import 'package:progression_lab/curated_programs.dart';
import 'package:progression_lab/curated_training.dart';
import 'package:progression_lab/curated_training_screen.dart';
import 'package:progression_lab/store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('iron_cadence/storage');
  var failStorage = false;

  setUp(() {
    failStorage = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'write' && failStorage) {
            throw PlatformException(code: 'storage_failed');
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  void phone(WidgetTester tester, {double width = 430}) {
    tester.view.physicalSize = Size(width, 950);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Widget app(Widget home, {double textScale = 1}) => MaterialApp(
    theme: ProgressionBrand.theme(),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    home: home,
  );

  AppStore session(List<CuratedMetric> metrics, {DateTime? restEndsAt}) {
    final id = CuratedPrograms.all.first.id;
    final day = CuratedDay(
      title: 'Test training day',
      notes: 'Test five-day session',
      movements: [
        for (final entry in metrics.asMap().entries)
          CuratedMovement(
            name: entry.value == CuratedMetric.reps
                ? 'Dips'
                : 'Movement ${entry.key + 1}',
            metric: entry.value,
            instructions: 'Use controlled movement.',
            restSeconds: 0,
            targets: [
              CuratedSetTarget(
                reps:
                    entry.value == CuratedMetric.reps ||
                        entry.value == CuratedMetric.loadedReps
                    ? '8–12'
                    : null,
                seconds: entry.value == CuratedMetric.duration ? 30 : null,
                meters:
                    entry.value == CuratedMetric.distance ||
                        entry.value == CuratedMetric.loadedDistance
                    ? 20
                    : null,
              ),
            ],
          ),
      ],
    );
    return AppStore()
      ..automaticBackupsEnabled = false
      ..week = 12
      ..workoutIndex = 2
      ..athleticWeek = 4
      ..athleticSessionIndex = 1
      ..curatedTraining = CuratedTrainingState(
        drafts: {
          id: CuratedWorkoutDraft(
            programId: id,
            sessionId: 'curated-widget-session',
            week: 1,
            dayIndex: 0,
            run: 1,
            startedAt: DateTime.now(),
            day: day,
            restEndsAt: restEndsAt,
          ),
        },
      );
  }

  Future<void> tap(WidgetTester tester, String key) async {
    final finder = find.byKey(ValueKey(key));
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> enter(WidgetTester tester, String key, String value) async {
    final finder = find.byKey(ValueKey(key));
    await tester.ensureVisible(finder);
    await tester.enterText(finder, value);
    await tester.pumpAndSettle();
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  }

  testWidgets('program selection exposes evidence, all five days, and start', (
    tester,
  ) async {
    phone(tester);
    final store = AppStore()..automaticBackupsEnabled = false;
    final program = CuratedPrograms.all.first;
    await tester.pumpWidget(app(CuratedProgramsScreen(store: store)));
    await tester.pumpAndSettle();
    expect(find.text('Actor-inspired programs'), findsOneWidget);
    expect(find.textContaining('not promises of an actor'), findsOneWidget);
    await tap(tester, 'curated-program-${program.id}');
    for (var index = 0; index < 5; index++) {
      await tester.scrollUntilVisible(
        find.byKey(ValueKey('curated-day-$index')),
        150,
      );
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey('curated-day-$index')), findsOneWidget);
    }
    await tester.scrollUntilVisible(find.text(program.evidence), 150);
    await tester.pumpAndSettle();
    expect(find.text(program.evidence), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text(program.sources.first.title),
      150,
    );
    await tester.pumpAndSettle();
    expect(find.text(program.sources.first.title), findsOneWidget);
    await tap(tester, 'curated-start');
    expect(
      find.byKey(const ValueKey('curated-current-movement')),
      findsOneWidget,
    );
    expect(store.curatedDraftFor(program.id), isNotNull);
    await close(tester);
  });

  testWidgets(
    'bodyweight logs without weight; loaded sets need their own actual input',
    (tester) async {
      phone(tester);
      final store = session([CuratedMetric.reps, CuratedMetric.loadedReps]);
      final id = CuratedPrograms.all.first.id;
      await tester.pumpWidget(
        app(CuratedSessionScreen(store: store, programId: id)),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('curated-weight')), findsNothing);
      expect(find.text('Bodyweight · reps only'), findsOneWidget);
      await tap(tester, 'curated-log-set');
      expect(store.logs, isEmpty);
      await enter(tester, 'curated-reps', '9');
      await tap(tester, 'curated-log-set');
      expect(store.logs, hasLength(1));
      expect(store.logs.single.weight, 0);
      expect(store.logs.single.reps, 9);
      expect(store.logs.single.trackingType, 'bodyweightReps');
      expect(store.curatedDraftFor(id)!.nextStepIndex, 1);
      expect(find.byKey(const ValueKey('curated-weight')), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('curated-reps')))
            .controller!
            .text,
        isEmpty,
      );
      await enter(tester, 'curated-weight', '0');
      await enter(tester, 'curated-reps', '7');
      await tap(tester, 'curated-log-set');
      expect(store.logs, hasLength(1));
      await enter(tester, 'curated-weight', '35');
      await tap(tester, 'curated-log-set');
      expect(store.logs, hasLength(2));
      expect(store.logs.last.weight, 35);
      expect(store.logs.last.reps, 7);
      await tap(tester, 'curated-finish');
      expect(find.text('Workout complete'), findsOneWidget);
      expect(store.curatedHistory.single.status, 'completed');
      expect(store.curatedProgressFor(id).dayIndex, 1);
      expect(store.week, 12);
      expect(store.workoutIndex, 2);
      expect(store.athleticWeek, 4);
      expect(store.athleticSessionIndex, 1);
      await close(tester);
    },
  );

  testWidgets('unfinished actual inputs survive screen recreation', (
    tester,
  ) async {
    phone(tester);
    final store = session([CuratedMetric.loadedReps]);
    final id = CuratedPrograms.all.first.id;
    await tester.pumpWidget(
      app(CuratedSessionScreen(store: store, programId: id)),
    );
    await tester.pumpAndSettle();
    await enter(tester, 'curated-weight', '32.5');
    await enter(tester, 'curated-reps', '6');
    await enter(tester, 'curated-notes', 'Keep this entry');
    expect(store.curatedDraftFor(id)!.inputs['weight'], '32.5');
    await close(tester);
    await tester.pumpWidget(
      app(CuratedSessionScreen(store: store, programId: id)),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextFormField>(find.byKey(const ValueKey('curated-weight')))
          .controller!
          .text,
      '32.5',
    );
    expect(
      tester
          .widget<TextFormField>(find.byKey(const ValueKey('curated-reps')))
          .controller!
          .text,
      '6',
    );
    expect(
      tester
          .widget<TextFormField>(find.byKey(const ValueKey('curated-notes')))
          .controller!
          .text,
      'Keep this entry',
    );
    expect(store.logs, isEmpty);
    await close(tester);
  });

  testWidgets(
    'deleted set reopens its target without duplicating later logged sets',
    (tester) async {
      phone(tester);
      final store = session([CuratedMetric.reps, CuratedMetric.reps]);
      final id = CuratedPrograms.all.first.id;
      await tester.pumpWidget(
        app(CuratedSessionScreen(store: store, programId: id)),
      );
      await tester.pumpAndSettle();
      await enter(tester, 'curated-reps', '8');
      await tap(tester, 'curated-log-set');
      await enter(tester, 'curated-reps', '9');
      await tap(tester, 'curated-log-set');
      expect(find.text('All sets logged'), findsOneWidget);
      final retainedSourceId = store.logs.last.sourceId;
      await store.removeSet(store.logs.first);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('curated-reps')), findsOneWidget);
      expect(store.curatedDraftFor(id)!.nextStepIndex, 0);
      await enter(tester, 'curated-reps', '7');
      await tap(tester, 'curated-log-set');
      expect(store.logs, hasLength(2));
      expect(
        store.logs.where((log) => log.sourceId == retainedSourceId),
        hasLength(1),
      );
      expect(store.curatedDraftFor(id)!.nextStepIndex, 2);
      await tap(tester, 'curated-finish');
      expect(store.curatedHistory.single.status, 'completed');
      expect(store.curatedHistory.single.setCount, 2);
      await close(tester);
    },
  );

  testWidgets('timed and distance movements use matching actual metrics', (
    tester,
  ) async {
    phone(tester);
    final store = session([
      CuratedMetric.duration,
      CuratedMetric.loadedDistance,
      CuratedMetric.distance,
    ]);
    final id = CuratedPrograms.all.first.id;
    await tester.pumpWidget(
      app(CuratedSessionScreen(store: store, programId: id)),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('curated-reps')), findsNothing);
    expect(find.byKey(const ValueKey('curated-weight')), findsNothing);
    await enter(tester, 'curated-seconds', '40');
    await tap(tester, 'curated-log-set');
    expect(store.logs.single.durationSeconds, 40);
    expect(find.byKey(const ValueKey('curated-seconds')), findsNothing);
    await enter(tester, 'curated-weight', '45');
    await enter(tester, 'curated-meters', '25.5');
    await tap(tester, 'curated-log-set');
    expect(store.logs.last.trackingType, 'weightDistance');
    expect(store.logs.last.distance, 25.5);
    expect(find.byKey(const ValueKey('curated-weight')), findsNothing);
    await enter(tester, 'curated-meters', '400');
    await tap(tester, 'curated-log-set');
    expect(store.logs.last.trackingType, 'distanceOnly');
    expect(store.logs.last.weight, 0);
    expect(store.logs.last.distanceUnit, 'm');
    await close(tester);
  });

  testWidgets(
    'partial completion needs confirmation and records only actual sets',
    (tester) async {
      phone(tester);
      final store = session([CuratedMetric.reps, CuratedMetric.reps]);
      final id = CuratedPrograms.all.first.id;
      await tester.pumpWidget(
        app(CuratedSessionScreen(store: store, programId: id)),
      );
      await tester.pumpAndSettle();
      await enter(tester, 'curated-reps', '8');
      await tap(tester, 'curated-log-set');
      await tap(tester, 'curated-finish-partial');
      expect(store.curatedHistory, isEmpty);
      await tester.tap(find.text('KEEP TRAINING'));
      await tester.pumpAndSettle();
      expect(store.curatedDraftFor(id), isNotNull);
      await tap(tester, 'curated-finish-partial');
      await tester.tap(find.text('SAVE PARTIAL'));
      await tester.pumpAndSettle();
      expect(find.text('Partial workout saved'), findsOneWidget);
      expect(store.curatedHistory.single.status, 'partial');
      expect(store.curatedHistory.single.setCount, 1);
      expect(store.curatedHistory.single.totalSteps, 2);
      expect(store.curatedProgressFor(id).dayIndex, 1);
      await close(tester);
    },
  );

  testWidgets(
    'storage errors retain actual entries and do not advance the session',
    (tester) async {
      phone(tester);
      final store = session([CuratedMetric.reps]);
      final id = CuratedPrograms.all.first.id;
      await tester.pumpWidget(
        app(CuratedSessionScreen(store: store, programId: id)),
      );
      await tester.pumpAndSettle();
      await enter(tester, 'curated-reps', '11');
      failStorage = true;
      await tap(tester, 'curated-log-set');
      expect(store.logs, isEmpty);
      expect(store.curatedDraftFor(id)!.nextStepIndex, 0);
      expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('curated-reps')))
            .controller!
            .text,
        '11',
      );
      expect(find.byKey(const ValueKey('curated-error')), findsOneWidget);
      failStorage = false;
      await tap(tester, 'curated-log-set');
      expect(store.logs.single.reps, 11);
      await close(tester);
    },
  );

  testWidgets(
    'rest panel expires without dismissal and does not block set entry',
    (tester) async {
      phone(tester);
      final store = session([
        CuratedMetric.reps,
      ], restEndsAt: DateTime.now().add(const Duration(milliseconds: 250)));
      final id = CuratedPrograms.all.first.id;
      await tester.pumpWidget(
        app(CuratedSessionScreen(store: store, programId: id)),
      );
      await tester.pump();
      expect(find.byKey(const ValueKey('curated-rest')), findsOneWidget);
      expect(find.byKey(const ValueKey('curated-reps')), findsOneWidget);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 280)),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(find.byKey(const ValueKey('curated-rest')), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
      await close(tester);
    },
  );

  testWidgets('runner stays usable on a narrow phone with large text', (
    tester,
  ) async {
    phone(tester, width: 320);
    final store = session([CuratedMetric.loadedDistance]);
    await tester.pumpWidget(
      app(
        CuratedSessionScreen(
          store: store,
          programId: CuratedPrograms.all.first.id,
        ),
        textScale: 1.4,
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await enter(tester, 'curated-weight', '20');
    await enter(tester, 'curated-meters', '30');
    await tap(tester, 'curated-log-set');
    expect(tester.takeException(), isNull);
    expect(store.logs, hasLength(1));
    await close(tester);
  });
}
