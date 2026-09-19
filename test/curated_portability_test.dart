import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:progression_lab/comprehensive_export.dart';
import 'package:progression_lab/data_portability_core.dart';

List<Map<String, String>> csvRecords(Uint8List bytes) {
  final rows = CsvCodec.decode(utf8.decode(bytes));
  return [
    for (final row in rows.skip(1))
      {
        for (var index = 0; index < rows.first.length; index++)
          rows.first[index]: row[index],
      },
  ];
}

Map<String, dynamic> sampleState() => {
  'schemaVersion': 19,
  'unit': 'kg',
  'workoutHistory': [],
  'importedWorkouts': [],
  'logs': [
    {
      's': 'curated-complete',
      'd': '2026-09-18T09:00:00.000Z',
      'o': 'Superhero · Strength, pull',
      'e': 'Dip',
      'w': 0,
      'r': 8,
      'i': 0,
      'setOrder': 1,
      'sourceApp': 'progression_lab_curated',
      'sourceId': 'curated-complete:step:0',
    },
    {
      's': 'curated-complete',
      'd': '2026-09-18T09:01:00.000Z',
      'o': 'Superhero · Strength, pull',
      'e': 'Row',
      'w': 20,
      'r': 10,
      'i': 1,
      'setOrder': 1,
      'sourceApp': 'progression_lab_curated',
      'sourceId': 'curated-complete:step:1',
    },
    {
      's': 'curated-partial',
      'd': '2026-09-19T09:00:00.000Z',
      'o': 'Superhero · Conditioning',
      'e': 'Rowing',
      'w': 0,
      'r': 0,
      'durationSeconds': 45,
      'i': 0,
      'setOrder': 1,
      'sourceApp': 'progression_lab_curated',
      'sourceId': 'curated-partial:step:0',
    },
  ],
  'curatedTraining': {
    'progress': {
      'superhero': {'completedSessions': 5, 'run': 1},
    },
    'drafts': {
      'martial-arts': {
        'programId': 'martial-arts',
        'sessionId': 'curated-active',
        'week': 1,
        'dayIndex': 0,
        'run': 1,
        'startedAt': '2026-09-19T10:00:00.000Z',
        'nextStepIndex': 0,
        'inputs': {'reps': '12', 'notes': 'Resume this set'},
        'restEndsAt': '2026-09-19T10:01:00.000Z',
        'day': {
          'title': 'Saved prescription',
          'notes': 'An immutable session snapshot',
          'movements': [
            {
              'name': 'Push-up',
              'metric': 'reps',
              'restSeconds': 60,
              'instructions': '',
              'group': null,
              'targets': [
                {'reps': '8–12', 'seconds': null, 'meters': null, 'note': ''},
              ],
            },
          ],
        },
      },
    },
    'history': [
      {
        'programId': 'superhero',
        'sessionId': 'curated-complete',
        'week': 1,
        'dayIndex': 3,
        'run': 1,
        'title': 'Strength, pull',
        'startedAt': '2026-09-18T09:00:00.000Z',
        'completedAt': '2026-09-18T09:30:00.000Z',
        'status': 'completed',
        'setCount': 2,
        'totalSteps': 2,
      },
      {
        'programId': 'superhero',
        'sessionId': 'curated-partial',
        'week': 1,
        'dayIndex': 4,
        'run': 1,
        'title': 'Conditioning',
        'startedAt': '2026-09-19T09:00:00.000Z',
        'completedAt': '2026-09-19T09:10:00.000Z',
        'status': 'partial',
        'setCount': 1,
        'totalSteps': 3,
      },
    ],
  },
};

void main() {
  test(
    'exact backup retains curated snapshots, inputs, history and release version',
    () {
      final state = sampleState();
      final backup = ProgressionBackupCodec.decode(
        ProgressionBackupCodec.encode(state),
      );

      expect(backup.state, state);
      expect(backup.manifest['appVersion'], progressionAppVersion);
      final curated = jsonDecode(
        utf8.decode(backup.files['curated_training.json']!),
      );
      expect(curated, state['curatedTraining']);
      final grouped =
          jsonDecode(utf8.decode(backup.files['workouts.json']!)) as Map;
      expect(
        grouped['curatedHistory'],
        (state['curatedTraining'] as Map)['history'],
      );
    },
  );

  test(
    'portable sessions link actual sets and preserve partial status without placeholders',
    () {
      final files = ProgressionCsvExport.portableFiles(sampleState());
      final workouts = csvRecords(files['workouts.csv']!);
      final sets = csvRecords(files['sets.csv']!);

      expect(workouts, hasLength(2));
      expect(workouts.first['workout_name'], 'Strength, pull');
      expect(workouts.first['started_at'], '2026-09-18T09:00:00.000Z');
      expect(workouts.first['duration_seconds'], '1800');
      expect(workouts.last['duration_seconds'], '600');
      expect(workouts.last['notes'], contains('partial'));
      expect(workouts.last['notes'], contains('1/3 sets'));
      expect(workouts.map((e) => e['source_app']).toSet(), {
        'progression_lab_curated',
      });
      expect(sets, hasLength(3));
      expect(sets.map((e) => e['source_id']).toSet(), hasLength(3));
      expect(sets.first['weight'], '0');
      expect(sets.first['reps'], '8');
      expect(sets.last['duration_seconds'], '45');
      expect(
        sets.map((e) => e['workout_id']).toSet(),
        workouts.map((e) => e['session_id']).toSet(),
      );
    },
  );

  test(
    'comprehensive export includes finished-day progress and active first session',
    () {
      final files = ComprehensivePortableExport.portableFiles(sampleState());
      final progress = csvRecords(files['curated_progress.csv']!);
      final history = csvRecords(files['curated_history.csv']!);
      final nextWeek = progress.singleWhere(
        (e) => e['program_id'] == 'superhero',
      );
      final active = progress.singleWhere(
        (e) => e['program_id'] == 'martial-arts',
      );

      expect(nextWeek['finished_sessions'], '5');
      expect(nextWeek['next_week'], '2');
      expect(nextWeek['next_day'], '1');
      expect(nextWeek['active_session_id'], isEmpty);
      expect(active['next_week'], '1');
      expect(active['next_day'], '1');
      expect(active['active_session_id'], 'curated-active');
      expect(active['active_step_index'], '0');
      expect(history, hasLength(2));
      expect(history.last['day'], '5');
      expect(history.last['status'], 'partial');
      expect(history.last['logged_sets'], '1');
      expect(history.last['planned_sets'], '3');
    },
  );

  test('states predating curated programs still export and back up', () {
    final state = sampleState()..remove('curatedTraining');
    final files = ComprehensivePortableExport.portableFiles(state);
    expect(csvRecords(files['curated_progress.csv']!), isEmpty);
    expect(csvRecords(files['curated_history.csv']!), isEmpty);
    final backup = ProgressionBackupCodec.decode(
      ProgressionBackupCodec.encode(state),
    );
    expect(backup.state, state);
    expect(
      jsonDecode(utf8.decode(backup.files['curated_training.json']!)),
      isEmpty,
    );
  });
}
