import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';

const String progressionBackupFormat = 'progression-lab-backup';
const int progressionBackupSchemaVersion = 1;
const String progressionAppVersion = '1.6.0';
const int _maxBackupFiles = 64;
const int _maxBackupUncompressedBytes = 128 * 1024 * 1024;

String sha256Hex(List<int> bytes) => sha256.convert(bytes).toString();

class BackupValidationException implements Exception {
  const BackupValidationException(this.message);

  final String message;

  @override
  String toString() => message;
}

class PortableBackupDocument {
  const PortableBackupDocument({
    required this.manifest,
    required this.state,
    required this.files,
  });

  final Map<String, dynamic> manifest;
  final Map<String, dynamic> state;
  final Map<String, Uint8List> files;

  DateTime get createdAt {
    final value = manifest['createdAt'];
    return value is String
        ? DateTime.tryParse(value) ?? DateTime.fromMillisecondsSinceEpoch(0)
        : DateTime.fromMillisecondsSinceEpoch(0);
  }
}

abstract final class ProgressionBackupCodec {
  static Uint8List encode(
    Map<String, dynamic> state, {
    DateTime? createdAt,
    String reason = 'manual',
  }) {
    final timestamp = (createdAt ?? DateTime.now()).toUtc();
    final payload = <String, Uint8List>{
      'state.json': _jsonBytes(state),
      'workouts.json': _jsonBytes({
        'strengthHistory': _listValue(state['workoutHistory']),
        'importedWorkouts': _listValue(state['importedWorkouts']),
      }),
      'sets.json': _jsonBytes(_listValue(state['logs'])),
      'exercises.json': _jsonBytes(_listValue(state['customExercises'])),
      'program_state.json': _jsonBytes({
        'days': state['days'],
        'week': state['week'],
        'workout': state['workout'],
        'programStartDate': state['programStartDate'],
        'draft': state['draft'],
        'drafts': _listValue(state['drafts']),
        'athleticProgramRun': state['athleticProgramRun'],
        'athleticWeek': state['athleticWeek'],
        'athleticSessionIndex': state['athleticSessionIndex'],
        'athleticStartDate': state['athleticStartDate'],
      }),
      'athletic_history.json': _jsonBytes(
        _listValue(state['athleticHistory']),
      ),
      'assessments.json': _jsonBytes(
        _listValue(state['athleticAssessments']),
      ),
      'settings.json': _jsonBytes({
        'unit': state['unit'],
        'preferredTrack': state['preferredTrack'],
        'onboardingVersionSeen': state['onboardingVersionSeen'],
        'automaticBackupsEnabled': state['automaticBackupsEnabled'],
      }),
      'import_history.json': _jsonBytes(
        _listValue(state['importHistory']),
      ),
      ...ProgressionCsvExport.portableFiles(state),
    };
    final contents = payload.keys.toList()..sort();
    final checksums = {
      for (final name in contents) name: sha256Hex(payload[name]!),
    };
    final manifest = <String, dynamic>{
      'format': progressionBackupFormat,
      'schemaVersion': progressionBackupSchemaVersion,
      'appVersion': progressionAppVersion,
      'appSchemaVersion': state['schemaVersion'],
      'createdAt': timestamp.toIso8601String(),
      'reason': reason,
      'unitSystem': state['unit'] == 'kg' ? 'kg' : 'lb',
      'contents': contents,
    };

    final archive = Archive();
    _addArchiveFile(archive, 'manifest.json', _jsonBytes(manifest));
    _addArchiveFile(archive, 'checksums.json', _jsonBytes(checksums));
    for (final name in contents) {
      _addArchiveFile(archive, name, payload[name]!);
    }
    final encoded = ZipEncoder().encode(archive);
    if (encoded == null || encoded.isEmpty) {
      throw const BackupValidationException('Could not encode the backup.');
    }
    return Uint8List.fromList(encoded);
  }

  static PortableBackupDocument decode(List<int> bytes) {
    if (bytes.isEmpty) {
      throw const BackupValidationException('The selected backup is empty.');
    }
    Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes, verify: true);
    } on Object {
      throw const BackupValidationException(
        'This file is not a valid Progression Lab backup.',
      );
    }
    if (archive.length > _maxBackupFiles) {
      throw const BackupValidationException(
        'The backup contains too many files.',
      );
    }

    final files = <String, Uint8List>{};
    var totalUncompressed = 0;
    for (final file in archive) {
      if (!file.isFile) continue;
      final name = file.name.replaceAll('\\', '/');
      if (name.isEmpty ||
          name.startsWith('/') ||
          name.split('/').contains('..') ||
          files.containsKey(name)) {
        throw const BackupValidationException(
          'The backup contains an unsafe or duplicate file name.',
        );
      }
      totalUncompressed += file.size;
      if (totalUncompressed > _maxBackupUncompressedBytes) {
        throw const BackupValidationException(
          'The expanded backup is larger than 128 MB.',
        );
      }
      final content = file.content;
      if (content is Uint8List) {
        files[name] = content;
      } else if (content is List<int>) {
        files[name] = Uint8List.fromList(content);
      } else {
        throw BackupValidationException('$name could not be decoded.');
      }
    }

    final manifest = _jsonMap(files['manifest.json'], 'manifest.json');
    if (manifest['format'] != progressionBackupFormat) {
      throw const BackupValidationException(
        'The selected file is not a Progression Lab backup.',
      );
    }
    final schema = _readInt(manifest['schemaVersion']);
    if (schema == null || schema < 1 || schema > progressionBackupSchemaVersion) {
      throw BackupValidationException(
        'Backup schema ${manifest['schemaVersion']} is not supported.',
      );
    }
    final contentNames = _stringList(manifest['contents']);
    if (contentNames.isEmpty || !contentNames.contains('state.json')) {
      throw const BackupValidationException(
        'The backup manifest does not include state.json.',
      );
    }
    if (contentNames.length != contentNames.toSet().length) {
      throw const BackupValidationException(
        'The backup manifest contains duplicate file names.',
      );
    }

    final checksums = _jsonMap(files['checksums.json'], 'checksums.json');
    for (final name in contentNames) {
      final expected = checksums[name];
      final fileBytes = files[name];
      if (expected is! String || fileBytes == null) {
        throw BackupValidationException('The backup is missing $name.');
      }
      if (sha256Hex(fileBytes) != expected) {
        throw BackupValidationException(
          'The checksum for $name does not match.',
        );
      }
    }
    if (checksums.keys.any((name) => !contentNames.contains(name))) {
      throw const BackupValidationException(
        'The checksum index does not match the backup manifest.',
      );
    }
    final expectedFiles = {
      'manifest.json',
      'checksums.json',
      ...contentNames,
    };
    if (files.keys.any((name) => !expectedFiles.contains(name))) {
      throw const BackupValidationException(
        'The backup contains files that are not indexed by its manifest.',
      );
    }

    final state = _jsonMap(files['state.json'], 'state.json');
    final appSchema = _readInt(state['schemaVersion']);
    if (appSchema == null || appSchema < 1) {
      throw const BackupValidationException(
        'The backup does not contain a valid app schema version.',
      );
    }
    final manifestAppSchema = _readInt(manifest['appSchemaVersion']);
    if (manifestAppSchema != null && manifestAppSchema != appSchema) {
      throw const BackupValidationException(
        'The backup manifest and app state schema do not match.',
      );
    }
    return PortableBackupDocument(
      manifest: manifest,
      state: state,
      files: Map.unmodifiable(files),
    );
  }

  static Uint8List _jsonBytes(Object? value) => Uint8List.fromList(
    utf8.encode(const JsonEncoder.withIndent('  ').convert(value)),
  );

  static void _addArchiveFile(
    Archive archive,
    String name,
    Uint8List bytes,
  ) {
    archive.addFile(ArchiveFile(name, bytes.length, bytes));
  }

  static Map<String, dynamic> _jsonMap(Uint8List? bytes, String name) {
    if (bytes == null) {
      throw BackupValidationException('The backup is missing $name.');
    }
    try {
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } on Object {
      // Use one stable, actionable validation error.
    }
    throw BackupValidationException('$name is not valid JSON.');
  }

  static List<Object?> _listValue(Object? value) =>
      value is List ? List<Object?>.from(value) : const <Object?>[];
}

class CsvCodec {
  const CsvCodec._();

  static String encode(List<List<Object?>> rows) {
    final buffer = StringBuffer();
    for (final row in rows) {
      for (var index = 0; index < row.length; index++) {
        if (index > 0) buffer.write(',');
        final value = row[index]?.toString() ?? '';
        final escaped = value.replaceAll('"', '""');
        if (value.contains(',') ||
            value.contains('"') ||
            value.contains('\n') ||
            value.contains('\r')) {
          buffer
            ..write('"')
            ..write(escaped)
            ..write('"');
        } else {
          buffer.write(value);
        }
      }
      buffer.write('\r\n');
    }
    return buffer.toString();
  }

  static List<List<String>> decode(String input) {
    final rows = <List<String>>[];
    var row = <String>[];
    final cell = StringBuffer();
    var quoted = false;
    var index = 0;
    while (index < input.length) {
      final char = input[index];
      if (quoted) {
        if (char == '"') {
          if (index + 1 < input.length && input[index + 1] == '"') {
            cell.write('"');
            index += 2;
            continue;
          }
          quoted = false;
          index++;
          continue;
        }
        cell.write(char);
        index++;
        continue;
      }
      if (char == '"' && cell.isEmpty) {
        quoted = true;
      } else if (char == ',') {
        row.add(cell.toString());
        cell.clear();
      } else if (char == '\n' || char == '\r') {
        row.add(cell.toString());
        cell.clear();
        if (row.any((value) => value.isNotEmpty)) rows.add(row);
        row = <String>[];
        if (char == '\r' &&
            index + 1 < input.length &&
            input[index + 1] == '\n') {
          index++;
        }
      } else {
        cell.write(char);
      }
      index++;
    }
    if (quoted) {
      throw const FormatException('CSV contains an unterminated quote.');
    }
    if (cell.isNotEmpty || row.isNotEmpty) {
      row.add(cell.toString());
      if (row.any((value) => value.isNotEmpty)) rows.add(row);
    }
    return rows;
  }
}

enum WorkoutImportSource { strong, hevy, fitNotes, progressionLab, generic }

extension WorkoutImportSourceLabel on WorkoutImportSource {
  String get label => switch (this) {
    WorkoutImportSource.strong => 'Strong',
    WorkoutImportSource.hevy => 'Hevy',
    WorkoutImportSource.fitNotes => 'FitNotes',
    WorkoutImportSource.progressionLab => 'Progression Lab CSV',
    WorkoutImportSource.generic => 'Generic CSV',
  };
}

class CsvImportMapping {
  const CsvImportMapping({
    required this.date,
    required this.exercise,
    required this.reps,
    this.endDate,
    this.workout,
    this.setOrder,
    this.weight,
    this.alternateWeight,
    this.weightUnit,
    this.notes,
    this.workoutNotes,
    this.workoutDuration,
    this.setDuration,
    this.distance,
    this.distanceUnit,
    this.setType,
    this.rpe,
    this.rir,
    this.supersetId,
    this.sourceId,
  });

  final String date;
  final String exercise;
  final String reps;
  final String? endDate;
  final String? workout;
  final String? setOrder;
  final String? weight;
  final String? alternateWeight;
  final String? weightUnit;
  final String? notes;
  final String? workoutNotes;
  final String? workoutDuration;
  final String? setDuration;
  final String? distance;
  final String? distanceUnit;
  final String? setType;
  final String? rpe;
  final String? rir;
  final String? supersetId;
  final String? sourceId;

  bool get isComplete =>
      date.isNotEmpty && exercise.isNotEmpty && reps.isNotEmpty;
}

class CsvInspection {
  const CsvInspection({
    required this.headers,
    required this.rows,
    required this.source,
    required this.suggestedMapping,
  });

  final List<String> headers;
  final List<Map<String, String>> rows;
  final WorkoutImportSource source;
  final CsvImportMapping? suggestedMapping;
}

class ImportSetDraft {
  const ImportSetDraft({
    required this.exercise,
    required this.weight,
    required this.canonicalWeightKilograms,
    required this.reps,
    required this.setOrder,
    required this.sequence,
    this.notes = '',
    this.setType = 'normal',
    this.rpe,
    this.rir,
    this.durationSeconds,
    this.distanceMeters,
    this.supersetId,
  });

  final String exercise;
  final double weight;
  final double canonicalWeightKilograms;
  final int reps;
  final int setOrder;
  final int sequence;
  final String notes;
  final String setType;
  final double? rpe;
  final double? rir;
  final int? durationSeconds;
  final double? distanceMeters;
  final String? supersetId;
}

class ImportWorkoutDraft {
  const ImportWorkoutDraft({
    required this.source,
    required this.sourceId,
    required this.name,
    required this.startedAt,
    required this.sourceTimestamp,
    required this.sets,
    required this.signature,
    this.durationSeconds,
    this.notes = '',
  });

  final WorkoutImportSource source;
  final String? sourceId;
  final String name;
  final DateTime startedAt;
  final String sourceTimestamp;
  final List<ImportSetDraft> sets;
  final String signature;
  final int? durationSeconds;
  final String notes;
}

class WorkoutImportPlan {
  const WorkoutImportPlan({
    required this.source,
    required this.fileName,
    required this.fileHash,
    required this.sourceWeightUnit,
    required this.workouts,
    required this.duplicateSignatures,
    required this.unknownExercises,
    required this.invalidRows,
  });

  final WorkoutImportSource source;
  final String fileName;
  final String fileHash;
  final String sourceWeightUnit;
  final List<ImportWorkoutDraft> workouts;
  final Set<String> duplicateSignatures;
  final Set<String> unknownExercises;
  final int invalidRows;

  int get setCount => workouts.fold(0, (sum, item) => sum + item.sets.length);
  int get duplicateCount => workouts
      .where((workout) => duplicateSignatures.contains(workout.signature))
      .length;
  int get importableCount => workouts.length - duplicateCount;
}

abstract final class WorkoutCsvImporter {
  static const _dateAliases = <String>[
    'date',
    'workout date',
    'start time',
    'start_time',
    'started at',
    'started_at',
    'timestamp',
  ];
  static const _endDateAliases = <String>[
    'end time',
    'end_time',
    'ended at',
    'ended_at',
  ];
  static const _workoutAliases = <String>[
    'workout name',
    'workout_name',
    'workout',
    'title',
    'routine',
    'session',
    'category',
  ];
  static const _exerciseAliases = <String>[
    'exercise name',
    'exercise_name',
    'exercise',
    'exercise title',
    'exercise_title',
    'movement',
  ];
  static const _setAliases = <String>[
    'set order',
    'set_order',
    'set',
    'set index',
    'set_index',
    'set number',
  ];
  static const _weightAliases = <String>[
    'weight',
    'weight lbs',
    'weight_lbs',
    'weight kg',
    'weight_kg',
    'weight (kg)',
    'weight (lbs)',
    'weight(kg)',
    'weight(lbs)',
    'load',
  ];
  static const _repsAliases = <String>[
    'reps',
    'repetitions',
    'rep count',
  ];
  static const _unitAliases = <String>[
    'weight unit',
    'weight_unit',
    'unit',
  ];
  static const _notesAliases = <String>[
    'notes',
    'note',
    'exercise notes',
    'exercise_notes',
    'comment',
  ];
  static const _workoutNotesAliases = <String>[
    'workout notes',
    'workout_notes',
    'description',
  ];
  static const _workoutDurationAliases = <String>[
    'workout duration',
    'workout_duration',
    'duration',
  ];
  static const _setDurationAliases = <String>[
    'duration seconds',
    'duration_seconds',
    'seconds',
    'time',
  ];
  static const _distanceAliases = <String>[
    'distance',
    'distance meters',
    'distance_meters',
    'distance m',
    'distance_m',
    'distance miles',
    'distance_miles',
    'distance km',
    'distance_km',
  ];
  static const _distanceUnitAliases = <String>[
    'distance unit',
    'distance_unit',
  ];
  static const _setTypeAliases = <String>[
    'set type',
    'set_type',
  ];
  static const _rpeAliases = <String>['rpe'];
  static const _rirAliases = <String>['rir', 'reps in reserve'];
  static const _supersetAliases = <String>['superset id', 'superset_id'];
  static const _sourceIdAliases = <String>[
    'workout id',
    'workout_id',
    'source id',
    'source_id',
    'id',
  ];

  static CsvInspection inspect(Uint8List bytes) {
    String text;
    try {
      text = utf8.decode(bytes, allowMalformed: false);
    } on Object {
      throw const FormatException('The selected CSV is not UTF-8 text.');
    }
    final decoded = CsvCodec.decode(text);
    if (decoded.length < 2) {
      throw const FormatException('The CSV does not contain workout rows.');
    }
    final headers = decoded.first
        .map((value) => value.trim().replaceFirst('\ufeff', ''))
        .toList();
    if (headers.every((value) => value.isEmpty)) {
      throw const FormatException('The CSV header row is empty.');
    }
    final rows = <Map<String, String>>[];
    for (final values in decoded.skip(1)) {
      final row = <String, String>{};
      for (var index = 0; index < headers.length; index++) {
        row[headers[index]] = index < values.length ? values[index].trim() : '';
      }
      if (row.values.any((value) => value.isNotEmpty)) rows.add(row);
    }
    if (rows.isEmpty) {
      throw const FormatException('The CSV does not contain workout rows.');
    }
    final normalized = {
      for (final header in headers) _normalize(header): header,
    };
    final source = _detectSource(normalized.keys.toSet());
    return CsvInspection(
      headers: headers,
      rows: rows,
      source: source,
      suggestedMapping: _suggestMapping(normalized, source),
    );
  }

  static CsvInspection inspectPortableZip(Uint8List bytes) {
    Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes, verify: true);
    } on Object {
      throw const FormatException('The selected ZIP could not be opened.');
    }
    for (final file in archive) {
      if (!file.isFile || file.name.split('/').last != 'sets.csv') continue;
      final content = file.content;
      if (content is Uint8List) return inspect(content);
      if (content is List<int>) return inspect(Uint8List.fromList(content));
    }
    throw const FormatException(
      'The ZIP does not contain a portable sets.csv file.',
    );
  }

  static bool needsWeightUnitChoice(
    WorkoutImportSource source,
    CsvImportMapping mapping,
  ) {
    if (mapping.weight == null && mapping.alternateWeight == null) return false;
    if (mapping.weightUnit != null) return false;
    if (_unitFromHeader(mapping.weight) != null ||
        _unitFromHeader(mapping.alternateWeight) != null) {
      return false;
    }
    return source == WorkoutImportSource.strong ||
        source == WorkoutImportSource.generic;
  }

  static WorkoutImportPlan buildPlan({
    required CsvInspection inspection,
    required CsvImportMapping mapping,
    required String fileName,
    required Uint8List fileBytes,
    required String targetUnit,
    required String defaultSourceWeightUnit,
    required Set<String> knownSignatures,
    required Set<String> knownExercises,
  }) {
    if (!mapping.isComplete) {
      throw const FormatException(
        'Date, exercise, and repetitions must be mapped.',
      );
    }
    final normalizedSourceUnit = defaultSourceWeightUnit == 'kg' ? 'kg' : 'lb';
    final grouped = <String, _MutableImportWorkout>{};
    var invalidRows = 0;
    for (var rowIndex = 0; rowIndex < inspection.rows.length; rowIndex++) {
      final row = inspection.rows[rowIndex];
      final sourceTimestamp = (row[mapping.date] ?? '').trim();
      final date = _parseDate(sourceTimestamp);
      final exercise = (row[mapping.exercise] ?? '').trim();
      final setDuration = _parseDurationSeconds(
        _value(row, mapping.setDuration),
      );
      final distanceMeters = _parseDistanceMeters(
        raw: _value(row, mapping.distance),
        unitRaw: _value(row, mapping.distanceUnit),
        header: mapping.distance,
      );
      final parsedReps = _parseInt(row[mapping.reps]);
      final reps = parsedReps ?? 0;
      if (date == null ||
          exercise.isEmpty ||
          reps < 0 ||
          (reps == 0 && setDuration == null && distanceMeters == null)) {
        invalidRows++;
        continue;
      }

      final workoutName = _value(row, mapping.workout).trim().isEmpty
          ? 'Imported Workout'
          : _value(row, mapping.workout).trim();
      final sourceId = _value(row, mapping.sourceId).trim();
      final key = sourceId.isNotEmpty
          ? 'id:$sourceId'
          : '${date.toUtc().toIso8601String()}|${workoutName.toLowerCase()}';
      final endDate = _parseDate(_value(row, mapping.endDate));
      final parsedWorkoutDuration = _parseDurationSeconds(
        _value(row, mapping.workoutDuration),
      );
      final derivedWorkoutDuration = endDate != null && endDate.isAfter(date)
          ? endDate.difference(date).inSeconds
          : null;
      final mutable = grouped.putIfAbsent(
        key,
        () => _MutableImportWorkout(
          sourceId: sourceId.isEmpty ? null : sourceId,
          name: workoutName,
          startedAt: date,
          sourceTimestamp: sourceTimestamp,
          durationSeconds: parsedWorkoutDuration ?? derivedWorkoutDuration,
          notes: _value(row, mapping.workoutNotes),
        ),
      );

      final parsedWeight = _parseWeight(
        row: row,
        mapping: mapping,
        targetUnit: targetUnit,
        defaultSourceWeightUnit: normalizedSourceUnit,
      );
      final rawOrder = _parseInt(_value(row, mapping.setOrder));
      final fallbackOrder = mutable.nextSetOrder(exercise);
      final setOrder = rawOrder == null
          ? fallbackOrder
          : inspection.source == WorkoutImportSource.hevy
          ? rawOrder + 1
          : rawOrder.clamp(1, 1000000).toInt();
      mutable.sets.add(
        ImportSetDraft(
          exercise: exercise,
          weight: parsedWeight.targetValue,
          canonicalWeightKilograms: parsedWeight.kilograms,
          reps: reps,
          setOrder: setOrder,
          sequence: rowIndex,
          notes: _value(row, mapping.notes),
          setType: _canonicalSetType(_value(row, mapping.setType)),
          rpe: _boundedDouble(_value(row, mapping.rpe), 0, 10),
          rir: _boundedDouble(_value(row, mapping.rir), 0, 20),
          durationSeconds: setDuration,
          distanceMeters: distanceMeters,
          supersetId: _nullableText(_value(row, mapping.supersetId)),
        ),
      );
    }

    final workouts = <ImportWorkoutDraft>[];
    final unknownExercises = <String>{};
    final normalizedKnown = knownExercises.map(_normalizeExercise).toSet();
    for (final mutable in grouped.values) {
      mutable.sets.sort((a, b) => a.sequence.compareTo(b.sequence));
      if (mutable.sets.isEmpty) continue;
      final signature = workoutSignature(
        name: mutable.name,
        startedAt: mutable.startedAt,
        sets: mutable.sets,
      );
      for (final set in mutable.sets) {
        if (!normalizedKnown.contains(_normalizeExercise(set.exercise))) {
          unknownExercises.add(set.exercise);
        }
      }
      workouts.add(
        ImportWorkoutDraft(
          source: inspection.source,
          sourceId: mutable.sourceId,
          name: mutable.name,
          startedAt: mutable.startedAt,
          sourceTimestamp: mutable.sourceTimestamp,
          durationSeconds: mutable.durationSeconds,
          notes: mutable.notes,
          sets: List.unmodifiable(mutable.sets),
          signature: signature,
        ),
      );
    }
    workouts.sort((a, b) => a.startedAt.compareTo(b.startedAt));
    return WorkoutImportPlan(
      source: inspection.source,
      fileName: fileName,
      fileHash: sha256Hex(fileBytes),
      sourceWeightUnit: normalizedSourceUnit,
      workouts: List.unmodifiable(workouts),
      duplicateSignatures: {
        for (final workout in workouts)
          if (knownSignatures.contains(workout.signature)) workout.signature,
      },
      unknownExercises: Set.unmodifiable(unknownExercises),
      invalidRows: invalidRows,
    );
  }

  static String workoutSignature({
    required String name,
    required DateTime startedAt,
    required List<ImportSetDraft> sets,
  }) {
    final minute = startedAt.toUtc().millisecondsSinceEpoch ~/ 60000;
    final buffer = StringBuffer('${_normalize(name)}|$minute');
    for (final set in sets) {
      buffer
        ..write('|')
        ..write(_normalizeExercise(set.exercise))
        ..write('#')
        ..write(set.setOrder)
        ..write(':')
        ..write(set.canonicalWeightKilograms.toStringAsFixed(5))
        ..write('x')
        ..write(set.reps)
        ..write('@')
        ..write(set.durationSeconds ?? 0)
        ..write('/')
        ..write(set.distanceMeters?.toStringAsFixed(3) ?? '0');
    }
    return sha256Hex(utf8.encode(buffer.toString()));
  }

  static WorkoutImportSource _detectSource(Set<String> headers) {
    if (headers.contains('start time') ||
        headers.contains('exercise title') ||
        headers.contains('set index')) {
      return WorkoutImportSource.hevy;
    }
    if (headers.contains('kind') &&
        headers.contains('exercise') &&
        (headers.contains('weight (kg)') ||
            headers.contains('weight (lbs)'))) {
      return WorkoutImportSource.fitNotes;
    }
    if (headers.contains('workout name') &&
        headers.contains('exercise name') &&
        headers.contains('set order')) {
      return WorkoutImportSource.strong;
    }
    if (headers.contains('workout id') &&
        headers.contains('import batch id') &&
        headers.contains('source app')) {
      return WorkoutImportSource.progressionLab;
    }
    return WorkoutImportSource.generic;
  }

  static CsvImportMapping? _suggestMapping(
    Map<String, String> normalized,
    WorkoutImportSource source,
  ) {
    String? find(List<String> aliases) {
      for (final alias in aliases) {
        final match = normalized[_normalize(alias)];
        if (match != null) return match;
      }
      return null;
    }

    final date = find(_dateAliases);
    final exercise = find(_exerciseAliases);
    final reps = find(_repsAliases);
    if (date == null || exercise == null || reps == null) return null;

    final weightKg = normalized[_normalize('Weight (kg)')];
    final weightLb = normalized[_normalize('Weight (lbs)')];
    final hevyKg = normalized[_normalize('weight_kg')];
    final hevyLb = normalized[_normalize('weight_lbs')];
    return CsvImportMapping(
      date: date,
      exercise: exercise,
      reps: reps,
      endDate: find(_endDateAliases),
      workout: find(_workoutAliases),
      setOrder: find(_setAliases),
      weight: switch (source) {
        WorkoutImportSource.fitNotes => weightKg ?? weightLb,
        WorkoutImportSource.hevy => hevyKg ?? hevyLb,
        _ => find(_weightAliases),
      },
      alternateWeight: source == WorkoutImportSource.fitNotes
          ? weightKg != null
                ? weightLb
                : weightKg
          : null,
      weightUnit: find(_unitAliases),
      notes: find(_notesAliases),
      workoutNotes: find(_workoutNotesAliases),
      workoutDuration: source == WorkoutImportSource.strong
          ? find(_workoutDurationAliases)
          : null,
      setDuration: find(_setDurationAliases),
      distance: find(_distanceAliases),
      distanceUnit: find(_distanceUnitAliases),
      setType: find(_setTypeAliases),
      rpe: find(_rpeAliases),
      rir: find(_rirAliases),
      supersetId: find(_supersetAliases),
      sourceId: find(_sourceIdAliases),
    );
  }

  static _ParsedWeight _parseWeight({
    required Map<String, String> row,
    required CsvImportMapping mapping,
    required String targetUnit,
    required String defaultSourceWeightUnit,
  }) {
    final primary = _parseDouble(_value(row, mapping.weight));
    final alternate = _parseDouble(_value(row, mapping.alternateWeight));
    final value = primary ?? alternate ?? 0;
    final selectedHeader = primary != null
        ? mapping.weight
        : alternate != null
        ? mapping.alternateWeight
        : mapping.weight ?? mapping.alternateWeight;
    final explicit = _value(row, mapping.weightUnit).toLowerCase();
    final sourceUnit = explicit.contains('kg') ||
            explicit.contains('kilogram')
        ? 'kg'
        : explicit.contains('lb') || explicit.contains('pound')
        ? 'lb'
        : _unitFromHeader(selectedHeader) ?? defaultSourceWeightUnit;
    final kilograms = sourceUnit == 'kg' ? value : value * 0.45359237;
    final targetValue = targetUnit == 'kg'
        ? kilograms
        : kilograms / 0.45359237;
    return _ParsedWeight(targetValue: targetValue, kilograms: kilograms);
  }

  static String? _unitFromHeader(String? header) {
    final value = header?.toLowerCase() ?? '';
    if (value.contains('kg') || value.contains('kilogram')) return 'kg';
    if (value.contains('lb') || value.contains('pound')) return 'lb';
    return null;
  }

  static DateTime? _parseDate(String? raw) {
    final value = raw?.trim();
    if (value == null || value.isEmpty) return null;
    final direct = DateTime.tryParse(value);
    if (direct != null) return direct;

    final named = RegExp(
      r'^(\d{1,2})\s+([A-Za-z]{3,9})\s+(\d{4})(?:,?\s+(\d{1,2}):(\d{2})(?::(\d{2}))?)?$',
    ).firstMatch(value);
    if (named != null) {
      final month = _monthNumber(named.group(2)!);
      if (month != null) {
        return DateTime(
          int.parse(named.group(3)!),
          month,
          int.parse(named.group(1)!),
          int.tryParse(named.group(4) ?? '') ?? 0,
          int.tryParse(named.group(5) ?? '') ?? 0,
          int.tryParse(named.group(6) ?? '') ?? 0,
        );
      }
    }

    final numeric = RegExp(
      r'^(\d{1,2})[/-](\d{1,2})[/-](\d{2,4})(?:[ T](\d{1,2}):(\d{2})(?::(\d{2}))?(?:\s*(AM|PM))?)?$',
      caseSensitive: false,
    ).firstMatch(value);
    if (numeric == null) return null;
    var first = int.parse(numeric.group(1)!);
    var second = int.parse(numeric.group(2)!);
    var year = int.parse(numeric.group(3)!);
    if (year < 100) year += year >= 70 ? 1900 : 2000;
    var month = first;
    var day = second;
    if (first > 12 && second <= 12) {
      day = first;
      month = second;
    }
    var hour = int.tryParse(numeric.group(4) ?? '') ?? 0;
    final minute = int.tryParse(numeric.group(5) ?? '') ?? 0;
    final secondValue = int.tryParse(numeric.group(6) ?? '') ?? 0;
    final meridiem = numeric.group(7)?.toUpperCase();
    if (meridiem == 'PM' && hour < 12) hour += 12;
    if (meridiem == 'AM' && hour == 12) hour = 0;
    try {
      return DateTime(year, month, day, hour, minute, secondValue);
    } on Object {
      return null;
    }
  }

  static int? _monthNumber(String raw) {
    const months = <String, int>{
      'jan': 1,
      'january': 1,
      'feb': 2,
      'february': 2,
      'mar': 3,
      'march': 3,
      'apr': 4,
      'april': 4,
      'may': 5,
      'jun': 6,
      'june': 6,
      'jul': 7,
      'july': 7,
      'aug': 8,
      'august': 8,
      'sep': 9,
      'sept': 9,
      'september': 9,
      'oct': 10,
      'october': 10,
      'nov': 11,
      'november': 11,
      'dec': 12,
      'december': 12,
    };
    return months[raw.toLowerCase()];
  }

  static int? _parseDurationSeconds(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return null;
    final direct = _parseInt(value);
    if (direct != null && !value.contains(':')) return direct;
    final parts = value.split(':').map(int.tryParse).toList();
    if (parts.length > 1 && parts.every((item) => item != null)) {
      if (parts.length == 2) return parts[0]! * 60 + parts[1]!;
      if (parts.length == 3) {
        return parts[0]! * 3600 + parts[1]! * 60 + parts[2]!;
      }
    }
    final tokenPattern = RegExp(
      r'(?:(\d+)\s*h)?\s*(?:(\d+)\s*m)?\s*(?:(\d+)\s*s)?$',
      caseSensitive: false,
    ).firstMatch(value);
    if (tokenPattern == null || tokenPattern.group(0)!.trim().isEmpty) {
      return null;
    }
    final hours = int.tryParse(tokenPattern.group(1) ?? '') ?? 0;
    final minutes = int.tryParse(tokenPattern.group(2) ?? '') ?? 0;
    final seconds = int.tryParse(tokenPattern.group(3) ?? '') ?? 0;
    final total = hours * 3600 + minutes * 60 + seconds;
    return total > 0 ? total : null;
  }

  static double? _parseDistanceMeters({
    required String raw,
    required String unitRaw,
    required String? header,
  }) {
    final value = _parseDouble(raw);
    if (value == null) return null;
    final normalizedUnit = unitRaw.trim().toLowerCase().isNotEmpty
        ? unitRaw.trim().toLowerCase()
        : _distanceUnitFromHeader(header);
    final factor = switch (normalizedUnit) {
      'm' || 'meter' || 'meters' || 'metre' || 'metres' => 1.0,
      'km' || 'kilometer' || 'kilometers' || 'kilometre' || 'kilometres' =>
        1000.0,
      'cm' || 'centimeter' || 'centimeters' => 0.01,
      'mi' || 'mile' || 'miles' => 1609.344,
      'yd' || 'yard' || 'yards' => 0.9144,
      'ft' || 'foot' || 'feet' => 0.3048,
      'in' || 'inch' || 'inches' => 0.0254,
      _ => null,
    };
    return factor == null ? value : value * factor;
  }

  static String _distanceUnitFromHeader(String? header) {
    final value = header?.toLowerCase() ?? '';
    if (value.contains('mile')) return 'mi';
    if (value.contains('km')) return 'km';
    if (value.contains('meter') || value.contains('_m')) return 'm';
    return '';
  }

  static String _canonicalSetType(String raw) {
    final value = _normalize(raw);
    return switch (value) {
      'warmup' || 'warm up' => 'warmup',
      'drop set' || 'dropset' => 'drop_set',
      'failure' || 'to failure' => 'failure',
      '' || 'normal' || 'working' => 'normal',
      _ => value.replaceAll(' ', '_'),
    };
  }

  static double? _boundedDouble(String raw, double min, double max) {
    final value = _parseDouble(raw);
    if (value == null || !value.isFinite || value < min || value > max) {
      return null;
    }
    return value;
  }

  static String? _nullableText(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static int? _parseInt(String? raw) {
    final value = raw?.trim();
    if (value == null || value.isEmpty) return null;
    return int.tryParse(value) ?? double.tryParse(value)?.round();
  }

  static double? _parseDouble(String? raw) {
    final value = raw?.trim().replaceAll(',', '');
    if (value == null || value.isEmpty) return null;
    return double.tryParse(value);
  }

  static String _value(Map<String, String> row, String? column) =>
      column == null ? '' : row[column] ?? '';

  static String _normalize(String value) => value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[\s-]+'), ' ')
      .replaceAll('_', ' ');

  static String _normalizeExercise(String value) => value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

class _MutableImportWorkout {
  _MutableImportWorkout({
    required this.sourceId,
    required this.name,
    required this.startedAt,
    required this.sourceTimestamp,
    required this.durationSeconds,
    required this.notes,
  });

  final String? sourceId;
  final String name;
  final DateTime startedAt;
  final String sourceTimestamp;
  final int? durationSeconds;
  final String notes;
  final List<ImportSetDraft> sets = [];
  final Map<String, int> _setCounts = {};

  int nextSetOrder(String exercise) {
    final key = exercise.trim().toLowerCase();
    final next = (_setCounts[key] ?? 0) + 1;
    _setCounts[key] = next;
    return next;
  }
}

class _ParsedWeight {
  const _ParsedWeight({
    required this.targetValue,
    required this.kilograms,
  });

  final double targetValue;
  final double kilograms;
}

abstract final class ProgressionCsvExport {
  static Map<String, Uint8List> portableFiles(Map<String, dynamic> state) {
    Uint8List bytes(List<List<Object?>> rows) =>
        Uint8List.fromList(utf8.encode(CsvCodec.encode(rows)));
    return {
      'workouts.csv': bytes(_workoutRows(state)),
      'sets.csv': bytes(_setRows(state)),
      'exercises.csv': bytes(_exerciseRows(state)),
      'athletic_sessions.csv': bytes(_athleticSessionRows(state)),
      'athletic_assessments.csv': bytes(_assessmentRows(state)),
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
        'Progression Lab portable CSV export\n'
        'UTF-8, comma-separated, ISO-8601 timestamps, explicit units.\n'
        'See DATA_PORTABILITY.md in the Progression Lab repository.\n',
      ),
    );
    archive.addFile(ArchiveFile('README.txt', readme.length, readme));
    final encoded = ZipEncoder().encode(archive);
    if (encoded == null || encoded.isEmpty) {
      throw StateError('Could not encode CSV export.');
    }
    return Uint8List.fromList(encoded);
  }

  static Uint8List encodeStrongCompatibleCsv(Map<String, dynamic> state) {
    final rows = <List<Object?>>[
      [
        'Date',
        'Workout Name',
        'Duration',
        'Exercise Name',
        'Set Order',
        'Weight',
        'Reps',
        'Distance',
        'Seconds',
        'Notes',
        'Workout Notes',
        'RPE',
      ],
    ];
    final logs = _maps(state['logs']);
    final importedBySession = <String, Map<String, dynamic>>{};
    for (final workout in _maps(state['importedWorkouts'])) {
      final sessionId = workout['sessionId'];
      final id = workout['id'];
      if (sessionId is String && sessionId.isNotEmpty) {
        importedBySession[sessionId] = workout;
      } else if (id is String) {
        importedBySession[id] = workout;
      }
    }
    final counters = <String, int>{};
    logs.sort((a, b) {
      final date = '${a['d']}'.compareTo('${b['d']}');
      if (date != 0) return date;
      final exercise = '${a['e']}'.compareTo('${b['e']}');
      if (exercise != 0) return exercise;
      return (_readInt(a['setOrder']) ?? 0).compareTo(
        _readInt(b['setOrder']) ?? 0,
      );
    });
    for (final log in logs) {
      final session = '${log['s'] ?? '${log['d']}|${log['o']}'}';
      final counterKey = '$session|${log['e']}';
      final counter = (counters[counterKey] ?? 0) + 1;
      counters[counterKey] = counter;
      final duration = importedBySession[session]?['durationSeconds'];
      rows.add([
        _strongDate('${log['d']}'),
        log['o'],
        _strongDuration(_readInt(duration)),
        log['e'],
        _readInt(log['setOrder']) ?? counter,
        log['w'],
        log['r'],
        log['distance'] ?? 0,
        log['durationSeconds'] ?? 0,
        log['n'] ?? '',
        importedBySession[session]?['notes'] ?? '',
        log['rpe'] ?? '',
      ]);
    }
    return Uint8List.fromList(utf8.encode(CsvCodec.encode(rows)));
  }

  static List<List<Object?>> _workoutRows(Map<String, dynamic> state) {
    final rows = <List<Object?>>[
      [
        'workout_id',
        'session_id',
        'source_app',
        'source_id',
        'workout_name',
        'started_at',
        'source_started_at_raw',
        'duration_seconds',
        'notes',
        'signature',
        'import_batch_id',
      ],
    ];
    for (final record in _maps(state['workoutHistory'])) {
      rows.add([
        record['sessionId'] ??
            'strength-${record['loggedAt'] ?? record['date']}-${record['workout']}',
        record['sessionId'] ?? '',
        'progression_lab',
        '',
        record['workout'],
        record['loggedAt'] ?? record['date'],
        record['loggedAt'] ?? record['date'],
        '',
        '',
        '',
        '',
      ]);
    }
    for (final record in _maps(state['importedWorkouts'])) {
      rows.add([
        record['id'],
        record['sessionId'] ?? '',
        record['source'],
        record['sourceId'] ?? '',
        record['name'],
        record['startedAt'],
        record['sourceTimestamp'] ?? record['startedAt'],
        record['durationSeconds'] ?? '',
        record['notes'] ?? '',
        record['signature'],
        record['importBatchId'],
      ]);
    }
    return rows;
  }

  static List<List<Object?>> _setRows(Map<String, dynamic> state) {
    final unit = state['unit'] == 'kg' ? 'kg' : 'lb';
    final rows = <List<Object?>>[
      [
        'workout_id',
        'workout_date',
        'workout_name',
        'exercise_name',
        'exercise_order',
        'set_order',
        'set_type',
        'weight',
        'weight_unit',
        'reps',
        'duration_seconds',
        'distance',
        'distance_unit',
        'rpe',
        'rir',
        'rest_seconds',
        'superset_id',
        'notes',
        'source_app',
        'source_id',
        'import_batch_id',
      ],
    ];
    final counters = <String, int>{};
    for (final log in _maps(state['logs'])) {
      final session = '${log['s'] ?? '${log['d']}|${log['o']}'}';
      final counterKey = '$session|${log['e']}';
      final counter = (counters[counterKey] ?? 0) + 1;
      counters[counterKey] = counter;
      rows.add([
        session,
        log['d'],
        log['o'],
        log['e'],
        log['i'] ?? '',
        log['setOrder'] ?? counter,
        log['setType'] ?? 'normal',
        log['w'],
        unit,
        log['r'],
        log['durationSeconds'] ?? '',
        log['distance'] ?? '',
        log['distanceUnit'] ?? '',
        log['rpe'] ?? '',
        log['rir'] ?? '',
        log['restSeconds'] ?? '',
        log['supersetId'] ?? '',
        log['n'] ?? '',
        log['sourceApp'] ?? 'progression_lab',
        log['sourceId'] ?? '',
        log['importBatchId'] ?? '',
      ]);
    }
    return rows;
  }

  static List<List<Object?>> _exerciseRows(Map<String, dynamic> state) {
    final rows = <List<Object?>>[
      ['exercise_id', 'exercise_name', 'is_custom', 'is_archived'],
    ];
    for (final exercise in _maps(state['customExercises'])) {
      rows.add([
        exercise['id'],
        exercise['name'],
        true,
        exercise['isArchived'] == true,
      ]);
    }
    return rows;
  }

  static List<List<Object?>> _athleticSessionRows(Map<String, dynamic> state) {
    final rows = <List<Object?>>[
      [
        'program_run',
        'week',
        'session_index',
        'completed_at',
        'effort',
        'notes',
      ],
    ];
    for (final record in _maps(state['athleticHistory'])) {
      rows.add([
        record['programRun'],
        record['week'],
        record['sessionIndex'],
        record['completedAt'],
        record['effort'],
        record['notes'] ?? '',
      ]);
    }
    return rows;
  }

  static List<List<Object?>> _assessmentRows(Map<String, dynamic> state) {
    final rows = <List<Object?>>[
      [
        'program_run',
        'recorded_at',
        'left_balance_seconds',
        'right_balance_seconds',
        'broad_jump_centimeters',
        'sprint_10m_seconds',
        'change_of_direction_505_seconds',
        'movement_quality',
        'notes',
      ],
    ];
    for (final record in _maps(state['athleticAssessments'])) {
      rows.add([
        record['programRun'],
        record['recordedAt'],
        record['leftBalanceSeconds'] ?? '',
        record['rightBalanceSeconds'] ?? '',
        record['broadJumpCentimeters'] ?? '',
        record['sprint10MetersSeconds'] ?? '',
        record['changeOfDirection505Seconds'] ?? '',
        record['movementQuality'],
        record['notes'] ?? '',
      ]);
    }
    return rows;
  }

  static String _strongDate(String raw) {
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    final value = parsed.toLocal();
    String two(int number) => number.toString().padLeft(2, '0');
    return '${value.year.toString().padLeft(4, '0')}-${two(value.month)}-'
        '${two(value.day)} ${two(value.hour)}:${two(value.minute)}:'
        '${two(value.second)}';
  }

  static String _strongDuration(int? seconds) {
    if (seconds == null || seconds <= 0) return '';
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    if (hours > 0 && minutes > 0) return '${hours}h ${minutes}m';
    if (hours > 0) return '${hours}h';
    return '${minutes.clamp(1, 59)}m';
  }

  static List<Map<String, dynamic>> _maps(Object? value) {
    if (value is! List) return <Map<String, dynamic>>[];
    return [
      for (final item in value)
        if (item is Map) Map<String, dynamic>.from(item),
    ];
  }
}

class ImportedWorkoutRecord {
  const ImportedWorkoutRecord({
    required this.id,
    required this.source,
    required this.name,
    required this.startedAt,
    required this.sourceTimestamp,
    required this.signature,
    required this.importBatchId,
    this.sessionId,
    this.sourceId,
    this.durationSeconds,
    this.notes = '',
  });

  final String id;
  final String source;
  final String? sessionId;
  final String? sourceId;
  final String name;
  final DateTime startedAt;
  final String sourceTimestamp;
  final int? durationSeconds;
  final String notes;
  final String signature;
  final String importBatchId;

  Map<String, dynamic> toJson() => {
    'id': id,
    'source': source,
    if (sessionId != null) 'sessionId': sessionId,
    if (sourceId != null) 'sourceId': sourceId,
    'name': name,
    'startedAt': startedAt.toIso8601String(),
    'sourceTimestamp': sourceTimestamp,
    if (durationSeconds != null) 'durationSeconds': durationSeconds,
    'notes': notes,
    'signature': signature,
    'importBatchId': importBatchId,
  };

  factory ImportedWorkoutRecord.fromJson(Map<String, dynamic> json) =>
      ImportedWorkoutRecord(
        id: json['id'] as String,
        source: json['source'] as String,
        sessionId: json['sessionId'] is String
            ? json['sessionId'] as String
            : null,
        sourceId: json['sourceId'] is String
            ? json['sourceId'] as String
            : null,
        name: json['name'] as String,
        startedAt: DateTime.parse(json['startedAt'] as String),
        sourceTimestamp: json['sourceTimestamp'] is String
            ? json['sourceTimestamp'] as String
            : json['startedAt'] as String,
        durationSeconds: _readInt(json['durationSeconds']),
        notes: json['notes'] is String ? json['notes'] as String : '',
        signature: json['signature'] as String,
        importBatchId: json['importBatchId'] as String,
      );
}

class DataImportBatch {
  const DataImportBatch({
    required this.id,
    required this.source,
    required this.fileName,
    required this.fileHash,
    required this.importedAt,
    required this.workoutIds,
    required this.sessionIds,
    required this.createdExerciseIds,
    required this.signatures,
    required this.workoutCount,
    required this.setCount,
  });

  final String id;
  final String source;
  final String fileName;
  final String fileHash;
  final DateTime importedAt;
  final List<String> workoutIds;
  final List<String> sessionIds;
  final List<String> createdExerciseIds;
  final List<String> signatures;
  final int workoutCount;
  final int setCount;

  Map<String, dynamic> toJson() => {
    'id': id,
    'source': source,
    'fileName': fileName,
    'fileHash': fileHash,
    'importedAt': importedAt.toIso8601String(),
    'workoutIds': workoutIds,
    'sessionIds': sessionIds,
    'createdExerciseIds': createdExerciseIds,
    'signatures': signatures,
    'workoutCount': workoutCount,
    'setCount': setCount,
  };

  factory DataImportBatch.fromJson(Map<String, dynamic> json) =>
      DataImportBatch(
        id: json['id'] as String,
        source: json['source'] as String,
        fileName: json['fileName'] as String,
        fileHash: json['fileHash'] as String,
        importedAt: DateTime.parse(json['importedAt'] as String),
        workoutIds: _stringList(json['workoutIds']),
        sessionIds: _stringList(json['sessionIds']),
        createdExerciseIds: _stringList(json['createdExerciseIds']),
        signatures: _stringList(json['signatures']),
        workoutCount: _readInt(json['workoutCount']) ?? 0,
        setCount: _readInt(json['setCount']) ?? 0,
      );
}

List<String> _stringList(Object? value) {
  if (value is! List) return const [];
  return [for (final item in value) if (item is String) item];
}

int? _readInt(Object? value) {
  if (value is int) return value;
  if (value is num && value.isFinite) return value.toInt();
  return int.tryParse('$value');
}
