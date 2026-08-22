import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:progression_lab/data_portability_core.dart';
import 'package:progression_lab/store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const storageChannel = MethodChannel('iron_cadence/storage');
  String? storedValue;

  setUp(() {
    storedValue = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storageChannel, (call) async {
          switch (call.method) {
            case 'read':
              return storedValue;
            case 'write':
              storedValue = call.arguments as String;
              return null;
            default:
              throw PlatformException(code: 'unknown_method');
          }
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storageChannel, null);
  });

  test('schema 13 data migrates additively to the 2.1 schema', () async {
    storedValue = jsonEncode(<String, Object?>{
      'schemaVersion': 13,
      'days': 5,
      'week': 9,
      'workout': 2,
      'unit': 'kg',
      'logs': <Object?>[],
      'recoveryCheckIns': <Object?>[
        <String, Object?>{
          'id': 'recovery-before-2-1',
          'localDate': '2026-08-20T00:00:00.000',
          'bodyWeight': 84.2,
          'weightUnit': 'kg',
          'illness': false,
          'notes': 'Preserve me',
          'createdAt': '2026-08-20T07:00:00.000',
          'updatedAt': '2026-08-20T07:00:00.000',
        },
      ],
    });

    final store = AppStore();
    await store.load();

    expect(store.days, 5);
    expect(store.week, 9);
    expect(store.workoutIndex, 2);
    expect(store.unit, 'kg');
    expect(store.recoveryCheckIns.single.bodyWeight, 84.2);
    expect(store.recoveryCheckIns.single.notes, 'Preserve me');
    expect(store.integrationState, isEmpty);

    final migrated = jsonDecode(storedValue!) as Map<String, dynamic>;
    expect(migrated['schemaVersion'], AppStore.schemaVersion);
    expect(migrated['integrationState'], isA<Map>());
    expect(migrated['recoveryCheckIns'], hasLength(1));
  });

  test('integration state persists and survives an exact plab backup', () async {
    final integrationState = <String, Object?>{
      'healthBodyMetrics': <Object?>[
        <String, Object?>{
          'type': 'bodyFatPercentage',
          'value': 18.5,
          'unit': '%',
          'recordedAt': '2026-08-22T12:00:00.000Z',
          'source': 'Progression Lab',
        },
      ],
      'externalWorkouts': <Object?>[
        <String, Object?>{
          'id': 'health-workout-1',
          'source': 'healthConnect',
          'format': 'fit',
          'title': 'Imported run',
          'sport': 'running',
          'startedAt': '2026-08-21T10:00:00.000Z',
          'endedAt': '2026-08-21T10:30:00.000Z',
        },
      ],
      'experiments': <Object?>[
        <String, Object?>{
          'id': 'experiment-1',
          'name': 'Caffeine timing',
          'status': 'active',
        },
      ],
      'sharePreferences': <String, Object?>{
        'template': 'achievement',
        'aspect': 'story',
        'includeCaption': true,
      },
      'weeklyReviewEnabled': true,
    };

    final store = AppStore();
    await store.setIntegrationState(
      Map<String, dynamic>.from(integrationState),
    );

    final restored = AppStore();
    await restored.load();
    expect(restored.integrationState, integrationState);

    final state = restored.exportState();
    final backup = ProgressionBackupCodec.encode(
      state,
      createdAt: DateTime.utc(2026, 8, 22, 13),
      reason: 'integration-state-test',
    );
    final decoded = ProgressionBackupCodec.decode(backup);

    expect(decoded.state['integrationState'], integrationState);
    expect(
      (decoded.state['integrationState'] as Map)['healthBodyMetrics'],
      hasLength(1),
    );
    expect(
      (decoded.state['integrationState'] as Map)['externalWorkouts'],
      hasLength(1),
    );
    expect(
      jsonEncode(decoded.state),
      isNot(anyOf(contains('accessToken'), contains('refreshToken'))),
    );
  });
}
