import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:progression_lab/cloud_sync.dart';
import 'package:progression_lab/data_portability_core.dart';
import 'package:progression_lab/store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const cloud = MethodChannel('progression_lab/cloud_error_feedback_test');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  test(
    'cloud backup status hides integrity internals and keeps device data',
    () async {
      final store = AppStore()..automaticBackupsEnabled = false;
      final before = jsonEncode(store.exportState());
      final source = ZipDecoder().decodeBytes(
        ProgressionBackupCodec.encode(store.exportState()),
      );
      final archive = Archive();
      for (final file in source) {
        final bytes = file.name == 'state.json'
            ? utf8.encode('{"schemaVersion":21,"unit":"kg"}')
            : file.content as List<int>;
        archive.addFile(ArchiveFile(file.name, bytes.length, bytes));
      }
      final damaged = ZipEncoder().encode(archive)!;
      messenger.setMockMethodCallHandler(cloud, (call) async {
        if (call.method == 'readBackup') return damaged;
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(cloud, null));
      final service = CloudBackupSyncService(store: store, channel: cloud);
      addTearDown(service.dispose);
      await expectLater(
        service.prepareRestore(
          CloudBackupInfo(
            name: 'selected-copy.plab',
            modifiedAt: DateTime.now().toUtc(),
            size: damaged.length,
            token: 'copy',
          ),
        ),
        throwsA(isA<BackupValidationException>()),
      );
      expect(service.lastError, contains('damaged or incomplete'));
      expect(service.lastError, contains('Choose another backup'));
      expect(service.lastError, isNot(contains('state.json')));
      expect(service.lastError, isNot(contains('checksum')));
      expect(jsonEncode(store.exportState()), before);
    },
  );
}
