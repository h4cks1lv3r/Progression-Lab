import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:progression_lab/data_portability_bridge.dart';
import 'package:progression_lab/external_activity.dart';
import 'package:progression_lab/personal_experiments.dart';
import 'package:progression_lab/store.dart';

void main() {
  test('GPX import calculates time, distance, and heart rate', () {
    const gpx = '''<?xml version="1.0"?>
<gpx><trk><name>Morning Run</name><trkseg>
<trkpt lat="40.0000" lon="-75.0000"><time>2026-08-20T12:00:00Z</time><extensions><hr>140</hr></extensions></trkpt>
<trkpt lat="40.0010" lon="-75.0000"><time>2026-08-20T12:05:00Z</time><extensions><hr>150</hr></extensions></trkpt>
</trkseg></trk></gpx>''';
    final result = ExternalActivityImporter.parse(
      PortablePickedFile(name: 'run.gpx', bytes: Uint8List.fromList(utf8.encode(gpx))),
    );

    expect(result.activities, hasLength(1));
    final activity = result.activities.single;
    expect(activity.name, 'Morning Run');
    expect(activity.activityType, 'Running');
    expect(activity.duration, const Duration(minutes: 5));
    expect(activity.distanceMeters, greaterThan(100));
    expect(activity.averageHeartRate, 145);
  });

  test('TCX import reads a session summary', () {
    const tcx = '''<?xml version="1.0"?>
<TrainingCenterDatabase><Activities><Activity Sport="Biking">
<Id>2026-08-20T12:00:00Z</Id><Lap StartTime="2026-08-20T12:00:00Z">
<TotalTimeSeconds>1800</TotalTimeSeconds><DistanceMeters>12000</DistanceMeters>
<Calories>420</Calories><AverageHeartRateBpm><Value>132</Value></AverageHeartRateBpm>
</Lap></Activity></Activities></TrainingCenterDatabase>''';
    final result = ExternalActivityImporter.parse(
      PortablePickedFile(name: 'garmin-ride.tcx', bytes: Uint8List.fromList(utf8.encode(tcx))),
    );

    final activity = result.activities.single;
    expect(activity.source, ExternalActivitySource.garmin);
    expect(activity.activityType, 'Biking');
    expect(activity.duration, const Duration(minutes: 30));
    expect(activity.distanceMeters, 12000);
    expect(activity.calories, 420);
    expect(activity.averageHeartRate, 132);
  });

  test('experiment engine reports insufficient data instead of a conclusion', () {
    final experiment = PersonalExperiment(
      id: 'caffeine-bench',
      name: 'Caffeine and bench performance',
      variable: ExperimentVariable.caffeine,
      metric: ExperimentMetric.estimatedStrength,
      startedAt: DateTime(2026, 8, 1),
      minimumMatchedSessions: 12,
      durationDays: 42,
    );
    final result = PersonalExperimentEngine.evaluate(experiment, AppStore());

    expect(result.confidence, 'insufficient');
    expect(result.effectPercent, isNull);
    expect(result.hasEnoughData, isFalse);
    expect(result.confounders, isNotEmpty);
  });
}
