import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum CloudSyncConflictPolicy { newestWins, askBeforeRestore, localWins, remoteWins }

enum ConnectedProvider { strava, garmin }

class IntegrationSettings {
  const IntegrationSettings({
    this.healthReadEnabled = false,
    this.healthWriteEnabled = false,
    this.cloudSyncEnabled = false,
    this.cloudSyncUrl = '',
    this.cloudSyncUser = '',
    this.cloudSyncPath = 'Progression-Lab/latest.plab',
    this.cloudConflictPolicy = CloudSyncConflictPolicy.askBeforeRestore,
    this.stravaRelayUrl = '',
    this.garminRelayUrl = '',
    this.contextualTipsEnabled = true,
    this.shareTemplate = 'story',
    this.shareHideWeights = false,
    this.shareHideDuration = false,
    this.shareHideBodyMetrics = true,
    this.shareCompletionOnly = false,
  });

  final bool healthReadEnabled;
  final bool healthWriteEnabled;
  final bool cloudSyncEnabled;
  final String cloudSyncUrl;
  final String cloudSyncUser;
  final String cloudSyncPath;
  final CloudSyncConflictPolicy cloudConflictPolicy;
  final String stravaRelayUrl;
  final String garminRelayUrl;
  final bool contextualTipsEnabled;
  final String shareTemplate;
  final bool shareHideWeights;
  final bool shareHideDuration;
  final bool shareHideBodyMetrics;
  final bool shareCompletionOnly;

  IntegrationSettings copyWith({
    bool? healthReadEnabled,
    bool? healthWriteEnabled,
    bool? cloudSyncEnabled,
    String? cloudSyncUrl,
    String? cloudSyncUser,
    String? cloudSyncPath,
    CloudSyncConflictPolicy? cloudConflictPolicy,
    String? stravaRelayUrl,
    String? garminRelayUrl,
    bool? contextualTipsEnabled,
    String? shareTemplate,
    bool? shareHideWeights,
    bool? shareHideDuration,
    bool? shareHideBodyMetrics,
    bool? shareCompletionOnly,
  }) => IntegrationSettings(
    healthReadEnabled: healthReadEnabled ?? this.healthReadEnabled,
    healthWriteEnabled: healthWriteEnabled ?? this.healthWriteEnabled,
    cloudSyncEnabled: cloudSyncEnabled ?? this.cloudSyncEnabled,
    cloudSyncUrl: cloudSyncUrl ?? this.cloudSyncUrl,
    cloudSyncUser: cloudSyncUser ?? this.cloudSyncUser,
    cloudSyncPath: cloudSyncPath ?? this.cloudSyncPath,
    cloudConflictPolicy: cloudConflictPolicy ?? this.cloudConflictPolicy,
    stravaRelayUrl: stravaRelayUrl ?? this.stravaRelayUrl,
    garminRelayUrl: garminRelayUrl ?? this.garminRelayUrl,
    contextualTipsEnabled:
        contextualTipsEnabled ?? this.contextualTipsEnabled,
    shareTemplate: shareTemplate ?? this.shareTemplate,
    shareHideWeights: shareHideWeights ?? this.shareHideWeights,
    shareHideDuration: shareHideDuration ?? this.shareHideDuration,
    shareHideBodyMetrics:
        shareHideBodyMetrics ?? this.shareHideBodyMetrics,
    shareCompletionOnly: shareCompletionOnly ?? this.shareCompletionOnly,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'healthReadEnabled': healthReadEnabled,
    'healthWriteEnabled': healthWriteEnabled,
    'cloudSyncEnabled': cloudSyncEnabled,
    'cloudSyncUrl': cloudSyncUrl,
    'cloudSyncUser': cloudSyncUser,
    'cloudSyncPath': cloudSyncPath,
    'cloudConflictPolicy': cloudConflictPolicy.name,
    'stravaRelayUrl': stravaRelayUrl,
    'garminRelayUrl': garminRelayUrl,
    'contextualTipsEnabled': contextualTipsEnabled,
    'shareTemplate': shareTemplate,
    'shareHideWeights': shareHideWeights,
    'shareHideDuration': shareHideDuration,
    'shareHideBodyMetrics': shareHideBodyMetrics,
    'shareCompletionOnly': shareCompletionOnly,
  };

  factory IntegrationSettings.fromJson(Map<String, dynamic> json) =>
      IntegrationSettings(
        healthReadEnabled: json['healthReadEnabled'] == true,
        healthWriteEnabled: json['healthWriteEnabled'] == true,
        cloudSyncEnabled: json['cloudSyncEnabled'] == true,
        cloudSyncUrl: '${json['cloudSyncUrl'] ?? ''}',
        cloudSyncUser: '${json['cloudSyncUser'] ?? ''}',
        cloudSyncPath:
            '${json['cloudSyncPath'] ?? 'Progression-Lab/latest.plab'}',
        cloudConflictPolicy: CloudSyncConflictPolicy.values.firstWhere(
          (value) => value.name == json['cloudConflictPolicy'],
          orElse: () => CloudSyncConflictPolicy.askBeforeRestore,
        ),
        stravaRelayUrl: '${json['stravaRelayUrl'] ?? ''}',
        garminRelayUrl: '${json['garminRelayUrl'] ?? ''}',
        contextualTipsEnabled: json['contextualTipsEnabled'] != false,
        shareTemplate: '${json['shareTemplate'] ?? 'story'}',
        shareHideWeights: json['shareHideWeights'] == true,
        shareHideDuration: json['shareHideDuration'] == true,
        shareHideBodyMetrics: json['shareHideBodyMetrics'] != false,
        shareCompletionOnly: json['shareCompletionOnly'] == true,
      );
}

class IntegrationSettingsRepository {
  static const _settingsKey = 'progression_lab_integration_settings_v1';
  static const _cloudPasswordKey = 'progression_lab_cloud_password';
  static const _providerTokenPrefix = 'progression_lab_provider_token_';

  const IntegrationSettingsRepository({
    FlutterSecureStorage secureStorage = const FlutterSecureStorage(),
  }) : _secureStorage = secureStorage;

  final FlutterSecureStorage _secureStorage;

  Future<IntegrationSettings> load() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_settingsKey);
    if (raw == null || raw.isEmpty) return const IntegrationSettings();
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map
          ? IntegrationSettings.fromJson(Map<String, dynamic>.from(decoded))
          : const IntegrationSettings();
    } on Object {
      return const IntegrationSettings();
    }
  }

  Future<void> save(IntegrationSettings settings) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_settingsKey, jsonEncode(settings.toJson()));
  }

  Future<String> readCloudPassword() async =>
      await _secureStorage.read(key: _cloudPasswordKey) ?? '';

  Future<void> writeCloudPassword(String value) async {
    if (value.isEmpty) {
      await _secureStorage.delete(key: _cloudPasswordKey);
    } else {
      await _secureStorage.write(key: _cloudPasswordKey, value: value);
    }
  }

  Future<String?> readProviderToken(ConnectedProvider provider) =>
      _secureStorage.read(key: '$_providerTokenPrefix${provider.name}');

  Future<void> writeProviderToken(
    ConnectedProvider provider,
    String? token,
  ) async {
    final key = '$_providerTokenPrefix${provider.name}';
    if (token == null || token.isEmpty) {
      await _secureStorage.delete(key: key);
    } else {
      await _secureStorage.write(key: key, value: token);
    }
  }

  Future<void> clearAllSecrets() async {
    await _secureStorage.delete(key: _cloudPasswordKey);
    for (final provider in ConnectedProvider.values) {
      await _secureStorage.delete(
        key: '$_providerTokenPrefix${provider.name}',
      );
    }
  }
}
