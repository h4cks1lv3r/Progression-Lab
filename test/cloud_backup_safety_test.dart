import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:progression_lab/cloud_sync.dart';
import 'package:progression_lab/data_portability.dart';
import 'package:progression_lab/data_portability_core.dart';
import 'package:progression_lab/store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const cloud = MethodChannel('progression_lab/cloud_safety_test');
  const storage = MethodChannel('iron_cadence/storage');
  const files = MethodChannel('progression_lab/data_portability');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final yesterday = DateTime.now().toUtc().subtract(const Duration(days: 1));
  final backup = CloudBackupInfo(
    name: 'previous-device.plab',
    modifiedAt: yesterday,
    createdAt: yesterday,
    size: 1000,
    token: 'cloud-backup',
  );
  final folder = <String, Object>{
    'configured': true,
    'provider': 'googleDrive',
    'displayName': 'Training backups',
  };

  SetLog set(double weight) => SetLog(
    exercise: 'Barbell Bench Press',
    exerciseId: 'barbell_bench_press',
    weight: weight,
    reps: 5,
    date: yesterday,
    workout: 'Upper',
  );

  AppStore appWithSet(double weight) => AppStore()
    ..automaticBackupsEnabled = false
    ..logs.add(set(weight));

  Map<String, Object> backupMetadata() => {
    'name': backup.name,
    'token': backup.token,
    'modifiedAt': yesterday.toIso8601String(),
    'createdAt': yesterday.toIso8601String(),
    'size': 1000,
  };

  setUp(() {
    messenger.setMockMethodCallHandler(storage, (_) async => null);
    messenger.setMockMethodCallHandler(files, (_) async => null);
  });
  tearDown(() {
    messenger.setMockMethodCallHandler(cloud, null);
    messenger.setMockMethodCallHandler(storage, null);
    messenger.setMockMethodCallHandler(files, null);
  });

  test('identical state with an older export time is aligned', () async {
    final app = appWithSet(185);
    final state = app.exportState();
    // Map insertion order must not create a false conflict.
    final reordered = {
      for (final key in state.keys.toList().reversed) key: state[key],
    };
    final bytes = ProgressionBackupCodec.encode(
      reordered,
      createdAt: yesterday,
    );
    messenger.setMockMethodCallHandler(
      cloud,
      (call) async => switch (call.method) {
        'listBackups' => [backupMetadata()],
        'readBackup' => bytes,
        _ => null,
      },
    );
    final service = CloudBackupSyncService(store: app, channel: cloud);
    addTearDown(service.dispose);
    final preview = await service.preview();
    expect(preview.direction, CloudSyncDirection.none);
    expect(service.backupStatusVerified, isTrue);
    expect(service.pendingChanges, isFalse);
  });

  test(
    'different saved histories require a choice regardless of export time',
    () async {
      final app = appWithSet(185);
      final state = app.exportState()..['logs'] = [set(200).toJson()];
      final bytes = ProgressionBackupCodec.encode(state, createdAt: yesterday);
      var writes = 0;
      messenger.setMockMethodCallHandler(cloud, (call) async {
        if (call.method == 'listBackups') return [backupMetadata()];
        if (call.method == 'readBackup') return bytes;
        if (call.method == 'writeBackup') writes++;
        return null;
      });
      final service = CloudBackupSyncService(store: app, channel: cloud);
      addTearDown(service.dispose);
      expect((await service.preview()).direction, CloudSyncDirection.conflict);
      expect(writes, 0);
      expect(app.logs.single.weight, 185);
    },
  );

  test(
    'failed upload preserves last success and pending work, then retry clears error',
    () async {
      final app = appWithSet(185);
      var fail = false;
      messenger.setMockMethodCallHandler(cloud, (call) async {
        if (call.method == 'status') return folder;
        if (call.method == 'writeBackup') {
          if (fail) {
            throw PlatformException(
              code: 'permission_denied',
              message: 'provider diagnostics',
            );
          }
          return backupMetadata();
        }
        return null;
      });
      final service = CloudBackupSyncService(store: app, channel: cloud);
      addTearDown(service.dispose);
      await service.initialize();
      expect(service.status.lastSuccessfulSync, isNull);
      await service.uploadNow();
      final successfulAt = service.status.lastSuccessfulSync;
      expect(successfulAt, isNotNull);
      expect(service.pendingChanges, isFalse);
      await app.add(set(200));
      expect(service.pendingChanges, isTrue);
      fail = true;
      await expectLater(service.uploadNow(), throwsA(isA<PlatformException>()));
      expect(service.status.lastSuccessfulSync, successfulAt);
      expect(service.lastError, contains('try again'));
      expect(service.lastError, isNot(contains('provider diagnostics')));
      expect(service.pendingChanges, isTrue);
      final uploadError = service.lastError;
      await service.listBackups();
      expect(service.lastError, uploadError);
      fail = false;
      await service.uploadNow();
      expect(service.lastError, isNull);
      expect(service.pendingChanges, isFalse);
    },
  );

  test(
    'cloud restore stops before replacement if safety backup cannot be verified',
    () async {
      final app = appWithSet(185);
      final state = app.exportState()..['logs'] = [set(200).toJson()];
      final remote = ProgressionBackupCodec.encode(state, createdAt: yesterday);
      messenger.setMockMethodCallHandler(
        cloud,
        (call) async => call.method == 'readBackup' ? remote : null,
      );
      messenger.setMockMethodCallHandler(
        files,
        (call) async => switch (call.method) {
          'writeAutomaticBackup' => '/backups/safety.plab',
          'readAutomaticBackup' => Uint8List.fromList([1, 2, 3]),
          _ => null,
        },
      );
      final service = CloudBackupSyncService(store: app, channel: cloud);
      addTearDown(service.dispose);
      final preview = await service.prepareRestore(backup);
      expect(preview.backupSetCount, 1);
      expect(preview.currentSetCount, 1);
      await expectLater(
        service.restorePrepared(preview),
        throwsA(isA<BackupValidationException>()),
      );
      expect(app.logs.single.weight, 185);
    },
  );

  test(
    'local restore stops when the safety writer returns no saved file',
    () async {
      final app = appWithSet(185);
      final remote = ProgressionBackupCodec.decode(
        ProgressionBackupCodec.encode(
          app.exportState()..['logs'] = [set(200).toJson()],
        ),
      );
      await expectLater(
        DataPortabilityController(app).restoreDocument(remote),
        throwsA(isA<StateError>()),
      );
      expect(app.logs.single.weight, 185);
    },
  );

  test(
    'restore cannot overwrite work saved after the replacement was reviewed',
    () async {
      final app = appWithSet(185);
      final remote = ProgressionBackupCodec.encode(
        app.exportState()..['logs'] = [set(200).toJson()],
      );
      var safetyWrites = 0;
      messenger.setMockMethodCallHandler(
        cloud,
        (call) async => call.method == 'readBackup' ? remote : null,
      );
      messenger.setMockMethodCallHandler(files, (_) async {
        safetyWrites++;
        return null;
      });
      final service = CloudBackupSyncService(store: app, channel: cloud);
      addTearDown(service.dispose);
      final preview = await service.prepareRestore(backup);
      await app.add(set(225));
      await expectLater(
        service.restorePrepared(preview),
        throwsA(isA<StateError>()),
      );
      expect(app.logs.map((log) => log.weight), [185, 225]);
      expect(safetyWrites, 0);
    },
  );

  test(
    'restore cannot overwrite work saved while the safety copy is verified',
    () async {
      final app = appWithSet(185);
      final remote = ProgressionBackupCodec.encode(
        app.exportState()..['logs'] = [set(200).toJson()],
      );
      final readingSafety = Completer<void>();
      final continueRead = Completer<void>();
      Uint8List? safety;
      messenger.setMockMethodCallHandler(
        cloud,
        (call) async => call.method == 'readBackup' ? remote : null,
      );
      messenger.setMockMethodCallHandler(files, (call) async {
        if (call.method == 'writeAutomaticBackup') {
          safety = (call.arguments as Map)['bytes'] as Uint8List;
          return '/backups/safety.plab';
        }
        if (call.method == 'readAutomaticBackup') {
          readingSafety.complete();
          await continueRead.future;
          return safety;
        }
        return null;
      });
      final service = CloudBackupSyncService(store: app, channel: cloud);
      addTearDown(service.dispose);
      final restoring = service.restoreRemote(backup);
      await readingSafety.future;
      await app.add(set(225));
      final stopped = expectLater(restoring, throwsA(isA<StateError>()));
      continueRead.complete();
      await stopped;
      expect(app.logs.map((log) => log.weight), [185, 225]);
    },
  );

  test(
    'explicit restore replaces data only after the exact safety copy is verified',
    () async {
      final app = appWithSet(185);
      final state = app.exportState()..['logs'] = [set(200).toJson()];
      final remote = ProgressionBackupCodec.encode(state, createdAt: yesterday);
      Uint8List? safety;
      var restored = false;
      messenger.setMockMethodCallHandler(storage, (call) async {
        if (call.method == 'write') {
          expect(safety, isNotNull);
          expect(ProgressionBackupCodec.decode(safety!).state['logs'], [
            set(185).toJson(),
          ]);
          restored = true;
        }
        return null;
      });
      messenger.setMockMethodCallHandler(
        cloud,
        (call) async => switch (call.method) {
          'status' => {
            ...folder,
            'lastSuccessfulSync': yesterday.toIso8601String(),
          },
          'readBackup' => remote,
          _ => null,
        },
      );
      messenger.setMockMethodCallHandler(files, (call) async {
        if (call.method == 'writeAutomaticBackup') {
          safety ??= (call.arguments as Map)['bytes'] as Uint8List;
          return '/backups/safety.plab';
        }
        if (call.method == 'readAutomaticBackup') return safety;
        return null;
      });
      final service = CloudBackupSyncService(store: app, channel: cloud);
      addTearDown(service.dispose);
      await service.initialize();
      await service.restoreRemote(backup);
      expect(restored, isTrue);
      expect(app.logs.single.weight, 200);
      expect(service.status.lastSuccessfulSync, yesterday);
    },
  );
}
