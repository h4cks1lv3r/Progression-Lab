import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:progression_lab/body_media.dart';
import 'package:progression_lab/provider_integrations.dart';
import 'package:progression_lab/store.dart';

/// These responses run through the real request encoding, OAuth callback,
/// response decoding, credential guard and connection state code. No socket is
/// opened. Only the broker's exchange response is held until the test releases it.
class _ControlledBroker implements HttpClient {
  final exchangeStarted = Completer<void>();
  final exchangeResponse = Completer<HttpClientResponse>();
  final paths = <String>[];
  final exchangeBodies = <Map<String, dynamic>>[];
  bool closed = false;

  @override
  Future<HttpClientRequest> postUrl(Uri url) async {
    paths.add(url.path);
    return _JsonRequest((bytes) {
      final body = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      if (url.path.endsWith('/authorize')) {
        expect(body['codeChallengeMethod'], 'S256');
        expect(body['codeChallenge'], isNotEmpty);
        return Future.value(
          _JsonResponse({
            'authorizationUrl': 'https://provider.test/authorize',
          }),
        );
      }
      if (url.path.endsWith('/exchange')) {
        exchangeBodies.add(body);
        expect(body['code'], 'authorized-code');
        expect(body['codeVerifier'], isNotEmpty);
        expect(body['state'], isNotEmpty);
        exchangeStarted.complete();
        return exchangeResponse.future;
      }
      throw StateError('Unexpected broker request: ${url.path}');
    });
  }

  void finishExchange() => exchangeResponse.complete(
    _JsonResponse({
      'sessionToken': 'test-device-scoped-token',
      'displayName': 'Test athlete',
    }),
  );

  @override
  void close({bool force = false}) => closed = true;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnsupportedError(
    'Unexpected HTTP client operation: ${invocation.memberName}',
  );
}

class _JsonRequest implements HttpClientRequest {
  _JsonRequest(this.respond);
  final Future<HttpClientResponse> Function(List<int>) respond;
  final bytes = <int>[];

  @override
  final HttpHeaders headers = _RequestHeaders();

  @override
  void add(List<int> data) => bytes.addAll(data);

  @override
  Future<HttpClientResponse> close() => respond(bytes);

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnsupportedError(
    'Unexpected HTTP request operation: ${invocation.memberName}',
  );
}

class _RequestHeaders implements HttpHeaders {
  @override
  ContentType? contentType;

  final values = <String, Object>{};

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) =>
      values[name] = value;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnsupportedError(
    'Unexpected HTTP header operation: ${invocation.memberName}',
  );
}

class _JsonResponse extends Stream<List<int>> implements HttpClientResponse {
  _JsonResponse(Map<String, Object> body)
    : bytes = utf8.encode(jsonEncode(body));
  final List<int> bytes;

  @override
  int get statusCode => HttpStatus.ok;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => Stream.value(bytes).listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnsupportedError(
    'Unexpected HTTP response operation: ${invocation.memberName}',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const storage = MethodChannel('iron_cadence/storage');
  const secure = MethodChannel('progression_lab/provider_reset_test_secure');
  const browser = MethodChannel('progression_lab/provider_reset_test_browser');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late List<Map<Object?, Object?>> writes;
  late List<String> storageCalls;

  ProviderConfiguration configuration(TrainingProvider provider) =>
      ProviderConfiguration(
        provider: provider,
        brokerBaseUrl: provider == TrainingProvider.strava
            ? 'https://broker.test'
            : '',
        redirectUri: 'progressionlab://oauth/${provider.name}',
      );

  setUp(() {
    writes = [];
    storageCalls = [];
    messenger.setMockMethodCallHandler(storage, (call) async {
      storageCalls.add(call.method);
      if (call.method == 'deleteAllLocalData') return true;
      return null;
    });
    messenger.setMockMethodCallHandler(
      BodyMediaStore.channel,
      (_) async => null,
    );
    messenger.setMockMethodCallHandler(secure, (call) async {
      if (call.method == 'write') {
        writes.add(Map<Object?, Object?>.from(call.arguments as Map));
      }
      return null;
    });
    messenger.setMockMethodCallHandler(browser, (call) async {
      expect(call.method, 'authorize');
      final arguments = call.arguments as Map;
      return {'code': 'authorized-code', 'state': arguments['state']};
    });
  });

  tearDown(() {
    for (final channel in [storage, BodyMediaStore.channel, secure, browser]) {
      messenger.setMockMethodCallHandler(channel, null);
    }
  });

  ProviderIntegrationService service(
    AppStore store,
    _ControlledBroker broker,
  ) => ProviderIntegrationService(
    store: store,
    httpClient: broker,
    secureChannel: secure,
    browserChannel: browser,
    configurationForProvider: configuration,
  );

  test(
    'normal configured OAuth exchange writes one credential and connects',
    () async {
      final store = AppStore()..automaticBackupsEnabled = false;
      final broker = _ControlledBroker();
      final providers = service(store, broker);
      addTearDown(providers.dispose);
      addTearDown(store.dispose);
      expect(
        providers.statuses[TrainingProvider.strava]!.state,
        ProviderConnectionState.disconnected,
      );
      expect(
        providers.statuses[TrainingProvider.garmin]!.state,
        ProviderConnectionState.unavailable,
      );
      final connection = providers.connect(TrainingProvider.strava);
      await broker.exchangeStarted.future;
      expect(writes, isEmpty);
      broker.finishExchange();
      expect(await connection, isTrue);
      expect(broker.paths, ['/v1/strava/authorize', '/v1/strava/exchange']);
      expect(writes, [
        {
          'key': 'provider.strava.sessionToken',
          'value': 'test-device-scoped-token',
        },
      ]);
      expect(providers.statuses[TrainingProvider.strava]!.connected, isTrue);
      expect(providers.busy, isFalse);
    },
  );

  test('reset waits for an already-started secure credential write', () async {
    final store = AppStore()..automaticBackupsEnabled = false;
    final broker = _ControlledBroker();
    final providers = service(store, broker);
    final writeStarted = Completer<void>();
    final finishWrite = Completer<void>();
    final events = <String>[];
    messenger.setMockMethodCallHandler(secure, (call) async {
      if (call.method == 'write') {
        events.add('write-started');
        writeStarted.complete();
        await finishWrite.future;
        events.add('write-finished');
      }
      return null;
    });
    messenger.setMockMethodCallHandler(storage, (call) async {
      if (call.method == 'deleteAllLocalData') {
        events.add('native-reset');
        return true;
      }
      return null;
    });
    final connection = providers.connect(TrainingProvider.strava);
    await broker.exchangeStarted.future;
    broker.finishExchange();
    await writeStarted.future;
    final deletion = store.deleteAllLocalData();
    try {
      await Future<void>.delayed(Duration.zero);
      expect(events, [
        'write-started',
      ], reason: 'Native reset must not race a pending credential write.');
    } finally {
      finishWrite.complete();
      await connection;
      await deletion;
      providers.dispose();
      store.dispose();
    }
    expect(events, ['write-started', 'write-finished', 'native-reset']);
  });

  for (final disposeBeforeResponse in [false, true]) {
    test(
      'OAuth exchange finishing after reset ${disposeBeforeResponse ? 'and disposal ' : ''}cannot restore a credential',
      () async {
        final store = AppStore()..automaticBackupsEnabled = false;
        final broker = _ControlledBroker();
        final providers = service(store, broker);
        var notifications = 0;
        providers.addListener(() => notifications++);
        var disposed = false;
        addTearDown(() {
          if (!disposed) providers.dispose();
          store.dispose();
        });
        final connection = providers.connect(TrainingProvider.strava);
        // Attach the rejection check before the held HTTP response can complete.
        final rejected = expectLater(connection, throwsStateError);
        await broker.exchangeStarted.future;
        expect(providers.busy, isTrue);
        expect(broker.exchangeBodies, hasLength(1));
        expect(writes, isEmpty);
        await store.deleteAllLocalData();
        expect(
          storageCalls.where((method) => method == 'deleteAllLocalData'),
          hasLength(1),
        );
        expect(store.deletedAllLocalData, isTrue);
        if (disposeBeforeResponse) {
          providers.dispose();
          disposed = true;
          expect(broker.closed, isTrue);
        }
        final notificationsBeforeResponse = notifications;
        broker.finishExchange();
        await rejected;
        expect(writes, isEmpty);
        expect(providers.busy, isFalse);
        expect(providers.statuses[TrainingProvider.strava]!.connected, isFalse);
        if (disposeBeforeResponse) {
          expect(
            notifications,
            notificationsBeforeResponse,
            reason:
                'An old provider cannot notify disposed screens after reset.',
          );
        }
      },
    );
  }
}
