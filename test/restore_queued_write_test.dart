import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:progression_lab/store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const storage = MethodChannel('iron_cadence/storage');
  const body = MethodChannel('progression_lab/body_media');
  for (final bodyCommit in [false, true]) {
    test(
      'Queued unchanged ${bodyCommit ? 'body commit' : 'save'} rejects restore and keeps memory and disk consistent',
      () async {
        SetLog set(double weight) => SetLog(
          exercise: 'Bench Press',
          weight: weight,
          reps: 5,
          date: DateTime(2026, 9, 1),
          workout: 'Upper',
        );
        final store = AppStore()
          ..automaticBackupsEnabled = false
          ..logs.add(set(185));
        final remote = store.exportState()..['logs'] = [set(200).toJson()];
        final started = Completer<void>();
        final release = Completer<void>();
        var writes = 0;
        Map<String, dynamic>? disk;
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        messenger.setMockMethodCallHandler(storage, (call) async {
          if (call.method == 'write') {
            if (++writes == 1) {
              started.complete();
              await release.future;
            }
            disk = jsonDecode(call.arguments as String) as Map<String, dynamic>;
          }
          return null;
        });
        messenger.setMockMethodCallHandler(body, (call) async {
          if (call.method == 'commit') {
            final arguments = call.arguments as Map;
            disk =
                jsonDecode(arguments['state'] as String)
                    as Map<String, dynamic>;
          }
          return null;
        });
        addTearDown(() {
          messenger.setMockMethodCallHandler(storage, null);
          messenger.setMockMethodCallHandler(body, null);
        });
        final restoring = expectLater(
          store.restoreState(remote),
          throwsStateError,
        );
        await started.future;
        final saving = bodyCommit
            ? store.commitBodyJournal(const [], const {})
            : store.save(createAutomaticBackup: false);
        release.complete();
        await Future.wait([restoring, saving]);
        expect(store.logs.map((log) => log.weight), [185]);
        expect((disk!['logs'] as List).map((value) => (value as Map)['w']), [
          185,
        ]);
        store.dispose();
      },
    );
  }
}
