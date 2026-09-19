import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:progression_lab/athletic_training.dart';
import 'package:progression_lab/brand.dart';
import 'package:progression_lab/program_navigator.dart';
import 'package:progression_lab/store.dart';

void main() {
  const channel = MethodChannel('iron_cadence/storage');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => null);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  Future<void> open(WidgetTester tester, Widget page) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: ProgressionBrand.theme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.4)),
          child: child!,
        ),
        home: page,
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('strength plan and starting-point sheet fit a narrow phone', (
    tester,
  ) async {
    final store = AppStore()..automaticBackupsEnabled = false;
    await open(
      tester,
      ProgramNavigatorPage(store: store, onOpenWorkout: (_, _, _) {}),
    );
    expect(tester.takeException(), isNull);
    final changeStart = find.text('Change starting point');
    await tester.ensureVisible(changeStart);
    await tester.pumpAndSettle();
    await tester.tap(changeStart);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(
      find.byKey(const ValueKey('program-position-scroll')),
      findsOneWidget,
    );
    expect(find.text('Use this starting point'), findsOneWidget);
    await tester.tap(find.text('Use this starting point'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(store.week, 1);
  });

  testWidgets('functional plan opens its workout on a narrow phone', (
    tester,
  ) async {
    final store = AppStore()..automaticBackupsEnabled = false;
    await open(tester, AthleticTrainingPage(store: store));
    expect(tester.takeException(), isNull);
    final start = find.text('Start session');
    await tester.ensureVisible(start);
    await tester.pumpAndSettle();
    await tester.tap(start);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(AthleticSessionScreen), findsOneWidget);
    await tester.scrollUntilVisible(find.textContaining('Tripod Foot'), 200);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.textContaining('Tripod Foot'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
