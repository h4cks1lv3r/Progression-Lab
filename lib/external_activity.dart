import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data_portability_bridge.dart';
import 'data_portability_core.dart';

enum ExternalActivitySource {
  fit,
  tcx,
  gpx,
  strava,
  garmin,
  healthPlatform,
  other,
}

class ExternalActivity {
  const ExternalActivity({
    required this.id,
    required this.source,
    required this.name,
    required this.activityType,
    required this.start,
    required this.end,
    required this.importedAt,
    this.distanceMeters,
    this.calories,
    this.averageHeartRate,
    this.averageCadence,
    this.averagePowerWatts,
    this.notes = '',
    this.sourceFile = '',
  });

  final String id;
  final ExternalActivitySource source;
  final String name;
  final String activityType;
  final DateTime start;
  final DateTime end;
  final DateTime importedAt;
  final double? distanceMeters;
  final double? calories;
  final double? averageHeartRate;
  final double? averageCadence;
  final double? averagePowerWatts;
  final String notes;
  final String sourceFile;

  Duration get duration => end.difference(start);

  String get fingerprint => [
    source.name,
    start.toUtc().toIso8601String(),
    end.toUtc().toIso8601String(),
    activityType.toLowerCase(),
    (distanceMeters ?? 0).round(),
  ].join('|');

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'source': source.name,
    'name': name,
    'activityType': activityType,
    'start': start.toIso8601String(),
    'end': end.toIso8601String(),
    'importedAt': importedAt.toIso8601String(),
    if (distanceMeters != null) 'distanceMeters': distanceMeters,
    if (calories != null) 'calories': calories,
    if (averageHeartRate != null) 'averageHeartRate': averageHeartRate,
    if (averageCadence != null) 'averageCadence': averageCadence,
    if (averagePowerWatts != null) 'averagePowerWatts': averagePowerWatts,
    if (notes.isNotEmpty) 'notes': notes,
    if (sourceFile.isNotEmpty) 'sourceFile': sourceFile,
  };

  factory ExternalActivity.fromJson(Map<String, dynamic> json) =>
      ExternalActivity(
        id: '${json['id']}',
        source: ExternalActivitySource.values.firstWhere(
          (value) => value.name == json['source'],
          orElse: () => ExternalActivitySource.other,
        ),
        name: '${json['name'] ?? 'Imported activity'}',
        activityType: '${json['activityType'] ?? 'Other'}',
        start: DateTime.parse('${json['start']}'),
        end: DateTime.parse('${json['end']}'),
        importedAt: DateTime.parse('${json['importedAt']}'),
        distanceMeters: _double(json['distanceMeters']),
        calories: _double(json['calories']),
        averageHeartRate: _double(json['averageHeartRate']),
        averageCadence: _double(json['averageCadence']),
        averagePowerWatts: _double(json['averagePowerWatts']),
        notes: '${json['notes'] ?? ''}',
        sourceFile: '${json['sourceFile'] ?? ''}',
      );

  static double? _double(Object? value) =>
      value is num ? value.toDouble() : double.tryParse('$value');
}

class ExternalActivityRepository {
  static const _key = 'progression_lab_external_activities_v1';

  Future<List<ExternalActivity>> load() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_key);
    if (raw == null || raw.isEmpty) return <ExternalActivity>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <ExternalActivity>[];
      final values = <ExternalActivity>[];
      for (final item in decoded) {
        if (item is! Map) continue;
        try {
          values.add(
            ExternalActivity.fromJson(Map<String, dynamic>.from(item)),
          );
        } on Object {
          // Keep the usable records when one historical row is malformed.
        }
      }
      values.sort((a, b) => b.start.compareTo(a.start));
      return values;
    } on Object {
      return <ExternalActivity>[];
    }
  }

  Future<int> addAll(Iterable<ExternalActivity> activities) async {
    final current = await load();
    final fingerprints = current.map((item) => item.fingerprint).toSet();
    var added = 0;
    for (final activity in activities) {
      if (!fingerprints.add(activity.fingerprint)) continue;
      current.add(activity);
      added++;
    }
    current.sort((a, b) => b.start.compareTo(a.start));
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _key,
      jsonEncode(current.map((item) => item.toJson()).toList()),
    );
    return added;
  }

  Future<void> clear() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_key);
  }
}

class ExternalActivityImportResult {
  const ExternalActivityImportResult({
    required this.fileName,
    required this.activities,
    required this.warnings,
  });

  final String fileName;
  final List<ExternalActivity> activities;
  final List<String> warnings;
}

abstract final class ExternalActivityImporter {
  static Future<ExternalActivityImportResult?> pickAndParse() async {
    final file = await DataPortabilityBridge.pickFile();
    if (file == null) return null;
    return parse(file);
  }

  static ExternalActivityImportResult parse(PortablePickedFile file) {
    final lower = file.name.toLowerCase();
    if (lower.endsWith('.fit')) {
      return ExternalActivityImportResult(
        fileName: file.name,
        activities: <ExternalActivity>[_FitDecoder.decode(file)],
        warnings: const <String>[],
      );
    }
    if (lower.endsWith('.tcx')) {
      return ExternalActivityImportResult(
        fileName: file.name,
        activities: _parseTcx(file.name, file.bytes),
        warnings: const <String>[],
      );
    }
    if (lower.endsWith('.gpx')) {
      return ExternalActivityImportResult(
        fileName: file.name,
        activities: <ExternalActivity>[_parseGpx(file.name, file.bytes)],
        warnings: const <String>[],
      );
    }
    if (lower.endsWith('.zip')) return _parseZip(file);
    throw const FormatException(
      'Choose a FIT, TCX, GPX, Strava export ZIP, or Garmin export ZIP.',
    );
  }

  static ExternalActivityImportResult _parseZip(PortablePickedFile file) {
    final archive = ZipDecoder().decodeBytes(file.bytes, verify: true);
    final activities = <ExternalActivity>[];
    final warnings = <String>[];
    final csvEntries = <ArchiveFile>[];

    for (final entry in archive.files) {
      if (!entry.isFile) continue;
      final name = entry.name.toLowerCase();
      final bytes = Uint8List.fromList(entry.content as List<int>);
      try {
        if (name.endsWith('.fit')) {
          activities.add(
            _FitDecoder.decode(
              PortablePickedFile(name: entry.name, bytes: bytes),
            ),
          );
        } else if (name.endsWith('.tcx')) {
          activities.addAll(_parseTcx(entry.name, bytes));
        } else if (name.endsWith('.gpx')) {
          activities.add(_parseGpx(entry.name, bytes));
        } else if (name.endsWith('activities.csv')) {
          csvEntries.add(entry);
        }
      } on Object catch (error) {
        warnings.add('${entry.name}: $error');
      }
    }

    // Strava bulk exports include activities.csv even when original activity
    // files are unavailable. Use it only for sessions not already represented
    // by FIT, TCX, or GPX files.
    for (final entry in csvEntries) {
      final bytes = Uint8List.fromList(entry.content as List<int>);
      final summaries = _parseStravaCsv(entry.name, bytes);
      final known = activities.map((item) => item.fingerprint).toSet();
      for (final summary in summaries) {
        if (known.add(summary.fingerprint)) activities.add(summary);
      }
    }

    if (activities.isEmpty && warnings.isEmpty) {
      warnings.add('No supported activity files were found in this archive.');
    }
    activities.sort((a, b) => b.start.compareTo(a.start));
    return ExternalActivityImportResult(
      fileName: file.name,
      activities: activities,
      warnings: warnings,
    );
  }

  static List<ExternalActivity> _parseStravaCsv(
    String fileName,
    Uint8List bytes,
  ) {
    final rows = CsvCodec.decode(utf8.decode(bytes, allowMalformed: true));
    if (rows.length < 2) return <ExternalActivity>[];
    final header = <String, int>{};
    for (var index = 0; index < rows.first.length; index++) {
      header[_normal(rows.first[index])] = index;
    }

    String cell(List<String> row, Iterable<String> names) {
      for (final name in names) {
        final index = header[_normal(name)];
        if (index != null && index < row.length) return row[index].trim();
      }
      return '';
    }

    final activities = <ExternalActivity>[];
    for (final row in rows.skip(1)) {
      final start = _parseDate(
        cell(row, const <String>['Activity Date', 'Start Date', 'Date']),
      );
      if (start == null) continue;
      final elapsedSeconds = _number(
            cell(row, const <String>['Elapsed Time', 'Moving Time']),
          ) ??
          0;
      final duration = Duration(seconds: math.max(1, elapsedSeconds.round()));
      final distanceText = cell(row, const <String>['Distance']);
      final distance = _number(distanceText);
      final type = cell(row, const <String>['Activity Type', 'Type']);
      final name = cell(row, const <String>['Activity Name', 'Name']);
      final id = cell(row, const <String>['Activity ID', 'ID']);
      activities.add(
        ExternalActivity(
          id: id.isEmpty ? _id('strava', start, name) : 'strava-$id',
          source: ExternalActivitySource.strava,
          name: name.isEmpty ? (type.isEmpty ? 'Strava activity' : type) : name,
          activityType: type.isEmpty ? 'Other' : type,
          start: start,
          end: start.add(duration),
          importedAt: DateTime.now(),
          // Strava's bulk CSV commonly reports kilometres. Keep an explicit
          // conservative conversion for summaries; original FIT/TCX/GPX files
          // override these rows when available.
          distanceMeters: distance == null ? null : distance * 1000,
          sourceFile: fileName,
        ),
      );
    }
    return activities;
  }

  static List<ExternalActivity> _parseTcx(String fileName, Uint8List bytes) {
    final text = utf8.decode(bytes, allowMalformed: true);
    final activities = <ExternalActivity>[];
    final activityPattern = RegExp(
      r'<Activity\b([^>]*)>([\s\S]*?)</Activity>',
      caseSensitive: false,
    );
    for (final match in activityPattern.allMatches(text)) {
      final attributes = match.group(1) ?? '';
      final body = match.group(2) ?? '';
      final type = _attribute(attributes, 'Sport') ?? 'Other';
      final start = _parseDate(_tag(body, 'Id')) ??
          _parseDate(_tag(body, 'Time'));
      if (start == null) continue;
      final seconds = _number(_tag(body, 'TotalTimeSeconds')) ?? 1;
      final end = start.add(Duration(seconds: math.max(1, seconds.round())));
      final distance = _number(_tag(body, 'DistanceMeters'));
      final calories = _number(_tag(body, 'Calories'));
      final heartRate = _number(
        _tag(_block(body, 'AverageHeartRateBpm') ?? '', 'Value'),
      );
      final cadence = _number(_tag(body, 'Cadence'));
      activities.add(
        ExternalActivity(
          id: _id('tcx', start, fileName),
          source: _sourceForFile(fileName, ExternalActivitySource.tcx),
          name: type,
          activityType: type,
          start: start,
          end: end,
          importedAt: DateTime.now(),
          distanceMeters: distance,
          calories: calories,
          averageHeartRate: heartRate,
          averageCadence: cadence,
          sourceFile: fileName,
        ),
      );
    }
    if (activities.isEmpty) {
      throw const FormatException('The TCX file contains no readable activities.');
    }
    return activities;
  }

  static ExternalActivity _parseGpx(String fileName, Uint8List bytes) {
    final text = utf8.decode(bytes, allowMalformed: true);
    final times = RegExp(
      r'<time>([^<]+)</time>',
      caseSensitive: false,
    ).allMatches(text).map((match) => _parseDate(match.group(1))).whereType<DateTime>().toList();
    if (times.isEmpty) {
      throw const FormatException('The GPX file contains no readable timestamps.');
    }
    times.sort();
    final points = <({double latitude, double longitude})>[];
    final pointPattern = RegExp(
      r'<trkpt\b([^>]*)>',
      caseSensitive: false,
    );
    for (final match in pointPattern.allMatches(text)) {
      final attributes = match.group(1) ?? '';
      final latitude = double.tryParse(_attribute(attributes, 'lat') ?? '');
      final longitude = double.tryParse(_attribute(attributes, 'lon') ?? '');
      if (latitude != null && longitude != null) {
        points.add((latitude: latitude, longitude: longitude));
      }
    }
    var distance = 0.0;
    for (var index = 1; index < points.length; index++) {
      distance += _haversine(points[index - 1], points[index]);
    }
    final heartRates = RegExp(
      r'<(?:[\w]+:)?hr>(\d+(?:\.\d+)?)</(?:[\w]+:)?hr>',
      caseSensitive: false,
    ).allMatches(text).map((match) => double.parse(match.group(1)!)).toList();
    final name = _tag(text, 'name') ?? 'GPX activity';
    return ExternalActivity(
      id: _id('gpx', times.first, fileName),
      source: _sourceForFile(fileName, ExternalActivitySource.gpx),
      name: name,
      activityType: _guessActivityType(name),
      start: times.first,
      end: times.last.isAfter(times.first)
          ? times.last
          : times.first.add(const Duration(seconds: 1)),
      importedAt: DateTime.now(),
      distanceMeters: distance > 0 ? distance : null,
      averageHeartRate: heartRates.isEmpty
          ? null
          : heartRates.reduce((a, b) => a + b) / heartRates.length,
      sourceFile: fileName,
    );
  }

  static ExternalActivitySource _sourceForFile(
    String fileName,
    ExternalActivitySource fallback,
  ) {
    final lower = fileName.toLowerCase();
    if (lower.contains('strava')) return ExternalActivitySource.strava;
    if (lower.contains('garmin')) return ExternalActivitySource.garmin;
    return fallback;
  }

  static String _guessActivityType(String name) {
    final value = name.toLowerCase();
    if (value.contains('run')) return 'Running';
    if (value.contains('ride') || value.contains('bike')) return 'Cycling';
    if (value.contains('walk')) return 'Walking';
    if (value.contains('swim')) return 'Swimming';
    if (value.contains('row')) return 'Rowing';
    if (value.contains('strength') || value.contains('weight')) {
      return 'Strength Training';
    }
    return 'Other';
  }

  static String _normal(String value) => value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .trim();

  static double? _number(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return double.tryParse(value.replaceAll(',', '').trim());
  }

  static DateTime? _parseDate(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final direct = DateTime.tryParse(value.trim());
    if (direct != null) return direct;
    final match = RegExp(
      r'^(\d{1,2})/(\d{1,2})/(\d{4})\s+(\d{1,2}):(\d{2})(?::(\d{2}))?',
    ).firstMatch(value.trim());
    if (match == null) return null;
    return DateTime(
      int.parse(match.group(3)!),
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(4)!),
      int.parse(match.group(5)!),
      int.tryParse(match.group(6) ?? '') ?? 0,
    );
  }

  static String? _tag(String text, String name) {
    final match = RegExp(
      '<(?:[\\w]+:)?$name\\b[^>]*>([^<]+)</(?:[\\w]+:)?$name>',
      caseSensitive: false,
    ).firstMatch(text);
    return match?.group(1)?.trim();
  }

  static String? _block(String text, String name) {
    final match = RegExp(
      '<(?:[\\w]+:)?$name\\b[^>]*>([\\s\\S]*?)</(?:[\\w]+:)?$name>',
      caseSensitive: false,
    ).firstMatch(text);
    return match?.group(1);
  }

  static String? _attribute(String attributes, String name) {
    final match = RegExp(
      '$name\\s*=\\s*["\']([^"\']+)["\']',
      caseSensitive: false,
    ).firstMatch(attributes);
    return match?.group(1);
  }

  static String _id(String source, DateTime start, String name) {
    final seed = '$source|${start.toUtc().toIso8601String()}|$name';
    var hash = 0x811c9dc5;
    for (final unit in utf8.encode(seed)) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return '$source-${hash.toRadixString(16).padLeft(8, '0')}';
  }

  static double _haversine(
    ({double latitude, double longitude}) a,
    ({double latitude, double longitude}) b,
  ) {
    const radius = 6371000.0;
    final lat1 = a.latitude * math.pi / 180;
    final lat2 = b.latitude * math.pi / 180;
    final deltaLat = (b.latitude - a.latitude) * math.pi / 180;
    final deltaLon = (b.longitude - a.longitude) * math.pi / 180;
    final value = math.sin(deltaLat / 2) * math.sin(deltaLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(deltaLon / 2) *
            math.sin(deltaLon / 2);
    return radius * 2 * math.atan2(math.sqrt(value), math.sqrt(1 - value));
  }
}

class _FitFieldDefinition {
  const _FitFieldDefinition(this.number, this.size, this.baseType);

  final int number;
  final int size;
  final int baseType;
}

class _FitDefinition {
  const _FitDefinition({
    required this.littleEndian,
    required this.globalMessage,
    required this.fields,
    required this.developerFieldBytes,
  });

  final bool littleEndian;
  final int globalMessage;
  final List<_FitFieldDefinition> fields;
  final int developerFieldBytes;
}

abstract final class _FitDecoder {
  static const _fitEpochSeconds = 631065600;

  static ExternalActivity decode(PortablePickedFile file) {
    final bytes = file.bytes;
    if (bytes.length < 12) {
      throw const FormatException('The FIT file is too short.');
    }
    final headerSize = bytes[0];
    if (headerSize < 12 || headerSize > bytes.length) {
      throw const FormatException('The FIT header is invalid.');
    }
    if (ascii.decode(bytes.sublist(8, 12), allowInvalid: true) != '.FIT') {
      throw const FormatException('The selected file is not a FIT activity.');
    }
    final view = ByteData.sublistView(bytes);
    final dataSize = view.getUint32(4, Endian.little);
    final dataEnd = math.min(bytes.length, headerSize + dataSize);
    final definitions = <int, _FitDefinition>{};
    var offset = headerSize;
    int? lastTimestamp;
    DateTime? start;
    DateTime? end;
    double? distance;
    double? calories;
    final heartRates = <double>[];
    final cadences = <double>[];
    final powers = <double>[];
    String sport = 'Other';

    while (offset < dataEnd) {
      final header = bytes[offset++];
      if ((header & 0x80) != 0) {
        final localMessage = (header >> 5) & 0x03;
        final timeOffset = header & 0x1f;
        final definition = definitions[localMessage];
        if (definition == null) {
          throw const FormatException('FIT compressed record has no definition.');
        }
        if (lastTimestamp != null) {
          var timestamp = (lastTimestamp! & ~0x1f) + timeOffset;
          if (timestamp < lastTimestamp!) timestamp += 0x20;
          lastTimestamp = timestamp;
        }
        final parsed = _dataMessage(bytes, offset, definition);
        offset = parsed.offset;
        final values = parsed.values;
        if (lastTimestamp != null && !values.containsKey(253)) {
          values[253] = lastTimestamp;
        }
        final result = _consume(
          definition.globalMessage,
          values,
          start,
          end,
          distance,
          calories,
          sport,
          heartRates,
          cadences,
          powers,
        );
        start = result.start;
        end = result.end;
        distance = result.distance;
        calories = result.calories;
        sport = result.sport;
        continue;
      }

      final definitionMessage = (header & 0x40) != 0;
      final developerData = (header & 0x20) != 0;
      final localMessage = header & 0x0f;
      if (definitionMessage) {
        if (offset + 5 > dataEnd) {
          throw const FormatException('Truncated FIT definition.');
        }
        offset++; // reserved
        final architecture = bytes[offset++];
        final little = architecture == 0;
        final globalMessage = _uint16(bytes, offset, little);
        offset += 2;
        final fieldCount = bytes[offset++];
        final fields = <_FitFieldDefinition>[];
        for (var index = 0; index < fieldCount; index++) {
          if (offset + 3 > dataEnd) {
            throw const FormatException('Truncated FIT field definition.');
          }
          fields.add(
            _FitFieldDefinition(
              bytes[offset],
              bytes[offset + 1],
              bytes[offset + 2] & 0x1f,
            ),
          );
          offset += 3;
        }
        var developerBytes = 0;
        if (developerData) {
          if (offset >= dataEnd) {
            throw const FormatException('Truncated FIT developer definition.');
          }
          final developerCount = bytes[offset++];
          for (var index = 0; index < developerCount; index++) {
            if (offset + 3 > dataEnd) {
              throw const FormatException('Truncated FIT developer field.');
            }
            developerBytes += bytes[offset + 1];
            offset += 3;
          }
        }
        definitions[localMessage] = _FitDefinition(
          littleEndian: little,
          globalMessage: globalMessage,
          fields: fields,
          developerFieldBytes: developerBytes,
        );
      } else {
        final definition = definitions[localMessage];
        if (definition == null) {
          throw const FormatException('FIT data record has no definition.');
        }
        final parsed = _dataMessage(bytes, offset, definition);
        offset = parsed.offset;
        final values = parsed.values;
        if (values[253] case final num timestamp) {
          lastTimestamp = timestamp.toInt();
        }
        final result = _consume(
          definition.globalMessage,
          values,
          start,
          end,
          distance,
          calories,
          sport,
          heartRates,
          cadences,
          powers,
        );
        start = result.start;
        end = result.end;
        distance = result.distance;
        calories = result.calories;
        sport = result.sport;
      }
    }

    final safeStart = start ?? end;
    if (safeStart == null) {
      throw const FormatException('The FIT file contains no readable activity time.');
    }
    final safeEnd = end != null && end!.isAfter(safeStart)
        ? end!
        : safeStart.add(const Duration(seconds: 1));
    return ExternalActivity(
      id: ExternalActivityImporter._id('fit', safeStart, file.name),
      source: ExternalActivityImporter._sourceForFile(
        file.name,
        ExternalActivitySource.fit,
      ),
      name: sport,
      activityType: sport,
      start: safeStart,
      end: safeEnd,
      importedAt: DateTime.now(),
      distanceMeters: distance,
      calories: calories,
      averageHeartRate: _average(heartRates),
      averageCadence: _average(cadences),
      averagePowerWatts: _average(powers),
      sourceFile: file.name,
    );
  }

  static ({int offset, Map<int, Object?> values}) _dataMessage(
    Uint8List bytes,
    int offset,
    _FitDefinition definition,
  ) {
    final values = <int, Object?>{};
    for (final field in definition.fields) {
      if (offset + field.size > bytes.length) {
        throw const FormatException('Truncated FIT data field.');
      }
      values[field.number] = _fieldValue(
        bytes,
        offset,
        field.size,
        field.baseType,
        definition.littleEndian,
      );
      offset += field.size;
    }
    offset += definition.developerFieldBytes;
    return (offset: offset, values: values);
  }

  static Object? _fieldValue(
    Uint8List bytes,
    int offset,
    int size,
    int baseType,
    bool little,
  ) {
    if (size <= 0) return null;
    final endian = little ? Endian.little : Endian.big;
    final view = ByteData.sublistView(bytes, offset, offset + size);
    switch (baseType) {
      case 0: // enum
      case 2: // uint8
      case 10: // uint8z
        return bytes[offset] == 0xff ? null : bytes[offset];
      case 1: // sint8
        final value = view.getInt8(0);
        return value == 0x7f ? null : value;
      case 3: // sint16
        if (size < 2) return null;
        final value = view.getInt16(0, endian);
        return value == 0x7fff ? null : value;
      case 4: // uint16
      case 11: // uint16z
        if (size < 2) return null;
        final value = view.getUint16(0, endian);
        return value == 0xffff ? null : value;
      case 5: // sint32
        if (size < 4) return null;
        final value = view.getInt32(0, endian);
        return value == 0x7fffffff ? null : value;
      case 6: // uint32
      case 12: // uint32z
        if (size < 4) return null;
        final value = view.getUint32(0, endian);
        return value == 0xffffffff ? null : value;
      case 7: // string
        return utf8
            .decode(bytes.sublist(offset, offset + size), allowMalformed: true)
            .split('\u0000')
            .first;
      case 8: // float32
        if (size < 4) return null;
        final value = view.getFloat32(0, endian);
        return value.isFinite ? value : null;
      case 9: // float64
        if (size < 8) return null;
        final value = view.getFloat64(0, endian);
        return value.isFinite ? value : null;
      default:
        return null;
    }
  }

  static ({
    DateTime? start,
    DateTime? end,
    double? distance,
    double? calories,
    String sport,
  }) _consume(
    int globalMessage,
    Map<int, Object?> values,
    DateTime? start,
    DateTime? end,
    double? distance,
    double? calories,
    String sport,
    List<double> heartRates,
    List<double> cadences,
    List<double> powers,
  ) {
    DateTime? timestamp(Object? value) {
      if (value is! num) return null;
      return DateTime.fromMillisecondsSinceEpoch(
        (value.toInt() + _fitEpochSeconds) * 1000,
        isUtc: true,
      );
    }

    if (globalMessage == 20) {
      final time = timestamp(values[253]);
      if (time != null) {
        start ??= time;
        if (end == null || time.isAfter(end)) end = time;
      }
      if (values[5] is num) distance = (values[5] as num).toDouble() / 100;
      if (values[3] is num) heartRates.add((values[3] as num).toDouble());
      if (values[4] is num) cadences.add((values[4] as num).toDouble());
      if (values[7] is num) powers.add((values[7] as num).toDouble());
    } else if (globalMessage == 18) {
      start = timestamp(values[2]) ?? start;
      end = timestamp(values[253]) ?? end;
      if (values[9] is num) distance = (values[9] as num).toDouble() / 100;
      if (values[11] is num) calories = (values[11] as num).toDouble();
      if (values[5] is num) sport = _sport((values[5] as num).toInt());
      final timer = values[8];
      if (start != null && timer is num) {
        final candidate = start.add(
          Duration(milliseconds: timer.toDouble().round()),
        );
        if (end == null || candidate.isAfter(end)) end = candidate;
      }
    }
    return (
      start: start,
      end: end,
      distance: distance,
      calories: calories,
      sport: sport,
    );
  }

  static String _sport(int value) => switch (value) {
    1 => 'Running',
    2 => 'Cycling',
    3 => 'Transition',
    4 => 'Fitness Equipment',
    5 => 'Swimming',
    11 => 'Walking',
    15 => 'Hiking',
    16 => 'Multisport',
    17 => 'Paddling',
    20 => 'Training',
    21 => 'Strength Training',
    22 => 'Cardio Training',
    24 => 'Rowing',
    25 => 'Mountaineering',
    _ => 'FIT activity',
  };

  static int _uint16(Uint8List bytes, int offset, bool little) {
    final view = ByteData.sublistView(bytes, offset, offset + 2);
    return view.getUint16(0, little ? Endian.little : Endian.big);
  }

  static double? _average(List<double> values) => values.isEmpty
      ? null
      : values.reduce((a, b) => a + b) / values.length;
}
