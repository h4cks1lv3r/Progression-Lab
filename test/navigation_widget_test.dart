import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:progression_lab/program_navigator.dart';
import 'package:progression_lab/progress_dashboard.dart';
import 'package:progression_lab/store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const storageChannel = MethodChannel('iron_cadence/storage');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storageChannel, (call) async {
          if (call.method == 'write') return null;
          if (call.method == 'read') return null;
          throw PlatformException(code: 'unknown_method');
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storageChannel, null);
  });

  testWidgets('cadence sheet preserves cycle and accepts an exact next workout',
      (tester) async {
    final store = AppStore()
      ..days = 4
      ..week = 19
      ..workoutIndex = 1;

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
        home: Scaffold(body: ProgramNavigatorPage(store: store)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('P2 · M3'), findsOneWidget);
    await tester.tap(find.text('5 DAYS').first);
    await tester.pumpAndSettle();

    expect(find.text('CHANGE CADENCE'), findsOneWidget);
    expect(
      find.text(
        'Phase 2 · Microcycle 3 is preserved. Only the weekly cadence and next workout change.',
        findRichText: true,
      ),
      findsOneWidget,
    );

    final upperBodyC = find.text('Upper Body C');
    await tester.scrollUntilVisible(
      upperBodyC,
      250,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey('cadence-options-scroll')),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.tap(upperBodyC);
    await tester.pump();

    final confirm = find.text('SWITCH TO 5 DAYS');
    await tester.ensureVisible(confirm);
    await tester.tap(confirm);
    await tester.pumpAndSettle();

    expect(store.days, 5);
    expect(store.week, 19);
    expect(store.workoutIndex, 4);
    expect(find.text('CHANGE CADENCE'), findsNothing);
  });

  testWidgets('progress dashboard never needs fake data for an empty history',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
        home: Scaffold(body: ProgressDashboard(store: AppStore())),
      ),
    );
    await tester.pump();

    expect(find.text('Strength signal'), findsOneWidget);
    expect(find.text('Your progress starts with a set'), findsOneWidget);
    expect(find.text('No exercises logged'), findsOneWidget);
  });

  testWidgets('progress dashboard selects one exercise and metric at a time',
      (tester) async {
    final now = DateTime.now();
    final store = AppStore()
      ..logs = [
        SetLog(
          exercise: 'Barbell Bench Press',
          weight: 180,
          reps: 6,
          date: now.subtract(const Duration(days: 20)),
          workout: 'Upper Body A',
        ),
        SetLog(
          exercise: 'Barbell Bench Press',
          weight: 185,
          reps: 6,
          date: now.subtract(const Duration(days: 2)),
          workout: 'Upper Body A',
        ),
        SetLog(
          exercise: 'Barbell Back Squat',
          weight: 275,
          reps: 5,
          date: now.subtract(const Duration(days: 1)),
          workout: 'Legs & Calves',
        ),
      ];

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
        home: Scaffold(body: ProgressDashboard(store: store)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Barbell Bench Press').last);
    await tester.pumpAndSettle();

    expect(find.text('Barbell Bench Press'), findsWidgets);
    expect(find.textContaining('185 lb × 6'), findsWidgets);
    await tester.tap(find.text('Weight'));
    await tester.pumpAndSettle();
    expect(find.text('WORKING WEIGHT'), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);
  });
}
