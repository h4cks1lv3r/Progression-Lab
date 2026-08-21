import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'external_workout_formats.dart';

enum TrainingProvider { strava, garmin }

enum ProviderConnectionState { unavailable, disconnected, connecting, connected, expired, error }

class ProviderConfiguration {
  const ProviderConfiguration({
    required this.provider,
    required this.brokerBaseUrl,
    required this.redirectUri,
  });

  final TrainingProvider provider;
  final String brokerBaseUrl;
  final String redirectUri;

  bool get configured => brokerBaseUrl.trim().isNotEmpty && redirectUri.trim().isNotEmpty;

  static ProviderConfiguration forProvider(TrainingProvider provider) => switch (provider) {
        TrainingProvider.strava => const ProviderConfiguration(
            provider: TrainingProvider.strava,
            brokerBaseUrl: String.fromEnvironment('STRAVA_SYNC_BROKER_URL'),
            redirectUri: String.fromEnvironment(
              'STRAVA_REDIRECT_URI',
              defaultValue: 'progressionlab://oauth/strava',
            ),
          ),
        TrainingProvider.garmin => const ProviderConfiguration(
            provider: TrainingProvider.garmin,
            brokerBaseUrl: String.fromEnvironment('GARMIN_SYNC_BROKER_URL'),
            redirectUri: String.fromEnvironment(
              'GARMIN_REDIRECT_URI',
              defaultValue: 'progressionlab://oauth/garmin',
            ),
          ),
      };
}

class ProviderStatus {
  const ProviderStatus({
    required this.provider,
    required this.state,
    this.accountName = '',
    this.connectedAt,
    this.lastSyncAt,
    this.message = '',
  });

  final TrainingProvider provider;
  final ProviderConnectionState state;
  final String accountName;
  final DateTime? connectedAt;
  final DateTime? lastSyncAt;
  final String message;

  bool get connected => state == ProviderConnectionState.connected;

  ProviderStatus copyWith({
    ProviderConnectionState? state,
    String? accountName,
    DateTime? connectedAt,
    DateTime? lastSyncAt,
    String? message,
  }) =>
      ProviderStatus(
        provider: provider,
        state: state ?? this.state,
        accountName: accountName ?? this.accountName,
        connectedAt: connectedAt ?? this.connectedAt,
        lastSyncAt: lastSyncAt ?? this.lastSyncAt,
        message: message ?? this.message,
      );
}

class ProviderActivityPage {
  const ProviderActivityPage({
    required this.workouts,
    this.nextCursor,
    this.warnings = const <String>[],
  });

  final List<ExternalWorkout> workouts;
  final String? nextCursor;
  final List<String> warnings;
}

/// Direct provider synchronization uses a small, separately deployable OAuth
/// broker. Client secrets and Garmin partner credentials must never ship in the
/// APK or IPA. The broker exchanges authorization codes and returns short-lived,
/// device-scoped session tokens. File import remains available without a broker.
class ProviderIntegrationService extends ChangeNotifier {
  ProviderIntegrationService({
    HttpClient? httpClient,
    MethodChannel? secureChannel,
    MethodChannel? browserChannel,
  })  : _httpClient = httpClient ?? HttpClient(),
        _secureChannel = secureChannel ??
            const MethodChannel('progression_lab/secure_storage'),
        _browserChannel = browserChannel ??
            const MethodChannel('progression_lab/oauth');

  final HttpClient _httpClient;
  final MethodChannel _secureChannel;
  final MethodChannel _browserChannel;
  final Map<TrainingProvider, ProviderStatus> _status = <TrainingProvider, ProviderStatus>{
    for (final provider in TrainingProvider.values)
      provider: ProviderStatus(
        provider: provider,
        state: ProviderConfiguration.forProvider(provider).configured
            ? ProviderConnectionState.disconnected
            : ProviderConnectionState.unavailable,
      ),
  };
  bool _busy = false;
  String? _lastError;

  Map<TrainingProvider, ProviderStatus> get statuses => Map.unmodifiable(_status);
  bool get busy => _busy;
  String? get lastError => _lastError;

  Future<void> initialize() async {
    for (final provider in TrainingProvider.values) {
      final config = ProviderConfiguration.forProvider(provider);
      if (!config.configured) continue;
      final token = await _readSecret(_tokenKey(provider));
      if (token == null || token.isEmpty) continue;
      try {
        final profile = await _getJson(
          config,
          '/v1/${provider.name}/profile',
          sessionToken: token,
        );
        _status[provider] = ProviderStatus(
          provider: provider,
          state: ProviderConnectionState.connected,
          accountName: '${profile['displayName'] ?? profile['username'] ?? ''}',
          connectedAt: _date(profile['connectedAt']),
          lastSyncAt: _date(profile['lastSyncAt']),
        );
      } on Object {
        _status[provider] = ProviderStatus(
          provider: provider,
          state: ProviderConnectionState.expired,
          message: 'Reconnect to continue syncing.',
        );
      }
    }
    notifyListeners();
  }

  Future<bool> connect(TrainingProvider provider) async {
    final config = ProviderConfiguration.forProvider(provider);
    if (!config.configured) {
      throw StateError(
        '${provider.name} synchronization needs a configured OAuth broker. '
        'Manual FIT, TCX, GPX, and export-file import remains available.',
      );
    }
    return _guard(() async {
      _status[provider] = _status[provider]!.copyWith(
        state: ProviderConnectionState.connecting,
        message: '',
      );
      notifyListeners();

      final verifier = _randomVerifier();
      final challenge = base64Url
          .encode(sha256.convert(utf8.encode(verifier)).bytes)
          .replaceAll('=', '');
      final state = _randomVerifier(length: 32);
      final start = await _postJson(
        config,
        '/v1/${provider.name}/authorize',
        <String, Object>{
          'redirectUri': config.redirectUri,
          'state': state,
          'codeChallenge': challenge,
          'codeChallengeMethod': 'S256',
          'platform': defaultTargetPlatform.name,
        },
      );
      final authorizationUrl = '${start['authorizationUrl'] ?? ''}';
      if (!authorizationUrl.startsWith('https://')) {
        throw const FormatException('The provider returned an invalid authorization URL.');
      }
      final callback = await _browserChannel.invokeMapMethod<Object?, Object?>(
        'authorize',
        <String, Object>{
          'url': authorizationUrl,
          'redirectUri': config.redirectUri,
          'state': state,
        },
      );
      if (callback == null) {
        _status[provider] = _status[provider]!.copyWith(
          state: ProviderConnectionState.disconnected,
        );
        notifyListeners();
        return false;
      }
      if ('${callback['state']}' != state) {
        throw const FormatException('OAuth state verification failed.');
      }
      final code = '${callback['code'] ?? ''}';
      if (code.isEmpty) {
        final description = '${callback['errorDescription'] ?? callback['error'] ?? 'Authorization was cancelled.'}';
        throw StateError(description);
      }
      final exchange = await _postJson(
        config,
        '/v1/${provider.name}/exchange',
        <String, Object>{
          'code': code,
          'redirectUri': config.redirectUri,
          'codeVerifier': verifier,
          'state': state,
        },
      );
      final sessionToken = '${exchange['sessionToken'] ?? ''}';
      if (sessionToken.isEmpty) {
        throw const FormatException('The OAuth broker returned no session token.');
      }
      await _writeSecret(_tokenKey(provider), sessionToken);
      _status[provider] = ProviderStatus(
        provider: provider,
        state: ProviderConnectionState.connected,
        accountName: '${exchange['displayName'] ?? exchange['username'] ?? ''}',
        connectedAt: DateTime.now().toUtc(),
      );
      notifyListeners();
      return true;
    }, provider: provider);
  }

  Future<void> disconnect(TrainingProvider provider) async {
    final config = ProviderConfiguration.forProvider(provider);
    final token = await _readSecret(_tokenKey(provider));
    if (config.configured && token != null && token.isNotEmpty) {
      try {
        await _postJson(
          config,
          '/v1/${provider.name}/disconnect',
          const <String, Object>{},
          sessionToken: token,
        );
      } on Object {
        // Local disconnect still proceeds. The broker can expire orphaned
        // sessions according to its own retention policy.
      }
    }
    await _deleteSecret(_tokenKey(provider));
    _status[provider] = ProviderStatus(
      provider: provider,
      state: config.configured
          ? ProviderConnectionState.disconnected
          : ProviderConnectionState.unavailable,
    );
    notifyListeners();
  }

  Future<ProviderActivityPage> fetchActivities(
    TrainingProvider provider, {
    required DateTime start,
    required DateTime end,
    String? cursor,
  }) async {
    final config = ProviderConfiguration.forProvider(provider);
    final token = await _requiredToken(provider);
    return _guard(() async {
      final query = <String, String>{
        'start': start.toUtc().toIso8601String(),
        'end': end.toUtc().toIso8601String(),
        if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
      };
      final response = await _getJson(
        config,
        '/v1/${provider.name}/activities',
        sessionToken: token,
        query: query,
      );
      final rawActivities = response['activities'];
      final workouts = <ExternalWorkout>[];
      final warnings = <String>[];
      if (rawActivities is List) {
        for (final raw in rawActivities.whereType<Map>()) {
          try {
            workouts.add(_providerWorkout(provider, Map<String, dynamic>.from(raw)));
          } on Object catch (error) {
            warnings.add('One ${provider.name} activity was skipped: $error');
          }
        }
      }
      _status[provider] = _status[provider]!.copyWith(
        state: ProviderConnectionState.connected,
        lastSyncAt: DateTime.now().toUtc(),
        message: '',
      );
      notifyListeners();
      return ProviderActivityPage(
        workouts: workouts,
        nextCursor: response['nextCursor'] is String
            ? response['nextCursor']! as String
            : null,
        warnings: warnings,
      );
    }, provider: provider);
  }

  Future<Uint8List> downloadOriginalActivity(
    TrainingProvider provider,
    String activityId, {
    String preferredFormat = 'fit',
  }) async {
    final config = ProviderConfiguration.forProvider(provider);
    final token = await _requiredToken(provider);
    final uri = _uri(
      config,
      '/v1/${provider.name}/activities/$activityId/original',
      <String, String>{'format': preferredFormat},
    );
    final request = await _httpClient.getUrl(uri);
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    request.headers.set(HttpHeaders.acceptHeader, 'application/octet-stream');
    final response = await request.close();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException('Provider export failed with HTTP ${response.statusCode}.', uri: uri);
    }
    final chunks = <int>[];
    await for (final chunk in response) {
      chunks.addAll(chunk);
    }
    return Uint8List.fromList(chunks);
  }

  Future<Map<String, dynamic>> _getJson(
    ProviderConfiguration config,
    String path, {
    String? sessionToken,
    Map<String, String> query = const <String, String>{},
  }) async {
    final uri = _uri(config, path, query);
    final request = await _httpClient.getUrl(uri);
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    if (sessionToken != null) {
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $sessionToken');
    }
    final response = await request.close();
    return _decodeResponse(response, uri);
  }

  Future<Map<String, dynamic>> _postJson(
    ProviderConfiguration config,
    String path,
    Map<String, Object> body, {
    String? sessionToken,
  }) async {
    final uri = _uri(config, path);
    final request = await _httpClient.postUrl(uri);
    request.headers.contentType = ContentType.json;
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    if (sessionToken != null) {
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $sessionToken');
    }
    request.add(utf8.encode(jsonEncode(body)));
    final response = await request.close();
    return _decodeResponse(response, uri);
  }

  Future<Map<String, dynamic>> _decodeResponse(
    HttpClientResponse response,
    Uri uri,
  ) async {
    final text = await utf8.decoder.bind(response).join();
    Map<String, dynamic> body = const <String, dynamic>{};
    if (text.trim().isNotEmpty) {
      final decoded = jsonDecode(text);
      if (decoded is Map) body = Map<String, dynamic>.from(decoded);
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = '${body['message'] ?? body['error'] ?? 'HTTP ${response.statusCode}'}';
      throw HttpException(message, uri: uri);
    }
    return body;
  }

  Uri _uri(
    ProviderConfiguration config,
    String path, [
    Map<String, String> query = const <String, String>{},
  ]) {
    final base = Uri.parse(config.brokerBaseUrl);
    if (base.scheme != 'https') {
      throw StateError('Provider broker URLs must use HTTPS.');
    }
    return base.replace(
      path: '${base.path.replaceFirst(RegExp(r'/$'), '')}$path',
      queryParameters: query.isEmpty ? null : query,
    );
  }

  Future<String> _requiredToken(TrainingProvider provider) async {
    final token = await _readSecret(_tokenKey(provider));
    if (token == null || token.isEmpty) {
      throw StateError('Connect ${provider.name} before syncing activities.');
    }
    return token;
  }

  Future<String?> _readSecret(String key) =>
      _secureChannel.invokeMethod<String>('read', <String, String>{'key': key});

  Future<void> _writeSecret(String key, String value) =>
      _secureChannel.invokeMethod<void>(
        'write',
        <String, String>{'key': key, 'value': value},
      );

  Future<void> _deleteSecret(String key) =>
      _secureChannel.invokeMethod<void>('delete', <String, String>{'key': key});

  String _tokenKey(TrainingProvider provider) =>
      'provider.${provider.name}.sessionToken';

  String _randomVerifier({int length = 64}) {
    const alphabet = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~';
    final random = Random.secure();
    return List<String>.generate(
      length,
      (_) => alphabet[random.nextInt(alphabet.length)],
    ).join();
  }

  DateTime? _date(Object? value) =>
      value is String ? DateTime.tryParse(value)?.toUtc() : null;

  ExternalWorkout _providerWorkout(
    TrainingProvider provider,
    Map<String, dynamic> raw,
  ) {
    final startedAt = DateTime.parse('${raw['startedAt'] ?? raw['startDate']}').toUtc();
    final durationSeconds = (raw['durationSeconds'] as num?)?.toDouble() ??
        (raw['movingTimeSeconds'] as num?)?.toDouble() ??
        0;
    final endedAt = raw['endedAt'] is String
        ? DateTime.parse(raw['endedAt']! as String).toUtc()
        : startedAt.add(Duration(milliseconds: (durationSeconds * 1000).round()));
    return ExternalWorkout(
      id: '${provider.name}-${raw['id']}',
      source: provider == TrainingProvider.strava
          ? ExternalWorkoutSource.strava
          : ExternalWorkoutSource.garmin,
      format: ExternalWorkoutFormat.fit,
      title: '${raw['name'] ?? raw['title'] ?? '${provider.name} activity'}',
      sport: '${raw['sport'] ?? raw['type'] ?? 'other'}',
      startedAt: startedAt,
      endedAt: endedAt,
      durationSeconds: durationSeconds > 0 ? durationSeconds : null,
      distanceMeters: (raw['distanceMeters'] as num?)?.toDouble(),
      calories: (raw['calories'] as num?)?.round(),
      averageHeartRate: (raw['averageHeartRate'] as num?)?.round(),
      maximumHeartRate: (raw['maximumHeartRate'] as num?)?.round(),
      averageCadence: (raw['averageCadence'] as num?)?.round(),
      averagePowerWatts: (raw['averagePowerWatts'] as num?)?.round(),
      notes: raw['description'] is String ? raw['description']! as String : '',
      metadata: <String, dynamic>{
        'provider': provider.name,
        'providerActivityId': '${raw['id']}',
        if (raw['url'] != null) 'providerUrl': raw['url'],
      },
    );
  }

  Future<T> _guard<T>(
    Future<T> Function() action, {
    TrainingProvider? provider,
  }) async {
    if (_busy) throw StateError('A provider operation is already running.');
    _busy = true;
    _lastError = null;
    notifyListeners();
    try {
      return await action();
    } catch (error) {
      _lastError = '$error';
      if (provider != null) {
        _status[provider] = _status[provider]!.copyWith(
          state: ProviderConnectionState.error,
          message: _lastError!,
        );
      }
      notifyListeners();
      rethrow;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _httpClient.close(force: true);
    super.dispose();
  }
}
