import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:progression_lab/brand.dart';
import 'package:progression_lab/body_progress.dart';
import 'package:progression_lab/cloud_sync.dart';
import 'package:progression_lab/data_portability_core.dart';
import 'package:progression_lab/integrations_hub.dart';
import 'package:progression_lab/lab_experiments.dart';
import 'package:progression_lab/store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const cloud = MethodChannel('progression_lab/cloud_sync');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const otherChannels = [
    MethodChannel('iron_cadence/storage'),
    MethodChannel('progression_lab/health'),
    MethodChannel('progression_lab/integration_preferences'),
    MethodChannel('progression_lab/guide_state'),
  ];

  setUp(() {
    for (final channel in otherChannels) {
      messenger.setMockMethodCallHandler(channel, (_) async => null);
    }
  });
  tearDown(() {
    messenger.setMockMethodCallHandler(cloud, null);
    for (final channel in otherChannels) {
      messenger.setMockMethodCallHandler(channel, null);
    }
  });

  testWidgets('health weight export uses current Body measurements', (
    tester,
  ) async {
    final now = DateTime.utc(2026, 9, 30, 12);
    final app = AppStore()
      ..automaticBackupsEnabled = false
      ..bodyMeasurements.add(
        BodyMeasurement(
          id: 'current-weight',
          metric: BodyMetric.weight,
          value: 91,
          date: bodyDay(now),
          recordedAt: now,
        ),
      );
    Map? written;
    messenger.setMockMethodCallHandler(
      const MethodChannel('progression_lab/health'),
      (call) async {
        if (call.method == 'status') {
          return {
            'platform': 'healthConnect',
            'authorization': 'authorized',
            'available': true,
          };
        }
        if (call.method == 'writeBodyWeight') {
          written = call.arguments as Map;
          return true;
        }
        return null;
      },
    );
    messenger.setMockMethodCallHandler(cloud, (_) async => null);
    final service = CloudBackupSyncService.shared(app);
    addTearDown(service.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: ProgressionBrand.theme(),
        home: IntegrationsHubScreen(store: app),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Sync latest bodyweight'),
      200,
      scrollable: find.byWidgetPredicate(
        (widget) =>
            widget is Scrollable && widget.axisDirection == AxisDirection.down,
      ),
    );
    await tester.tap(find.text('Sync latest bodyweight'));
    await tester.pumpAndSettle();
    expect(written?['value'], 91);
    expect(written?['unit'], 'kg');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets(
    'resumed workout export keeps actual finish time and active time note',
    (tester) async {
      final start = DateTime.utc(2026, 9, 28, 18);
      final end = DateTime.utc(2026, 9, 29, 19);
      final app = AppStore()
        ..automaticBackupsEnabled = false
        ..workoutHistory.add(
          WorkoutRecord(
            week: 1,
            workoutIndex: 0,
            workout: 'Upper',
            date: end,
            status: WorkoutStatus.completed,
            sessionId: 'resumed',
            startedAt: start,
            elapsedSeconds: 1800,
          ),
        );
      Map? written;
      messenger.setMockMethodCallHandler(
        const MethodChannel('progression_lab/health'),
        (call) async {
          if (call.method == 'status') {
            return {
              'platform': 'healthConnect',
              'authorization': 'authorized',
              'available': true,
            };
          }
          if (call.method == 'writeWorkout') {
            written = call.arguments as Map;
            return true;
          }
          return null;
        },
      );
      messenger.setMockMethodCallHandler(cloud, (_) async => null);
      final service = CloudBackupSyncService.shared(app);
      addTearDown(service.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: ProgressionBrand.theme(),
          home: IntegrationsHubScreen(store: app),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Export a saved workout'),
        200,
        scrollable: find.byWidgetPredicate(
          (widget) =>
              widget is Scrollable &&
              widget.axisDirection == AxisDirection.down,
        ),
      );
      await tester.tap(find.text('Export a saved workout'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Upper'));
      await tester.pumpAndSettle();
      expect(written?['startedAt'], start.toIso8601String());
      expect(written?['endedAt'], end.toIso8601String());
      expect(written?['notes'], contains('1800 seconds'));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'experiment creation reviews conditions and requirements before saving',
    (tester) async {
      final app = AppStore()..automaticBackupsEnabled = false;
      messenger.setMockMethodCallHandler(cloud, (_) async => null);
      final service = CloudBackupSyncService.shared(app);
      addTearDown(service.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: ProgressionBrand.theme(),
          home: IntegrationsHubScreen(
            store: app,
            section: IntegrationSection.lab,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start an experiment'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Caffeine timing'));
      await tester.pumpAndSettle();
      expect(find.text('Review caffeine timing'), findsOneWidget);
      expect(
        find.textContaining('6 comparable workouts in each condition'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Log caffeine amount and time'),
        findsOneWidget,
      );
      expect(app.integrationState['integrations'], isNull);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(app.integrationState['integrations'], isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'experiment deletion requires confirmation and cancel keeps setup',
    (tester) async {
      final experiment = LabExperimentTemplates.caffeineTiming();
      final app = AppStore()
        ..automaticBackupsEnabled = false
        ..integrationState = {
          'integrations': {
            'experiments': [experiment.toJson()],
          },
        };
      messenger.setMockMethodCallHandler(cloud, (_) async => null);
      final service = CloudBackupSyncService.shared(app);
      addTearDown(service.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: ProgressionBrand.theme(),
          home: IntegrationsHubScreen(
            store: app,
            section: IntegrationSection.lab,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byTooltip('Delete experiment'),
        200,
        scrollable: find.byWidgetPredicate(
          (widget) =>
              widget is Scrollable &&
              widget.axisDirection == AxisDirection.down,
        ),
      );
      await tester.tap(find.byTooltip('Delete experiment'));
      await tester.pumpAndSettle();
      expect(find.text('Delete this experiment?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(
        (app.integrationState['integrations'] as Map)['experiments'],
        hasLength(1),
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'backup status and explicit restore show replacement preview without writing',
    (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final app = AppStore()..automaticBackupsEnabled = false;
      final old = DateTime.now().subtract(const Duration(days: 1));
      final remote = app.exportState()
        ..['logs'] = [
          SetLog(
            exercise: 'Barbell Bench Press',
            weight: 200,
            reps: 5,
            date: old,
            workout: 'Upper',
          ).toJson(),
        ];
      final bytes = ProgressionBackupCodec.encode(remote, createdAt: old);
      var writes = 0;
      messenger.setMockMethodCallHandler(cloud, (call) async {
        if (call.method == 'status') {
          return {
            'configured': true,
            'provider': 'googleDrive',
            'displayName': 'Training backups',
          };
        }
        if (call.method == 'listBackups') {
          return [
            {
              'name': 'Old-phone.plab',
              'token': 'old',
              'modifiedAt': old.toIso8601String(),
              'size': bytes.length,
            },
          ];
        }
        if (call.method == 'readBackup') return bytes;
        if (call.method == 'writeBackup') writes++;
        return null;
      });
      final service = CloudBackupSyncService.shared(app);
      addTearDown(service.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: ProgressionBrand.theme(),
          home: IntegrationsHubScreen(
            store: app,
            section: IntegrationSection.backup,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('No successful cloud backup yet'), findsOneWidget);
      expect(find.textContaining('Google Drive'), findsOneWidget);
      expect(find.textContaining('googleDrive'), findsNothing);
      await tester.scrollUntilVisible(
        find.text('Restore from cloud'),
        200,
        scrollable: find.byWidgetPredicate(
          (widget) =>
              widget is Scrollable &&
              widget.axisDirection == AxisDirection.down,
        ),
      );
      await tester.tap(find.text('Restore from cloud'));
      await tester.pumpAndSettle();
      expect(find.text('Choose a cloud backup'), findsOneWidget);
      await tester.tap(find.text('Old-phone.plab'));
      await tester.pumpAndSettle();
      expect(
        find.text('Replace device data with this backup?'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Backup: 0 workouts and 1 sets.'),
        findsOneWidget,
      );
      expect(find.textContaining('does not merge histories'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(app.logs, isEmpty);
      expect(writes, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );
}
