import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:app_links/app_links.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import 'external_activity.dart';
import 'integration_settings.dart';

class ProviderConnectionStatus {
  const ProviderConnectionStatus({
    required this.provider,
    required this.configured,
    required this.connected,
    this.message = '',
  });

  final ConnectedProvider provider;
  final bool configured;
  final bool connected;
  final String message;
}

class OAuthRelayConfiguration {
  const OAuthRelayConfiguration({
    required this.provider,
    required this.relayUrl,
    required this.callbackScheme,
  });

  final ConnectedProvider provider;
  final String relayUrl;
  final String callbackScheme;

  bool get isConfigured {
    final uri = Uri.tryParse(relayUrl);
    return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty;
  }
}

/// Direct account connections deliberately use an approved OAuth relay.
///
/// Strava's token exchange and Garmin's approved developer APIs require
/// provider credentials that must not be embedded in a mobile binary. The app
/// source is complete, but the build owner must configure an HTTPS relay with
/// approved credentials through a build-time or settings URL.
class ConnectedAccountService {
  ConnectedAccountService({
    IntegrationSettingsRepository settingsRepository =
        const IntegrationSettingsRepository(),
    http.Client? client,
    AppLinks? appLinks,
  }) : _settingsRepository = settingsRepository,
       _client = client ?? http.Client(),
       _appLinks = appLinks ?? AppLinks();

  final IntegrationSettingsRepository _settingsRepository;
  final http.Client _client;
  final AppLinks _appLinks;

  static const _callbackScheme = 'progressionlab';

  Future<ProviderConnectionStatus> status(
    ConnectedProvider provider,
  ) async {
    final settings = await _settingsRepository.load();
    final configuration = _configuration(provider, settings);
    final token = await _settingsRepository.readProviderToken(provider);
    return ProviderConnectionStatus(
      provider: provider,
      configured: configuration.isConfigured,
      connected: token != null && token.isNotEmpty,
      message: configuration.isConfigured
          ? (token == null || token.isEmpty
                ? 'Ready to connect through the configured OAuth relay.'
                : 'Connected. Disconnect at any time without deleting imported data.')
          : 'An approved OAuth relay has not been configured for this build.',
    );
  }

  Future<void> connect(ConnectedProvider provider) async {
    final settings = await _settingsRepository.load();
    final configuration = _configuration(provider, settings);
    if (!configuration.isConfigured) {
      throw StateError(
        '${_label(provider)} needs an approved HTTPS OAuth relay. '
        'Configure it in Data & Connections first.',
      );
    }

    final nonce = '${DateTime.now().microsecondsSinceEpoch}-${Platform.operatingSystem}';
    final callback = Uri(
      scheme: _callbackScheme,
      host: 'oauth',
      path: '/${provider.name}',
    );
    final authorize = Uri.parse(configuration.relayUrl).replace(
      queryParameters: <String, String>{
        'provider': provider.name,
        'redirect_uri': '$callback',
        'state': nonce,
        'platform': Platform.operatingSystem,
      },
    );

    if (!await launchUrl(authorize, mode: LaunchMode.externalApplication)) {
      throw StateError('Could not open the ${_label(provider)} authorization page.');
    }

    final result = await _appLinks.uriLinkStream
        .firstWhere(
          (uri) =>
              uri.scheme == _callbackScheme &&
              uri.host == 'oauth' &&
              uri.pathSegments.contains(provider.name),
        )
        .timeout(const Duration(minutes: 5));
    if (result.queryParameters['state'] != nonce) {
      throw const FormatException('The OAuth response state did not match.');
    }
    final token = result.queryParameters['token'];
    final error = result.queryParameters['error'];
    if (error != null && error.isNotEmpty) {
      throw StateError(error);
    }
    if (token == null || token.isEmpty) {
      throw const FormatException('The OAuth relay returned no access token.');
    }
    await _settingsRepository.writeProviderToken(provider, token);
  }

  Future<void> disconnect(ConnectedProvider provider) =>
      _settingsRepository.writeProviderToken(provider, null);

  Future<List<ExternalActivity>> importRecent(
    ConnectedProvider provider, {
    DateTime? after,
  }) async {
    final settings = await _settingsRepository.load();
    final configuration = _configuration(provider, settings);
    final token = await _settingsRepository.readProviderToken(provider);
    if (!configuration.isConfigured || token == null || token.isEmpty) {
      throw StateError('${_label(provider)} is not connected.');
    }
    final endpoint = Uri.parse(configuration.relayUrl).resolve('activities').replace(
      queryParameters: <String, String>{
        'provider': provider.name,
        if (after != null) 'after': after.toUtc().toIso8601String(),
      },
    );
    final response = await _client.get(
      endpoint,
      headers: <String, String>{
        HttpHeaders.authorizationHeader: 'Bearer $token',
        HttpHeaders.acceptHeader: 'application/json',
      },
    );
    if (response.statusCode == HttpStatus.unauthorized) {
      await disconnect(provider);
      throw StateError(
        '${_label(provider)} authorization expired. Connect the account again.',
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        '${_label(provider)} relay returned ${response.statusCode}.',
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw const FormatException('The account relay returned an invalid activity list.');
    }
    final activities = <ExternalActivity>[];
    for (final item in decoded) {
      if (item is! Map) continue;
      final json = Map<String, dynamic>.from(item);
      final start = DateTime.tryParse('${json['start']}');
      final end = DateTime.tryParse('${json['end']}');
      if (start == null || end == null) continue;
      activities.add(
        ExternalActivity(
          id: '${provider.name}-${json['id'] ?? start.microsecondsSinceEpoch}',
          source: provider == ConnectedProvider.strava
              ? ExternalActivitySource.strava
              : ExternalActivitySource.garmin,
          name: '${json['name'] ?? _label(provider)}',
          activityType: '${json['type'] ?? 'Other'}',
          start: start,
          end: end.isAfter(start) ? end : start.add(const Duration(seconds: 1)),
          importedAt: DateTime.now(),
          distanceMeters: _number(json['distanceMeters']),
          calories: _number(json['calories']),
          averageHeartRate: _number(json['averageHeartRate']),
          averageCadence: _number(json['averageCadence']),
          averagePowerWatts: _number(json['averagePowerWatts']),
          notes: '${json['notes'] ?? ''}',
          sourceFile: '${_label(provider)} account',
        ),
      );
    }
    await ExternalActivityRepository().addAll(activities);
    return activities;
  }

  OAuthRelayConfiguration _configuration(
    ConnectedProvider provider,
    IntegrationSettings settings,
  ) {
    final buildValue = switch (provider) {
      ConnectedProvider.strava => const String.fromEnvironment(
        'STRAVA_OAUTH_RELAY_URL',
      ),
      ConnectedProvider.garmin => const String.fromEnvironment(
        'GARMIN_OAUTH_RELAY_URL',
      ),
    };
    final savedValue = switch (provider) {
      ConnectedProvider.strava => settings.stravaRelayUrl,
      ConnectedProvider.garmin => settings.garminRelayUrl,
    };
    return OAuthRelayConfiguration(
      provider: provider,
      relayUrl: buildValue.isNotEmpty ? buildValue : savedValue,
      callbackScheme: _callbackScheme,
    );
  }

  void close() => _client.close();

  static double? _number(Object? value) =>
      value is num ? value.toDouble() : double.tryParse('$value');

  static String _label(ConnectedProvider provider) => switch (provider) {
    ConnectedProvider.strava => 'Strava',
    ConnectedProvider.garmin => 'Garmin',
  };
}
