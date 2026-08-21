import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:xml/xml.dart';

enum ExternalWorkoutFormat { fit, tcx, gpx }

enum ExternalWorkoutSource { file, strava, garmin, healthConnect, appleHealth }

class ExternalWorkoutPoint {
  const ExternalWorkoutPoint({
    this.time,
    this.latitude,
    this.longitude,
    this.altitudeMeters,
    this.distanceMeters,
    this.speedMetersPerSecond,
    this.heartRate,
    this.cadence,
    this.powerWatts,
  });

  final DateTime? time;
  final double? latitude;
  final double? longitude;
  final double? altitudeMeters;
  final double? distanceMeters;
  final double? speedMetersPerSecond;
  final int? heartRate;
  final int? cadence;
  final int? powerWatts;

  Map<String, dynamic> toJson() => <String, dynamic>{
        if (time != null) 'time': time!.toUtc().toIso8601String(),
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (altitudeMeters != null) 'altitudeMeters': altitudeMeters,
        if (distanceMeters != null) 'distanceMeters': distanceMeters,
        if (speedMetersPerSecond != null)
          'speedMetersPerSecond': speedMetersPerSecond,
        if (heartRate != null) 'heartRate': heartRate,
        if (cadence != null) 'cadence': cadence,
        if (powerWatts != null) 'powerWatts': powerWatts,
      };
}

class ExternalWorkout {
  const ExternalWorkout({
    required this.id,
    required this.source,
    required this.format,
    required this.title,
    required this.sport,
    required this.startedAt,
    required this.endedAt,
    this.distanceMeters,
    this.durationSeconds,
    this.calories,
    this.averageHeartRate,
    this.maximumHeartRate,
    this.averageCadence,
    this.averagePowerWatts,
    this.notes = '',
    this.points = const <ExternalWorkoutPoint>[],
    this.metadata = const <String, dynamic>{},
  });

  final String id;
  final ExternalWorkoutSource source;
  final ExternalWorkoutFormat format;
  final String title;
  final String sport;
  final DateTime startedAt;
  final DateTime endedAt;
  final double? distanceMeters;
  final double? durationSeconds;
  final int? calories;
  final int? averageHeartRate;
  final int? maximumHeartRate;
  final int? averageCadence;
  final int? averagePowerWatts;
  final String notes;
  final List<ExternalWorkoutPoint> points;
  final Map<String, dynamic> metadata;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'source': source.name,
        'format': format.name,
        'title': title,
        'sport': sport,
        'startedAt': startedAt.toUtc().toIso8601String(),
        'endedAt': endedAt.toUtc().toIso8601String(),
        if (distanceMeters != null) 'distanceMeters': distanceMeters,
        if (durationSeconds != null) 'durationSeconds': durationSeconds,
        if (calories != null) 'calories': calories,
        if (averageHeartRate != null) 'averageHeartRate': averageHeartRate,
        if (maximumHeartRate != null) 'maximumHeartRate': maximumHeartRate,
        if (averageCadence != null) 'averageCadence': averageCadence,
        if (averagePowerWatts != null) 'averagePowerWatts': averagePowerWatts,
        if (notes.isNotEmpty) 'notes': notes,
        if (points.isNotEmpty)
          'points': points.map((point) => point.toJson()).toList(),
        if (metadata.isNotEmpty) 'metadata': metadata,
      };
}

class ExternalWorkoutParseResult {
  const ExternalWorkoutParseResult({
    required this.workouts,
    this.warnings = const <String>[],
  });

  final List<ExternalWorkout> workouts;
  final List<String> warnings;
}

abstract final class ExternalWorkoutFileParser {
  static ExternalWorkoutFormat formatForFileName(String fileName) {
    final normalized = fileName.trim().toLowerCase();
    if (normalized.endsWith('.fit')) return ExternalWorkoutFormat.fit;
    if (normalized.endsWith('.tcx')) return ExternalWorkoutFormat.tcx;
    if (normalized.endsWith('.gpx')) return ExternalWorkoutFormat.gpx;
    throw FormatException('Unsupported workout file: $fileName');
  }

  static ExternalWorkoutParseResult parse({
    required Uint8List bytes,
    required String fileName,
    ExternalWorkoutSource source = ExternalWorkoutSource.file,
  }) {
    return switch (formatForFileName(fileName)) {
      ExternalWorkoutFormat.fit => _FitParser(bytes, source).parse(),
      ExternalWorkoutFormat.tcx => _TcxParser(bytes, source).parse(),
      ExternalWorkoutFormat.gpx => _GpxParser(bytes, source).parse(),
    };
  }
}

class _GpxParser {
  _GpxParser(this.bytes, this.source);

  final Uint8List bytes;
  final ExternalWorkoutSource source;

  ExternalWorkoutParseResult parse() {
    final document = XmlDocument.parse(utf8.decode(bytes));
    final tracks = _elements(document, 'trk').toList();
    final routes = _elements(document, 'rte').toList();
    final containers = <XmlElement>[...tracks, ...routes];
    if (containers.isEmpty) {
      throw const FormatException('The GPX file contains no track or route.');
    }

    final workouts = <ExternalWorkout>[];
    final warnings = <String>[];
    for (var index = 0; index < containers.length; index++) {
      final container = containers[index];
      final rawPoints = <XmlElement>[
        ..._elements(container, 'trkpt'),
        ..._elements(container, 'rtept'),
      ];
      if (rawPoints.isEmpty) {
        warnings.add('GPX item ${index + 1} contained no points and was skipped.');
        continue;
      }
      final points = rawPoints.map(_gpxPoint).toList(growable: false);
      final times = points.map((point) => point.time).whereType<DateTime>().toList();
      final startedAt = times.isNotEmpty ? times.first : DateTime.now().toUtc();
      final endedAt = times.length > 1 ? times.last : startedAt;
      final title = _firstText(container, 'name')?.trim();
      final sport = _firstText(container, 'type')?.trim();
      final calculatedDistance = _polylineDistance(points);
      final suppliedDistance = points
          .map((point) => point.distanceMeters)
          .whereType<double>()
          .fold<double?>(null, (value, item) => value == null || item > value ? item : value);
      final duration = endedAt.difference(startedAt).inMilliseconds / 1000;
      workouts.add(
        ExternalWorkout(
          id: 'gpx-${startedAt.microsecondsSinceEpoch}-$index',
          source: source,
          format: ExternalWorkoutFormat.gpx,
          title: title?.isNotEmpty == true ? title! : 'Imported GPX Activity',
          sport: sport?.isNotEmpty == true ? sport! : 'outdoor',
          startedAt: startedAt,
          endedAt: endedAt,
          durationSeconds: duration > 0 ? duration : null,
          distanceMeters: suppliedDistance ??
              (calculatedDistance > 0 ? calculatedDistance : null),
          averageHeartRate: _meanInt(points.map((point) => point.heartRate)),
          maximumHeartRate: _maxInt(points.map((point) => point.heartRate)),
          averageCadence: _meanInt(points.map((point) => point.cadence)),
          averagePowerWatts: _meanInt(points.map((point) => point.powerWatts)),
          points: points,
          metadata: <String, dynamic>{'itemIndex': index},
        ),
      );
    }
    if (workouts.isEmpty) {
      throw const FormatException('No usable workout was found in the GPX file.');
    }
    return ExternalWorkoutParseResult(workouts: workouts, warnings: warnings);
  }

  ExternalWorkoutPoint _gpxPoint(XmlElement element) {
    final latitude = double.tryParse(element.getAttribute('lat') ?? '');
    final longitude = double.tryParse(element.getAttribute('lon') ?? '');
    final extensions = _elements(element, 'extensions').firstOrNull;
    int? extensionInt(String name) => extensions == null
        ? null
        : int.tryParse(_firstText(extensions, name)?.trim() ?? '');
    double? extensionDouble(String name) => extensions == null
        ? null
        : double.tryParse(_firstText(extensions, name)?.trim() ?? '');
    return ExternalWorkoutPoint(
      time: _parseDate(_firstText(element, 'time')),
      latitude: latitude,
      longitude: longitude,
      altitudeMeters: double.tryParse(_firstText(element, 'ele') ?? ''),
      distanceMeters: extensionDouble('distance'),
      speedMetersPerSecond: extensionDouble('speed'),
      heartRate: extensionInt('hr'),
      cadence: extensionInt('cad'),
      powerWatts: extensionInt('power') ?? extensionInt('watts'),
    );
  }
}

class _TcxParser {
  _TcxParser(this.bytes, this.source);

  final Uint8List bytes;
  final ExternalWorkoutSource source;

  ExternalWorkoutParseResult parse() {
    final document = XmlDocument.parse(utf8.decode(bytes));
    final activities = _elements(document, 'Activity').toList();
    if (activities.isEmpty) {
      throw const FormatException('The TCX file contains no activity.');
    }

    final workouts = <ExternalWorkout>[];
    final warnings = <String>[];
    for (var index = 0; index < activities.length; index++) {
      final activity = activities[index];
      final trackpoints = _elements(activity, 'Trackpoint').map(_tcxPoint).toList();
      final activityId = _parseDate(_firstText(activity, 'Id'));
      final times = trackpoints.map((point) => point.time).whereType<DateTime>().toList();
      final startedAt = activityId ??
          (times.isNotEmpty ? times.first : DateTime.now().toUtc());
      final endedAt = times.isNotEmpty ? times.last : startedAt;
      final laps = _elements(activity, 'Lap').toList();
      double sumDouble(String name) => laps
          .map((lap) => double.tryParse(_firstText(lap, name) ?? '') ?? 0)
          .fold<double>(0, (total, item) => total + item);
      int sumInt(String name) => laps
          .map((lap) => int.tryParse(_firstText(lap, name) ?? '') ?? 0)
          .fold<int>(0, (total, item) => total + item);
      final totalTime = sumDouble('TotalTimeSeconds');
      final distance = sumDouble('DistanceMeters');
      final calories = sumInt('Calories');
      final averageHeartRates = laps
          .map((lap) => int.tryParse(
                _firstText(
                      _elements(lap, 'AverageHeartRateBpm').firstOrNull,
                      'Value',
                    ) ??
                    '',
              ))
          .whereType<int>();
      final maximumHeartRates = laps
          .map((lap) => int.tryParse(
                _firstText(
                      _elements(lap, 'MaximumHeartRateBpm').firstOrNull,
                      'Value',
                    ) ??
                    '',
              ))
          .whereType<int>();
      final sport = activity.getAttribute('Sport')?.trim();
      if (trackpoints.isEmpty) {
        warnings.add('TCX activity ${index + 1} has no trackpoints; summary data was imported.');
      }
      workouts.add(
        ExternalWorkout(
          id: 'tcx-${startedAt.microsecondsSinceEpoch}-$index',
          source: source,
          format: ExternalWorkoutFormat.tcx,
          title: sport?.isNotEmpty == true ? '$sport Activity' : 'Imported TCX Activity',
          sport: sport?.isNotEmpty == true ? sport! : 'other',
          startedAt: startedAt,
          endedAt: totalTime > 0
              ? startedAt.add(Duration(milliseconds: (totalTime * 1000).round()))
              : endedAt,
          durationSeconds: totalTime > 0
              ? totalTime
              : math.max(0, endedAt.difference(startedAt).inMilliseconds / 1000),
          distanceMeters: distance > 0 ? distance : null,
          calories: calories > 0 ? calories : null,
          averageHeartRate: _weightedMean(averageHeartRates),
          maximumHeartRate: maximumHeartRates.isEmpty
              ? _maxInt(trackpoints.map((point) => point.heartRate))
              : maximumHeartRates.reduce(math.max),
          averageCadence: _meanInt(trackpoints.map((point) => point.cadence)),
          averagePowerWatts: _meanInt(trackpoints.map((point) => point.powerWatts)),
          points: trackpoints,
          metadata: <String, dynamic>{'lapCount': laps.length},
        ),
      );
    }
    return ExternalWorkoutParseResult(workouts: workouts, warnings: warnings);
  }

  ExternalWorkoutPoint _tcxPoint(XmlElement element) {
    final position = _elements(element, 'Position').firstOrNull;
    final heartRate = _elements(element, 'HeartRateBpm').firstOrNull;
    final extensions = _elements(element, 'Extensions').firstOrNull;
    return ExternalWorkoutPoint(
      time: _parseDate(_firstText(element, 'Time')),
      latitude: double.tryParse(_firstText(position, 'LatitudeDegrees') ?? ''),
      longitude: double.tryParse(_firstText(position, 'LongitudeDegrees') ?? ''),
      altitudeMeters: double.tryParse(_firstText(element, 'AltitudeMeters') ?? ''),
      distanceMeters: double.tryParse(_firstText(element, 'DistanceMeters') ?? ''),
      speedMetersPerSecond: double.tryParse(_firstText(extensions, 'Speed') ?? ''),
      heartRate: int.tryParse(_firstText(heartRate, 'Value') ?? ''),
      cadence: int.tryParse(_firstText(element, 'Cadence') ?? ''),
      powerWatts: int.tryParse(_firstText(extensions, 'Watts') ?? ''),
    );
  }
}

class _FitParser {
  _FitParser(this.bytes, this.source);

  final Uint8List bytes;
  final ExternalWorkoutSource source;
  final Map<int, _FitDefinition> _definitions = <int, _FitDefinition>{};
  final List<ExternalWorkoutPoint> _points = <ExternalWorkoutPoint>[];
  final List<Map<String, num>> _sessions = <Map<String, num>>[];
  final List<String> _warnings = <String>[];
  DateTime? _fileCreatedAt;

  ExternalWorkoutParseResult parse() {
    if (bytes.length < 14) {
      throw const FormatException('The FIT file is too short.');
    }
    final headerSize = bytes[0];
    if (headerSize < 12 || headerSize > bytes.length) {
      throw const FormatException('The FIT header is invalid.');
    }
    final signature = ascii.decode(bytes.sublist(8, 12), allowInvalid: true);
    if (signature != '.FIT') {
      throw const FormatException('The file does not contain a FIT signature.');
    }
    final view = ByteData.sublistView(bytes);
    final dataSize = view.getUint32(4, Endian.little);
    final dataStart = headerSize;
    final dataEnd = math.min(bytes.length, dataStart + dataSize);
    var offset = dataStart;
    while (offset < dataEnd) {
      try {
        offset = _parseMessage(offset, dataEnd);
      } on FormatException catch (error) {
        _warnings.add(error.message);
        break;
      }
    }

    final defaultStart = _points.map((point) => point.time).whereType<DateTime>().firstOrNull ??
        _fileCreatedAt ??
        DateTime.now().toUtc();
    final defaultEnd = _points.map((point) => point.time).whereType<DateTime>().lastOrNull ??
        defaultStart;
    final session = _sessions.isNotEmpty ? _sessions.last : const <String, num>{};
    final startedAt = _fitDate(session['startTime']) ?? defaultStart;
    final endedAt = _fitDate(session['timestamp']) ?? defaultEnd;
    final sport = _fitSport(session['sport']?.toInt());
    final durationSeconds = _scaled(session['totalTimerTime'], 1000) ??
        _scaled(session['totalElapsedTime'], 1000) ??
        math.max(0, endedAt.difference(startedAt).inMilliseconds / 1000);
    final workout = ExternalWorkout(
      id: 'fit-${startedAt.microsecondsSinceEpoch}',
      source: source,
      format: ExternalWorkoutFormat.fit,
      title: 'Imported ${_titleCase(sport)} Activity',
      sport: sport,
      startedAt: startedAt,
      endedAt: endedAt.isBefore(startedAt) ? startedAt : endedAt,
      distanceMeters: _scaled(session['totalDistance'], 100),
      durationSeconds: durationSeconds,
      calories: session['totalCalories']?.toInt(),
      averageHeartRate: session['averageHeartRate']?.toInt() ??
          _meanInt(_points.map((point) => point.heartRate)),
      maximumHeartRate: session['maximumHeartRate']?.toInt() ??
          _maxInt(_points.map((point) => point.heartRate)),
      averageCadence: session['averageCadence']?.toInt() ??
          _meanInt(_points.map((point) => point.cadence)),
      averagePowerWatts: session['averagePower']?.toInt() ??
          _meanInt(_points.map((point) => point.powerWatts)),
      points: List.unmodifiable(_points),
      metadata: <String, dynamic>{
        'protocolVersion': bytes[1],
        'profileVersion': view.getUint16(2, Endian.little),
      },
    );
    return ExternalWorkoutParseResult(workouts: <ExternalWorkout>[workout], warnings: _warnings);
  }

  int _parseMessage(int offset, int dataEnd) {
    if (offset >= dataEnd) return dataEnd;
    final header = bytes[offset++];
    if ((header & 0x80) != 0) {
      final localType = (header >> 5) & 0x03;
      final definition = _definitions[localType];
      if (definition == null) {
        throw FormatException('FIT compressed record references missing definition $localType.');
      }
      return _parseData(offset, dataEnd, definition);
    }
    final isDefinition = (header & 0x40) != 0;
    final hasDeveloperData = (header & 0x20) != 0;
    final localType = header & 0x0f;
    if (!isDefinition) {
      final definition = _definitions[localType];
      if (definition == null) {
        throw FormatException('FIT record references missing definition $localType.');
      }
      return _parseData(offset, dataEnd, definition);
    }
    if (offset + 5 > dataEnd) {
      throw const FormatException('FIT definition message is truncated.');
    }
    offset += 1;
    final architecture = bytes[offset++];
    final endian = architecture == 0 ? Endian.little : Endian.big;
    final globalMessage = _readUnsigned(offset, 2, endian);
    offset += 2;
    final count = bytes[offset++];
    final fields = <_FitField>[];
    for (var index = 0; index < count; index++) {
      if (offset + 3 > dataEnd) {
        throw const FormatException('FIT field definition is truncated.');
      }
      fields.add(_FitField(bytes[offset], bytes[offset + 1], bytes[offset + 2]));
      offset += 3;
    }
    if (hasDeveloperData) {
      if (offset >= dataEnd) {
        throw const FormatException('FIT developer-field definition is truncated.');
      }
      final developerCount = bytes[offset++];
      final developerBytes = developerCount * 3;
      if (offset + developerBytes > dataEnd) {
        throw const FormatException('FIT developer-field definitions are truncated.');
      }
      offset += developerBytes;
    }
    _definitions[localType] = _FitDefinition(globalMessage, endian, fields);
    return offset;
  }

  int _parseData(int offset, int dataEnd, _FitDefinition definition) {
    final values = <int, num>{};
    for (final field in definition.fields) {
      if (offset + field.size > dataEnd) {
        throw const FormatException('FIT data message is truncated.');
      }
      final value = _readFitNumber(offset, field.size, field.baseType, definition.endian);
      if (value != null) values[field.number] = value;
      offset += field.size;
    }
    switch (definition.globalMessage) {
      case 0:
        _fileCreatedAt = _fitDate(values[4]);
      case 18:
        _sessions.add(<String, num>{
          if (values[2] != null) 'startTime': values[2]!,
          if (values[253] != null) 'timestamp': values[253]!,
          if (values[5] != null) 'sport': values[5]!,
          if (values[7] != null) 'totalElapsedTime': values[7]!,
          if (values[8] != null) 'totalTimerTime': values[8]!,
          if (values[9] != null) 'totalDistance': values[9]!,
          if (values[11] != null) 'totalCalories': values[11]!,
          if (values[16] != null) 'averageHeartRate': values[16]!,
          if (values[17] != null) 'maximumHeartRate': values[17]!,
          if (values[18] != null) 'averageCadence': values[18]!,
          if (values[20] != null) 'averagePower': values[20]!,
        });
      case 20:
        _points.add(
          ExternalWorkoutPoint(
            time: _fitDate(values[253]),
            latitude: _semicircles(values[0]),
            longitude: _semicircles(values[1]),
            altitudeMeters: values[78] != null
                ? _scaled(values[78], 5, offset: -500)
                : _scaled(values[2], 5, offset: -500),
            heartRate: values[3]?.toInt(),
            cadence: values[4]?.toInt(),
            distanceMeters: _scaled(values[5], 100),
            speedMetersPerSecond: values[73] != null
                ? _scaled(values[73], 1000)
                : _scaled(values[6], 1000),
            powerWatts: values[7]?.toInt(),
          ),
        );
    }
    return offset;
  }

  num? _readFitNumber(int offset, int size, int baseType, Endian endian) {
    final type = baseType & 0x1f;
    if (size <= 0) return null;
    final view = ByteData.sublistView(bytes, offset, offset + size);
    try {
      return switch (type) {
        0 || 2 || 10 || 13 => view.getUint8(0),
        1 => view.getInt8(0),
        3 => size >= 2 ? view.getInt16(0, endian) : null,
        4 || 11 => size >= 2 ? view.getUint16(0, endian) : null,
        5 => size >= 4 ? view.getInt32(0, endian) : null,
        6 || 12 => size >= 4 ? view.getUint32(0, endian) : null,
        8 => size >= 4 ? view.getFloat32(0, endian) : null,
        9 => size >= 8 ? view.getFloat64(0, endian) : null,
        _ => null,
      };
    } on RangeError {
      return null;
    }
  }

  int _readUnsigned(int offset, int size, Endian endian) {
    final view = ByteData.sublistView(bytes, offset, offset + size);
    return switch (size) {
      1 => view.getUint8(0),
      2 => view.getUint16(0, endian),
      4 => view.getUint32(0, endian),
      _ => throw FormatException('Unsupported FIT integer size: $size'),
    };
  }
}

class _FitDefinition {
  const _FitDefinition(this.globalMessage, this.endian, this.fields);

  final int globalMessage;
  final Endian endian;
  final List<_FitField> fields;
}

class _FitField {
  const _FitField(this.number, this.size, this.baseType);

  final int number;
  final int size;
  final int baseType;
}

Iterable<XmlElement> _elements(XmlNode? node, String localName) sync* {
  if (node == null) return;
  for (final descendant in node.descendants.whereType<XmlElement>()) {
    if (descendant.name.local == localName) yield descendant;
  }
}

String? _firstText(XmlNode? node, String localName) {
  if (node == null) return null;
  if (node is XmlElement && node.name.local == localName) return node.innerText;
  return _elements(node, localName).firstOrNull?.innerText;
}

DateTime? _parseDate(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  return DateTime.tryParse(value.trim())?.toUtc();
}

DateTime? _fitDate(num? seconds) {
  if (seconds == null) return null;
  const fitEpochToUnix = 631065600;
  return DateTime.fromMillisecondsSinceEpoch(
    (seconds.toDouble() + fitEpochToUnix) * 1000 ~/ 1,
    isUtc: true,
  );
}

double? _scaled(num? value, double scale, {double offset = 0}) =>
    value == null ? null : value.toDouble() / scale + offset;

double? _semicircles(num? value) =>
    value == null ? null : value.toDouble() * 180 / 2147483648;

String _fitSport(int? value) => switch (value) {
      1 => 'running',
      2 => 'cycling',
      4 => 'fitness equipment',
      5 => 'swimming',
      10 => 'training',
      11 => 'walking',
      15 => 'rowing',
      20 => 'strength training',
      _ => 'other',
    };

String _titleCase(String value) => value
    .split(' ')
    .where((part) => part.isNotEmpty)
    .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
    .join(' ');

double _polylineDistance(List<ExternalWorkoutPoint> points) {
  var total = 0.0;
  ExternalWorkoutPoint? previous;
  for (final point in points) {
    if (previous?.latitude != null &&
        previous?.longitude != null &&
        point.latitude != null &&
        point.longitude != null) {
      total += _haversine(
        previous!.latitude!,
        previous.longitude!,
        point.latitude!,
        point.longitude!,
      );
    }
    previous = point;
  }
  return total;
}

double _haversine(double lat1, double lon1, double lat2, double lon2) {
  const earthRadius = 6371000.0;
  double radians(double degrees) => degrees * math.pi / 180;
  final dLat = radians(lat2 - lat1);
  final dLon = radians(lon2 - lon1);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(radians(lat1)) *
          math.cos(radians(lat2)) *
          math.sin(dLon / 2) *
          math.sin(dLon / 2);
  return earthRadius * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

int? _meanInt(Iterable<int?> values) {
  final items = values.whereType<int>().toList();
  if (items.isEmpty) return null;
  return (items.reduce((left, right) => left + right) / items.length).round();
}

int? _weightedMean(Iterable<int> values) {
  final items = values.toList();
  if (items.isEmpty) return null;
  return (items.reduce((left, right) => left + right) / items.length).round();
}

int? _maxInt(Iterable<int?> values) {
  final items = values.whereType<int>().toList();
  if (items.isEmpty) return null;
  return items.reduce(math.max);
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }

  T? get lastOrNull {
    T? value;
    var found = false;
    for (final item in this) {
      value = item;
      found = true;
    }
    return found ? value : null;
  }
}
