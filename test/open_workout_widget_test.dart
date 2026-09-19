import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:progression_lab/brand.dart';
import 'package:progression_lab/open_workout_screen.dart';
import 'package:progression_lab/store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('iron_cadence/storage');
  setUp(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => null),
  );
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );

  Widget app(AppStore store) => MaterialApp(
    theme: ProgressionBrand.theme(),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(1.4)),
      child: child!,
    ),
    home: OpenWorkoutScreen(store: store),
  );

  Future<void> tap(WidgetTester tester, String key) async {
    final finder = find.byKey(ValueKey(key));
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'phone workout supports bodyweight, resume, timed sets and saved history',
    (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = AppStore()
        ..automaticBackupsEnabled = false
        ..week = 12
        ..workoutIndex = 2;
      await tester.pumpWidget(app(store));
      await tester.pumpAndSettle();
      await tap(tester, 'open-workout-start');
      await tap(tester, 'open-add-exercise');
      await tester.enterText(
        find.byKey(const ValueKey('open-exercise-search')),
        'dips',
      );
      await tester.pumpAndSettle();
      await tap(tester, 'open-choose-dip');
      expect(find.byKey(const ValueKey('open-weight')), findsNothing);
      await tester.ensureVisible(find.byKey(const ValueKey('open-reps')));
      await tester.enterText(find.byKey(const ValueKey('open-reps')), '10');
      await tester.pumpAndSettle();
      await tap(tester, 'open-log-set');
      expect(store.logs.single.weight, 0);
      expect(store.logs.single.reps, 10);
      expect(find.text('Set saved'), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(find.text('Set saved'), findsNothing);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Resume workout'), findsOneWidget);
      await tap(tester, 'open-workout-start');
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('open-reps')))
            .controller!
            .text,
        '10',
      );
      await tap(tester, 'open-add-exercise');
      await tester.enterText(
        find.byKey(const ValueKey('open-exercise-search')),
        'front plank',
      );
      await tester.pumpAndSettle();
      await tap(tester, 'open-choose-front_plank');
      expect(find.byKey(const ValueKey('open-reps')), findsNothing);
      await tester.ensureVisible(find.byKey(const ValueKey('open-seconds')));
      await tester.enterText(find.byKey(const ValueKey('open-seconds')), '45');
      await tester.pumpAndSettle();
      final dipChip = find.widgetWithText(ChoiceChip, 'Dip');
      await tester.ensureVisible(dipChip);
      await tester.tap(dipChip);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('open-reps')))
            .controller!
            .text,
        '10',
      );
      await tap(tester, 'open-add-exercise');
      await tester.enterText(
        find.byKey(const ValueKey('open-exercise-search')),
        'dips',
      );
      await tester.pumpAndSettle();
      await tap(tester, 'open-choose-dip');
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tap(tester, 'open-workout-start');
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('open-reps')))
            .controller!
            .text,
        '10',
      );
      final plankChip = find.widgetWithText(ChoiceChip, 'Front Plank');
      await tester.ensureVisible(plankChip);
      await tester.tap(plankChip);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('open-seconds')))
            .controller!
            .text,
        '45',
      );
      await tap(tester, 'open-log-set');
      expect(store.logs.last.durationSeconds, 45);
      expect(store.logs.last.reps, 0);
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      await tap(tester, 'open-finish-workout');
      expect(store.openWorkoutDraft, isNull);
      expect(store.openWorkoutHistory, hasLength(1));
      expect(find.text('2 exercises · 2 sets saved'), findsOneWidget);
      expect(store.week, 12);
      expect(store.workoutIndex, 2);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );
}
