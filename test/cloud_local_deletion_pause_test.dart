import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:progression_lab/cloud_sync.dart';
import 'package:progression_lab/store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const cloud = MethodChannel('progression_lab/cloud_deletion_pause_test');
  const storage = MethodChannel('iron_cadence/storage');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(cloud, null);
    messenger.setMockMethodCallHandler(storage, null);
  });

  testWidgets('local deletion drains an upload and stops subsequent uploads', (
    tester,
  ) async {
    final uploaded = Completer<Map<String, Object>>();
    final started = Completer<void>();
    var uploads = 0;
    messenger.setMockMethodCallHandler(storage, (_) async => null);
    messenger.setMockMethodCallHandler(cloud, (call) async {
      if (call.method == 'status') {
        return {
          'configured': true,
          'provider': 'googleDrive',
          'automaticSyncEnabled': true,
        };
      }
      if (call.method == 'writeBackup') {
        uploads++;
        if (!started.isCompleted) started.complete();
        return uploaded.future;
      }
      return null;
    });
    final store = AppStore()..automaticBackupsEnabled = false;
    final service = CloudBackupSyncService(store: store, channel: cloud);
    addTearDown(service.dispose);
    await service.initialize();
    final upload = service.uploadNow();
    await started.future;
    var paused = false;
    final pause = service.pauseForLocalDeletion().then((_) => paused = true);
    await tester.pump();
    expect(paused, isFalse);
    await expectLater(service.uploadNow(), throwsStateError);
    uploaded.complete({
      'name': 'retained-cloud-backup.plab',
      'token': 'retained-copy',
      'modifiedAt': DateTime.now().toUtc().toIso8601String(),
      'size': 1000,
    });
    await upload;
    await pause;
    expect(paused, isTrue);
    expect(service.busy, isFalse);
    await store.setUnit('kg');
    await tester.pump(const Duration(seconds: 10));
    expect(uploads, 1);
    await expectLater(service.listBackups(), throwsStateError);
    service.resumeAfterFailedLocalDeletion();
    await tester.pump(const Duration(seconds: 10));
    expect(uploads, 2);
  });
}
