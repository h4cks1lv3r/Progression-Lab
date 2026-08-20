#!/usr/bin/env python3
"""Generate Progression Lab's data portability implementation on materialized source."""

from __future__ import annotations

import re
import sys
from pathlib import Path


def match_brace(text: str, start: int, opening: str = "{", closing: str = "}") -> int:
    if text[start] != opening:
        raise ValueError(f"Expected {opening!r} at {start}")
    depth = 0
    quote: str | None = None
    escaped = False
    line_comment = False
    block_comment = False
    i = start
    while i < len(text):
        c = text[i]
        n = text[i + 1] if i + 1 < len(text) else ""
        if line_comment:
            if c == "\n":
                line_comment = False
            i += 1
            continue
        if block_comment:
            if c == "*" and n == "/":
                block_comment = False
                i += 2
            else:
                i += 1
            continue
        if quote:
            if escaped:
                escaped = False
            elif c == "\\":
                escaped = True
            elif c == quote:
                quote = None
            i += 1
            continue
        if c == "/" and n == "/":
            line_comment = True
            i += 2
            continue
        if c == "/" and n == "*":
            block_comment = True
            i += 2
            continue
        if c in ("'", '"'):
            quote = c
            i += 1
            continue
        if c == opening:
            depth += 1
        elif c == closing:
            depth -= 1
            if depth == 0:
                return i
        i += 1
    raise ValueError(f"Unmatched {opening!r}")


def add_dependency(pubspec: str, name: str, version: str) -> str:
    if re.search(rf"^\s*{re.escape(name)}\s*:", pubspec, re.M):
        return pubspec
    marker = "dependencies:\n"
    if marker not in pubspec:
        raise ValueError("pubspec.yaml has no dependencies section")
    return pubspec.replace(marker, marker + f"  {name}: {version}\n", 1)


def modify_store(path: Path) -> None:
    text = path.read_text()
    if "exportPortableState" in text:
        return

    save_match = re.search(r"\n\s*Future<void>\s+save\s*\(\s*\)\s*async\s*\{", text)
    if not save_match:
        raise ValueError("Could not find AppStore.save()")
    save_open = text.find("{", save_match.start())
    save_close = match_brace(text, save_open)
    save_body = text[save_open + 1 : save_close]

    json_pos = save_body.find("jsonEncode(")
    if json_pos < 0:
        raise ValueError("Could not find jsonEncode in AppStore.save()")
    map_start = json_pos + len("jsonEncode(")
    while map_start < len(save_body) and save_body[map_start].isspace():
        map_start += 1
    type_prefix_start = map_start
    if save_body.startswith("<String, dynamic>", map_start):
        map_start += len("<String, dynamic>")
        while save_body[map_start].isspace():
            map_start += 1
    if save_body[map_start] != "{":
        raise ValueError("AppStore.save() jsonEncode argument is not a map literal")
    map_end = match_brace(save_body, map_start)
    state_literal = save_body[type_prefix_start : map_end + 1]

    await_start = save_body.rfind("await ", 0, json_pos)
    if await_start < 0:
        raise ValueError("Could not find storage write await statement")
    semicolon = save_body.find(";", map_end)
    if semicolon < 0:
        raise ValueError("Could not find end of storage write statement")
    write_statement = save_body[await_start : semicolon + 1]
    state_arg_start = write_statement.find("jsonEncode(") + len("jsonEncode(")
    state_arg_end = write_statement.rfind(")")
    write_with_state = write_statement[:state_arg_start] + "state" + write_statement[state_arg_end:]

    new_save_body = save_body[:await_start] + "await _writePortableState(_portableState());" + save_body[semicolon + 1 :]
    methods = f'''\n\n  /// Returns the complete, versioned state persisted by Progression Lab.\n  Map<String, dynamic> exportPortableState() =>\n      Map<String, dynamic>.from(\n        jsonDecode(jsonEncode(_portableState())) as Map<String, dynamic>,\n      );\n\n  Map<String, dynamic> _portableState() => {state_literal};\n\n  Future<void> _writePortableState(Map<String, dynamic> state) async {{\n    {write_with_state.strip()}\n  }}\n\n  /// Replaces all app state transactionally and reloads the in-memory model.\n  Future<void> restorePortableState(Map<String, dynamic> state) async {{\n    final previous = exportPortableState();\n    try {{\n      await _writePortableState(Map<String, dynamic>.from(state));\n      await load();\n    }} on Object {{\n      await _writePortableState(previous);\n      await load();\n      rethrow;\n    }}\n    notifyListeners();\n  }}\n'''
    save_method_start = save_match.start() + 1
    text = text[:save_method_start] + methods + text[save_method_start:save_open + 1] + new_save_body + text[save_close:]

    insertion_marker = "\n  DateTime dateForSlot("
    insertion = '''\n\n  /// Adds externally imported sets and workout summaries as one transaction.\n  Future<void> importExternalData({\n    required List<SetLog> importedLogs,\n    required List<WorkoutRecord> importedHistory,\n  }) async {\n    final previousLogs = List<SetLog>.of(logs);\n    final previousHistory = List<WorkoutRecord>.of(workoutHistory);\n    logs.addAll(importedLogs);\n    workoutHistory.addAll(importedHistory);\n    try {\n      await save();\n    } on Object {\n      logs = previousLogs;\n      workoutHistory = previousHistory;\n      rethrow;\n    }\n    notifyListeners();\n  }\n'''
    marker_pos = text.find(insertion_marker)
    if marker_pos < 0:
        insertion_marker = "\n  void _advanceWorkout("
        marker_pos = text.find(insertion_marker)
    if marker_pos < 0:
        raise ValueError("Could not find AppStore import-method insertion point")
    text = text[:marker_pos] + insertion + text[marker_pos:]
    path.write_text(text)


DATA_PORTABILITY_DART = r'''import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'exercise_library.dart';
import 'store.dart';

const int portabilitySchemaVersion = 1;
const String portabilityFormat = 'progression-lab-backup';

class PortabilityException implements Exception {
  const PortabilityException(this.message);
  final String message;
  @override
  String toString() => message;
}

enum WorkoutImportSource { strong, hevy, fitNotes, generic }

extension WorkoutImportSourceLabel on WorkoutImportSource {
  String get label => switch (this) {
    WorkoutImportSource.strong => 'Strong',
    WorkoutImportSource.hevy => 'Hevy',
    WorkoutImportSource.fitNotes => 'FitNotes',
    WorkoutImportSource.generic => 'Generic CSV',
  };
}

class GenericColumnMapping {
  const GenericColumnMapping({
    required this.date,
    required this.exercise,
    required this.reps,
    this.workout,
    this.setOrder,
    this.weight,
    this.weightUnit,
    this.notes,
    this.duration,
    this.distance,
    this.rpe,
  });

  final String date;
  final String exercise;
  final String reps;
  final String? workout;
  final String? setOrder;
  final String? weight;
  final String? weightUnit;
  final String? notes;
  final String? duration;
  final String? distance;
  final String? rpe;
}

class MappingRequired implements Exception {
  const MappingRequired(this.headers);
  final List<String> headers;
}

class ImportedSet {
  const ImportedSet({
    required this.exercise,
    required this.order,
    required this.reps,
    this.weight,
    this.weightUnit,
    this.notes = '',
    this.durationSeconds,
    this.distanceMeters,
    this.rpe,
  });

  final String exercise;
  final int order;
  final int reps;
  final double? weight;
  final String? weightUnit;
  final String notes;
  final int? durationSeconds;
  final double? distanceMeters;
  final double? rpe;

  Map<String, dynamic> toCanonicalJson() => <String, dynamic>{
    'exercise': exercise.trim().toLowerCase(),
    'order': order,
    'reps': reps,
    'weight': weight,
    'weightUnit': weightUnit,
    'durationSeconds': durationSeconds,
    'distanceMeters': distanceMeters,
    'rpe': rpe,
  };
}

class ImportedSession {
  ImportedSession({
    required this.title,
    required this.startedAt,
    required this.sets,
    this.notes = '',
    this.sourceId,
  });

  final String title;
  final DateTime startedAt;
  final List<ImportedSet> sets;
  final String notes;
  final String? sourceId;

  String get signature => sha256
      .convert(
        utf8.encode(
          jsonEncode(<String, dynamic>{
            'title': title.trim().toLowerCase(),
            'startedAt': startedAt.toUtc().toIso8601String(),
            'sets': sets.map((set) => set.toCanonicalJson()).toList(),
          }),
        ),
      )
      .toString();
}

class ImportPreview {
  ImportPreview({
    required this.source,
    required this.sessions,
    required this.invalidRows,
    required this.headers,
    this.duplicateSignatures = const <String>{},
    this.unmatchedExercises = const <String>{},
    this.assumedWeightUnit,
  });

  final WorkoutImportSource source;
  final List<ImportedSession> sessions;
  final int invalidRows;
  final List<String> headers;
  final Set<String> duplicateSignatures;
  final Set<String> unmatchedExercises;
  final String? assumedWeightUnit;

  int get workoutCount => sessions.length;
  int get setCount => sessions.fold<int>(0, (sum, item) => sum + item.sets.length);
  int get duplicateCount => sessions.where((item) => duplicateSignatures.contains(item.signature)).length;
  int get importableWorkoutCount => workoutCount - duplicateCount;
  DateTime? get earliest => sessions.isEmpty
      ? null
      : sessions.map((item) => item.startedAt).reduce((a, b) => a.isBefore(b) ? a : b);
  DateTime? get latest => sessions.isEmpty
      ? null
      : sessions.map((item) => item.startedAt).reduce((a, b) => a.isAfter(b) ? a : b);

  ImportPreview copyWith({
    Set<String>? duplicateSignatures,
    Set<String>? unmatchedExercises,
  }) => ImportPreview(
    source: source,
    sessions: sessions,
    invalidRows: invalidRows,
    headers: headers,
    duplicateSignatures: duplicateSignatures ?? this.duplicateSignatures,
    unmatchedExercises: unmatchedExercises ?? this.unmatchedExercises,
    assumedWeightUnit: assumedWeightUnit,
  );
}

class PortabilityCodec {
  const PortabilityCodec._();

  static Uint8List encodeBackup({
    required Map<String, dynamic> state,
    required Map<String, dynamic> portabilityMetadata,
    required String appVersion,
    required String platform,
    required DateTime createdAt,
    String reason = 'manual',
  }) {
    final manifest = <String, dynamic>{
      'format': portabilityFormat,
      'schemaVersion': portabilitySchemaVersion,
      'appVersion': appVersion,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'devicePlatform': platform,
      'unitSystem': state['unit'] ?? 'unknown',
      'reason': reason,
    };
    final entries = <String, Uint8List>{
      'manifest.json': _jsonBytes(manifest),
      'state.json': _jsonBytes(state),
      'workouts.json': _jsonBytes(_subset(state, const <String>['workoutHistory', 'draft', 'drafts'])),
      'sets.json': _jsonBytes(<String, dynamic>{'logs': _list(state['logs'])}),
      'exercises.json': _jsonBytes(<String, dynamic>{'customExercises': _list(state['customExercises'])}),
      'program_state.json': _jsonBytes(_subset(state, const <String>[
        'days', 'week', 'workoutIndex', 'programStartDate', 'unit',
      ])),
      'athletic_history.json': _jsonBytes(Map<String, dynamic>.fromEntries(
        state.entries.where((entry) => entry.key.toLowerCase().contains('athletic')),
      )),
      'settings.json': _jsonBytes(Map<String, dynamic>.fromEntries(
        state.entries.where((entry) => !_historyKey(entry.key)),
      )),
      'portability_metadata.json': _jsonBytes(portabilityMetadata),
    };
    final checksums = <String, String>{
      for (final entry in entries.entries)
        entry.key: sha256.convert(entry.value).toString(),
    };
    entries['checksums.json'] = _jsonBytes(checksums);
    final archive = Archive();
    for (final entry in entries.entries) {
      archive.addFile(ArchiveFile(entry.key, entry.value.length, entry.value));
    }
    final encoded = ZipEncoder().encode(archive);
    if (encoded == null) throw const PortabilityException('Could not create backup archive.');
    return Uint8List.fromList(encoded);
  }

  static DecodedBackup decodeBackup(List<int> bytes) {
    final archive = ZipDecoder().decodeBytes(bytes, verify: true);
    final files = <String, Uint8List>{};
    for (final file in archive.files.where((entry) => entry.isFile)) {
      files[file.name] = _contentBytes(file.content);
    }
    final manifest = _decodeMap(files['manifest.json'], 'manifest.json');
    if (manifest['format'] != portabilityFormat) {
      throw const PortabilityException('This is not a Progression Lab backup.');
    }
    final schema = (manifest['schemaVersion'] as num?)?.toInt();
    if (schema == null || schema > portabilitySchemaVersion) {
      throw PortabilityException('Backup schema $schema is not supported by this version.');
    }
    final checksums = _decodeMap(files['checksums.json'], 'checksums.json');
    for (final entry in checksums.entries) {
      final content = files[entry.key];
      if (content == null || sha256.convert(content).toString() != entry.value) {
        throw PortabilityException('Backup integrity check failed for ${entry.key}.');
      }
    }
    final state = _decodeMap(files['state.json'], 'state.json');
    final metadata = files.containsKey('portability_metadata.json')
        ? _decodeMap(files['portability_metadata.json'], 'portability_metadata.json')
        : <String, dynamic>{};
    return DecodedBackup(manifest: manifest, state: state, portabilityMetadata: metadata);
  }

  static Uint8List encodePortableCsvPackage(Map<String, dynamic> state) {
    final entries = <String, Uint8List>{
      'workouts.csv': Uint8List.fromList(utf8.encode(_workoutsCsv(state))),
      'sets.csv': Uint8List.fromList(utf8.encode(_setsCsv(state))),
      'exercises.csv': Uint8List.fromList(utf8.encode(_exercisesCsv(state))),
      'athletic_assessments.csv': Uint8List.fromList(utf8.encode(_athleticCsv(state))),
      'README.txt': Uint8List.fromList(utf8.encode(
        'Progression Lab portable CSV export\n'
        'All timestamps use ISO-8601. Weight and distance units are explicit.\n'
        'The .plab backup format, not CSV, is required for exact restoration.\n',
      )),
    };
    final archive = Archive();
    for (final entry in entries.entries) {
      archive.addFile(ArchiveFile(entry.key, entry.value.length, entry.value));
    }
    final encoded = ZipEncoder().encode(archive);
    if (encoded == null) throw const PortabilityException('Could not create CSV export.');
    return Uint8List.fromList(encoded);
  }

  static Uint8List encodeStrongCompatibleCsv(Map<String, dynamic> state) =>
      Uint8List.fromList(utf8.encode(_strongCsv(state)));

  static Map<String, dynamic> _subset(Map<String, dynamic> state, List<String> keys) =>
      <String, dynamic>{for (final key in keys) if (state.containsKey(key)) key: state[key]};

  static bool _historyKey(String key) {
    final normalized = key.toLowerCase();
    return normalized.contains('log') || normalized.contains('history') ||
        normalized.contains('draft') || normalized.contains('athletic') ||
        normalized.contains('exercise');
  }

  static Uint8List _jsonBytes(Object? value) =>
      Uint8List.fromList(utf8.encode(const JsonEncoder.withIndent('  ').convert(value)));

  static Map<String, dynamic> _decodeMap(Uint8List? bytes, String name) {
    if (bytes == null) throw PortabilityException('Backup is missing $name.');
    final value = jsonDecode(utf8.decode(bytes));
    if (value is! Map) throw PortabilityException('$name is invalid.');
    return Map<String, dynamic>.from(value);
  }

  static Uint8List _contentBytes(Object? content) {
    if (content is Uint8List) return content;
    if (content is List<int>) return Uint8List.fromList(content);
    throw const PortabilityException('Backup contains an unreadable file.');
  }

  static List<dynamic> _list(Object? value) => value is List ? value : const <dynamic>[];
  static Map<String, dynamic> _map(Object? value) =>
      value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

  static String _csv(List<List<dynamic>> rows) => const ListToCsvConverter().convert(rows);

  static String _workoutsCsv(Map<String, dynamic> state) {
    final rows = <List<dynamic>>[[
      'workout_id', 'workout_date', 'workout_name', 'status', 'week',
      'workout_index', 'cadence_days', 'retroactive', 'notes',
    ]];
    for (final raw in _list(state['workoutHistory'])) {
      final item = _map(raw);
      rows.add(<dynamic>[
        item['sessionId'] ?? '', item['loggedAt'] ?? item['date'] ?? '',
        item['workout'] ?? '', item['status'] ?? '', item['week'] ?? '',
        item['workoutIndex'] ?? '', item['days'] ?? '', item['retroactive'] ?? false,
        item['notes'] ?? '',
      ]);
    }
    return _csv(rows);
  }

  static String _setsCsv(Map<String, dynamic> state) {
    final rows = <List<dynamic>>[[
      'workout_id', 'workout_date', 'workout_name', 'exercise_name',
      'exercise_order', 'set_order', 'set_type', 'weight', 'weight_unit',
      'reps', 'duration_seconds', 'distance', 'distance_unit', 'rpe', 'rir',
      'rest_seconds', 'notes', 'source_app', 'source_id',
    ]];
    final counters = <String, int>{};
    for (final raw in _list(state['logs'])) {
      final item = _map(raw);
      final id = '${item['sessionId'] ?? item['date'] ?? ''}|${item['exercise'] ?? ''}';
      final order = (counters[id] ?? 0) + 1;
      counters[id] = order;
      rows.add(<dynamic>[
        item['sessionId'] ?? '', item['date'] ?? '', item['workout'] ?? '',
        item['exercise'] ?? '', item['exerciseIndex'] ?? '', order,
        item['setType'] ?? 'working', item['weight'] ?? '', state['unit'] ?? '',
        item['reps'] ?? '', item['durationSeconds'] ?? '', item['distance'] ?? '',
        item['distanceUnit'] ?? '', item['rpe'] ?? '', item['rir'] ?? '',
        item['restSeconds'] ?? '', item['notes'] ?? '', item['sourceApp'] ?? '',
        item['sourceId'] ?? '',
      ]);
    }
    return _csv(rows);
  }

  static String _exercisesCsv(Map<String, dynamic> state) {
    final rows = <List<dynamic>>[['id', 'name', 'archived', 'created_at']];
    for (final raw in _list(state['customExercises'])) {
      final item = _map(raw);
      rows.add(<dynamic>[
        item['id'] ?? '', item['name'] ?? '', item['isArchived'] ?? false,
        item['createdAt'] ?? '',
      ]);
    }
    return _csv(rows);
  }

  static String _athleticCsv(Map<String, dynamic> state) {
    final rows = <List<dynamic>>[['record']];
    for (final entry in state.entries.where((entry) =>
        entry.key.toLowerCase().contains('assessment'))) {
      for (final raw in _list(entry.value)) {
        rows.add(<dynamic>[jsonEncode(raw)]);
      }
    }
    return _csv(rows);
  }

  static String _strongCsv(Map<String, dynamic> state) {
    final rows = <List<dynamic>>[[
      'Date', 'Workout Name', 'Duration', 'Exercise Name', 'Set Order',
      'Weight', 'Reps', 'Distance', 'Seconds', 'Notes', 'Workout Notes', 'RPE',
    ]];
    final counters = <String, int>{};
    for (final raw in _list(state['logs'])) {
      final item = _map(raw);
      final id = '${item['sessionId'] ?? item['date'] ?? ''}|${item['exercise'] ?? ''}';
      final order = (counters[id] ?? 0) + 1;
      counters[id] = order;
      rows.add(<dynamic>[
        item['date'] ?? '', item['workout'] ?? 'Imported Workout', '',
        item['exercise'] ?? '', order, item['weight'] ?? '', item['reps'] ?? '',
        item['distance'] ?? '', item['durationSeconds'] ?? '', item['notes'] ?? '',
        '', item['rpe'] ?? '',
      ]);
    }
    return _csv(rows);
  }
}

class DecodedBackup {
  const DecodedBackup({
    required this.manifest,
    required this.state,
    required this.portabilityMetadata,
  });
  final Map<String, dynamic> manifest;
  final Map<String, dynamic> state;
  final Map<String, dynamic> portabilityMetadata;
}

class CsvImportParser {
  const CsvImportParser._();

  static ImportPreview parse(
    Uint8List bytes, {
    GenericColumnMapping? mapping,
    String defaultWeightUnit = 'lb',
  }) {
    final text = utf8.decode(bytes, allowMalformed: true).replaceFirst('\ufeff', '');
    final matrix = const CsvToListConverter(shouldParseNumbers: false).convert(text);
    if (matrix.length < 2) throw const PortabilityException('CSV contains no workout rows.');
    final headers = matrix.first.map((item) => item.toString().trim()).toList();
    final normalized = headers.map(_normalize).toList();
    final source = _detect(normalized);
    if (source == WorkoutImportSource.generic && mapping == null) {
      throw MappingRequired(headers);
    }
    final rows = <Map<String, String>>[];
    for (final raw in matrix.skip(1)) {
      final row = <String, String>{};
      for (var index = 0; index < headers.length; index++) {
        row[headers[index]] = index < raw.length ? raw[index].toString().trim() : '';
      }
      if (row.values.any((value) => value.isNotEmpty)) rows.add(row);
    }
    return _parseRows(
      source: source,
      headers: headers,
      normalizedHeaders: normalized,
      rows: rows,
      mapping: mapping,
      defaultWeightUnit: defaultWeightUnit,
    );
  }

  static WorkoutImportSource _detect(List<String> keys) {
    final set = keys.toSet();
    if (set.contains('kind') && set.contains('exercise') &&
        (set.contains('weight_kg') || set.contains('weight_lbs'))) {
      return WorkoutImportSource.fitNotes;
    }
    if (set.contains('exercise_title') && set.contains('start_time') &&
        set.contains('set_index')) {
      return WorkoutImportSource.hevy;
    }
    if (set.contains('workout_name') && set.contains('exercise_name') &&
        set.contains('set_order')) {
      return WorkoutImportSource.strong;
    }
    return WorkoutImportSource.generic;
  }

  static ImportPreview _parseRows({
    required WorkoutImportSource source,
    required List<String> headers,
    required List<String> normalizedHeaders,
    required List<Map<String, String>> rows,
    required GenericColumnMapping? mapping,
    required String defaultWeightUnit,
  }) {
    final byNormalized = <String, String>{
      for (var i = 0; i < headers.length; i++) normalizedHeaders[i]: headers[i],
    };
    String? key(String normalized) => byNormalized[normalized];
    String value(Map<String, String> row, String? header) =>
        header == null ? '' : (row[header] ?? '').trim();

    late String dateHeader;
    late String exerciseHeader;
    late String repsHeader;
    String? workoutHeader;
    String? setHeader;
    String? weightHeader;
    String? weightUnitHeader;
    String? notesHeader;
    String? durationHeader;
    String? distanceHeader;
    String? rpeHeader;
    String? kgHeader;
    String? lbHeader;
    String assumedUnit = defaultWeightUnit;

    switch (source) {
      case WorkoutImportSource.strong:
        dateHeader = key('date')!;
        exerciseHeader = key('exercise_name')!;
        repsHeader = key('reps')!;
        workoutHeader = key('workout_name');
        setHeader = key('set_order');
        weightHeader = key('weight');
        notesHeader = key('notes');
        durationHeader = key('seconds');
        distanceHeader = key('distance');
        rpeHeader = key('rpe');
      case WorkoutImportSource.hevy:
        dateHeader = key('start_time')!;
        exerciseHeader = key('exercise_title')!;
        repsHeader = key('reps')!;
        workoutHeader = key('title');
        setHeader = key('set_index');
        weightHeader = key('weight_kg');
        notesHeader = key('exercise_notes');
        durationHeader = key('duration_seconds');
        distanceHeader = key('distance_km');
        rpeHeader = key('rpe');
        assumedUnit = 'kg';
      case WorkoutImportSource.fitNotes:
        dateHeader = key('date')!;
        exerciseHeader = key('exercise')!;
        repsHeader = key('reps')!;
        workoutHeader = key('category');
        notesHeader = key('notes');
        durationHeader = key('time');
        distanceHeader = key('distance');
        weightUnitHeader = key('distance_unit');
        kgHeader = key('weight_kg');
        lbHeader = key('weight_lbs');
      case WorkoutImportSource.generic:
        final selected = mapping!;
        dateHeader = selected.date;
        exerciseHeader = selected.exercise;
        repsHeader = selected.reps;
        workoutHeader = selected.workout;
        setHeader = selected.setOrder;
        weightHeader = selected.weight;
        weightUnitHeader = selected.weightUnit;
        notesHeader = selected.notes;
        durationHeader = selected.duration;
        distanceHeader = selected.distance;
        rpeHeader = selected.rpe;
    }

    final sessions = LinkedHashMap<String, _SessionBuilder>();
    var invalid = 0;
    for (final row in rows) {
      final date = _parseDate(value(row, dateHeader));
      final exercise = value(row, exerciseHeader);
      final reps = _int(value(row, repsHeader));
      if (date == null || exercise.isEmpty || reps == null) {
        invalid++;
        continue;
      }
      final workout = value(row, workoutHeader).isEmpty
          ? 'Imported Workout'
          : value(row, workoutHeader);
      final sessionKey = '${date.toUtc().toIso8601String()}|$workout';
      final builder = sessions.putIfAbsent(
        sessionKey,
        () => _SessionBuilder(title: workout, startedAt: date),
      );
      double? weight;
      String? unit;
      if (source == WorkoutImportSource.fitNotes) {
        weight = _double(value(row, kgHeader));
        unit = weight == null ? null : 'kg';
        if (weight == null) {
          weight = _double(value(row, lbHeader));
          unit = weight == null ? null : 'lb';
        }
      } else {
        weight = _double(value(row, weightHeader));
        unit = value(row, weightUnitHeader);
        if (unit.isEmpty) unit = weight == null ? null : assumedUnit;
      }
      var distance = _double(value(row, distanceHeader));
      if (distance != null && source == WorkoutImportSource.hevy) distance *= 1000;
      if (distance != null && source == WorkoutImportSource.fitNotes) {
        distance *= _distanceFactor(value(row, weightUnitHeader));
      }
      final notes = value(row, notesHeader);
      builder.sets.add(ImportedSet(
        exercise: exercise,
        order: _int(value(row, setHeader)) ?? builder.sets.length + 1,
        reps: reps,
        weight: weight,
        weightUnit: unit,
        notes: notes,
        durationSeconds: _duration(value(row, durationHeader)),
        distanceMeters: distance,
        rpe: _double(value(row, rpeHeader)),
      ));
    }
    return ImportPreview(
      source: source,
      sessions: sessions.values
          .map((builder) => ImportedSession(
                title: builder.title,
                startedAt: builder.startedAt,
                sets: builder.sets,
              ))
          .where((session) => session.sets.isNotEmpty)
          .toList(),
      invalidRows: invalid,
      headers: headers,
      assumedWeightUnit: source == WorkoutImportSource.strong ||
              source == WorkoutImportSource.generic
          ? defaultWeightUnit
          : null,
    );
  }

  static String _normalize(String value) => value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'\([^)]*\)'), (match) => '_${match.group(0)!.substring(1, match.group(0)!.length - 1)}')
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');

  static DateTime? _parseDate(String raw) {
    if (raw.isEmpty) return null;
    final direct = DateTime.tryParse(raw);
    if (direct != null) return direct;
    final normalized = raw.replaceFirst(' ', 'T');
    final iso = DateTime.tryParse(normalized);
    if (iso != null) return iso;
    final parts = RegExp(r'^(\d{1,2})[/-](\d{1,2})[/-](\d{4})(?:\s+(\d{1,2}):(\d{2})(?::(\d{2}))?)?').firstMatch(raw);
    if (parts == null) return null;
    final first = int.parse(parts.group(1)!);
    final second = int.parse(parts.group(2)!);
    final month = first > 12 ? second : first;
    final day = first > 12 ? first : second;
    return DateTime(
      int.parse(parts.group(3)!), month, day,
      int.tryParse(parts.group(4) ?? '') ?? 0,
      int.tryParse(parts.group(5) ?? '') ?? 0,
      int.tryParse(parts.group(6) ?? '') ?? 0,
    );
  }

  static int? _int(String raw) => raw.isEmpty ? null : int.tryParse(raw.split('.').first);
  static double? _double(String raw) => raw.isEmpty ? null : double.tryParse(raw.replaceAll(',', '.'));

  static int? _duration(String raw) {
    if (raw.isEmpty) return null;
    final direct = int.tryParse(raw);
    if (direct != null) return direct;
    final parts = raw.split(':').map(int.tryParse).toList();
    if (parts.any((part) => part == null)) return null;
    if (parts.length == 2) return parts[0]! * 60 + parts[1]!;
    if (parts.length == 3) return parts[0]! * 3600 + parts[1]! * 60 + parts[2]!;
    return null;
  }

  static double _distanceFactor(String raw) => switch (raw.toLowerCase()) {
    'km' => 1000,
    'cm' => .01,
    'mi' => 1609.344,
    'yd' => .9144,
    'ft' => .3048,
    'in' => .0254,
    _ => 1,
  };
}

class _SessionBuilder {
  _SessionBuilder({required this.title, required this.startedAt});
  final String title;
  final DateTime startedAt;
  final List<ImportedSet> sets = <ImportedSet>[];
}

class DataPortabilityService extends ChangeNotifier {
  DataPortabilityService._();
  static final DataPortabilityService instance = DataPortabilityService._();

  AppStore? _store;
  Directory? _root;
  Timer? _debounce;
  bool _initialized = false;
  bool _suspended = false;
  bool automaticBackupsEnabled = true;
  DateTime? lastBackupAt;
  String? lastBackupPath;
  String? lastImportUndoPath;
  final Set<String> _importHashes = <String>{};

  AppStore get store {
    final value = _store;
    if (value == null) throw const PortabilityException('Data portability is not initialized.');
    return value;
  }

  Future<void> initialize(AppStore value, {Directory? rootDirectory}) async {
    if (_initialized && identical(_store, value)) return;
    _store?.removeListener(_onStoreChanged);
    _store = value;
    final docs = rootDirectory ?? await getApplicationDocumentsDirectory();
    _root = Directory('${docs.path}${Platform.pathSeparator}Progression Lab');
    await _root!.create(recursive: true);
    await _loadMetadata();
    value.addListener(_onStoreChanged);
    _initialized = true;
    notifyListeners();
  }

  void _onStoreChanged() {
    if (!_initialized || _suspended || !automaticBackupsEnabled) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 3), () async {
      try {
        await createAutomaticBackup();
      } on Object {
        // Automatic backup failure must never interrupt workout logging.
      }
    });
  }

  Directory get _backupDirectory => Directory(
    '${_root!.path}${Platform.pathSeparator}Backups',
  );
  File get _metadataFile => File(
    '${_root!.path}${Platform.pathSeparator}portability.json',
  );

  Map<String, dynamic> get metadata => <String, dynamic>{
    'automaticBackupsEnabled': automaticBackupsEnabled,
    'lastBackupAt': lastBackupAt?.toUtc().toIso8601String(),
    'lastBackupPath': lastBackupPath,
    'lastImportUndoPath': lastImportUndoPath,
    'importHashes': _importHashes.toList()..sort(),
  };

  Future<void> setAutomaticBackupsEnabled(bool enabled) async {
    automaticBackupsEnabled = enabled;
    await _saveMetadata();
    notifyListeners();
    if (enabled) await createAutomaticBackup();
  }

  Future<Uint8List> buildBackup({String reason = 'manual'}) async =>
      PortabilityCodec.encodeBackup(
        state: store.exportPortableState(),
        portabilityMetadata: metadata,
        appVersion: '1.6.0',
        platform: Platform.operatingSystem,
        createdAt: DateTime.now(),
        reason: reason,
      );

  Future<File> createAutomaticBackup() async {
    await _backupDirectory.create(recursive: true);
    final bytes = await buildBackup(reason: 'automatic');
    final file = File(
      '${_backupDirectory.path}${Platform.pathSeparator}'
      'Progression-Lab-Auto-${_timestamp(DateTime.now())}.plab',
    );
    await file.writeAsBytes(bytes, flush: true);
    PortabilityCodec.decodeBackup(await file.readAsBytes());
    lastBackupAt = DateTime.now();
    lastBackupPath = file.path;
    await _pruneBackups();
    await _saveMetadata();
    notifyListeners();
    return file;
  }

  Future<String?> saveManualBackup() async {
    final bytes = await buildBackup();
    final name = 'Progression-Lab-Backup-${_timestamp(DateTime.now())}.plab';
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Save Progression Lab backup',
      fileName: name,
      type: FileType.custom,
      allowedExtensions: const <String>['plab'],
      bytes: bytes,
    );
    if (path == null) return null;
    final file = File(path);
    if (!await file.exists()) await file.writeAsBytes(bytes, flush: true);
    PortabilityCodec.decodeBackup(await file.readAsBytes());
    lastBackupAt = DateTime.now();
    lastBackupPath = path;
    await _saveMetadata();
    notifyListeners();
    return path;
  }

  Future<String?> exportPortableCsv() async {
    final bytes = PortabilityCodec.encodePortableCsvPackage(store.exportPortableState());
    final name = 'Progression-Lab-CSV-${_timestamp(DateTime.now())}.zip';
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Export workout data',
      fileName: name,
      type: FileType.custom,
      allowedExtensions: const <String>['zip'],
      bytes: bytes,
    );
    if (path != null && !await File(path).exists()) await File(path).writeAsBytes(bytes, flush: true);
    return path;
  }

  Future<String?> exportStrongCompatibleCsv() async {
    final bytes = PortabilityCodec.encodeStrongCompatibleCsv(store.exportPortableState());
    final name = 'Progression-Lab-Strong-Compatible-${_timestamp(DateTime.now())}.csv';
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Export Strong-compatible CSV',
      fileName: name,
      type: FileType.custom,
      allowedExtensions: const <String>['csv'],
      bytes: bytes,
    );
    if (path != null && !await File(path).exists()) await File(path).writeAsBytes(bytes, flush: true);
    return path;
  }

  Future<DecodedBackup?> chooseBackup() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const <String>['plab'],
      withData: true,
    );
    if (result == null) return null;
    return PortabilityCodec.decodeBackup(await _pickedBytes(result.files.single));
  }

  Future<void> restoreChosenBackup(DecodedBackup backup) async {
    final safety = await _writeSafetyBackup('pre-restore');
    _suspended = true;
    try {
      await store.restorePortableState(backup.state);
      _applyMetadata(backup.portabilityMetadata);
      lastImportUndoPath = safety.path;
      await _saveMetadata();
    } on Object {
      final previous = PortabilityCodec.decodeBackup(await safety.readAsBytes());
      await store.restorePortableState(previous.state);
      rethrow;
    } finally {
      _suspended = false;
    }
    notifyListeners();
  }

  Future<ImportPreview?> chooseCsv({GenericColumnMapping? mapping}) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const <String>['csv'],
      withData: true,
    );
    if (result == null) return null;
    final preview = CsvImportParser.parse(
      await _pickedBytes(result.files.single),
      mapping: mapping,
      defaultWeightUnit: store.unit,
    );
    return preparePreview(preview);
  }

  ImportPreview preparePreview(ImportPreview preview) {
    final duplicate = <String>{..._importHashes, ..._existingSignatures()};
    final builtIns = BuiltInExercises.values.map((item) => item.name.toLowerCase()).toSet();
    final custom = store.customExercises
        .where((item) => !item.isArchived)
        .map((item) => item.name.toLowerCase())
        .toSet();
    final unmatched = preview.sessions
        .expand((session) => session.sets)
        .map((set) => set.exercise.trim())
        .where((name) => !builtIns.contains(name.toLowerCase()) &&
            !custom.contains(name.toLowerCase()))
        .toSet();
    return preview.copyWith(
      duplicateSignatures: preview.sessions
          .where((session) => duplicate.contains(session.signature))
          .map((session) => session.signature)
          .toSet(),
      unmatchedExercises: unmatched,
    );
  }

  Future<void> commitImport(ImportPreview preview) async {
    final sessions = preview.sessions
        .where((session) => !preview.duplicateSignatures.contains(session.signature))
        .toList();
    if (sessions.isEmpty) throw const PortabilityException('No new workouts were available to import.');
    final safety = await _writeSafetyBackup('pre-import');
    _suspended = true;
    try {
      for (final name in preview.unmatchedExercises) {
        try {
          await store.addCustomExercise(name);
        } on ArgumentError {
          // The name became available between preview and commit.
        }
      }
      final logs = <SetLog>[];
      final history = <WorkoutRecord>[];
      for (final session in sessions) {
        final sessionId = 'import-${session.signature.substring(0, 20)}';
        final exerciseOrder = <String, int>{};
        for (final set in session.sets) {
          final index = exerciseOrder.putIfAbsent(
            set.exercise,
            () => exerciseOrder.length,
          );
          final notes = <String>[
            if (set.notes.trim().isNotEmpty) set.notes.trim(),
            if (set.durationSeconds != null) 'Duration: ${set.durationSeconds}s',
            if (set.distanceMeters != null) 'Distance: ${set.distanceMeters!.toStringAsFixed(2)} m',
            if (set.rpe != null) 'RPE: ${set.rpe}',
            'Imported from ${preview.source.label}',
          ].join('\n');
          logs.add(SetLog(
            exercise: set.exercise,
            weight: _convertWeight(set.weight ?? 0, set.weightUnit, store.unit),
            reps: set.reps,
            date: session.startedAt,
            workout: session.title,
            sessionId: sessionId,
            exerciseIndex: index,
            notes: notes,
          ));
        }
        history.add(WorkoutRecord(
          week: 0,
          workoutIndex: 0,
          workout: session.title,
          date: session.startedAt,
          status: WorkoutStatus.completed,
          days: 0,
          scheduledDate: session.startedAt,
          loggedAt: session.startedAt,
          retroactive: true,
          sessionId: sessionId,
        ));
      }
      await store.importExternalData(importedLogs: logs, importedHistory: history);
      _importHashes.addAll(sessions.map((session) => session.signature));
      lastImportUndoPath = safety.path;
      await _saveMetadata();
    } on Object {
      final previous = PortabilityCodec.decodeBackup(await safety.readAsBytes());
      await store.restorePortableState(previous.state);
      rethrow;
    } finally {
      _suspended = false;
    }
    notifyListeners();
  }

  Future<void> undoLastImport() async {
    final path = lastImportUndoPath;
    if (path == null || !await File(path).exists()) {
      throw const PortabilityException('No import can be undone.');
    }
    final backup = PortabilityCodec.decodeBackup(await File(path).readAsBytes());
    _suspended = true;
    try {
      await store.restorePortableState(backup.state);
      _applyMetadata(backup.portabilityMetadata);
      lastImportUndoPath = null;
      await _saveMetadata();
    } finally {
      _suspended = false;
    }
    notifyListeners();
  }

  Future<void> testLatestBackup() async {
    final path = lastBackupPath;
    if (path == null || !await File(path).exists()) {
      throw const PortabilityException('No backup is available to test.');
    }
    PortabilityCodec.decodeBackup(await File(path).readAsBytes());
  }

  Future<File> _writeSafetyBackup(String reason) async {
    await _backupDirectory.create(recursive: true);
    final file = File(
      '${_backupDirectory.path}${Platform.pathSeparator}'
      'Progression-Lab-$reason-${_timestamp(DateTime.now())}.plab',
    );
    await file.writeAsBytes(await buildBackup(reason: reason), flush: true);
    PortabilityCodec.decodeBackup(await file.readAsBytes());
    return file;
  }

  Set<String> _existingSignatures() {
    final state = store.exportPortableState();
    final logs = state['logs'] is List ? state['logs'] as List : const <dynamic>[];
    final grouped = LinkedHashMap<String, List<Map<String, dynamic>>>();
    for (final raw in logs.whereType<Map>()) {
      final item = Map<String, dynamic>.from(raw);
      final key = (item['sessionId'] ?? '${item['date']}|${item['workout']}').toString();
      grouped.putIfAbsent(key, () => <Map<String, dynamic>>[]).add(item);
    }
    return grouped.values.map((items) {
      items.sort((a, b) => ((a['exerciseIndex'] as num?)?.toInt() ?? 0)
          .compareTo((b['exerciseIndex'] as num?)?.toInt() ?? 0));
      final date = DateTime.tryParse(items.first['date']?.toString() ?? '') ?? DateTime(1970);
      final session = ImportedSession(
        title: items.first['workout']?.toString() ?? 'Workout',
        startedAt: date,
        sets: <ImportedSet>[
          for (var i = 0; i < items.length; i++)
            ImportedSet(
              exercise: items[i]['exercise']?.toString() ?? '',
              order: i + 1,
              reps: (items[i]['reps'] as num?)?.toInt() ?? 0,
              weight: (items[i]['weight'] as num?)?.toDouble(),
              weightUnit: state['unit']?.toString(),
            ),
        ],
      );
      return session.signature;
    }).toSet();
  }

  Future<void> _pruneBackups() async {
    final files = _backupDirectory
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.plab') && file.path.contains('-Auto-'))
        .toList()
      ..sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    final keep = <String>{};
    keep.addAll(files.take(5).map((file) => file.path));
    final days = <String>{};
    final weeks = <String>{};
    for (final file in files) {
      final modified = file.lastModifiedSync();
      final day = '${modified.year}-${modified.month}-${modified.day}';
      if (days.length < 7 && days.add(day)) keep.add(file.path);
      final firstDay = modified.subtract(Duration(days: modified.weekday - 1));
      final week = '${firstDay.year}-${firstDay.month}-${firstDay.day}';
      if (weeks.length < 4 && weeks.add(week)) keep.add(file.path);
    }
    for (final file in files.where((file) => !keep.contains(file.path))) {
      await file.delete();
    }
  }

  Future<Uint8List> _pickedBytes(PlatformFile file) async {
    if (file.bytes != null) return file.bytes!;
    if (file.path != null) return File(file.path!).readAsBytes();
    throw const PortabilityException('The selected file could not be read.');
  }

  Future<void> _loadMetadata() async {
    if (!await _metadataFile.exists()) return;
    try {
      _applyMetadata(Map<String, dynamic>.from(
        jsonDecode(await _metadataFile.readAsString()) as Map,
      ));
    } on Object {
      // Ignore corrupt metadata. Backups themselves remain independently valid.
    }
  }

  void _applyMetadata(Map<String, dynamic> value) {
    automaticBackupsEnabled = value['automaticBackupsEnabled'] as bool? ?? true;
    lastBackupAt = DateTime.tryParse(value['lastBackupAt']?.toString() ?? '');
    lastBackupPath = value['lastBackupPath']?.toString();
    lastImportUndoPath = value['lastImportUndoPath']?.toString();
    _importHashes
      ..clear()
      ..addAll((value['importHashes'] as List? ?? const <dynamic>[]).map((item) => item.toString()));
  }

  Future<void> _saveMetadata() async {
    await _metadataFile.parent.create(recursive: true);
    await _metadataFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(metadata),
      flush: true,
    );
  }

  static double _convertWeight(double value, String? from, String to) {
    final source = from?.toLowerCase();
    final target = to.toLowerCase();
    if (source == null || source == target) return value;
    if (source == 'kg' && target == 'lb') return value * 2.2046226218;
    if (source == 'lb' && target == 'kg') return value / 2.2046226218;
    return value;
  }

  static String _timestamp(DateTime value) => value
      .toUtc()
      .toIso8601String()
      .replaceAll(':', '-')
      .replaceAll('.', '-');
}

class DataPortabilityCard extends StatelessWidget {
  const DataPortabilityCard({super.key, required this.store});
  final AppStore store;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: const Icon(Icons.cloud_sync_rounded),
      title: const Text('DATA & BACKUP'),
      subtitle: const Text('Automatic backup, restore, import, and export'),
      trailing: const Icon(Icons.arrow_forward_rounded),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => DataPortabilityScreen(store: store),
        ),
      ),
    ),
  );
}

class DataPortabilityScreen extends StatefulWidget {
  const DataPortabilityScreen({super.key, required this.store});
  final AppStore store;
  @override
  State<DataPortabilityScreen> createState() => _DataPortabilityScreenState();
}

class _DataPortabilityScreenState extends State<DataPortabilityScreen> {
  final service = DataPortabilityService.instance;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    service.initialize(widget.store);
  }

  Future<void> run(Future<void> Function() action, {String? success}) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await action();
      if (mounted && success != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(success)));
      }
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: service,
    builder: (context, _) => Scaffold(
      appBar: AppBar(title: const Text('Data & backup')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Card(
            child: SwitchListTile(
              value: service.automaticBackupsEnabled,
              onChanged: busy
                  ? null
                  : (value) => run(
                        () => service.setAutomaticBackupsEnabled(value),
                        success: value ? 'Automatic backup enabled.' : 'Automatic backup disabled.',
                      ),
              title: const Text('AUTOMATIC BACKUP'),
              subtitle: Text(service.lastBackupAt == null
                  ? 'No verified backup yet'
                  : 'Last verified: ${service.lastBackupAt!.toLocal()}'),
              secondary: const Icon(Icons.shield_outlined),
            ),
          ),
          const SizedBox(height: 14),
          _Section(
            title: 'BACKUP & RESTORE',
            children: [
              _ActionTile(
                icon: Icons.backup_rounded,
                title: 'Back up now',
                subtitle: 'Save an exact .plab backup',
                onTap: busy ? null : () => run(() async { await service.saveManualBackup(); }),
              ),
              _ActionTile(
                icon: Icons.settings_backup_restore_rounded,
                title: 'Restore backup',
                subtitle: 'Validate and restore all app data',
                onTap: busy ? null : _restore,
              ),
              _ActionTile(
                icon: Icons.verified_rounded,
                title: 'Test latest backup',
                subtitle: 'Check the archive and every checksum',
                onTap: busy ? null : () => run(service.testLatestBackup, success: 'Backup verified.'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _Section(
            title: 'EXPORT',
            children: [
              _ActionTile(
                icon: Icons.table_view_rounded,
                title: 'Portable CSV package',
                subtitle: 'Workouts, sets, exercises, and assessments',
                onTap: busy ? null : () => run(() async { await service.exportPortableCsv(); }),
              ),
              _ActionTile(
                icon: Icons.swap_horiz_rounded,
                title: 'Strong-compatible CSV',
                subtitle: 'Accepted by some workout apps, including Hevy',
                onTap: busy ? null : () => run(() async { await service.exportStrongCompatibleCsv(); }),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _Section(
            title: 'IMPORT',
            children: [
              _ActionTile(
                icon: Icons.file_open_rounded,
                title: 'Import workout CSV',
                subtitle: 'Strong, Hevy, FitNotes, or mapped CSV',
                onTap: busy ? null : _import,
              ),
              _ActionTile(
                icon: Icons.undo_rounded,
                title: 'Undo last import',
                subtitle: service.lastImportUndoPath == null
                    ? 'No import is available to undo'
                    : 'Restore the safety backup from before the import',
                onTap: busy || service.lastImportUndoPath == null
                    ? null
                    : () => run(service.undoLastImport, success: 'Import undone.'),
              ),
            ],
          ),
          if (busy) ...[
            const SizedBox(height: 18),
            const Center(child: CircularProgressIndicator()),
          ],
        ],
      ),
    ),
  );

  Future<void> _restore() => run(() async {
    final backup = await service.chooseBackup();
    if (backup == null || !mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore this backup?'),
        content: Text(
          'Created ${backup.manifest['createdAt'] ?? 'at an unknown time'}. '
          'A safety backup will be created before replacement.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('RESTORE')),
        ],
      ),
    );
    if (confirmed == true) await service.restoreChosenBackup(backup);
  }, success: 'Backup restored.');

  Future<void> _import() async {
    if (busy) return;
    setState(() => busy = true);
    try {
      ImportPreview? preview;
      try {
        preview = await service.chooseCsv();
      } on MappingRequired catch (needed) {
        if (!mounted) return;
        final mapping = await showDialog<GenericColumnMapping>(
          context: context,
          builder: (_) => _MappingDialog(headers: needed.headers),
        );
        if (mapping == null) return;
        preview = await service.chooseCsv(mapping: mapping);
      }
      if (preview == null || !mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => _ImportPreviewDialog(preview: preview!),
      );
      if (confirmed == true) {
        await service.commitImport(preview);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${preview.importableWorkoutCount} workouts imported.')),
          );
        }
      }
    } on Object catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(title, style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2)),
      ),
      Card(child: Column(children: children)),
    ],
  );
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.icon, required this.title, required this.subtitle, required this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon),
    title: Text(title),
    subtitle: Text(subtitle),
    trailing: const Icon(Icons.chevron_right_rounded),
    enabled: onTap != null,
    onTap: onTap,
  );
}

class _ImportPreviewDialog extends StatelessWidget {
  const _ImportPreviewDialog({required this.preview});
  final ImportPreview preview;
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('${preview.source.label} import'),
    content: SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('${preview.workoutCount} workouts · ${preview.setCount} sets'),
          Text('${preview.duplicateCount} duplicate workouts will be skipped'),
          Text('${preview.invalidRows} invalid rows will be ignored'),
          if (preview.assumedWeightUnit != null)
            Text('Unlabelled weights are assumed to be ${preview.assumedWeightUnit}.'),
          if (preview.unmatchedExercises.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text('New custom exercises:', style: TextStyle(fontWeight: FontWeight.bold)),
            Text(preview.unmatchedExercises.take(12).join(', ')),
          ],
          const SizedBox(height: 12),
          const Text('A verified safety backup is created before import.'),
        ],
      ),
    ),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL')),
      FilledButton(
        onPressed: preview.importableWorkoutCount == 0
            ? null
            : () => Navigator.pop(context, true),
        child: const Text('IMPORT'),
      ),
    ],
  );
}

class _MappingDialog extends StatefulWidget {
  const _MappingDialog({required this.headers});
  final List<String> headers;
  @override
  State<_MappingDialog> createState() => _MappingDialogState();
}

class _MappingDialogState extends State<_MappingDialog> {
  String? date;
  String? workout;
  String? exercise;
  String? setOrder;
  String? weight;
  String? weightUnit;
  String? reps;
  String? notes;

  @override
  void initState() {
    super.initState();
    date = _guess(const ['date', 'time', 'start']);
    workout = _guess(const ['workout', 'routine', 'session', 'title']);
    exercise = _guess(const ['exercise', 'movement', 'lift']);
    setOrder = _guess(const ['set', 'set order', 'set_index']);
    weight = _guess(const ['weight', 'load']);
    weightUnit = _guess(const ['weight unit', 'unit']);
    reps = _guess(const ['reps', 'repetitions']);
    notes = _guess(const ['notes', 'note', 'description']);
  }

  String? _guess(List<String> terms) {
    for (final header in widget.headers) {
      final normalized = header.toLowerCase();
      if (terms.any(normalized.contains)) return header;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Map CSV columns'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _field('Date *', date, (value) => setState(() => date = value)),
          _field('Workout', workout, (value) => setState(() => workout = value)),
          _field('Exercise *', exercise, (value) => setState(() => exercise = value)),
          _field('Set order', setOrder, (value) => setState(() => setOrder = value)),
          _field('Weight', weight, (value) => setState(() => weight = value)),
          _field('Weight unit', weightUnit, (value) => setState(() => weightUnit = value)),
          _field('Reps *', reps, (value) => setState(() => reps = value)),
          _field('Notes', notes, (value) => setState(() => notes = value)),
        ],
      ),
    ),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
      FilledButton(
        onPressed: date == null || exercise == null || reps == null
            ? null
            : () => Navigator.pop(
                  context,
                  GenericColumnMapping(
                    date: date!, exercise: exercise!, reps: reps!, workout: workout,
                    setOrder: setOrder, weight: weight, weightUnit: weightUnit, notes: notes,
                  ),
                ),
        child: const Text('PREVIEW'),
      ),
    ],
  );

  Widget _field(String label, String? value, ValueChanged<String?> changed) =>
      DropdownButtonFormField<String?>(
        initialValue: value,
        decoration: InputDecoration(labelText: label),
        items: <DropdownMenuItem<String?>>[
          const DropdownMenuItem<String?>(value: null, child: Text('Not mapped')),
          ...widget.headers.map((header) => DropdownMenuItem<String?>(value: header, child: Text(header))),
        ],
        onChanged: changed,
      );
}
'''


TEST_DART = r'''import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:progression_lab/data_portability.dart';

void main() {
  group('Progression Lab backup codec', () {
    test('round-trips exact state and verifies checksums', () {
      final state = <String, dynamic>{
        'schema': 7,
        'unit': 'lb',
        'week': 12,
        'logs': <Map<String, dynamic>>[
          <String, dynamic>{
            'exercise': 'Barbell Bench Press',
            'weight': 185,
            'reps': 5,
            'date': '2026-08-20T12:00:00.000Z',
          },
        ],
      };
      final bytes = PortabilityCodec.encodeBackup(
        state: state,
        portabilityMetadata: const <String, dynamic>{'automaticBackupsEnabled': true},
        appVersion: '1.6.0',
        platform: 'test',
        createdAt: DateTime.utc(2026, 8, 20),
      );
      final decoded = PortabilityCodec.decodeBackup(bytes);
      expect(decoded.state, state);
      expect(decoded.manifest['format'], portabilityFormat);
      expect(decoded.portabilityMetadata['automaticBackupsEnabled'], isTrue);
    });

    test('rejects a modified archive', () {
      final bytes = PortabilityCodec.encodeBackup(
        state: const <String, dynamic>{'unit': 'kg'},
        portabilityMetadata: const <String, dynamic>{},
        appVersion: '1.6.0',
        platform: 'test',
        createdAt: DateTime.utc(2026, 8, 20),
      );
      final corrupt = Uint8List.fromList(bytes);
      corrupt[corrupt.length ~/ 2] ^= 0x01;
      expect(() => PortabilityCodec.decodeBackup(corrupt), throwsA(anything));
    });
  });

  group('CSV migration', () {
    test('detects and parses Strong CSV', () {
      final csv = '''Date,Workout Name,Duration,Exercise Name,Set Order,Weight,Reps,Distance,Seconds,Notes,Workout Notes,RPE\n2026-08-19 18:30:00,Upper A,00:45:00,Barbell Bench Press,1,185,5,,,Paused,,8\n''';
      final preview = CsvImportParser.parse(Uint8List.fromList(utf8.encode(csv)));
      expect(preview.source, WorkoutImportSource.strong);
      expect(preview.workoutCount, 1);
      expect(preview.setCount, 1);
      expect(preview.sessions.single.sets.single.weight, 185);
    });

    test('detects and parses Hevy CSV', () {
      final csv = '''title,start_time,end_time,description,exercise_title,superset_id,exercise_notes,set_index,set_type,weight_kg,reps,distance_km,duration_seconds,rpe\nPull,2026-08-19T18:30:00Z,2026-08-19T19:00:00Z,,Lat Pulldown,,Controlled,0,normal,70,8,,,7.5\n''';
      final preview = CsvImportParser.parse(Uint8List.fromList(utf8.encode(csv)));
      expect(preview.source, WorkoutImportSource.hevy);
      expect(preview.sessions.single.sets.single.weightUnit, 'kg');
      expect(preview.sessions.single.sets.single.rpe, 7.5);
    });

    test('detects and parses FitNotes CSV', () {
      final csv = '''Date,Exercise,Category,Weight (kg),Weight (lbs),Reps,Distance,Distance Unit,Time,Notes,Kind\n2026-08-19,Belt Squat,Legs,100,,10,,,00:45,Smooth,wr\n''';
      final preview = CsvImportParser.parse(Uint8List.fromList(utf8.encode(csv)));
      expect(preview.source, WorkoutImportSource.fitNotes);
      expect(preview.sessions.single.title, 'Legs');
      expect(preview.sessions.single.sets.single.durationSeconds, 45);
    });

    test('requires mapping for an unknown CSV and accepts explicit mapping', () {
      final csv = '''When,Routine,Movement,Load,Count\n2026-08-19,Push,Push Up,0,20\n''';
      final bytes = Uint8List.fromList(utf8.encode(csv));
      expect(() => CsvImportParser.parse(bytes), throwsA(isA<MappingRequired>()));
      final preview = CsvImportParser.parse(
        bytes,
        mapping: const GenericColumnMapping(
          date: 'When', workout: 'Routine', exercise: 'Movement',
          weight: 'Load', reps: 'Count',
        ),
      );
      expect(preview.source, WorkoutImportSource.generic);
      expect(preview.sessions.single.sets.single.reps, 20);
    });

    test('session signatures are deterministic', () {
      ImportedSession session() => ImportedSession(
        title: 'Upper A',
        startedAt: DateTime.utc(2026, 8, 20),
        sets: const <ImportedSet>[
          ImportedSet(exercise: 'Bench Press', order: 1, reps: 5, weight: 100, weightUnit: 'kg'),
        ],
      );
      expect(session().signature, session().signature);
    });
  });
}
'''


DATA_DOC = '''# Progression Lab data portability\n\nProgression Lab keeps workout data local and provides open backup and CSV formats.\n\n## Exact `.plab` backup\n\nA `.plab` file is a ZIP archive containing:\n\n- `manifest.json` — format, schema, app version, creation time, platform, unit system, and reason.\n- `state.json` — the canonical exact-restoration state.\n- `workouts.json`, `sets.json`, `exercises.json`, `program_state.json`, `athletic_history.json`, and `settings.json` — readable logical views.\n- `portability_metadata.json` — backup and import metadata.\n- `checksums.json` — SHA-256 for every preceding entry.\n\nThe current public backup schema is `1`. Restores reject newer unsupported schemas and any checksum mismatch.\n\n## Automatic backup\n\nAutomatic backup runs after persisted app-state changes. Retention keeps the union of:\n\n- the five newest backups,\n- the newest backup from each of the seven newest days, and\n- the newest backup from each of the four newest weeks.\n\nImports and restores always create a verified safety backup first. The last import can be undone from the Data & Backup screen.\n\n## Portable CSV package\n\nThe ZIP export contains `workouts.csv`, `sets.csv`, `exercises.csv`, and `athletic_assessments.csv`. Timestamps use ISO-8601 and unit columns are explicit. CSV is intended for migration and analysis, not exact app restoration.\n\n## Strong-compatible CSV\n\nProgression Lab can export the common Strong-style workout CSV accepted by some workout apps, including Hevy. Strong itself does not currently import its exported history.\n\n## Supported imports\n\n- Strong CSV\n- Hevy CSV\n- FitNotes CSV\n- Generic CSV through explicit column mapping\n\nAll imports are parsed into a staging model, previewed, checked for duplicates, backed up, and committed as one transaction. Unknown exercise names are retained as custom exercises.\n'''


def modify_main(path: Path) -> None:
    text = path.read_text()
    if "data_portability.dart" not in text:
        imports = list(re.finditer(r"^import '[^']+';\n", text, re.M))
        if not imports:
            raise ValueError("Could not find import insertion point in main.dart")
        pos = imports[-1].end()
        text = text[:pos] + "import 'data_portability.dart';\n" + text[pos:]
    if "DataPortabilityService.instance.initialize" not in text:
        text, count = re.subn(
            r"(^\s*)store\.load\(\);",
            r"\1store.load().then((_) => DataPortabilityService.instance.initialize(store));",
            text,
            count=1,
            flags=re.M,
        )
        if count != 1:
            raise ValueError("Could not initialize DataPortabilityService from main.dart")
    if "DataPortabilityCard(store: store)" not in text:
        start = text.find("class SettingsPage")
        if start < 0:
            raise ValueError("Could not find SettingsPage")
        end = text.find("\nclass ", start + 20)
        if end < 0:
            end = len(text)
        region = text[start:end]
        candidates = []
        for marker in ("ListView(", "SliverList.list(", "Column("):
            local = region.find(marker)
            if local >= 0:
                children = region.find("children: [", local)
                if children >= 0:
                    candidates.append(children)
        if not candidates:
            raise ValueError("Could not find SettingsPage children list")
        local_children = min(candidates)
        insert_at = start + local_children + len("children: [")
        text = text[:insert_at] + "\n          DataPortabilityCard(store: store),\n          const SizedBox(height: 16)," + text[insert_at:]
    path.write_text(text)


def bump_version(root: Path) -> None:
    pubspec = root / "pubspec.yaml"
    text = pubspec.read_text()
    text = re.sub(r"^version:\s*[^\n]+", "version: 1.6.0+9", text, count=1, flags=re.M)
    for name, version in (
        ("archive", "^4.0.7"),
        ("crypto", "^3.0.6"),
        ("csv", "^6.0.0"),
        ("file_picker", "^10.3.3"),
        ("path_provider", "^2.1.5"),
    ):
        text = add_dependency(text, name, version)
    pubspec.write_text(text)

    gradle = root / "android/app/build.gradle.kts"
    if gradle.exists():
        g = gradle.read_text()
        g = re.sub(r"versionCode\s*=\s*\d+", "versionCode = 9", g)
        g = re.sub(r'versionName\s*=\s*"[^"]+"', 'versionName = "1.6.0"', g)
        gradle.write_text(g)

    changelog = root / "CHANGELOG.md"
    if changelog.exists():
        c = changelog.read_text()
        entry = '''# Changelog\n\n## 1.6.0+9 — 2026-08-20\n\n### Added\n\n- Exact, checksum-verified `.plab` backup and transactional restore.\n- Automatic rolling backups and pre-import/pre-restore safety backups.\n- Portable CSV and Strong-compatible CSV exports.\n- Strong, Hevy, FitNotes, and mapped generic CSV imports.\n- Import preview, duplicate skipping, custom-exercise preservation, and undo.\n- An open data-portability schema and in-app Data & Backup controls.\n\n'''
        if c.startswith("# Changelog\n"):
            c = entry + c[len("# Changelog\n\n"):]
        else:
            c = entry + c
        changelog.write_text(c)


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit("usage: generate_data_portability.py PROJECT_ROOT")
    root = Path(sys.argv[1]).resolve()
    modify_store(root / "lib/store.dart")
    (root / "lib/data_portability.dart").write_text(DATA_PORTABILITY_DART)
    modify_main(root / "lib/main.dart")
    (root / "test/data_portability_test.dart").write_text(TEST_DART)
    (root / "DATA_PORTABILITY.md").write_text(DATA_DOC)
    bump_version(root)
    print("Generated Progression Lab data portability implementation")


if __name__ == "__main__":
    main()
