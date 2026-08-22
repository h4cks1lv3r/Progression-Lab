import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:progression_lab/athletic_history.dart';
import 'package:progression_lab/athletic_program.dart';
import 'package:progression_lab/brand.dart';
import 'package:progression_lab/progress_hub.dart';
import 'package:progression_lab/store.dart';

void main() {
  void usePhoneSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('functional progress exposes programmed drills without history', (
    tester,
  ) async {
    usePhoneSurface(tester);
    final store = AppStore()..preferredTrack = TrainingTrack.athletic;
    final currentDrill = store.currentAthleticSession.drills.first.name;
    final anotherDrill = AthleticProgram.week(
      12,
    ).sessions.last.drills.last.name;

    await tester.pumpWidget(
      MaterialApp(
        theme: ProgressionBrand.theme(),
        home: ProgressHub(store: store),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('FUNCTIONAL PROGRESS'), findsOneWidget);
    expect(find.text('No exercises logged'), findsNothing);
    final dropdownFinder = find.byKey(
      const ValueKey('functional-drill-dropdown'),
    );
    expect(dropdownFinder, findsOneWidget);
    expect(find.text(currentDrill), findsWidgets);

    final innerDropdownFinder = find.descendant(
      of: dropdownFinder,
      matching: find.byWidgetPredicate(
        (widget) => widget is DropdownButton<String>,
      ),
    );
    expect(innerDropdownFinder, findsOneWidget);
    final dropdown = tester.widget<DropdownButton<String>>(innerDropdownFinder);
    final values = dropdown.items!.map((item) => item.value).toSet();
    expect(values, contains(currentDrill));
    expect(values, contains(anotherDrill));
    expect(values.length, greaterThan(20));
  });

  testWidgets(
    'functional progress derives drill history from completed sessions',
    (tester) async {
      usePhoneSurface(tester);
      final completedAt = DateTime(2026, 8, 22, 9, 30);
      final store = AppStore()
        ..preferredTrack = TrainingTrack.athletic
        ..athleticHistory = [
          AthleticSessionRecord(
            programRun: 1,
            week: 1,
            sessionIndex: 0,
            completedAt: completedAt,
            effort: 8,
            sessionId: 'athletic-session-test',
          ),
        ];

      await tester.pumpWidget(
        MaterialApp(
          theme: ProgressionBrand.theme(),
          home: ProgressHub(store: store),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<Text>(
              find.byKey(const ValueKey('functional-completions-value')),
            )
            .data,
        '1',
      );
      expect(
        tester
            .widget<Text>(
              find.byKey(const ValueKey('functional-average-effort-value')),
            )
            .data,
        '8.0 / 10',
      );

      final historyText = find.textContaining('Run 1 • Week 1');
      final dashboard = find.byKey(
        const PageStorageKey('functional-progress-dashboard'),
      );
      final scrollable = find.descendant(
        of: dashboard,
        matching: find.byType(Scrollable),
      );
      expect(scrollable, findsOneWidget);
      await tester.scrollUntilVisible(historyText, 300, scrollable: scrollable);
      await tester.pumpAndSettle();

      expect(historyText, findsOneWidget);
      expect(find.text('8/10'), findsOneWidget);
    },
  );

  testWidgets(
    'progress track switch keeps strength and functional views separate',
    (tester) async {
      usePhoneSurface(tester);
      final store = AppStore();

      await tester.pumpWidget(
        MaterialApp(
          theme: ProgressionBrand.theme(),
          home: ProgressHub(store: store),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Strength signal'), findsOneWidget);
      expect(find.text('No exercises logged'), findsOneWidget);

      await tester.tap(find.text('FUNCTIONAL'));
      await tester.pumpAndSettle();

      expect(find.text('FUNCTIONAL PROGRESS'), findsOneWidget);
      expect(find.text('No exercises logged'), findsNothing);
    },
  );
}
