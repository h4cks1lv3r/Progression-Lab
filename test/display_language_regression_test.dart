import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:progression_lab/brand.dart';
import 'package:progression_lab/display_format.dart';
import 'package:progression_lab/logged_sets.dart';
import 'package:progression_lab/program.dart';
import 'package:progression_lab/program_navigator.dart';
import 'package:progression_lab/progress_dashboard.dart';
import 'package:progression_lab/store.dart';

void main() {
  Future<void> mount(
    WidgetTester tester,
    Widget child, {
    Size size = const Size(412, 915),
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
        home: child,
      ),
    );
    await tester.pumpAndSettle();
  }

  test('display dates have one readable format and local 12-hour time', () {
    expect(formatAppDate(DateTime(2026, 9, 30)), 'Sep 30, 2026');
    expect(formatAppDateTime(DateTime(2026, 9, 30)), 'Sep 30, 2026 · 12:00 AM');
    expect(
      formatAppDateTime(DateTime(2026, 9, 30, 12, 3)),
      'Sep 30, 2026 · 12:03 PM',
    );
    expect(
      formatAppDateTime(DateTime(2026, 9, 30, 16, 50)),
      'Sep 30, 2026 · 4:50 PM',
    );
    final timestamp = DateTime.utc(2026, 9, 30, 20, 50);
    expect(
      formatAppDateTime(timestamp),
      formatAppDateTime(timestamp.toLocal()),
    );
  });

  testWidgets('Year One has one title and explains the AMRAP prescription', (
    tester,
  ) async {
    final store = AppStore()
      ..automaticBackupsEnabled = false
      ..week = 15
      ..programStartDate = DateTime(2026, 6, 24);
    await mount(
      tester,
      ProgramNavigatorPage(store: store, onOpenWorkout: (_, _, _) {}),
    );
    expect(find.text('Year One Strength'), findsOneWidget);
    expect(find.text('Build your strength'), findsOneWidget);
    final texts = tester.widgetList<Text>(find.byType(Text));
    expect(
      texts.any(
        (text) => (text.data ?? text.textSpan?.toPlainText() ?? '')
            .toLowerCase()
            .contains('microcycle'),
      ),
      isFalse,
    );
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('week-15')),
      500,
      maxScrolls: 30,
    );
    final card = find.byKey(const ValueKey('workout-15-0'));
    await tester.ensureVisible(card);
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: card,
        matching: find.text(
          'AMRAP means as many reps as possible with good form. “+ 4” means 4 reps in the second set.',
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: card,
        matching: find.text(
          ProgramEngine.week(15, store.days).workouts.first.name,
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: card, matching: find.text('Sep 30, 2026')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('starting-point and schedule close buttons have action labels', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final store = AppStore()..automaticBackupsEnabled = false;
    await mount(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: Column(
            children: [
              TextButton(
                onPressed: () => showProgramPositionSheet(context, store),
                child: const Text('Position'),
              ),
              TextButton(
                onPressed: () => showCadenceSwitchSheet(context, store),
                child: const Text('Schedule'),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.text('Position'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Close starting point choices'), findsOneWidget);
    expect(
      tester
          .getSemantics(find.byTooltip('Close starting point choices'))
          .tooltip,
      'Close starting point choices',
    );
    expect(find.text('Cycle (training week)'), findsOneWidget);
    expect(find.textContaining('Microcycle'), findsNothing);
    await tester.tap(find.byTooltip('Close starting point choices'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Schedule'));
    await tester.pumpAndSettle();
    expect(
      tester.getSemantics(find.byTooltip('Close schedule choices')).tooltip,
      'Close schedule choices',
    );
    expect(find.textContaining('Microcycle'), findsNothing);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('performed and entered dates meet text contrast on history', (
    tester,
  ) async {
    final record = WorkoutRecord(
      week: 1,
      workoutIndex: 0,
      workout: 'Push',
      date: DateTime(2026, 9, 29, 18, 30),
      loggedAt: DateTime(2026, 9, 30, 16, 50),
      scheduledDate: DateTime(2026, 9, 28),
      status: WorkoutStatus.completed,
      sessionId: 'date-history',
    );
    final store = AppStore()..workoutHistory = [record];
    final savedDates = record.toJson();
    await mount(tester, LoggedWorkoutScreen(store: store, record: record));
    final line = find.text(
      'Performed Sep 29, 2026 · 6:30 PM · Entered Sep 30, 2026 · 4:50 PM',
    );
    expect(line, findsOneWidget);
    final color = tester.widget<Text>(line).style!.color!;
    final foreground = color.computeLuminance();
    final background = ProgressionBrand.theme().scaffoldBackgroundColor
        .computeLuminance();
    expect((foreground + .05) / (background + .05), greaterThanOrEqualTo(4.5));
    expect(record.toJson(), savedDates);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'strength progress explains its estimated maximum and formats dates',
    (tester) async {
      final store = AppStore()
        ..logs = [
          SetLog(
            exercise: 'Barbell Bench Press',
            weight: 185,
            reps: 5,
            date: DateTime(2026, 9, 30, 18),
            workout: 'Push',
          ),
        ];
      await mount(tester, Scaffold(body: ProgressDashboard(store: store)));
      expect(
        find.textContaining('Estimated one-rep maximum (e1RM)'),
        findsOneWidget,
      );
      expect(find.textContaining('Sep 30, 2026'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('full progress dates fit a narrow phone at large text', (
    tester,
  ) async {
    final store = AppStore()
      ..logs = [
        for (final day in [29, 30])
          SetLog(
            exercise: 'Barbell Bench Press',
            weight: 185,
            reps: 5,
            date: DateTime(2026, 9, day, 18),
            workout: 'Push',
          ),
      ];
    await mount(
      tester,
      Scaffold(body: ProgressDashboard(store: store)),
      size: const Size(320, 750),
      scale: 2,
    );
    await tester.scrollUntilVisible(find.text('Sep 30, 2026'), 400);
    await tester.pumpAndSettle();
    expect(find.textContaining('Sep 30, 2026'), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(find.text('Personal records'), 400);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
