import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:progression_lab/brand.dart';
import 'package:progression_lab/daily_inputs_screen.dart';
import 'package:progression_lab/store.dart';

void main() {
  const storage = MethodChannel('iron_cadence/storage');
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storage, (_) async => null);
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storage, null);
  });

  for (final layout in [(412.0, 1.0), (320.0, 1.0), (320.0, 2.0)]) {
    testWidgets('embedded Daily has one bar and retains editing at $layout', (
      tester,
    ) async {
      tester.view.physicalSize = Size(layout.$1, 915);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = AppStore()..automaticBackupsEnabled = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: ProgressionBrand.theme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(layout.$2)),
            child: child!,
          ),
          home: Scaffold(
            appBar: AppBar(title: const Text('Daily check-in')),
            body: DailyInputsScreen(
              store: store,
              embedded: true,
              initialDate: DateTime(2026, 9, 29),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.byType(SliverAppBar), findsNothing);
      expect(find.text('Sep 29, 2026'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Previous day'));
      await tester.pumpAndSettle();
      expect(find.text('Sep 28, 2026'), findsOneWidget);
      final edit = find.text('Edit saved supplements');
      await tester.ensureVisible(edit);
      await tester.tap(edit);
      await tester.pumpAndSettle();
      expect(find.byType(SupplementPresetsScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      store.dispose();
    });
  }

  testWidgets('standalone Daily keeps its own bar and supplement action', (
    tester,
  ) async {
    final store = AppStore()..automaticBackupsEnabled = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: ProgressionBrand.theme(),
        home: DailyInputsScreen(store: store),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(SliverAppBar), findsOneWidget);
    expect(find.text('Daily check-in'), findsOneWidget);
    await tester.tap(find.byTooltip('Edit saved supplements'));
    await tester.pumpAndSettle();
    expect(find.byType(SupplementPresetsScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    store.dispose();
  });

  testWidgets('post-workout input is named Workout rating', (tester) async {
    final store = AppStore()..automaticBackupsEnabled = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: ProgressionBrand.theme(),
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () => showWorkoutResponseSheet(
                context,
                store,
                sessionId: 'rated-session',
                track: 'strength',
              ),
              child: const Text('Rate workout'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Rate workout'));
    await tester.pumpAndSettle();
    expect(find.text('Workout rating'), findsOneWidget);
    expect(find.text('Save check-in'), findsNothing);
    await tester.ensureVisible(find.text('Save workout rating'));
    await tester.tap(find.text('Save workout rating'));
    await tester.pumpAndSettle();
    expect(store.responseForSession('rated-session'), isNotNull);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    store.dispose();
  });
}
