import 'dart:typed_data';

import 'comprehensive_export.dart';
import 'data_portability_bridge.dart';
import 'data_portability_core.dart';
import 'store.dart';

sealed class DataImportCandidate {
  const DataImportCandidate(this.file);

  final PortablePickedFile file;
}

class BackupImportCandidate extends DataImportCandidate {
  const BackupImportCandidate(super.file, this.document);

  final PortableBackupDocument document;
}

class CsvImportCandidate extends DataImportCandidate {
  const CsvImportCandidate(super.file, this.inspection);

  final CsvInspection inspection;
}

class DataPortabilityController {
  const DataPortabilityController(this.store);

  final AppStore store;

  String _dateStamp([DateTime? value]) {
    final date = value ?? DateTime.now();
    return '${date.year.toString().padLeft(4, '0')}'
        '${date.month.toString().padLeft(2, '0')}'
        '${date.day.toString().padLeft(2, '0')}-'
        '${date.hour.toString().padLeft(2, '0')}'
        '${date.minute.toString().padLeft(2, '0')}'
        '${date.second.toString().padLeft(2, '0')}';
  }

  Uint8List buildBackup({String reason = 'manual'}) =>
      ProgressionBackupCodec.encode(store.exportState(), reason: reason);

  Future<String?> saveBackup() => DataPortabilityBridge.saveFile(
    bytes: buildBackup(),
    fileName: 'Progression-Lab-Backup-${_dateStamp()}.plab',
    mimeType: 'application/zip',
  );

  Future<void> shareBackup() => DataPortabilityBridge.shareFile(
    bytes: buildBackup(),
    fileName: 'Progression-Lab-Backup-${_dateStamp()}.plab',
    mimeType: 'application/zip',
  );

  Future<String?> savePortableCsv() => DataPortabilityBridge.saveFile(
    bytes: ComprehensivePortableExport.encodePortableCsvZip(
      store.exportState(),
    ),
    fileName: 'Progression-Lab-CSV-${_dateStamp()}.zip',
    mimeType: 'application/zip',
  );

  Future<String?> saveStrongCompatibleCsv() => DataPortabilityBridge.saveFile(
    bytes: ProgressionCsvExport.encodeStrongCompatibleCsv(store.exportState()),
    fileName: 'Progression-Lab-Strong-Compatible-${_dateStamp()}.csv',
    mimeType: 'text/csv',
  );

  Future<DataImportCandidate?> pickImportFile() async {
    var file = await DataPortabilityBridge.pickFile();
    if (file == null) return null;
    var lower = file.name.toLowerCase();
    if (lower.endsWith('.plab')) {
      return BackupImportCandidate(
        file,
        ProgressionBackupCodec.decode(file.bytes),
      );
    }
    if (lower.endsWith('.fitnotes')) {
      file = await DataPortabilityBridge.convertFitNotes(file);
      lower = file.name.toLowerCase();
    }
    if (lower.endsWith('.json')) {
      return CsvImportCandidate(
        file,
        WorkoutCsvImporter.inspectJson(file.bytes),
      );
    }
    if (lower.endsWith('.csv') ||
        lower.endsWith('.tsv') ||
        lower.endsWith('.txt')) {
      return CsvImportCandidate(
        file,
        WorkoutCsvImporter.inspect(file.bytes, fileName: file.name),
      );
    }
    if (lower.endsWith('.zip')) {
      return CsvImportCandidate(
        file,
        WorkoutCsvImporter.inspectArchive(file.bytes),
      );
    }
    throw const FormatException(
      'Choose a .plab backup, a native FitNotes .fitnotes backup, or a CSV, TSV, JSON, TXT, or ZIP workout export.',
    );
  }

  WorkoutImportPlan buildImportPlan({
    required CsvImportCandidate candidate,
    required CsvImportMapping mapping,
    required String sourceWeightUnit,
  }) => WorkoutCsvImporter.buildPlan(
    inspection: candidate.inspection,
    mapping: mapping,
    fileName: candidate.file.name,
    fileBytes: candidate.file.bytes,
    targetUnit: store.unit,
    defaultSourceWeightUnit: sourceWeightUnit,
    knownSignatures: store.knownImportSignatures,
    knownExercises: store.knownExerciseNames,
  );

  Future<DataImportBatch> importPlan(
    WorkoutImportPlan plan, {
    bool skipDuplicates = true,
    Map<String, String> exerciseMappings = const {},
  }) async {
    await store.createAutomaticBackup(reason: 'before-import', required: true);
    return store.applyImport(
      plan,
      skipDuplicates: skipDuplicates,
      exerciseMappings: exerciseMappings,
    );
  }

  Future<void> restoreDocument(PortableBackupDocument document) async {
    await store.createAutomaticBackup(reason: 'before-restore', required: true);
    await store.restoreState(document.state);
    await store.createAutomaticBackup(reason: 'after-restore');
  }

  Future<List<AutomaticBackupInfo>> automaticBackups() =>
      DataPortabilityBridge.listAutomaticBackups();

  Future<PortableBackupDocument> validateAutomaticBackup(
    AutomaticBackupInfo info,
  ) async => ProgressionBackupCodec.decode(
    await DataPortabilityBridge.readAutomaticBackup(info.path),
  );

  Future<void> restoreAutomaticBackup(AutomaticBackupInfo info) async {
    final document = await validateAutomaticBackup(info);
    await restoreDocument(document);
  }

  Future<void> exportAutomaticBackup(AutomaticBackupInfo info) async {
    final bytes = await DataPortabilityBridge.readAutomaticBackup(info.path);
    await DataPortabilityBridge.saveFile(
      bytes: bytes,
      fileName: info.name,
      mimeType: 'application/zip',
    );
  }

  Future<void> deleteAutomaticBackup(AutomaticBackupInfo info) =>
      DataPortabilityBridge.deleteAutomaticBackup(info.path);
}
