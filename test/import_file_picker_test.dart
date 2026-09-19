import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:progression_lab/data_portability.dart';
import 'package:progression_lab/data_portability_core.dart';
import 'package:progression_lab/store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('progression_lab/data_portability');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final csv = Uint8List.fromList(
    utf8.encode(
      'Date,Workout Name,Exercise Name,Set Order,Weight,Weight Unit,Reps\n'
      '2026-09-01 18:00,Upper,Bench Press,1,100,kg,5\n',
    ),
  );
  late AppStore store;
  late DataPortabilityController controller;
  late Map<String, dynamic> before;
  Map<String, Object?>? selectedFile;
  late List<String> calls;

  setUp(() {
    selectedFile = null;
    calls = [];
    store = AppStore()..week = 17;
    store.logs.add(
      SetLog(
        exercise: 'Dip',
        weight: 0,
        reps: 8,
        date: DateTime(2026, 9, 1),
        workout: 'Existing workout',
      ),
    );
    before = store.exportState();
    controller = DataPortabilityController(store);
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      if (call.method == 'pickFile') return selectedFile;
      fail('Picking a file must not write a backup or import any data.');
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    store.dispose();
  });

  for (final mime in [
    'application/vnd.ms-excel',
    'text/plain',
    'application/octet-stream',
  ]) {
    test('CSV with provider MIME $mime reaches import preview', () async {
      selectedFile = {
        'name': 'Strong-Export.CSV',
        'bytes': csv,
        'mimeType': mime,
      };

      final candidate = await controller.pickImportFile();

      expect(candidate, isA<CsvImportCandidate>());
      final csvCandidate = candidate! as CsvImportCandidate;
      final mapping = csvCandidate.inspection.suggestedMapping;
      expect(mapping, isNotNull);
      final plan = controller.buildImportPlan(
        candidate: csvCandidate,
        mapping: mapping!,
        sourceWeightUnit: 'kg',
      );
      expect(plan.setCount, 1);
      expect(plan.workouts.single.sets.single.exercise, 'Bench Press');
      expect(plan.workouts.single.sets.single.reps, 5);
      expect(store.exportState(), before);
      expect(calls, ['pickFile']);
    });
  }

  test('backup with a custom provider MIME reaches restore preview', () async {
    final source = AppStore()..week = 33;
    addTearDown(source.dispose);
    final sourceState = source.exportState();
    selectedFile = {
      'name': 'Progression-Lab-Backup.PLAB',
      'bytes': ProgressionBackupCodec.encode(sourceState),
      'mimeType': 'application/x-plab',
    };

    final candidate = await controller.pickImportFile();

    expect(candidate, isA<BackupImportCandidate>());
    expect((candidate! as BackupImportCandidate).document.state, sourceState);
    expect(store.exportState(), before);
    expect(calls, ['pickFile']);
  });

  test('canceling the picker preserves current data', () async {
    expect(await controller.pickImportFile(), isNull);
    expect(store.exportState(), before);
    expect(calls, ['pickFile']);
  });

  test(
    'unsupported file gives a supported-format error without changes',
    () async {
      selectedFile = {
        'name': 'workouts.pdf',
        'bytes': csv,
        'mimeType': 'text/csv',
      };

      await expectLater(
        controller.pickImportFile(),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            contains('Choose a .plab backup'),
          ),
        ),
      );
      expect(store.exportState(), before);
      expect(calls, ['pickFile']);
    },
  );

  test(
    'file selection still validates backup contents before restore',
    () async {
      selectedFile = {
        'name': 'not-a-backup.plab',
        'bytes': csv,
        'mimeType': 'application/x-plab',
      };

      await expectLater(
        controller.pickImportFile(),
        throwsA(isA<BackupValidationException>()),
      );
      expect(store.exportState(), before);
      expect(calls, ['pickFile']);
    },
  );
}
