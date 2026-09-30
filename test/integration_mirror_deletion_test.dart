import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:progression_lab/integrations_hub.dart';
import 'package:progression_lab/store.dart';

class _HeldIntegrationStore extends AppStore {
  final saved = Completer<void>();
  final release = Completer<void>();

  @override
  Future<void> setIntegrationState(Map<String, dynamic> value) async {
    await super.setIntegrationState(value);
    saved.complete();
    await release.future;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const storage = MethodChannel('iron_cadence/storage');
  const mirror = MethodChannel('progression_lab/integration_mirror_test');
  const body = MethodChannel('progression_lab/body_media');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  test(
    'completed deletion blocks a late integration preference mirror',
    () async {
      var mirrored = 0;
      messenger.setMockMethodCallHandler(storage, (call) async {
        if (call.method == 'deleteAllLocalData') return true;
        return null;
      });
      messenger.setMockMethodCallHandler(body, (_) async => null);
      messenger.setMockMethodCallHandler(mirror, (call) async {
        if (call.method == 'write') mirrored++;
        return null;
      });
      addTearDown(() {
        messenger.setMockMethodCallHandler(storage, null);
        messenger.setMockMethodCallHandler(body, null);
        messenger.setMockMethodCallHandler(mirror, null);
      });
      final store = _HeldIntegrationStore()..automaticBackupsEnabled = false;
      final preferences = IntegrationPreferencesStore(
        store: store,
        channel: mirror,
      )..weeklyReviewEnabled = true;
      final save = preferences.save();
      await store.saved.future;
      await store.deleteAllLocalData();
      store.release.complete();
      await expectLater(save, throwsStateError);
      expect(mirrored, 0);
      expect(store.integrationState, isEmpty);
    },
  );
}
