import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:progression_lab/brand.dart';
import 'package:progression_lab/first_launch_data_setup.dart';
import 'package:progression_lab/main.dart';
import 'package:progression_lab/store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const storageChannel = MethodChannel('iron_cadence/storage');
  const portabilityChannel = MethodChannel('progression_lab/data_portability');

  final writes = <Map<String, dynamic>>[];
  var writesInFlight = 0;
  var maximumWritesInFlight = 0;
  String? storedState;
  List<Object?> automaticBackups = const [];

  setUp(() {
    writes.clear();
    writesInFlight = 0;
    maximumWritesInFlight = 0;
    storedState = null;
    automaticBackups = const [];

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storageChannel, (call) async {
          switch (call.method) {
            case 'read':
              return storedState;
            case 'write':
              writesInFlight++;
              maximumWritesInFlight = maximumWritesInFlight < writesInFlight
                  ? writesInFlight
                  : maximumWritesInFlight;
              await Future<void>.delayed(const Duration(milliseconds: 20));
              final encoded = call.arguments as String;
              storedState = encoded;
              writes.add(
                Map<String, dynamic>.from(jsonDecode(encoded) as Map),
              );
              writesInFlight--;
              return true;
            default:
              throw PlatformException(code: 'unknown_storage_method');
          }
        });

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(portabilityChannel, (call) async {
          switch (call.method) {
            case 'listAutomaticBackups':
              return automaticBackups;
            case 'writeAutomaticBackup':
              return '/test/automatic.plab';
            case 'pickFile':
              return null;
            default:
              throw PlatformException(code: 'unknown_portability_method');
          }
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storageChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(portabilityChannel, null);
  });

  void usePhoneSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  test('local writes are serialized and preserve mutation order', () async {
    final store = AppStore();

    final first = store.setPreferredTrack(TrainingTrack.athletic);
    final second = store.markDataSetupSeen(1);
    await Future.wait([first, second]);
    await store.flushPendingSaves();

    expect(maximumWritesInFlight, 1);
    expect(writes, hasLength(2));
    expect(writes.first['preferredTrack'], 'athletic');
    expect(writes.first['dataSetupVersionSeen'], 0);
    expect(writes.last['preferredTrack'], 'athletic');
    expect(writes.last['dataSetupVersionSeen'], 1);
  });

  test('load reports existing meaningful device data', () async {
    storedState = jsonEncode({
      'schemaVersion': 15,
      'days': 4,
      'week': 1,
      'workout': 0,
      'unit': 'lb',
      'logs': [
        {
          'e': 'Barbell Bench Press',
          'w': 185,
          'r': 5,
          'd': DateTime(2026, 8, 31).toIso8601String(),
          'o': 'Upper Body A',
          'n': '',
        },
      ],
    });
    final store = AppStore();

    await store.load();

    expect(store.hadStoredStateAtLaunch, isTrue);
    expect(store.hasMeaningfulData, isTrue);
    expect(store.logs, hasLength(1));
    expect(store.dataSetupVersionSeen, 0);
    expect(store.isLoaded, isTrue);
  });

  testWidgets('first app open presents data setup before the visual tour', (
    tester,
  ) async {
    usePhoneSurface(tester);
    final store = AppStore()
      ..isLoaded = true
      ..onboardingVersionSeen = 0
      ..dataSetupVersionSeen = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: ProgressionBrand.theme(),
        home: Shell(store: store),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('BRING YOUR TRAINING HISTORY'), findsOneWidget);
    expect(find.text('NO EXISTING APP DATA FOUND'), findsOneWidget);
    expect(find.text('CHOOSE AN EXPORT FILE'), findsOneWidget);
    expect(find.text('SKIP TOUR'), findsNothing);

    await tester.tap(find.text('NOT NOW'));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();

    expect(store.dataSetupVersionSeen, 1);
    expect(find.text('BRING YOUR TRAINING HISTORY'), findsNothing);
    expect(find.text('SKIP TOUR'), findsOneWidget);
  });

  testWidgets('data setup reports previously loaded Progression Lab history', (
    tester,
  ) async {
    usePhoneSurface(tester);
    final store = AppStore()
      ..isLoaded = true
      ..hadStoredStateAtLaunch = true
      ..logs = [
        SetLog(
          exercise: 'Barbell Bench Press',
          weight: 185,
          reps: 5,
          date: DateTime(2026, 8, 31),
          workout: 'Upper Body A',
        ),
      ];

    await tester.pumpWidget(
      MaterialApp(
        theme: ProgressionBrand.theme(),
        home: FirstLaunchDataSetupScreen(store: store),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('EXISTING DATA LOADED'), findsOneWidget);
    expect(find.textContaining('1 logged sets'), findsOneWidget);
    expect(find.text('NO EXISTING APP DATA FOUND'), findsNothing);
  });

  testWidgets('recoverable automatic backup is shown for an empty install', (
    tester,
  ) async {
    usePhoneSurface(tester);
    automaticBackups = [
      {
        'name': 'Progression-Lab-automatic-20260831.plab',
        'path': '/test/automatic.plab',
        'size': 4096,
        'modified': DateTime(2026, 8, 31, 21, 30).millisecondsSinceEpoch,
      },
    ];
    final store = AppStore()..isLoaded = true;

    await tester.pumpWidget(
      MaterialApp(
        theme: ProgressionBrand.theme(),
        home: FirstLaunchDataSetupScreen(store: store),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('DEVICE BACKUP FOUND'), findsOneWidget);
    expect(find.text('RESTORE LATEST BACKUP'), findsOneWidget);
  });
}
