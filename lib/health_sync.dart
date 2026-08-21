import 'dart:io';

import 'package:health/health.dart';

import 'external_activity.dart';
import 'store.dart';

class HealthSyncStatus {
  const HealthSyncStatus({
    required this.available,
    required this.authorized,
    required this.platformName,
    this.message = '',
  });

  final bool available;
  final bool authorized;
  final String platformName;
  final String message;
}

class HealthSyncResult {
  const HealthSyncResult({
    required this.workoutsRead,
    required this.workoutsWritten,
    required this.bodyMeasurementsRead,
    required this.warnings,
  });

  final int workoutsRead;
  final int workoutsWritten;
  final int bodyMeasurementsRead;
  final List<String> warnings;
}

/// Local platform-health bridge.
///
/// On Android the `health` plugin uses Health Connect. On iOS it uses
/// HealthKit. Progression Lab keeps its own database authoritative and syncs
/// summaries and body measurements only after explicit user authorization.
class ProgressionHealthSync {
  ProgressionHealthSync({Health? health}) : _health = health ?? Health();

  final Health _health;

  static const _readTypes = <HealthDataType>[
    HealthDataType.WORKOUT,
    HealthDataType.WEIGHT,
    HealthDataType.BODY_FAT_PERCENTAGE,
    HealthDataType.HEART_RATE,
    HealthDataType.ACTIVE_ENERGY_BURNED,
  ];

  static const _writeTypes = <HealthDataType>[
    HealthDataType.WORKOUT,
    HealthDataType.WEIGHT,
  ];

  Future<HealthSyncStatus> status() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return const HealthSyncStatus(
        available: false,
        authorized: false,
        platformName: 'Unsupported platform',
        message: 'Health synchronization is available on Android and iOS.',
      );
    }
    try {
      await _health.configure();
      final permissions = <HealthDataAccess>[
        for (final type in _readTypes)
          _writeTypes.contains(type)
              ? HealthDataAccess.READ_WRITE
              : HealthDataAccess.READ,
      ];
      final authorized =
          await _health.hasPermissions(_readTypes, permissions: permissions) ??
          false;
      return HealthSyncStatus(
        available: true,
        authorized: authorized,
        platformName: Platform.isAndroid ? 'Health Connect' : 'Apple Health',
        message: authorized
            ? 'Connected. Your permissions remain under system control.'
            : 'Permission has not been granted yet.',
      );
    } on Object catch (error) {
      return HealthSyncStatus(
        available: false,
        authorized: false,
        platformName: Platform.isAndroid ? 'Health Connect' : 'Apple Health',
        message: '$error',
      );
    }
  }

  Future<bool> requestAuthorization({
    bool read = true,
    bool write = true,
  }) async {
    await _health.configure();
    final types = <HealthDataType>[
      if (read) ..._readTypes,
      if (write)
        for (final type in _writeTypes)
          if (!read || !_readTypes.contains(type)) type,
    ];
    final permissions = <HealthDataAccess>[
      for (final type in types)
        write && _writeTypes.contains(type)
            ? HealthDataAccess.READ_WRITE
            : HealthDataAccess.READ,
    ];
    return _health.requestAuthorization(types, permissions: permissions);
  }

  Future<HealthSyncResult> sync({
    required AppStore store,
    bool read = true,
    bool write = true,
    Duration lookback = const Duration(days: 365),
  }) async {
    final warnings = <String>[];
    var workoutsRead = 0;
    var workoutsWritten = 0;
    var bodyMeasurementsRead = 0;
    final now = DateTime.now();
    final start = now.subtract(lookback);

    if (read) {
      try {
        final points = await _health.getHealthDataFromTypes(
          types: _readTypes,
          startTime: start,
          endTime: now,
        );
        final activities = <ExternalActivity>[];
        for (final point in _health.removeDuplicates(points)) {
          if (point.type == HealthDataType.WORKOUT) {
            final dynamic value = point.value;
            final activityType = _workoutTypeLabel(value);
            activities.add(
              ExternalActivity(
                id: 'health-${point.uuid}',
                source: ExternalActivitySource.healthPlatform,
                name: activityType,
                activityType: activityType,
                start: point.dateFrom,
                end: point.dateTo.isAfter(point.dateFrom)
                    ? point.dateTo
                    : point.dateFrom.add(const Duration(seconds: 1)),
                importedAt: now,
                distanceMeters: _dynamicNumber(value, const <String>[
                  'totalDistance',
                  'distance',
                ]),
                calories: _dynamicNumber(value, const <String>[
                  'totalEnergyBurned',
                  'energyBurned',
                ]),
                sourceFile: Platform.isAndroid
                    ? 'Health Connect'
                    : 'Apple Health',
              ),
            );
          } else if (point.type == HealthDataType.WEIGHT) {
            final kilograms = _numericPoint(point);
            if (kilograms != null && kilograms > 0) {
              final displayValue = store.unit == 'lb'
                  ? kilograms / AppStore.poundsToKilograms
                  : kilograms;
              await store.upsertRecoveryCheckIn(
                localDate: point.dateFrom,
                bodyWeight: displayValue,
                weightUnit: store.unit,
              );
              bodyMeasurementsRead++;
            }
          }
        }
        workoutsRead = await ExternalActivityRepository().addAll(activities);
      } on Object catch (error) {
        warnings.add('Read from the health platform: $error');
      }
    }

    if (write) {
      final completed = store.workoutHistory
          .where((record) => record.status == WorkoutStatus.completed)
          .where((record) => record.loggedAt.isAfter(start))
          .toList();
      for (final record in completed) {
        try {
          final end = record.loggedAt;
          final relatedSets = store.logs
              .where(
                (log) =>
                    (record.sessionId != null &&
                        log.sessionId == record.sessionId) ||
                    (log.workout == record.workout &&
                        log.date.difference(record.loggedAt).abs() <
                            const Duration(hours: 8)),
              )
              .toList();
          final earliest = relatedSets.isEmpty
              ? end.subtract(const Duration(minutes: 45))
              : relatedSets
                  .map((set) => set.date)
                  .reduce((a, b) => a.isBefore(b) ? a : b);
          final safeStart = earliest.isBefore(end)
              ? earliest
              : end.subtract(const Duration(minutes: 1));
          final success = await _health.writeWorkoutData(
            activityType: HealthWorkoutActivityType.STRENGTH_TRAINING,
            start: safeStart,
            end: end,
          );
          if (success) workoutsWritten++;
        } on Object catch (error) {
          warnings.add('${record.workout}: $error');
        }
      }

      for (final assessment in store.athleticHistory.where(
        (session) => session.completedAt.isAfter(start),
      )) {
        try {
          final end = assessment.completedAt;
          final success = await _health.writeWorkoutData(
            activityType:
                HealthWorkoutActivityType.HIGH_INTENSITY_INTERVAL_TRAINING,
            start: end.subtract(const Duration(minutes: 45)),
            end: end,
          );
          if (success) workoutsWritten++;
        } on Object catch (error) {
          warnings.add('Athletic session: $error');
        }
      }
    }

    return HealthSyncResult(
      workoutsRead: workoutsRead,
      workoutsWritten: workoutsWritten,
      bodyMeasurementsRead: bodyMeasurementsRead,
      warnings: warnings,
    );
  }

  static double? _numericPoint(HealthDataPoint point) {
    final dynamic value = point.value;
    try {
      final dynamic numeric = value.numericValue;
      return numeric is num ? numeric.toDouble() : double.tryParse('$numeric');
    } on Object {
      final match = RegExp(r'-?\d+(?:\.\d+)?').firstMatch('$value');
      return match == null ? null : double.tryParse(match.group(0)!);
    }
  }

  static String _workoutTypeLabel(dynamic value) {
    try {
      final text = '${value.workoutActivityType}';
      if (text.isNotEmpty) {
        return text
            .split('.')
            .last
            .replaceAll('_', ' ')
            .split(' ')
            .map(
              (word) => word.isEmpty
                  ? word
                  : '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}',
            )
            .join(' ');
      }
    } on Object {
      // Fall through to the generic label.
    }
    return 'Health workout';
  }

  static double? _dynamicNumber(dynamic value, List<String> fields) {
    for (final field in fields) {
      try {
        final dynamic candidate = switch (field) {
          'totalDistance' => value.totalDistance,
          'distance' => value.distance,
          'totalEnergyBurned' => value.totalEnergyBurned,
          'energyBurned' => value.energyBurned,
          _ => null,
        };
        if (candidate is num) return candidate.toDouble();
        final match = RegExp(r'-?\d+(?:\.\d+)?').firstMatch('$candidate');
        if (match != null) return double.tryParse(match.group(0)!);
      } on Object {
        // This health plugin version does not expose this optional field.
      }
    }
    return null;
  }
}
