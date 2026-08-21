import 'dart:convert';
import 'dart:typed_data';

import 'data_portability_core.dart';
import 'external_activity.dart';
import 'integration_settings.dart';
import 'personal_experiments.dart';

/// Loads and restores the feature data that lives outside the legacy AppStore
/// preference document. Secrets are deliberately excluded.
abstract final class AuxiliaryDataSnapshot {
  static Future<Map<String, dynamic>> load() async {
    final activities = await ExternalActivityRepository().load();
    final experiments = await PersonalExperimentRepository().load();
    final settings = await const IntegrationSettingsRepository().load();
    return <String, dynamic>{
      'externalActivities': activities.map((item) => item.toJson()).toList(),
      'personalExperiments': experiments.map((item) => item.toJson()).toList(),
      'integrationSettings': settings.toJson(),
    };
  }

  static Future<Map<String, dynamic>> merge(
    Map<String, dynamic> appState,
  ) async => <String, dynamic>{...appState, ...await load()};

  static Future<void> restore(Map<String, dynamic> state) async {
    final activityValues = state['externalActivities'];
    if (activityValues is List) {
      final activities = <ExternalActivity>[];
      for (final item in activityValues) {
        if (item is! Map) continue;
        try {
          activities.add(
            ExternalActivity.fromJson(Map<String, dynamic>.from(item)),
          );
        } on Object {
          // Preserve usable records when one auxiliary row is malformed.
        }
      }
      final repository = ExternalActivityRepository();
      await repository.clear();
      await repository.addAll(activities);
    }

    final experimentValues = state['personalExperiments'];
    if (experimentValues is List) {
      final experiments = <PersonalExperiment>[];
      for (final item in experimentValues) {
        if (item is! Map) continue;
        try {
          experiments.add(
            PersonalExperiment.fromJson(Map<String, dynamic>.from(item)),
          );
        } on Object {
          // Preserve usable records when one experiment is malformed.
        }
      }
      await PersonalExperimentRepository().save(experiments);
    }

    final settingsValue = state['integrationSettings'];
    if (settingsValue is Map) {
      await const IntegrationSettingsRepository().save(
        IntegrationSettings.fromJson(
          Map<String, dynamic>.from(settingsValue),
        ),
      );
    }
  }

  static Map<String, Uint8List> portableFiles(
    Map<String, dynamic> state,
  ) {
    Uint8List csv(List<List<Object?>> rows) =>
        Uint8List.fromList(utf8.encode(CsvCodec.encode(rows)));

    final activities = <List<Object?>>[
      <Object?>[
        'activity_id',
        'source',
        'name',
        'activity_type',
        'start',
        'end',
        'duration_seconds',
        'distance_meters',
        'calories',
        'average_heart_rate',
        'average_cadence',
        'average_power_watts',
        'notes',
        'source_file',
      ],
    ];
    final rawActivities = state['externalActivities'];
    if (rawActivities is List) {
      for (final item in rawActivities) {
        if (item is! Map) continue;
        final value = Map<String, dynamic>.from(item);
        final start = DateTime.tryParse('${value['start']}');
        final end = DateTime.tryParse('${value['end']}');
        activities.add(<Object?>[
          value['id'],
          value['source'],
          value['name'],
          value['activityType'],
          value['start'],
          value['end'],
          start != null && end != null ? end.difference(start).inSeconds : '',
          value['distanceMeters'] ?? '',
          value['calories'] ?? '',
          value['averageHeartRate'] ?? '',
          value['averageCadence'] ?? '',
          value['averagePowerWatts'] ?? '',
          value['notes'] ?? '',
          value['sourceFile'] ?? '',
        ]);
      }
    }

    final experiments = <List<Object?>>[
      <Object?>[
        'experiment_id',
        'name',
        'variable',
        'metric',
        'started_at',
        'minimum_matched_sessions',
        'duration_days',
        'status',
        'condition_label',
        'control_label',
        'notes',
      ],
    ];
    final rawExperiments = state['personalExperiments'];
    if (rawExperiments is List) {
      for (final item in rawExperiments) {
        if (item is! Map) continue;
        final value = Map<String, dynamic>.from(item);
        experiments.add(<Object?>[
          value['id'],
          value['name'],
          value['variable'],
          value['metric'],
          value['startedAt'],
          value['minimumMatchedSessions'],
          value['durationDays'],
          value['status'],
          value['conditionLabel'] ?? '',
          value['controlLabel'] ?? '',
          value['notes'] ?? '',
        ]);
      }
    }

    final settings = state['integrationSettings'];
    final settingsRows = <List<Object?>>[
      <Object?>['setting', 'value'],
      if (settings is Map)
        for (final entry in settings.entries)
          if (!'${entry.key}'.toLowerCase().contains('password') &&
              !'${entry.key}'.toLowerCase().contains('token'))
            <Object?>[entry.key, entry.value],
    ];

    return <String, Uint8List>{
      'external_activities.csv': csv(activities),
      'personal_experiments.csv': csv(experiments),
      'integration_settings.csv': csv(settingsRows),
    };
  }
}
