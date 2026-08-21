import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'external_workout_formats.dart';

enum HealthPlatformKind { healthConnect, appleHealth, unavailable }

enum HealthAuthorizationState { unknown, unavailable, notDetermined, denied, authorized }

class HealthPlatformStatus {
  const HealthPlatformStatus({
    required this.platform,
    required this.authorization,
    required this.available,
    this.message = '',
  });

  final HealthPlatformKind platform;
  final HealthAuthorizationState authorization;
  final bool available;
  final String message;

  factory HealthPlatformStatus.fromJson(Map<Object?, Object?> value) {
    T enumValue<T extends Enum>(List<T> values, Object? raw, T fallback) {
      final text = '$raw';
      return values.where((item) => item.name == text).firstOrNull ?? fallback;
    }

    return HealthPlatformStatus(
      platform: enumValue(
        HealthPlatformKind.values,
        value['platform'],
        HealthPlatformKind.unavailable,
      ),
      authorization: enumValue(
        HealthAuthorizationState.values,
        value['authorization'],
        HealthAuthorizationState.unknown,
      ),
      available: value['available'] == true,
      message: value['message'] is String ? value['message']! as String : '',
    );
  }
}

class HealthBodyMetric {
  const HealthBodyMetric({
    required this.type,
    required this.value,
    required this.unit,
    required this.recordedAt,
    this.source = '',
  });

  final String type;
  final double value;
  final String unit;
  final DateTime recordedAt;
  final String source;

  factory HealthBodyMetric.fromJson(Map<Object?, Object?> value) =>
      HealthBodyMetric(
        type: '${value['type']}',
        value: (value['value'] as num).toDouble(),
        unit: '${value['unit']}',
        recordedAt: DateTime.parse('${value['recordedAt']}').toUtc(),
        source: value['source'] is String ? value['source']! as String : '',
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'type': type,
        'value': value,
        'unit': unit,
        'recordedAt': recordedAt.toUtc().toIso8601String(),
        if (source.isNotEmpty) 'source': source,
      };
}

class HealthWorkoutWriteRequest {
  const HealthWorkoutWriteRequest({
    required this.externalId,
    required this.title,
    required this.sport,
    required this.startedAt,
    required this.endedAt,
    this.calories,
    this.distanceMeters,
    this.notes = '',
    this.rateOfPerceivedExertion,
  });

  final String externalId;
  final String title;
  final String sport;
  final DateTime startedAt;
  final DateTime endedAt;
  final double? calories;
  final double? distanceMeters;
  final String notes;
  final double? rateOfPerceivedExertion;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'externalId': externalId,
        'title': title,
        'sport': sport,
        'startedAt': startedAt.toUtc().toIso8601String(),
        'endedAt': endedAt.toUtc().toIso8601String(),
        if (calories != null) 'calories': calories,
        if (distanceMeters != null) 'distanceMeters': distanceMeters,
        if (notes.isNotEmpty) 'notes': notes,
        if (rateOfPerceivedExertion != null)
          'rateOfPerceivedExertion': rateOfPerceivedExertion,
      };
}

/// One API for Health Connect on Android and HealthKit/Apple Health on iOS.
///
/// Permission requests are always user-triggered. No health record is read or
/// written until the operating system reports authorization. Progression Lab's
/// local database remains authoritative for set-by-set strength history.
class HealthSyncService extends ChangeNotifier {
  HealthSyncService({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel('progression_lab/health');

  final MethodChannel _channel;
  HealthPlatformStatus _status = const HealthPlatformStatus(
    platform: HealthPlatformKind.unavailable,
    authorization: HealthAuthorizationState.unknown,
    available: false,
  );
  bool _busy = false;
  String? _lastError;

  HealthPlatformStatus get status => _status;
  bool get busy => _busy;
  String? get lastError => _lastError;

  Future<HealthPlatformStatus> refreshStatus() async {
    try {
      final result = await _channel.invokeMapMethod<Object?, Object?>('status');
      _status = HealthPlatformStatus.fromJson(result ?? const <Object?, Object?>{});
      _lastError = null;
    } on PlatformException catch (error) {
      _lastError = error.message ?? error.code;
      _status = HealthPlatformStatus(
        platform: defaultTargetPlatform == TargetPlatform.iOS
            ? HealthPlatformKind.appleHealth
            : HealthPlatformKind.healthConnect,
        authorization: HealthAuthorizationState.unavailable,
        available: false,
        message: _lastError!,
      );
    }
    notifyListeners();
    return _status;
  }

  Future<bool> requestAuthorization() async {
    return _guard(() async {
      final granted = await _channel.invokeMethod<bool>(
            'requestAuthorization',
            <String, Object>{
              'read': <String>[
                'workouts',
                'bodyWeight',
                'bodyFat',
                'heartRate',
                'sleep',
                'steps',
                'activeEnergy',
              ],
              'write': <String>['workouts', 'bodyWeight'],
            },
          ) ??
          false;
      await refreshStatus();
      return granted;
    });
  }

  Future<List<ExternalWorkout>> readWorkouts({
    required DateTime start,
    required DateTime end,
  }) async {
    return _guard(() async {
      final result = await _channel.invokeListMethod<Object?>(
            'readWorkouts',
            <String, String>{
              'start': start.toUtc().toIso8601String(),
              'end': end.toUtc().toIso8601String(),
            },
          ) ??
          const <Object?>[];
      return result
          .whereType<Map>()
          .map((raw) => _workoutFromMap(Map<Object?, Object?>.from(raw)))
          .toList(growable: false);
    });
  }

  Future<List<HealthBodyMetric>> readBodyMetrics({
    required DateTime start,
    required DateTime end,
  }) async {
    return _guard(() async {
      final result = await _channel.invokeListMethod<Object?>(
            'readBodyMetrics',
            <String, String>{
              'start': start.toUtc().toIso8601String(),
              'end': end.toUtc().toIso8601String(),
            },
          ) ??
          const <Object?>[];
      return result
          .whereType<Map>()
          .map((raw) => HealthBodyMetric.fromJson(Map<Object?, Object?>.from(raw)))
          .toList(growable: false);
    });
  }

  Future<bool> writeWorkout(HealthWorkoutWriteRequest request) async {
    return _guard(() async {
      return await _channel.invokeMethod<bool>('writeWorkout', request.toJson()) ??
          false;
    });
  }

  Future<bool> writeBodyWeight(HealthBodyMetric metric) async {
    if (metric.type != 'bodyWeight') {
      throw ArgumentError.value(metric.type, 'metric.type', 'Must be bodyWeight');
    }
    return _guard(() async {
      return await _channel.invokeMethod<bool>('writeBodyWeight', metric.toJson()) ??
          false;
    });
  }

  Future<T> _guard<T>(Future<T> Function() action) async {
    if (_busy) throw StateError('A health operation is already running.');
    _busy = true;
    _lastError = null;
    notifyListeners();
    try {
      return await action();
    } on PlatformException catch (error) {
      _lastError = error.message ?? error.code;
      rethrow;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  ExternalWorkout _workoutFromMap(Map<Object?, Object?> value) {
    final startedAt = DateTime.parse('${value['startedAt']}').toUtc();
    final endedAt = DateTime.parse('${value['endedAt']}').toUtc();
    final platform = '${value['platform']}';
    return ExternalWorkout(
      id: value['id'] is String
          ? value['id']! as String
          : 'health-${startedAt.microsecondsSinceEpoch}',
      source: platform == 'appleHealth'
          ? ExternalWorkoutSource.appleHealth
          : ExternalWorkoutSource.healthConnect,
      format: ExternalWorkoutFormat.fit,
      title: value['title'] is String ? value['title']! as String : 'Health Workout',
      sport: value['sport'] is String ? value['sport']! as String : 'other',
      startedAt: startedAt,
      endedAt: endedAt,
      durationSeconds: (value['durationSeconds'] as num?)?.toDouble(),
      distanceMeters: (value['distanceMeters'] as num?)?.toDouble(),
      calories: (value['calories'] as num?)?.round(),
      averageHeartRate: (value['averageHeartRate'] as num?)?.round(),
      maximumHeartRate: (value['maximumHeartRate'] as num?)?.round(),
      notes: value['notes'] is String ? value['notes']! as String : '',
      metadata: <String, dynamic>{
        'healthPlatform': platform,
        if (value['source'] != null) 'source': value['source'],
      },
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
