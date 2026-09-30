import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:progression_lab/body_media.dart';
import 'package:progression_lab/brand.dart';
import 'package:progression_lab/data_management_screen.dart';
import 'package:progression_lab/data_portability.dart';
import 'package:progression_lab/store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const storage = MethodChannel('iron_cadence/storage');
  const backups = MethodChannel('progression_lab/data_portability');
  const guides = MethodChannel('progression_lab/guide_state');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late List<String> calls;
  setUp(() {
    calls = [];
    messenger.setMockMethodCallHandler(storage, (call) async {
      calls.add(call.method);
      if (call.method == 'deleteAllLocalData') return true;
      return null;
    });
    messenger.setMockMethodCallHandler(backups, (_) async => null);
    messenger.setMockMethodCallHandler(guides, (_) async => {'seen': []});
    messenger.setMockMethodCallHandler(
      BodyMediaStore.channel,
      (_) async => null,
    );
  });
  tearDown(() {
    for (final channel in [storage, backups, guides, BodyMediaStore.channel]) {
      messenger.setMockMethodCallHandler(channel, null);
    }
  });

  AppStore populated() => AppStore()
    ..automaticBackupsEnabled = false
    ..integrationState = {
      'integrations': {
        'privateKey': 'secret',
        'experiments': ['saved'],
      },
    }
    ..logs = [
      SetLog(
        exercise: 'Bench Press',
        weight: 185,
        reps: 5,
        date: DateTime(2026, 9, 30),
        workout: 'Upper',
      ),
    ]
    ..bodyMedia.apply({
      'checkIns': [
        {
          'id': 'private',
          'date': '2026-09-30',
          'notes': 'private',
          'photos': [],
        },
      ],
      'draft': {'id': 'draft'},
    });

  test(
    'Successful reset clears state and retires old persistence paths',
    () async {
      final store = populated();
      await store.beginOpenWorkout();
      await store.beginCuratedWorkout('hunnam_arthur');
      await store.deleteAllLocalData();
      expect(store.deletedAllLocalData, isTrue);
      expect(store.logs, isEmpty);
      expect(store.openWorkoutDraft, isNull);
      expect(store.curatedTraining.drafts, isEmpty);
      expect(store.integrationState, isEmpty);
      expect(store.bodyMedia.checkIns, isEmpty);
      expect(store.bodyMedia.draft, isNull);
      await expectLater(store.save(), throwsStateError);
      await expectLater(store.commitBodyJournal([], {}), throwsStateError);
      await expectLater(
        store.restoreState(AppStore().exportState()),
        throwsStateError,
      );
      await expectLater(
        store.bodyMedia.save({'checkIns': []}),
        throwsStateError,
      );
      expect(calls.where((value) => value == 'deleteAllLocalData').length, 1);
      store.dispose();
    },
  );

  for (final refusal in [true, false]) {
    test(
      'Native ${refusal ? 'refusal' : 'failure'} preserves state and allows retry',
      () async {
        final store = populated();
        final before = jsonEncode(store.exportState());
        final photos = jsonEncode(store.bodyMedia.journal);
        messenger.setMockMethodCallHandler(storage, (call) async {
          if (call.method == 'deleteAllLocalData') {
            if (refusal) return false;
            throw PlatformException(code: 'local_data_delete_failed');
          }
          return null;
        });
        await expectLater(store.deleteAllLocalData(), throwsA(isA<Object>()));
        expect(store.deletedAllLocalData, isFalse);
        expect(store.deletingAllLocalData, isFalse);
        expect(jsonEncode(store.exportState()), before);
        expect(jsonEncode(store.bodyMedia.journal), photos);
        await store.save(createAutomaticBackup: false);
        await store.bodyMedia.save(store.bodyMedia.journal);
        store.dispose();
      },
    );
  }

  test(
    'Deletion drains an active primary save and suppresses its later backup',
    () async {
      final store = populated()..automaticBackupsEnabled = true;
      final started = Completer<void>(), release = Completer<void>();
      messenger.setMockMethodCallHandler(storage, (call) async {
        calls.add(call.method);
        if (call.method == 'write') {
          started.complete();
          await release.future;
        }
        return call.method == 'deleteAllLocalData' ? true : null;
      });
      messenger.setMockMethodCallHandler(backups, (call) async {
        calls.add('backup:${call.method}');
        return null;
      });
      final saving = store.save();
      await started.future;
      final deleting = store.deleteAllLocalData();
      await Future<void>.delayed(Duration.zero);
      expect(calls, ['write']);
      await expectLater(store.save(), throwsStateError);
      release.complete();
      await Future.wait([saving, deleting]);
      expect(calls, ['write', 'deleteAllLocalData']);
      expect(store.deletedAllLocalData, isTrue);
      store.dispose();
    },
  );

  test('Deletion waits for an in-flight private photo import', () async {
    final store = populated();
    final started = Completer<void>(), release = Completer<void>();
    messenger.setMockMethodCallHandler(BodyMediaStore.channel, (call) async {
      if (call.method == 'importPhoto') {
        started.complete();
        await release.future;
        return {'asset': 'p.jpg', 'thumbnail': 't.jpg'};
      }
      return null;
    });
    final importing = store.bodyMedia.importPhoto('/private/source.jpg');
    await started.future;
    final deleting = store.deleteAllLocalData();
    await Future<void>.delayed(Duration.zero);
    expect(calls, isEmpty);
    await expectLater(
      store.bodyMedia.importPhoto('/private/another.jpg'),
      throwsStateError,
    );
    release.complete();
    await importing;
    await deleting;
    expect(calls, ['deleteAllLocalData']);
    store.dispose();
  });

  test(
    'Deletion waits for an in-flight automatic backup before native reset',
    () async {
      final store = populated();
      final started = Completer<void>(), release = Completer<void>();
      messenger.setMockMethodCallHandler(backups, (call) async {
        if (call.method == 'writeAutomaticBackup') {
          started.complete();
          await release.future;
          calls.add('backup finished');
          return '/app/backup.plab';
        }
        return null;
      });
      final backingUp = store.createAutomaticBackup(required: true);
      await started.future;
      final deleting = store.deleteAllLocalData();
      await Future<void>.delayed(Duration.zero);
      expect(calls, isEmpty);
      release.complete();
      await Future.wait([backingUp, deleting]);
      expect(calls, ['backup finished', 'deleteAllLocalData']);
      store.dispose();
    },
  );

  test(
    'A committed partial native cleanup retires the store and reports failure',
    () async {
      final store = populated();
      messenger.setMockMethodCallHandler(storage, (call) async {
        if (call.method == 'deleteAllLocalData')
          throw PlatformException(code: 'local_data_delete_partial');
        return null;
      });
      await expectLater(
        store.deleteAllLocalData(),
        throwsA(isA<PlatformException>()),
      );
      expect(store.deletedAllLocalData, isTrue);
      expect(store.logs, isEmpty);
      await expectLater(store.save(), throwsStateError);
      store.dispose();
    },
  );

  test(
    'Startup with unfinished cleanup does not read retained app state',
    () async {
      final store = AppStore();
      messenger.setMockMethodCallHandler(storage, (call) async {
        calls.add(call.method);
        if (call.method == 'deletionStatus') return {'needsRetry': true};
        if (call.method == 'read') return jsonEncode(populated().exportState());
        return null;
      });
      await store.load();
      expect(calls, ['deletionStatus']);
      expect(store.localDataDeletionNeedsRetry, isTrue);
      expect(store.logs, isEmpty);
      expect(store.isLoaded, isTrue);
      await expectLater(store.save(), throwsStateError);
      store.dispose();
    },
  );

  test(
    'An incomplete rollback blocks saves but permits an explicit deletion retry',
    () async {
      final store = populated();
      var attempt = 0;
      messenger.setMockMethodCallHandler(storage, (call) async {
        if (call.method == 'deleteAllLocalData' && ++attempt == 1) {
          throw PlatformException(code: 'local_data_delete_incomplete');
        }
        return call.method == 'deleteAllLocalData' ? true : null;
      });
      await expectLater(
        store.deleteAllLocalData(),
        throwsA(isA<PlatformException>()),
      );
      expect(store.deletedAllLocalData, isFalse);
      expect(store.localDataDeletionNeedsRetry, isTrue);
      await expectLater(store.save(), throwsStateError);
      await expectLater(
        store.bodyMedia.save(store.bodyMedia.journal),
        throwsStateError,
      );
      await store.deleteAllLocalData();
      expect(store.deletedAllLocalData, isTrue);
      expect(store.localDataDeletionNeedsRetry, isFalse);
      expect(store.logs, isEmpty);
      store.dispose();
    },
  );

  test(
    'An explicitly older bridge can load state without a deletion-status method',
    () async {
      final store = AppStore();
      messenger.setMockMethodCallHandler(storage, (call) async {
        calls.add(call.method);
        if (call.method == 'deletionStatus')
          throw PlatformException(code: 'unknown_method');
        if (call.method == 'read') return jsonEncode(populated().exportState());
        return null;
      });
      await store.load();
      expect(calls, ['deletionStatus', 'read']);
      expect(store.localDataDeletionNeedsRetry, isFalse);
      expect(store.logs, hasLength(1));
      store.dispose();
    },
  );

  test(
    'A failed status check does not load private state or silently permit writes',
    () async {
      final store = AppStore();
      messenger.setMockMethodCallHandler(storage, (call) async {
        calls.add(call.method);
        if (call.method == 'deletionStatus')
          throw PlatformException(code: 'storage_access_failed');
        return null;
      });
      await store.load();
      expect(calls, ['deletionStatus']);
      expect(store.localDataDeletionNeedsRetry, isTrue);
      expect(store.localDataDeletionWarning, contains('Close and reopen'));
      await expectLater(store.save(), throwsStateError);
      store.dispose();
    },
  );

  test('Deletion drains an active body transaction before reset', () async {
    final store = populated();
    final started = Completer<void>(), release = Completer<void>();
    messenger.setMockMethodCallHandler(BodyMediaStore.channel, (call) async {
      if (call.method == 'commit') {
        started.complete();
        await release.future;
        calls.add('body committed');
      }
      return null;
    });
    final committing = store.commitBodyJournal([], {
      'version': 1,
      'checkIns': [],
    });
    await started.future;
    final deleting = store.deleteAllLocalData();
    await Future<void>.delayed(Duration.zero);
    expect(calls, isEmpty);
    release.complete();
    await Future.wait([committing, deleting]);
    expect(calls, ['body committed', 'deleteAllLocalData']);
    expect(store.bodyMedia.checkIns, isEmpty);
    store.dispose();
  });

  test(
    'Deletion waits for a controller safety file and its verification read',
    () async {
      final store = populated();
      final started = Completer<void>(), release = Completer<void>();
      Object? bytes;
      messenger.setMockMethodCallHandler(backups, (call) async {
        if (call.method == 'writeAutomaticBackup') {
          bytes = (call.arguments as Map)['bytes'];
          started.complete();
          await release.future;
          calls.add('safety file written');
          return '/private/safety.plab';
        }
        if (call.method == 'readAutomaticBackup') {
          calls.add('safety file verified');
          return bytes;
        }
        return null;
      });
      final checking = DataPortabilityController(
        store,
      ).createVerifiedSafetyBackup(reason: 'before-restore');
      await started.future;
      final deleting = store.deleteAllLocalData();
      await Future<void>.delayed(Duration.zero);
      expect(calls, isEmpty);
      release.complete();
      await Future.wait([checking, deleting]);
      expect(calls, [
        'safety file written',
        'safety file verified',
        'deleteAllLocalData',
      ]);
      store.dispose();
    },
  );

  testWidgets(
    'Delete needs exact typed confirmation and Cancel does not erase data',
    (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = populated();
      await tester.pumpWidget(
        MaterialApp(
          theme: ProgressionBrand.theme(),
          home: DataManagementScreen(store: store),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Delete all data'), 500);
      await tester.tap(find.text('Delete all data'));
      await tester.pumpAndSettle();
      expect(find.text('Delete all data on this device?'), findsOneWidget);
      expect(
        find.textContaining('Cloud backups, files you exported'),
        findsOneWidget,
      );
      final button = find.widgetWithText(FilledButton, 'Delete all data');
      expect(tester.widget<FilledButton>(button).onPressed, isNull);
      await tester.enterText(
        find.byKey(const ValueKey('delete-local-data-confirmation')),
        'delete',
      );
      await tester.pump();
      expect(tester.widget<FilledButton>(button).onPressed, isNull);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(calls.where((value) => value == 'deleteAllLocalData'), isEmpty);
      expect(store.logs, hasLength(1));
      await tester.tap(find.text('Delete all data'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('delete-local-data-confirmation')),
        'Delete',
      );
      await tester.pump();
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(
        calls.where((value) => value == 'deleteAllLocalData'),
        hasLength(1),
      );
      expect(store.logs, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      store.dispose();
    },
  );
}
