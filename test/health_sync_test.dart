import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:progression_lab/health_sync.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('progression_lab/test_health');
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return switch (call.method) {
            'requestAuthorization' => true,
            'status' => <String, Object>{
              'platform': 'healthConnect',
              'available': true,
              'authorization': 'authorized',
            },
            'writeBodyFat' => true,
            _ => null,
          };
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('requests only the health domains exposed by the app', () async {
    final service = HealthSyncService(channel: channel);
    addTearDown(service.dispose);

    expect(await service.requestAuthorization(), isTrue);

    final authorization = calls.firstWhere(
      (call) => call.method == 'requestAuthorization',
    );
    final arguments = Map<String, Object?>.from(
      authorization.arguments! as Map,
    );
    expect(arguments['read'], <String>['workouts', 'bodyWeight', 'bodyFat']);
    expect(arguments['write'], <String>['workouts', 'bodyWeight', 'bodyFat']);
    expect(service.status.authorization, HealthAuthorizationState.authorized);
  });

  test('writes body-fat percentages through the native bridge', () async {
    final service = HealthSyncService(channel: channel);
    addTearDown(service.dispose);
    final recordedAt = DateTime.utc(2026, 8, 22, 12);

    final written = await service.writeBodyFat(
      HealthBodyMetric(
        type: 'bodyFatPercentage',
        value: 18.5,
        unit: '%',
        recordedAt: recordedAt,
      ),
    );

    expect(written, isTrue);
    final write = calls.singleWhere((call) => call.method == 'writeBodyFat');
    final arguments = Map<String, Object?>.from(write.arguments! as Map);
    expect(arguments['value'], 18.5);
    expect(arguments['unit'], '%');
    expect(arguments['recordedAt'], recordedAt.toIso8601String());
  });

  test(
    'rejects invalid body-fat values before invoking the platform',
    () async {
      final service = HealthSyncService(channel: channel);
      addTearDown(service.dispose);

      expect(
        () => service.writeBodyFat(
          HealthBodyMetric(
            type: 'bodyFatPercentage',
            value: 101,
            unit: '%',
            recordedAt: DateTime.utc(2026, 8, 22),
          ),
        ),
        throwsArgumentError,
      );
      expect(calls, isEmpty);
    },
  );
}
