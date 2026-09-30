import 'dart:convert';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:progression_lab/store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const storage = MethodChannel('iron_cadence/storage');
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storage, null),
  );

  AppStore current() => AppStore()
    ..automaticBackupsEnabled = false
    ..integrationState = {
      'private': {'current': true},
    }
    ..logs = [
      SetLog(
        exercise: 'Barbell Bench Press',
        weight: 185,
        reps: 5,
        date: DateTime(2026, 9, 30),
        workout: 'Current workout',
      ),
    ];

  test(
    'Rejecting a newer schema preserves current data and integration settings',
    () async {
      final store = current();
      final before = jsonEncode(store.exportState());
      final remote = AppStore().exportState()
        ..['schemaVersion'] = AppStore.schemaVersion + 1
        ..['integrationState'] = {'private': 'remote'};
      await expectLater(store.restoreState(remote), throwsStateError);
      expect(jsonEncode(store.exportState()), before);
      store.dispose();
    },
  );

  test(
    'A failed durable restore write rolls back data and integration settings',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(storage, (call) async {
            if (call.method == 'write')
              throw PlatformException(code: 'disk_full');
            return null;
          });
      final store = current();
      final before = jsonEncode(store.exportState());
      final remote = AppStore().exportState()
        ..['integrationState'] = {'private': 'remote'};
      await expectLater(
        store.restoreState(remote),
        throwsA(isA<PlatformException>()),
      );
      expect(jsonEncode(store.exportState()), before);
      store.dispose();
    },
  );

  for (final failWrite in [true, false]) {
    test(
      'Concurrent saved set survives a ${failWrite ? 'failed' : 'conflicting successful'} restore write',
      () async {
        final started = Completer<void>();
        final release = Completer<void>();
        var writes = 0;
        Map<String, dynamic>? disk;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(storage, (call) async {
              if (call.method == 'write') {
                if (++writes == 1) {
                  started.complete();
                  await release.future;
                  if (failWrite)
                    throw PlatformException(code: 'failed_restore_write');
                }
                disk =
                    jsonDecode(call.arguments as String)
                        as Map<String, dynamic>;
              }
              return null;
            });
        final store = current();
        final remote = store.exportState()
          ..['logs'] = [
            SetLog(
              exercise: 'Barbell Bench Press',
              weight: 200,
              reps: 5,
              date: DateTime(2026, 9, 29),
              workout: 'Remote',
            ).toJson(),
          ];
        final restoring = expectLater(
          store.restoreState(remote),
          throwsA(failWrite ? isA<PlatformException>() : isA<StateError>()),
        );
        await started.future;
        final adding = store.add(
          SetLog(
            exercise: 'Barbell Bench Press',
            weight: 225,
            reps: 5,
            date: DateTime(2026, 9, 30),
            workout: 'Current workout',
          ),
        );
        expect(store.logs.map((log) => log.weight), [185, 225]);
        release.complete();
        await Future.wait([restoring, adding]);
        expect(store.logs.map((log) => log.weight), [185, 225]);
        expect((disk!['logs'] as List).map((value) => (value as Map)['w']), [
          185,
          225,
        ]);
        store.dispose();
      },
    );
  }
}
