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
    final anotherDrill = AthleticProgram.week(12).sessions.last.drills.last.name;

    await tester.pumpWidget(
      MaterialApp(
        theme: ProgressionBrand.theme(),
        home: ProgressHub(store: store),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('FUNCTIONAL PROGRESS'), findsOneWidget);
    expect(find.text('No exercises logged'), findsNothing);
    expect(find.byKey(const ValueKey('functional-drill-dropdown')), findsOneWidget);
    expect(find.text(currentDrill), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('functional-drill-dropdown')));
    await tester.pumpAndSettle();
    expect(find.text(anotherDrill), findsWidgets);
  });

  testWidgets('functional progress derives drill history from completed sessions', (
    tester,
  ) async {
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
      find.descendant(
        of: find.byKey(const ValueKey('functional-completions-value')),
        matching: find.text('1'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('functional-average-effort-value')),
        matching: find.text('8.0 / 10'),
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Run 1 • Week 1'), findsOneWidget);
    expect(find.text('8/10'), findsOneWidget);
  });

  testWidgets('progress track switch keeps strength and functional views separate', (
    tester,
  ) async {
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
  });
}
