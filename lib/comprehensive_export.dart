import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import 'data_portability_core.dart';

/// Builds the user-facing portable export from every current Progression Lab
/// data domain. Exact restoration still uses the versioned `.plab` archive;
/// these CSVs are intentionally readable by people and other applications.
abstract final class ComprehensivePortableExport {
  static Map<String, Uint8List> portableFiles(Map<String, dynamic> state) {
    Uint8List bytes(List<List<Object?>> rows) =>
        Uint8List.fromList(utf8.encode(CsvCodec.encode(rows)));

    return <String, Uint8List>{
      ...ProgressionCsvExport.portableFiles(state),
      'exercises.csv': bytes(_exerciseRows(state)),
      'supplement_presets.csv': bytes(_supplementPresetRows(state)),
      'supplement_events.csv': bytes(_supplementEventRows(state)),
      'meals.csv': bytes(_mealRows(state)),
      'hydration.csv': bytes(_hydrationRows(state)),
      'recovery.csv': bytes(_recoveryRows(state)),
      'body_metrics.csv': bytes(_bodyMetricRows(state)),
      'workout_responses.csv': bytes(_workoutResponseRows(state)),
      'lab_preferences.csv': bytes(_labPreferenceRows(state)),
    };
  }

  static Uint8List encodePortableCsvZip(Map<String, dynamic> state) {
    final archive = Archive();
    final files = portableFiles(state);
    for (final entry in files.entries) {
      archive.addFile(ArchiveFile(entry.key, entry.value.length, entry.value));
    }
    final readme = Uint8List.fromList(
      utf8.encode(
        'Progression Lab portable data export\n'
        'UTF-8, comma-separated, ISO-8601 timestamps, explicit units.\n'
        'Private Lab conversation text is excluded from portable CSVs.\n'
        'Use a .plab backup when you need an exact in-app restore.\n',
      ),
    );
    archive.addFile(ArchiveFile('README.txt', readme.length, readme));
    final encoded = ZipEncoder().encode(archive);
    if (encoded == null || encoded.isEmpty) {
      throw StateError('Could not encode the portable data export.');
    }
    return Uint8List.fromList(encoded);
  }

  static List<List<Object?>> _exerciseRows(Map<String, dynamic> state) {
    final rows = <List<Object?>>[
      <Object?>[
        'exercise_id',
        'exercise_name',
        'aliases',
        'primary_muscle',
        'secondary_muscles',
        'equipment',
        'movement_pattern',
        'tracking_type',
        'unilateral_mode',
        'unit_override',
        'default_rest_seconds',
        'is_primary_compound',
        'warmup_eligible',
        'tags',
        'notes',
        'media_reference',
        'is_favorite',
        'is_archived',
      ],
    ];
    for (final item in _maps(state['customExercises'])) {
      rows.add(<Object?>[
        item['id'],
        item['name'],
        _joinedList(item['aliases']),
        item['primaryMuscle'] ?? '',
        _joinedList(item['secondaryMuscles']),
        item['equipment'] ?? '',
        item['movementPattern'] ?? '',
        item['trackingType'] ?? '',
        item['unilateralMode'] ?? '',
        item['unitOverride'] ?? '',
        item['defaultRestSeconds'] ?? '',
        item['isPrimaryCompound'] == true,
        item['warmupEligible'] == true,
        _joinedList(item['tags']),
        item['notes'] ?? '',
        item['mediaReference'] ?? '',
        item['isFavorite'] == true,
        item['isArchived'] == true,
      ]);
    }
    return rows;
  }

  static List<List<Object?>> _supplementPresetRows(
    Map<String, dynamic> state,
  ) {
    final rows = <List<Object?>>[
      <Object?>[
        'preset_id',
        'name',
        'brand',
        'dose',
        'unit',
        'caffeine_mg',
        'archived',
        'created_at',
        'updated_at',
      ],
    ];
    for (final item in _maps(state['supplementPresets'])) {
      rows.add(<Object?>[
        item['id'],
        item['name'],
        item['brand'] ?? '',
        item['dose'],
        item['unit'],
        item['caffeineMg'] ?? 0,
        item['archived'] == true,
        item['createdAt'],
        item['updatedAt'],
      ]);
    }
    return rows;
  }

  static List<List<Object?>> _supplementEventRows(
    Map<String, dynamic> state,
  ) {
    final rows = <List<Object?>>[
      <Object?>[
        'event_id',
        'preset_id',
        'name',
        'brand',
        'dose',
        'unit',
        'caffeine_mg',
        'taken_at',
        'workout_session_id',
        'notes',
        'created_at',
        'updated_at',
      ],
    ];
    for (final item in _maps(state['supplementEvents'])) {
      rows.add(<Object?>[
        item['id'],
        item['presetId'] ?? '',
        item['name'],
        item['brand'] ?? '',
        item['dose'],
        item['unit'],
        item['caffeineMg'] ?? 0,
        item['takenAt'],
        item['workoutSessionId'] ?? '',
        item['notes'] ?? '',
        item['createdAt'],
        item['updatedAt'],
      ]);
    }
    return rows;
  }

  static List<List<Object?>> _mealRows(Map<String, dynamic> state) {
    final rows = <List<Object?>>[
      <Object?>[
        'meal_id',
        'name',
        'occurred_at',
        'size',
        'timing',
        'calories',
        'protein_grams',
        'carbohydrate_grams',
        'fat_grams',
        'workout_session_id',
        'notes',
        'created_at',
        'updated_at',
      ],
    ];
    for (final item in _maps(state['mealEvents'])) {
      rows.add(<Object?>[
        item['id'],
        item['name'],
        item['occurredAt'],
        item['size'],
        item['timing'],
        item['calories'] ?? '',
        item['proteinGrams'] ?? '',
        item['carbohydrateGrams'] ?? '',
        item['fatGrams'] ?? '',
        item['workoutSessionId'] ?? '',
        item['notes'] ?? '',
        item['createdAt'],
        item['updatedAt'],
      ]);
    }
    return rows;
  }

  static List<List<Object?>> _hydrationRows(Map<String, dynamic> state) {
    final rows = <List<Object?>>[
      <Object?>[
        'hydration_id',
        'occurred_at',
        'amount_ml',
        'electrolytes',
        'notes',
        'created_at',
        'updated_at',
      ],
    ];
    for (final item in _maps(state['hydrationEvents'])) {
      rows.add(<Object?>[
        item['id'],
        item['occurredAt'],
        item['amountMl'],
        item['electrolytes'] == true,
        item['notes'] ?? '',
        item['createdAt'],
        item['updatedAt'],
      ]);
    }
    return rows;
  }

  static List<List<Object?>> _recoveryRows(Map<String, dynamic> state) {
    final rows = <List<Object?>>[
      <Object?>[
        'check_in_id',
        'local_date',
        'sleep_hours',
        'sleep_quality',
        'stress',
        'soreness',
        'illness',
        'notes',
        'created_at',
        'updated_at',
      ],
    ];
    for (final item in _maps(state['recoveryCheckIns'])) {
      rows.add(<Object?>[
        item['id'],
        item['localDate'],
        item['sleepHours'] ?? '',
        item['sleepQuality'] ?? '',
        item['stress'] ?? '',
        item['soreness'] ?? '',
        item['illness'] == true,
        item['notes'] ?? '',
        item['createdAt'],
        item['updatedAt'],
      ]);
    }
    return rows;
  }

  static List<List<Object?>> _bodyMetricRows(Map<String, dynamic> state) {
    final rows = <List<Object?>>[
      <Object?>[
        'check_in_id',
        'local_date',
        'body_weight',
        'weight_unit',
        'created_at',
        'updated_at',
      ],
    ];
    for (final item in _maps(state['recoveryCheckIns'])) {
      if (item['bodyWeight'] == null) continue;
      rows.add(<Object?>[
        item['id'],
        item['localDate'],
        item['bodyWeight'],
        item['weightUnit'] ?? state['unit'] ?? 'lb',
        item['createdAt'],
        item['updatedAt'],
      ]);
    }
    return rows;
  }

  static List<List<Object?>> _workoutResponseRows(
    Map<String, dynamic> state,
  ) {
    final rows = <List<Object?>>[
      <Object?>[
        'response_id',
        'workout_session_id',
        'track',
        'recorded_at',
        'energy',
        'focus',
        'pump',
        'effort',
        'discomfort',
        'notes',
        'created_at',
        'updated_at',
      ],
    ];
    for (final item in _maps(state['workoutResponses'])) {
      rows.add(<Object?>[
        item['id'],
        item['workoutSessionId'],
        item['track'],
        item['recordedAt'],
        item['energy'],
        item['focus'],
        item['pump'],
        item['effort'],
        item['discomfort'],
        item['notes'] ?? '',
        item['createdAt'],
        item['updatedAt'],
      ]);
    }
    return rows;
  }

  static List<List<Object?>> _labPreferenceRows(
    Map<String, dynamic> state,
  ) => <List<Object?>>[
    <Object?>['ai_analysis_enabled', 'enabled_data_domains'],
    <Object?>[
      state['aiAnalysisEnabled'] == true,
      _joinedList(state['labDataDomains']),
    ],
  ];

  static String _joinedList(Object? value) =>
      value is List ? value.map((item) => '$item').join('|') : '';

  static List<Map<String, dynamic>> _maps(Object? value) {
    if (value is! List) return <Map<String, dynamic>>[];
    return <Map<String, dynamic>>[
      for (final item in value)
        if (item is Map) Map<String, dynamic>.from(item),
    ];
  }
}
