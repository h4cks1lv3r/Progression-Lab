import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:progression_lab/brand.dart';
import 'package:progression_lab/main.dart';
import 'package:progression_lab/logged_sets.dart';
import 'package:progression_lab/curated_programs.dart';
import 'package:progression_lab/curated_training_screen.dart';
import 'package:progression_lab/store.dart';
import 'package:progression_lab/daily_inputs_screen.dart';
import 'package:progression_lab/athletic_program.dart';
import 'package:progression_lab/athletic_training.dart';
import 'package:progression_lab/program.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('iron_cadence/storage');
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => null);
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });
  testWidgets('audit phone flows expose navigation and recovery controls', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(() async {
      final flutterRoot = _flutterRoot();
      final roboto = await File(
        '${flutterRoot.path}/bin/cache/artifacts/material_fonts/Roboto-Regular.ttf',
      ).readAsBytes();
      for (final family in ['Roboto', 'Ahem']) {
        final loader = FontLoader(family)
          ..addFont(Future.value(ByteData.sublistView(roboto)));
        await loader.load();
      }
      final icons = FontLoader('MaterialIcons')
        ..addFont(
          Future.value(
            ByteData.sublistView(
              await File(
                '${flutterRoot.path}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
              ).readAsBytes(),
            ),
          ),
        );
      await icons.load();
    });
    final store = AppStore()
      ..isLoaded = true
      ..dataOnboardingVersionSeen = 1
      ..onboardingVersionSeen = 2
      ..automaticBackupsEnabled = false
      ..integrationState = {
        'contextualGuides': {'tipsEnabled': false},
      };
    final boundaryKey = GlobalKey();
    final baseTheme = ProgressionBrand.theme();
    ButtonStyle readable(ButtonStyle original) => original.copyWith(
      textStyle: WidgetStateProperty.resolveWith(
        (states) => (original.textStyle?.resolve(states) ?? const TextStyle())
            .copyWith(fontFamily: 'Roboto'),
      ),
    );
    // Tests use Ahem for null-family platform text. Assign Android's Roboto
    // explicitly to those styles for readable renders; preserve other values.
    final renderTheme = baseTheme.copyWith(
      appBarTheme: baseTheme.appBarTheme.copyWith(
        titleTextStyle: baseTheme.appBarTheme.titleTextStyle?.copyWith(
          fontFamily: 'Roboto',
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: readable(baseTheme.filledButtonTheme.style!),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: readable(baseTheme.outlinedButtonTheme.style!),
      ),
      textButtonTheme: TextButtonThemeData(
        style: readable(baseTheme.textButtonTheme.style!),
      ),
      chipTheme: baseTheme.chipTheme.copyWith(
        labelStyle:
            (baseTheme.chipTheme.labelStyle ?? baseTheme.textTheme.labelLarge!)
                .copyWith(fontFamily: 'Roboto'),
      ),
    );
    Widget app(Widget home) => RepaintBoundary(
      key: boundaryKey,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: renderTheme,
        builder: (context, child) => Material(
          type: MaterialType.transparency,
          textStyle: Theme.of(context).textTheme.bodyMedium,
          child: child,
        ),
        home: home,
      ),
    );
    Future<void> capture(String name) async {
      await tester.pump();
      final boundary =
          boundaryKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final picture = await boundary.toImage(pixelRatio: 1);
        final data = await picture.toByteData(format: ui.ImageByteFormat.png);
        await Directory('build/audit-evidence').create(recursive: true);
        await File(
          'build/audit-evidence/$name.png',
        ).writeAsBytes(data!.buffer.asUint8List());
        picture.dispose();
      });
      print('AUDIT Captured $name');
    }

    await tester.pumpWidget(app(Shell(store: store)));
    await tester.pumpAndSettle();
    await capture('home-412x915');
    await tester.tap(find.byKey(const ValueKey('home-year-one-strength')));
    await tester.pumpAndSettle();
    await capture('strength-plan-top-412x915');
    expect(find.byType(BackButton), findsOneWidget);
    expect(find.text('Start workout').hitTestable(), findsOneWidget);
    Navigator.of(tester.element(find.text('Change starting point'))).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('home-open-workout')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('open-workout-start')));
    await tester.pumpAndSettle();
    await capture('open-workout-empty-412x915');
    final sessionId = store.openWorkoutDraft!.sessionId;
    expect(store.logs, isEmpty);
    expect(
      find.byKey(const ValueKey('open-discard-workout')).hitTestable(),
      findsOneWidget,
    );
    expect(
      tester
          .widget<ButtonStyleButton>(
            find.byKey(const ValueKey('open-finish-workout')),
          )
          .onPressed,
      isNull,
    );
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Resume workout'), findsOneWidget);
    expect(store.openWorkoutDraft!.sessionId, sessionId);
    await capture('open-workout-stuck-resume-412x915');
    await tester.tap(find.text('Resume workout'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('open-discard-workout')).hitTestable(),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('open-discard-confirm')));
    await tester.pumpAndSettle();
    expect(store.openWorkoutDraft, isNull);
    expect(store.logs, isEmpty);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    final editorStore = AppStore()
      ..automaticBackupsEnabled = false
      ..logs = [
        SetLog(
          exercise: 'Barbell Bench Press',
          weight: 185,
          reps: 5,
          date: DateTime(2026, 9, 30),
          workout: 'Upper Body A',
        ),
      ];
    await tester.pumpWidget(
      app(
        LoggedSetsScreen(store: editorStore, exercise: 'Barbell Bench Press'),
      ),
    );
    await tester.pumpAndSettle();
    await capture('saved-set-editor-412x915');
    expect(
      find.byKey(const ValueKey('saved-set-delete')).hitTestable(),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    final iconicStore = AppStore()..automaticBackupsEnabled = false;
    final iconicId = CuratedPrograms.all.first.id;
    await tester.pumpWidget(
      app(CuratedSessionScreen(store: iconicStore, programId: iconicId)),
    );
    await tester.pumpAndSettle();
    await capture('iconic-zero-set-first-exercise-412x915');
    expect(iconicStore.logs, isEmpty);
    expect(find.text('Finish early'), findsNothing);
    expect(
      find.byKey(const ValueKey('curated-discard-workout')).hitTestable(),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('curated-choose-exercise')).hitTestable(),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    await tester.pumpWidget(app(Shell(store: store)));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Open menu'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(Drawer),
        matching: find.text('Daily check-in'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(DailyInputsScreen), findsOneWidget);
    expect(find.byType(SliverAppBar), findsNothing);
    expect(find.byType(AppBar), findsOneWidget);
    await capture('daily-inputs-412x915');
    expect(find.text('Edit saved supplements').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    final strengthStore = AppStore()..automaticBackupsEnabled = false;
    final strengthWeek = ProgramEngine.week(1, 4);
    await tester.pumpWidget(
      app(
        WorkoutScreen(
          store: strengthStore,
          week: strengthWeek,
          workout: strengthWeek.workouts.first,
          workoutIndex: 0,
          scheduledDate: DateTime(2026, 9, 30),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await capture('strength-logging-412x915');
    expect(find.text('Log set').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    final functionalStore = AppStore()..automaticBackupsEnabled = false;
    await tester.pumpWidget(
      app(
        AthleticSessionScreen(
          store: functionalStore,
          week: AthleticProgram.week(1),
          sessionIndex: 0,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await capture('functional-logging-412x915');
    expect(find.text('Finish workout').hitTestable(), findsOneWidget);
    expect(find.textContaining('This workout uses a checklist'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    strengthStore.dispose();
    functionalStore.dispose();
    store.dispose();
    editorStore.dispose();
    iconicStore.dispose();
  });
}

Directory _flutterRoot() {
  final configured = Platform.environment['FLUTTER_ROOT'];
  if (configured != null) return Directory(configured);
  var candidate = File(Platform.resolvedExecutable).parent;
  while (candidate.parent.path != candidate.path) {
    if (Directory(
      '${candidate.path}/bin/cache/artifacts/material_fonts',
    ).existsSync()) {
      return candidate;
    }
    candidate = candidate.parent;
  }
  throw StateError('Flutter SDK font directory could not be found.');
}
