import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:progression_lab/brand.dart';
import 'package:progression_lab/cloud_sync.dart';
import 'package:progression_lab/health_sync.dart';
import 'package:progression_lab/integrations_hub.dart';
import 'package:progression_lab/store.dart';

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

  test('health status failures keep native diagnostics off screen', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async {
          throw PlatformException(
            code: 'native_status_failure',
            message: '/private/health.db: secret native status details',
          );
        });
    final service = HealthSyncService(channel: channel);
    addTearDown(service.dispose);
    final status = await service.refreshStatus();
    expect(status.available, isFalse);
    expect(status.message, contains('Try again'));
    expect(status.message, contains('device settings'));
    expect(status.message, isNot(contains('secret')));
    expect(status.message, isNot(contains('/private/')));
    expect(service.lastError, status.message);
  });

  test(
    'health operation failures keep native diagnostics out of lastError',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (_) async {
            throw PlatformException(
              code: 'native_read_failure',
              message: '/private/health.db: secret native read details',
            );
          });
      final service = HealthSyncService(channel: channel);
      addTearDown(service.dispose);
      await expectLater(
        service.readWorkouts(
          start: DateTime(2026, 9, 1),
          end: DateTime(2026, 9, 30),
        ),
        throwsA(isA<PlatformException>()),
      );
      expect(service.lastError, contains('try again'));
      expect(service.lastError, isNot(contains('secret')));
      expect(service.lastError, isNot(contains('/private/')));
    },
  );

  test('app-owned health setup instructions remain actionable', () {
    final update = HealthPlatformStatus.fromJson({
      'platform': 'healthConnect',
      'authorization': 'unavailable',
      'available': false,
      'message': 'Health Connect needs an update.',
    });
    expect(update.message, contains('Health Connect needs an update'));
    expect(update.message, contains('Update it'));
    final apple = HealthPlatformStatus.fromJson({
      'platform': 'appleHealth',
      'authorization': 'unavailable',
      'available': false,
      'message': 'Apple Health is not available on this device.',
    });
    expect(apple.message, 'Apple Health is not available on this device.');
    final unexpected = HealthPlatformStatus.fromJson({
      'message': '/private/health.db: secret platform details',
    });
    expect(unexpected.message, contains('Try again'));
    expect(unexpected.message, isNot(contains('secret')));
    expect(unexpected.message, isNot(contains('/private/')));
  });

  testWidgets('health status can be retried from safe connection feedback', (
    tester,
  ) async {
    const health = MethodChannel('progression_lab/health');
    const others = [
      MethodChannel('iron_cadence/storage'),
      MethodChannel('progression_lab/cloud_sync'),
      MethodChannel('progression_lab/integration_preferences'),
      MethodChannel('progression_lab/guide_state'),
    ];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    var attempts = 0;
    messenger.setMockMethodCallHandler(health, (call) async {
      if (call.method == 'status') {
        attempts++;
        if (attempts == 1) {
          throw PlatformException(
            code: 'native_status_failure',
            message: '/private/health.db: secret platform details',
          );
        }
        return {
          'platform': 'healthConnect',
          'authorization': 'authorized',
          'available': true,
        };
      }
      return null;
    });
    for (final other in others) {
      messenger.setMockMethodCallHandler(other, (_) async => null);
    }
    addTearDown(() {
      messenger.setMockMethodCallHandler(health, null);
      for (final other in others) {
        messenger.setMockMethodCallHandler(other, null);
      }
    });
    final store = AppStore()..automaticBackupsEnabled = false;
    final cloud = CloudBackupSyncService.shared(store);
    addTearDown(cloud.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: ProgressionBrand.theme(),
        home: IntegrationsHubScreen(store: store),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('secret'), findsNothing);
    expect(find.textContaining('/private/'), findsNothing);
    expect(
      find.textContaining('Health access could not be checked'),
      findsOneWidget,
    );
    await tester.tap(find.text('Retry health status'));
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(find.text('Retry health status'), findsNothing);
    expect(find.textContaining('Health access is allowed'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
