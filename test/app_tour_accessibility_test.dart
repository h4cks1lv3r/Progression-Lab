import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:progression_lab/app_tour.dart';
import 'package:progression_lab/brand.dart';
import 'package:progression_lab/main.dart';
import 'package:progression_lab/store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const storageChannel = MethodChannel('iron_cadence/storage');
  String? savedState;

  setUp(() {
    savedState = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storageChannel, (call) async {
          if (call.method == 'read') return savedState;
          if (call.method == 'write') savedState = call.arguments as String;
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storageChannel, null);
  });

  void surface(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Widget largeTextApp(Widget home) => MaterialApp(
    theme: ProgressionBrand.theme(),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(1.8)),
      child: child!,
    ),
    home: home,
  );

  for (final previousVersion in [0, 1]) {
    testWidgets(
      'full launch tour works with large text after version $previousVersion',
      (tester) async {
        surface(tester, const Size(320, 700));
        final store = AppStore()
          ..isLoaded = true
          ..dataOnboardingVersionSeen = 1
          ..onboardingVersionSeen = previousVersion
          ..automaticBackupsEnabled = false
          ..integrationState = {
            'contextualGuides': {'tipsEnabled': false},
          };

        await tester.pumpWidget(largeTextApp(Shell(store: store)));
        await tester.pumpAndSettle();
        final overlay = find.byType(AppTourOverlay);
        final count = tester.widget<AppTourOverlay>(overlay).steps.length;
        expect(count, greaterThan(1));
        for (var step = 0; step < count; step++) {
          final current = tester.widget<AppTourOverlay>(overlay);
          expect(current.stepIndex, step);
          expect(tester.takeException(), isNull);
          final content = find.byKey(ValueKey('tour-content-$step'));
          // Long copy remains reachable while the action stays in view.
          await tester.drag(content, const Offset(0, -180));
          await tester.pumpAndSettle();
          final next = find.descendant(
            of: overlay,
            matching: find.text(step == count - 1 ? 'Finish tour' : 'Next'),
          );
          expect(next.hitTestable(), findsOneWidget);
          await tester.tap(next);
          await tester.pumpAndSettle();
        }
        expect(overlay, findsNothing);
        expect(store.onboardingVersionSeen, 2);
        expect(
          find.text('Your training. Your way.').hitTestable(),
          findsOneWidget,
        );
        // Large text can put the first card below the fold. It stays reachable.
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('home-open-workout')),
          200,
          scrollable: find
              .descendant(
                of: find.byType(TodayPage),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('home-open-workout')).hitTestable(),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        store.dispose();

        final reloadedStore = AppStore();
        await reloadedStore.load();
        expect(reloadedStore.onboardingVersionSeen, 2);
        await tester.pumpWidget(largeTextApp(Shell(store: reloadedStore)));
        await tester.pumpAndSettle();
        expect(find.byType(AppTourOverlay), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        reloadedStore.dispose();
      },
    );
  }

  testWidgets('tour card stays inside a short landscape viewport', (
    tester,
  ) async {
    surface(tester, const Size(700, 320));
    final target = GlobalKey();
    var finished = false;
    await tester.pumpWidget(
      largeTextApp(
        Scaffold(
          body: Stack(
            children: [
              Positioned(
                top: 20,
                left: 20,
                child: SizedBox(key: target, width: 150, height: 60),
              ),
              AppTourOverlay(
                steps: [
                  AppTourStep(
                    targetKey: target,
                    title: 'Keep every workout within reach',
                    body:
                        'Pick a plan, build a workout, browse your exercise '
                        'library, and follow your progress. The left menu keeps '
                        'your training and the Lab within reach.',
                  ),
                ],
                stepIndex: 0,
                onBack: () {},
                onNext: () => finished = true,
                onSkip: () {},
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.drag(
      find.byKey(const ValueKey('tour-content-0')),
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();
    expect(find.text('Finish tour').hitTestable(), findsOneWidget);
    await tester.tap(find.text('Finish tour'));
    expect(finished, isTrue);
    expect(tester.takeException(), isNull);
  });
}
