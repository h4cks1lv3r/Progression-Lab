import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:progression_lab/external_workout_formats.dart';
import 'package:progression_lab/lab_experiments.dart';
import 'package:progression_lab/provider_integrations.dart';
import 'package:progression_lab/share_options.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('wearable workout formats', () {
    test('parses GPX routes with sensor extensions', () {
      const source = '''<?xml version="1.0"?>
<gpx version="1.1">
  <trk><name>Morning Run</name><type>running</type><trkseg>
    <trkpt lat="40.0" lon="-74.0"><ele>10</ele><time>2026-08-20T10:00:00Z</time><extensions><hr>140</hr><cad>82</cad></extensions></trkpt>
    <trkpt lat="40.001" lon="-74.001"><ele>12</ele><time>2026-08-20T10:05:00Z</time><extensions><hr>151</hr><cad>86</cad></extensions></trkpt>
  </trkseg></trk>
</gpx>''';
      final parsed = ExternalWorkoutFileParser.parse(
        bytes: Uint8List.fromList(utf8.encode(source)),
        fileName: 'run.gpx',
      );

      expect(parsed.workouts, hasLength(1));
      final workout = parsed.workouts.single;
      expect(workout.title, 'Morning Run');
      expect(workout.sport, 'running');
      expect(workout.points, hasLength(2));
      expect(workout.averageHeartRate, 146);
      expect(workout.maximumHeartRate, 151);
      expect(workout.distanceMeters, greaterThan(100));
    });

    test('parses TCX activity summaries and trackpoints', () {
      const source = '''<?xml version="1.0"?>
<TrainingCenterDatabase>
  <Activities><Activity Sport="Biking"><Id>2026-08-20T12:00:00Z</Id>
    <Lap StartTime="2026-08-20T12:00:00Z">
      <TotalTimeSeconds>600</TotalTimeSeconds><DistanceMeters>5000</DistanceMeters><Calories>120</Calories>
      <AverageHeartRateBpm><Value>145</Value></AverageHeartRateBpm>
      <MaximumHeartRateBpm><Value>168</Value></MaximumHeartRateBpm>
      <Track>
        <Trackpoint><Time>2026-08-20T12:00:00Z</Time><DistanceMeters>0</DistanceMeters><HeartRateBpm><Value>130</Value></HeartRateBpm></Trackpoint>
        <Trackpoint><Time>2026-08-20T12:10:00Z</Time><DistanceMeters>5000</DistanceMeters><HeartRateBpm><Value>168</Value></HeartRateBpm></Trackpoint>
      </Track>
    </Lap>
  </Activity></Activities>
</TrainingCenterDatabase>''';
      final parsed = ExternalWorkoutFileParser.parse(
        bytes: Uint8List.fromList(utf8.encode(source)),
        fileName: 'ride.tcx',
      );
      final workout = parsed.workouts.single;
      expect(workout.sport, 'Biking');
      expect(workout.durationSeconds, 600);
      expect(workout.distanceMeters, 5000);
      expect(workout.calories, 120);
      expect(workout.maximumHeartRate, 168);
    });

    test('rejects truncated FIT data without partial import', () {
      expect(
        () => ExternalWorkoutFileParser.parse(
          bytes: Uint8List.fromList(<int>[12, 1, 0, 0, 0, 0, 0, 0]),
          fileName: 'bad.fit',
        ),
        throwsFormatException,
      );
    });
  });

  group('deterministic personal experiments', () {
    test('requires enough matched sessions before drawing a conclusion', () {
      final experiment = LabExperimentTemplates.caffeineTiming(
        start: DateTime.utc(2026, 8, 1),
      );
      final state = <String, dynamic>{
        'workoutHistory': <Object?>[
          for (var index = 0; index < 4; index++)
            <String, dynamic>{
              'status': 'completed',
              'sessionId': 'session-$index',
              'workout': 'Upper Body A',
              'date': DateTime.utc(2026, 8, 10 + index, 18).toIso8601String(),
              'loggedAt': DateTime.utc(2026, 8, 10 + index, 18).toIso8601String(),
              'week': index + 1,
              'days': 4,
            },
        ],
        'logs': <Object?>[
          for (var index = 0; index < 4; index++)
            <String, dynamic>{
              's': 'session-$index',
              'e': 'Barbell Bench Press',
              'w': 185 + index,
              'r': 6,
              'd': DateTime.utc(2026, 8, 10 + index, 18).toIso8601String(),
              'o': 'Upper Body A',
            },
        ],
        'supplementEvents': <Object?>[
          for (var index = 0; index < 2; index++)
            <String, dynamic>{
              'name': 'Coffee',
              'caffeineMg': 180,
              'takenAt': DateTime.utc(2026, 8, 10 + index, 17).toIso8601String(),
            },
        ],
        'recoveryCheckIns': <Object?>[],
        'workoutResponses': <Object?>[],
      };

      final result = LabExperimentAnalyzer.analyze(experiment, state);
      expect(result.confidence, LabExperimentConfidence.insufficient);
      expect(result.summary, contains('More matched workouts are needed'));
      expect(result.summary, isNot(contains('works for you')));
    });

    test('weekly review reports signals and missing data honestly', () {
      final end = DateTime.utc(2026, 8, 21, 12);
      final review = LabExperimentAnalyzer.weeklyReview(
        <String, dynamic>{
          'workoutHistory': <Object?>[
            <String, dynamic>{
              'status': 'completed',
              'workout': 'Upper Body A',
              'date': DateTime.utc(2026, 8, 20).toIso8601String(),
              'loggedAt': DateTime.utc(2026, 8, 20).toIso8601String(),
            },
          ],
          'athleticHistory': <Object?>[],
          'logs': <Object?>[],
          'workoutResponses': <Object?>[],
          'recoveryCheckIns': <Object?>[],
          'supplementEvents': <Object?>[],
        },
        ending: end,
      );
      expect(review.completedStrengthWorkouts, 1);
      expect(review.signals, isNotEmpty);
      expect(review.dataGaps, contains('Sleep was not logged this week.'));
    });
  });

  group('share templates and privacy', () {
    testWidgets('renders all branded aspect ratios as PNG', (tester) async {
      final snapshot = ShareWorkoutSnapshot(
        program: 'Strength Program',
        workout: 'Upper Body A',
        completedAt: DateTime.utc(2026, 8, 20),
        duration: const Duration(minutes: 48),
        sets: 18,
        exercises: 5,
        volume: 12450,
        achievement: 'New bench press best',
        highlights: const <ShareHighlight>[
          ShareHighlight('Top set', '225 lb × 5', sensitiveWeight: true),
        ],
      );
      for (final aspect in WorkoutShareAspect.values) {
        final bytes = await tester.runAsync(
          () => AdvancedWorkoutShareCardGenerator.generate(
            snapshot,
            WorkoutSharePreferences(aspect: aspect),
          ),
        );
        expect(bytes, isNotNull);
        expect(bytes!.take(8).toList(), <int>[137, 80, 78, 71, 13, 10, 26, 10]);
      }
    });

    test('completion-only captions do not reveal exact weights', () {
      final snapshot = ShareWorkoutSnapshot(
        program: 'Strength Program',
        workout: 'Upper Body A',
        completedAt: DateTime.utc(2026, 8, 20),
        duration: const Duration(minutes: 48),
        sets: 18,
        exercises: 5,
        volume: 12450,
        highlights: const <ShareHighlight>[
          ShareHighlight('Top set', '225 lb × 5', sensitiveWeight: true),
        ],
      );
      final caption = WorkoutShareCaptionBuilder.build(
        snapshot,
        const WorkoutSharePreferences(
          privacy: WorkoutSharePrivacy(
            showExactWeights: false,
            completionOnly: true,
          ),
        ),
      );
      expect(caption, isNot(contains('225')));
      expect(caption, contains('Built, not guessed'));
    });
  });

  test('provider adapters require protected broker configuration', () {
    for (final provider in TrainingProvider.values) {
      final config = ProviderConfiguration.forProvider(provider);
      expect(config.redirectUri, startsWith('progressionlab://oauth/'));
      if (config.brokerBaseUrl.isNotEmpty) {
        expect(Uri.parse(config.brokerBaseUrl).scheme, 'https');
      }
    }
  });
}
