import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:progression_lab/comprehensive_export.dart';
import 'package:progression_lab/data_portability_core.dart';
import 'package:progression_lab/store.dart';

void main() {
  Map<String, dynamic> sampleState() => <String, dynamic>{
    'schemaVersion': AppStore.schemaVersion,
    'days': 4,
    'week': 21,
    'workout': 2,
    'unit': 'lb',
    'programStartDate': '2026-08-01T00:00:00.000',
    'strengthProgramRun': 3,
    'athleticProgramRun': 2,
    'athleticWeek': 7,
    'athleticSessionIndex': 1,
    'athleticStartDate': '2026-08-02T00:00:00.000',
    'logs': <Object?>[],
    'workoutHistory': <Object?>[],
    'customExercises': <Object?>[
      <String, dynamic>{
        'id': 'custom-offset-row',
        'name': 'Researcher Offset Row',
        'aliases': <String>['Offset Cable Row'],
        'primaryMuscle': 'midBack',
        'secondaryMuscles': <String>['lats', 'biceps'],
        'equipment': 'cable',
        'movementPattern': 'horizontalPull',
        'trackingType': 'weightReps',
        'unilateralMode': 'perSide',
        'unitOverride': 'lb',
        'defaultRestSeconds': 120,
        'isPrimaryCompound': true,
        'warmupEligible': false,
        'tags': <String>['Home Gym'],
        'notes': 'Offset stance',
        'mediaReference': '',
        'isFavorite': true,
        'isArchived': false,
      },
    ],
    'favoriteBuiltInExerciseIds': <String>['barbell_bench_press'],
    'draft': null,
    'drafts': <Object?>[],
    'athleticHistory': <Object?>[],
    'athleticAssessments': <Object?>[],
    'onboardingVersionSeen': 1,
    'preferredTrack': 'strength',
    'automaticBackupsEnabled': true,
    'importedWorkouts': <Object?>[],
    'importHistory': <Object?>[],
    'supplementPresets': <Object?>[
      <String, dynamic>{
        'id': 'preset-creatine',
        'name': 'Creatine',
        'brand': '',
        'dose': 5,
        'unit': 'g',
        'caffeineMg': 0,
        'archived': false,
        'createdAt': '2026-08-20T08:00:00.000',
        'updatedAt': '2026-08-20T08:00:00.000',
      },
    ],
    'supplementEvents': <Object?>[
      <String, dynamic>{
        'id': 'supplement-1',
        'presetId': 'preset-creatine',
        'name': 'Creatine',
        'brand': '',
        'dose': 5,
        'unit': 'g',
        'caffeineMg': 0,
        'takenAt': '2026-08-20T08:00:00.000',
        'notes': '',
        'createdAt': '2026-08-20T08:00:00.000',
        'updatedAt': '2026-08-20T08:00:00.000',
      },
    ],
    'mealEvents': <Object?>[
      <String, dynamic>{
        'id': 'meal-1',
        'name': 'Pre-workout meal',
        'occurredAt': '2026-08-20T15:00:00.000',
        'size': 'medium',
        'timing': 'preWorkout',
        'calories': 600,
        'proteinGrams': 40,
        'carbohydrateGrams': 75,
        'fatGrams': 14,
        'notes': '',
        'createdAt': '2026-08-20T15:00:00.000',
        'updatedAt': '2026-08-20T15:00:00.000',
      },
    ],
    'hydrationEvents': <Object?>[
      <String, dynamic>{
        'id': 'water-1',
        'occurredAt': '2026-08-20T14:30:00.000',
        'amountMl': 750,
        'electrolytes': true,
        'notes': '',
        'createdAt': '2026-08-20T14:30:00.000',
        'updatedAt': '2026-08-20T14:30:00.000',
      },
    ],
    'recoveryCheckIns': <Object?>[
      <String, dynamic>{
        'id': 'recovery-1',
        'localDate': '2026-08-20T00:00:00.000',
        'sleepHours': 7.5,
        'sleepQuality': 4,
        'stress': 2,
        'soreness': 2,
        'bodyWeight': 185,
        'weightUnit': 'lb',
        'illness': false,
        'notes': '',
        'createdAt': '2026-08-20T07:00:00.000',
        'updatedAt': '2026-08-20T07:00:00.000',
      },
    ],
    'workoutResponses': <Object?>[
      <String, dynamic>{
        'id': 'response-1',
        'workoutSessionId': 'session-1',
        'track': 'strength',
        'recordedAt': '2026-08-20T18:00:00.000',
        'energy': 4,
        'focus': 5,
        'pump': 4,
        'effort': 4,
        'discomfort': 1,
        'notes': 'Clean session',
        'createdAt': '2026-08-20T18:00:00.000',
        'updatedAt': '2026-08-20T18:00:00.000',
      },
    ],
    'aiAnalysisEnabled': true,
    'labDataDomains': <String>[
      'workouts',
      'supplements',
      'meals',
      'hydration',
      'recovery',
      'bodyMetrics',
      'athletic',
    ],
    'labMessages': <Object?>[
      <String, dynamic>{
        'id': 'message-1',
        'role': 'assistant',
        'text': 'Private analysis',
        'createdAt': '2026-08-20T18:05:00.000',
      },
    ],
  };

  test('exact backup round-trips every current data domain', () {
    final state = sampleState();
    final bytes = ProgressionBackupCodec.encode(
      state,
      createdAt: DateTime.utc(2026, 8, 21, 12),
      reason: 'test',
    );
    final decoded = ProgressionBackupCodec.decode(bytes);

    expect(decoded.state, state);
    expect(decoded.manifest['appSchemaVersion'], AppStore.schemaVersion);
    expect(decoded.manifest['reason'], 'test');
    expect(decoded.state['strengthProgramRun'], 3);
    expect(decoded.state['athleticProgramRun'], 2);
    expect(decoded.state['supplementEvents'], hasLength(1));
    expect(decoded.state['mealEvents'], hasLength(1));
    expect(decoded.state['recoveryCheckIns'], hasLength(1));
    expect(decoded.state['workoutResponses'], hasLength(1));
    expect(decoded.state['labMessages'], hasLength(1));
    expect(decoded.state['customExercises'], hasLength(1));
  });

  test('corrupted backups fail closed', () {
    final bytes = ProgressionBackupCodec.encode(sampleState());
    final corrupted = bytes.toList();
    corrupted[corrupted.length ~/ 2] ^= 0x7f;

    expect(
      () => ProgressionBackupCodec.decode(corrupted),
      throwsA(isA<BackupValidationException>()),
    );
  });

  test('portable export includes current tracking domains and metadata', () {
    final files = ComprehensivePortableExport.portableFiles(sampleState());

    expect(
      files.keys,
      containsAll(<String>[
        'workouts.csv',
        'sets.csv',
        'exercises.csv',
        'supplement_presets.csv',
        'supplement_events.csv',
        'meals.csv',
        'hydration.csv',
        'recovery.csv',
        'body_metrics.csv',
        'workout_responses.csv',
        'lab_preferences.csv',
      ]),
    );

    final exercises = utf8.decode(files['exercises.csv']!);
    expect(exercises, contains('primary_muscle'));
    expect(exercises, contains('tracking_type'));
    expect(exercises, contains('Researcher Offset Row'));
    expect(exercises, contains('Offset Cable Row'));

    final supplements = utf8.decode(files['supplement_events.csv']!);
    expect(supplements, contains('Creatine'));
    expect(supplements, contains('caffeine_mg'));

    final preferences = utf8.decode(files['lab_preferences.csv']!);
    expect(preferences, contains('ai_analysis_enabled'));
    expect(preferences, contains('supplements'));
    expect(preferences, isNot(contains('Private analysis')));
  });

  test(
    'portable ZIP is readable and excludes private Lab conversation text',
    () {
      final bytes = ComprehensivePortableExport.encodePortableCsvZip(
        sampleState(),
      );
      final archive = ZipDecoder().decodeBytes(bytes, verify: true);
      final names = archive.files
          .where((file) => file.isFile)
          .map((file) => file.name);

      expect(names, contains('README.txt'));
      expect(names, contains('supplement_events.csv'));
      expect(names, contains('workout_responses.csv'));
      expect(names, isNot(contains('lab_messages.csv')));
    },
  );
}
