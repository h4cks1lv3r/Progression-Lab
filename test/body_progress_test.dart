import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:progression_lab/body_progress.dart';
import 'package:progression_lab/body_media.dart';
import 'package:progression_lab/body_progress_screen.dart';
import 'package:progression_lab/body_privacy.dart';
import 'package:progression_lab/body_share.dart';
import 'package:progression_lab/brand.dart';
import 'package:progression_lab/health_sync.dart';
import 'package:progression_lab/progress_hub.dart';
import 'package:progression_lab/store.dart';

BodyMeasurement reading(
  String id,
  String date,
  double value, {
  BodyMetric metric = BodyMetric.weight,
  String source = 'manual',
  bool preferred = false,
  String method = '',
}) => BodyMeasurement(
  id: id,
  metric: metric,
  value: value,
  date: date,
  recordedAt: DateTime.parse('${date}T09:00:00'),
  source: source,
  preferred: preferred,
  method: method,
);
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const storage = MethodChannel('iron_cadence/storage');
  setUpAll(() async {
    final fontRoot = Platform.environment['BODY_FONT_ROOT'];
    if (fontRoot == null) return;
    for (final family in ['Roboto', 'sans-serif']) {
      final loader = FontLoader(family)
        ..addFont(
          File(
            '$fontRoot/Roboto-Regular.ttf',
          ).readAsBytes().then((b) => ByteData.sublistView(b)),
        );
      await loader.load();
    }
    final icons = FontLoader('MaterialIcons')
      ..addFont(
        File(
          '$fontRoot/MaterialIcons-Regular.otf',
        ).readAsBytes().then((b) => ByteData.sublistView(b)),
      );
    await icons.load();
  });
  final calls = <MethodCall>[];
  Map<String, dynamic> journal = {'version': 1, 'checkIns': []};
  String? saved;
  bool fail = false;
  Completer<void>? pendingBody;
  bool failBodyOnly = false;
  setUp(() {
    pendingBody = null;
    failBodyOnly = false;
    calls.clear();
    saved = null;
    fail = false;
    journal = {'version': 1, 'checkIns': []};
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(storage, (call) async {
      if (call.method == 'read') return saved;
      if (call.method == 'write') {
        if (fail) throw PlatformException(code: 'disk_full');
        saved = call.arguments as String;
      }
      return null;
    });
    messenger.setMockMethodCallHandler(BodyMediaStore.channel, (call) async {
      calls.add(call);
      if (call.method == 'load')
        return {'directory': '/tmp/body-fixtures', 'journal': journal};
      if (call.method == 'unlock') return true;
      if (call.method == 'commit') {
        if (pendingBody != null) await pendingBody!.future;
        if (fail || failBodyOnly) throw PlatformException(code: 'disk_full');
        final args = call.arguments as Map;
        saved = args['state'] as String;
        journal = Map<String, dynamic>.from(
          jsonDecode(args['journal'] as String) as Map,
        );
      }
      if (call.method == 'saveJournal')
        journal = Map<String, dynamic>.from(
          jsonDecode(call.arguments as String) as Map,
        );
      return null;
    });
  });
  tearDown(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(storage, null);
    messenger.setMockMethodCallHandler(BodyMediaStore.channel, null);
  });
  AppStore store() => AppStore()..automaticBackupsEnabled = false;
  test('units round trip without losing canonical precision', () {
    final kg = BodyMeasurement.canonical(BodyMetric.weight, 183.25, 'lb');
    expect(
      reading('x', '2026-09-01', kg).displayValue('lb', 'cm'),
      closeTo(183.25, 1e-10),
    );
    final cm = BodyMeasurement.canonical(BodyMetric.waist, 32.125, 'in');
    expect(
      reading(
        'x',
        '2026-09-01',
        cm,
        metric: BodyMetric.waist,
      ).displayValue('kg', 'in'),
      closeTo(32.125, 1e-10),
    );
  });
  test(
    'seven calendar days use one preferred reading per day and expose sparse coverage',
    () {
      final rows = [
        reading('old', '2026-08-31', 100),
        reading('a', '2026-09-01', 80),
        reading('duplicate', '2026-09-01', 90),
        reading('scale', '2026-09-01', 81, source: 'scale', preferred: true),
        reading('b', '2026-09-04', 82),
        reading('c', '2026-09-07', 83),
      ];
      final trend = BodyAnalysis.window(rows, DateTime(2026, 9, 7));
      expect(trend.days, 3);
      expect(trend.mean, 82);
      expect(trend.readings.first.id, 'scale');
      expect(
        BodyAnalysis.window(
          rows.where((r) => r.id != "old"),
          DateTime(2026, 9, 6),
        ).mean,
        isNull,
      );
      expect(BodyAnalysis.dailyWeights(rows).length, 4);
    },
  );
  test(
    'BMI uses effective historical height and adult categories are opt in',
    () {
      final weight = reading('w', '2026-09-01', 81);
      final heights = [
        reading('old', '2026-08-01', 180, metric: BodyMetric.height),
        reading('future', '2026-09-02', 190, metric: BodyMetric.height),
      ];
      expect(BodyAnalysis.bmi(weight, heights), closeTo(25, 1e-8));
      expect(BodyAnalysis.bmi(weight, []), isNull);
      expect(BodyAnalysis.bmiCategory(25, adult20: false), isNull);
      expect(BodyAnalysis.bmiCategory(25, adult20: true), isNotNull);
    },
  );
  test('invalid numbers and impossible calendar dates are rejected', () {
    for (final v in [double.nan, double.infinity, 0.0, -1.0])
      expect(reading('x', '2026-09-01', v).valid, isFalse);
    expect(reading('x', '2026-02-30', 80).valid, isFalse);
    expect(
      reading('x', '2026-09-01', 101, metric: BodyMetric.bodyFat).valid,
      isFalse,
    );
  });
  test(
    'legacy migration preserves separate source records and runs only once',
    () {
      final old = {
        'unit': 'lb',
        'recoveryCheckIns': [
          {
            'id': 'legacy',
            'localDate': '2026-09-01',
            'bodyWeight': 180,
            'weightUnit': 'lb',
          },
        ],
        'integrationState': {
          'integrations': {
            'healthBodyMetrics': [
              {
                'type': 'bodyWeight',
                'value': 81.6466266,
                'unit': 'kg',
                'recordedAt': '2026-09-01T09:00:00Z',
                'source': 'scale',
              },
            ],
          },
        },
      };
      final migrated = migrateBodyMeasurements(old);
      expect(migrated.length, 2);
      expect(migrated.first.value, closeTo(81.6466266, 1e-8));
      expect(
        migrateBodyMeasurements({
          ...old,
          'bodyMeasurements': migrated.map((r) => r.toJson()).toList(),
        }).length,
        2,
      );
    },
  );
  test(
    'Health Connect IDs survive revised timestamps and preserve record-local dates',
    () {
      final a = measurementFromHealth({
        'type': 'bodyWeight',
        'value': 80,
        'unit': 'kg',
        'recordedAt': '2026-09-02T01:00:00Z',
        'localDate': '2026-09-01',
        'recordId': 'record-1',
        'source': 'scale',
        'revision': 1,
      })!;
      final b = measurementFromHealth({
        'type': 'bodyWeight',
        'value': 81,
        'unit': 'kg',
        'recordedAt': '2026-09-03T01:00:00Z',
        'localDate': '2026-09-02',
        'recordId': 'record-1',
        'source': 'scale',
        'revision': 2,
      })!;
      expect(a.id, b.id);
      expect(a.date, '2026-09-01');
      expect(b.revision, 2);
    },
  );
  test(
    'sharing starts private and never substitutes nearby measurement dates',
    () {
      final rows = [
        reading('a', '2026-09-01', 80),
        reading('b', '2026-09-08', 79),
        reading('nearby', '2026-09-07', 70),
      ];
      BodyShareSnapshot snapshot({
        bool show = false,
        String end = '2026-09-08',
      }) => BodyShareSnapshot.build(
        title: 'My progress',
        start: '2026-09-01',
        end: end,
        measurements: rows,
        weightUnit: 'kg',
        lengthUnit: 'cm',
        weight: show,
      );
      expect(snapshot().lines, isEmpty);
      expect(snapshot().caption, isNot(contains('80')));
      expect(snapshot().earlierLabel, 'Earlier');
      expect(snapshot(show: true).lines.single, 'Weight change: -1.0 kg');
      expect(snapshot(show: true, end: '2026-09-09').lines, isEmpty);
      expect(snapshot().caption, isNot(contains('2026-09-01')));
    },
  );
  test('failed body commits preserve measurements and journal', () async {
    final app = store();
    app.bodyMeasurements = [reading('original', '2026-09-01', 80)];
    fail = true;
    await expectLater(
      app.commitBodyJournal(
        [reading('new', '2026-09-02', 81)],
        {'version': 1, 'checkIns': []},
      ),
      throwsA(isA<PlatformException>()),
    );
    expect(app.bodyMeasurements.single.id, 'original');
    expect(app.bodyMedia.checkIns, isEmpty);
    expect(saved, isNull);
  });
  test(
    'body commit joins app persistence queue and normal backups omit photo data',
    () async {
      final app = store();
      await app.commitBodyJournal(
        [reading('a', '2026-09-01', 80)],
        {
          'version': 1,
          'checkIns': [
            {
              'id': 'c',
              'date': '2026-09-01',
              'notes': 'private note',
              'photos': [],
            },
          ],
        },
      );
      await app.save();
      expect((jsonDecode(saved!) as Map)['bodyMeasurements'], hasLength(1));
      expect(saved, isNot(contains('private note')));
      expect(app.bodyMedia.checkIns.single.notes, 'private note');
    },
  );
  test(
    'an ordinary save queued during a failed photo commit cannot persist its measurements',
    () async {
      final model = store();
      model.bodyMeasurements = [reading('old', '2026-09-01', 80)];
      pendingBody = Completer<void>();
      failBodyOnly = true;
      final body = model.commitBodyJournal(
        [reading('uncommitted', '2026-09-02', 81)],
        {'version': 1, 'checkIns': []},
      );
      final check = expectLater(body, throwsA(isA<PlatformException>()));
      final ordinary = model.save();
      pendingBody!.complete();
      await check;
      await ordinary;
      expect((jsonDecode(saved!) as Map)['bodyMeasurements'][0]['id'], 'old');
    },
  );
  test(
    'selected body permissions request no writes or unrelated records',
    () async {
      const health = MethodChannel('test_body_health');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(health, (call) async {
            calls.add(call);
            return true;
          });
      final service = HealthSyncService(channel: health);
      await service.requestBodyAuthorization(['height']);
      expect((calls.single.arguments as Map)['read'], ['height']);
      expect((calls.single.arguments as Map)['write'], isEmpty);
      service.dispose();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(health, null);
    },
  );
  void phone(WidgetTester tester, {double scale = 1}) {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Widget app(Widget child, {double scale = 1}) => MaterialApp(
    theme: ProgressionBrand.theme().copyWith(
      textTheme: ProgressionBrand.theme().textTheme.apply(
        fontFamily: Platform.environment['BODY_FONT_ROOT'] == null
            ? null
            : 'Roboto',
      ),
    ),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(scale)),
      child: child!,
    ),
    home: child,
  );
  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'Body is reachable and supports $scale text scale on a small phone',
      (tester) async {
        phone(tester);
        final model = store();
        await tester.pumpWidget(app(ProgressHub(store: model), scale: scale));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Body'));
        await tester.pumpAndSettle();
        expect(find.text('Your body, over time'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('add-body-checkin')),
          200,
          scrollable: find.byType(Scrollable).last,
        );
        await tester.tap(find.byKey(const ValueKey('add-body-checkin')));
        await tester.pumpAndSettle();
        expect(find.text('New check-in'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      },
    );
  }
  testWidgets(
    'saving a draft commits it once and does not recreate it when leaving',
    (tester) async {
      phone(tester);
      final model = store();
      model.bodyMedia.apply({
        'version': 1,
        'draft': {
          'id': 'draft-1',
          'date': '2026-09-01',
          'photos': [],
          'values': {'weight': '183.25'},
          'weightUnit': 'lb',
          'lengthUnit': 'in',
          'notes': 'private note',
        },
        'checkIns': [],
      });
      await tester.pumpWidget(
        app(
          Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        BodyCheckInEditor(store: model, resume: true),
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save').first);
      await tester.pumpAndSettle();
      expect(model.bodyMedia.draft, isNull);
      expect(model.bodyMedia.checkIns.single.id, 'draft-1');
      expect(
        model.bodyMeasurements.single.value,
        closeTo(183.25 * .45359237, 1e-8),
      );
      expect(journal['draft'], isNull);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('photo lock hides every protected route after backgrounding', (
    tester,
  ) async {
    phone(tester);
    final media = BodyMediaStore()
      ..lockEnabled = true
      ..sessionUnlocked = true;
    await tester.pumpWidget(
      app(
        BodyPrivacyGate(
          media: media,
          child: const Scaffold(body: Text('Private photo content')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pumpAndSettle();
    expect(media.sessionUnlocked, isFalse);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open body progress'));
    await tester.pumpAndSettle();
    expect(media.sessionUnlocked, isTrue);
    expect(
      calls.where((c) => c.method == 'protectScreen' && c.arguments == true),
      isNotEmpty,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
  testWidgets(
    'measurement-only sharing works and renders the advertised PNG size',
    (tester) async {
      phone(tester);
      final model = store()
        ..bodyMeasurements = [
          reading('a', '2026-09-01', 80),
          reading('b', '2026-09-06', 79),
        ];
      await tester.pumpWidget(
        app(
          BodyShareScreen(
            store: model,
            first: const BodyCheckIn(id: 'a', date: '2026-09-01'),
            last: const BodyCheckIn(id: 'b', date: '2026-09-06'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Without a photo'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Preview final image'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Preview final image'));
      await tester.pump();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
      final images = tester
          .widgetList<Image>(find.byType(Image))
          .where((i) => i.image is MemoryImage)
          .toList();
      expect(images, isNotEmpty);
      final bytes = (images.last.image as MemoryImage).bytes;
      final codec = await tester.runAsync(
        () => ui.instantiateImageCodec(bytes),
      );
      final frame = await tester.runAsync(() => codec!.getNextFrame());
      expect(frame!.image.width, 1080);
      expect(frame.image.height, 1350);
      frame.image.dispose();
      codec!.dispose();
      if (Platform.environment['BODY_VISUALS'] != null)
        await tester.runAsync(() async {
          await Directory('/tmp/body-visuals').create(recursive: true);
          await File(
            '/tmp/body-visuals/share-portrait.png',
          ).writeAsBytes(bytes);
        });
      expect(tester.takeException(), isNull);
    },
  );
  for (final layout in [
    BodyShareLayout.comparison,
    BodyShareLayout.milestone,
    BodyShareLayout.recap,
  ]) {
    for (final height in [360.0, 450.0, 640.0]) {
      testWidgets(
        '${layout.name} photo artwork fits ${height.toInt()} with all optional fields',
        (tester) async {
          phone(tester);
          final media = BodyMediaStore()..directory = '/tmp/body-fixtures';
          const photo = BodyPhoto(
            id: 'fixture',
            asset: 'fixture.jpg',
            thumbnail: 'fixture.jpg',
            coverFace: true,
          );
          await tester.runAsync(() async {
            final recorder = ui.PictureRecorder();
            final canvas = Canvas(recorder);
            canvas.drawRect(
              const Rect.fromLTWH(0, 0, 60, 90),
              Paint()..color = Colors.blue,
            );
            canvas.drawRect(
              const Rect.fromLTWH(20, 20, 20, 50),
              Paint()..color = Colors.cyan,
            );
            final picture = recorder.endRecording();
            final bitmap = await picture.toImage(60, 90);
            picture.dispose();
            final bytes = await bitmap.toByteData(
              format: ui.ImageByteFormat.png,
            );
            bitmap.dispose();
            await Directory(media.directory).create(recursive: true);
            await File(
              media.path(photo),
            ).writeAsBytes(bytes!.buffer.asUint8List());
          });
          await tester.pumpWidget(app(const Scaffold(body: SizedBox())));
          await tester.runAsync(
            () => precacheImage(
              FileImage(File(media.path(photo))),
              tester.element(find.byType(Scaffold)),
            ),
          );
          final key = GlobalKey();
          const snapshot = BodyShareSnapshot(
            title: 'A longer personal title about my progress over time',
            interval: '42 days of progress',
            earlierLabel: '2026-07-01',
            latestLabel: '2026-08-12',
            lines: [
              'Weight change: -2.3 kg',
              'Waist change: -3.0 cm',
              '12 logged strength sessions in this interval',
            ],
          );
          await tester.pumpWidget(
            app(
              Scaffold(
                body: Center(
                  child: RepaintBoundary(
                    key: key,
                    child: SizedBox(
                      width: 360,
                      height: height,
                      child: BodyShareArtwork(
                        snapshot: snapshot,
                        layout: layout,
                        firstPhoto: photo,
                        lastPhoto: photo,
                        media: media,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.runAsync(
            () => precacheImage(
              FileImage(File(media.path(photo))),
              tester.element(find.byType(Scaffold)),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await tester.runAsync(() async {
            final bitmap =
                await (key.currentContext!.findRenderObject()
                        as RenderRepaintBoundary)
                    .toImage(pixelRatio: 3);
            expect(bitmap.width, 1080);
            expect(bitmap.height, (height * 3).toInt());
            if (Platform.environment['BODY_VISUALS'] != null &&
                layout == BodyShareLayout.comparison &&
                height == 450) {
              final bytes = await bitmap.toByteData(
                format: ui.ImageByteFormat.png,
              );
              await Directory('/tmp/body-visuals').create(recursive: true);
              await File(
                '/tmp/body-visuals/photo-comparison.png',
              ).writeAsBytes(bytes!.buffer.asUint8List());
            }
            bitmap.dispose();
          });
        },
      );
    }
  }
  testWidgets('body overview visual evidence', (tester) async {
    phone(tester);
    final model = store()
      ..bodyMeasurements = [
        for (var i = 1; i <= 6; i++) reading('$i', '2026-09-0$i', 80 - i * .1),
        reading('waist', '2026-09-06', 82, metric: BodyMetric.waist),
      ];
    final boundary = GlobalKey();
    await tester.pumpWidget(
      app(
        RepaintBoundary(
          key: boundary,
          child: Scaffold(
            body: BodyProgressScreen(store: model, embedded: true),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    if (Platform.environment['BODY_VISUALS'] != null)
      await tester.runAsync(() async {
        final image =
            await (boundary.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await Directory('/tmp/body-visuals').create(recursive: true);
        await File(
          '/tmp/body-visuals/body-overview.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
  });
}
