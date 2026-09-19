import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'brand.dart';
import 'data_portability.dart';
import 'data_portability_bridge.dart';
import 'data_portability_core.dart';
import 'store.dart';
import 'program_navigator.dart';
import 'contextual_guides.dart';
import 'integrations_hub.dart';
import 'body_progress_screen.dart';

String dataOperationErrorMessage(Object error) {
  if (error is FormatException) return error.message;
  if (error is PlatformException) {
    return error.message ?? 'Could not finish this file action. Try again.';
  }
  if (error is StateError) return '${error.message}';
  return '$error'.replaceFirst(
    RegExp(r'^(?:FormatException|Exception|Bad state):\s*'),
    '',
  );
}

class DataManagementScreen extends StatefulWidget {
  const DataManagementScreen({super.key, required this.store});

  final AppStore store;

  @override
  State<DataManagementScreen> createState() => _DataManagementScreenState();
}

class _DataManagementScreenState extends State<DataManagementScreen> {
  late final DataPortabilityController controller;
  Future<List<AutomaticBackupInfo>>? _backups;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    controller = DataPortabilityController(widget.store);
    _refreshBackups();
  }

  void _refreshBackups() {
    final backups = controller.automaticBackups();
    setState(() {
      _backups = backups;
    });
  }

  Future<void> _run(Future<void> Function() action, {String? success}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted || success == null) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(success)));
    } on PlatformException catch (error) {
      if (!mounted) return;
      _error(error.message ?? 'Could not finish this file action. Try again.');
    } on Object catch (error) {
      if (!mounted) return;
      _error(error);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        _refreshBackups();
      }
    }
  }

  void _error(Object error) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(dataOperationErrorMessage(error))));
  }

  Future<void> _pickImport() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final candidate = await controller.pickImportFile();
      if (!mounted || candidate == null) return;
      switch (candidate) {
        case BackupImportCandidate():
          await _confirmRestore(candidate);
          break;
        case CsvImportCandidate():
          await _configureCsvImport(candidate);
          break;
      }
    } on PlatformException catch (error) {
      if (mounted) {
        _error(
          error.message ?? 'Could not open that file. Try selecting it again.',
        );
      }
    } on Object catch (error) {
      if (mounted) _error(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmRestore(BackupImportCandidate candidate) async {
    final state = candidate.document.state;
    final logCount = state['logs'] is List ? (state['logs'] as List).length : 0;
    final importedCount = state['importedWorkouts'] is List
        ? (state['importedWorkouts'] as List).length
        : 0;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Restore this backup?'),
        content: Text(
          '${candidate.file.name}\n\n'
          '$logCount logged sets • $importedCount imported workouts\n\n'
          'This replaces your current app data with the backup. We will back up your current data first.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await controller.restoreDocument(candidate.document);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Backup restored.')));
  }

  Future<void> _configureCsvImport(CsvImportCandidate candidate) async {
    var mapping = candidate.inspection.suggestedMapping;
    if (mapping == null) {
      mapping = await Navigator.push<CsvImportMapping>(
        context,
        MaterialPageRoute(
          builder: (_) => CsvMappingScreen(inspection: candidate.inspection),
        ),
      );
    }
    if (mapping == null || !mounted) return;
    var sourceWeightUnit = widget.store.unit;
    if (WorkoutCsvImporter.needsWeightUnitChoice(
      candidate.inspection.source,
      mapping,
    )) {
      final selected = await _chooseSourceWeightUnit(
        candidate.inspection.source,
      );
      if (selected == null || !mounted) return;
      sourceWeightUnit = selected;
    }
    final plan = controller.buildImportPlan(
      candidate: candidate,
      mapping: mapping,
      sourceWeightUnit: sourceWeightUnit,
    );
    final imported = await Navigator.push<DataImportBatch>(
      context,
      MaterialPageRoute(
        builder: (_) => ImportPreviewScreen(controller: controller, plan: plan),
      ),
    );
    if (imported == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Imported ${imported.workoutCount} workouts and ${imported.setCount} sets.',
        ),
      ),
    );
  }

  Future<String?> _chooseSourceWeightUnit(WorkoutImportSource source) =>
      showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Which weight unit does this file use?'),
          content: Text(
            '${source.label} does not list a weight unit in this file. '
            'Choose the unit you used in the original app.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            OutlinedButton(
              onPressed: () => Navigator.pop(dialogContext, 'kg'),
              child: const Text('Kilograms'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, 'lb'),
              child: const Text('Pounds'),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      actions: [
        IconButton(
          tooltip: 'Cloud backup',
          icon: const Icon(Icons.cloud_outlined),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => IntegrationsHubScreen(
                store: widget.store,
                section: IntegrationSection.backup,
              ),
            ),
          ),
        ),
      ],
      title: const Text('Backup & data'),
    ),
    body: BrandBackdrop(
      child: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 36),
          children: [
            Card(
              child: ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Photos, measurements & backup'),
                subtitle: const Text(
                  'Manage body photos and measurements. Photos and private notes need a separate encrypted backup.',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BodyProgressScreen(store: widget.store),
                  ),
                ),
              ),
            ),

            FeatureTip(
              store: widget.store,
              id: ContextualGuideId.dataBackup,
              message:
                  'Moving to a new phone? Save a full backup first. Use Cloud backup to choose a synced folder.',
            ),
            if (widget.store.importedWorkouts.isNotEmpty)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.playlist_add_check),
                  title: const Text('Set your place in Year One Strength'),
                  subtitle: const Text(
                    'Choose a week or microcycle and match your earlier imported workouts.',
                  ),
                  onTap: _busy
                      ? null
                      : () async {
                          await showProgramPositionSheet(context, widget.store);
                          if (mounted) setState(() {});
                        },
                ),
              ),
            const _DataHeader(),
            const SizedBox(height: 22),
            const BrandSectionLabel('Automatic backups'),
            const SizedBox(height: 10),
            LabPanel(
              accent: BrandColors.cyan,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: widget.store.automaticBackupsEnabled,
                    title: const Text(
                      'Automatic backups',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: const Text(
                      'Keep recent backups on this device when your data changes.',
                    ),
                    onChanged: _busy
                        ? null
                        : (value) => unawaited(
                            _run(
                              () => widget.store.setAutomaticBackupsEnabled(
                                value,
                              ),
                              success: value
                                  ? 'Automatic backups enabled.'
                                  : 'Automatic backups disabled.',
                            ),
                          ),
                  ),
                  FutureBuilder<List<AutomaticBackupInfo>>(
                    future: _backups,
                    builder: (context, snapshot) {
                      final backups = snapshot.data ?? const [];
                      final latest = backups.isEmpty ? null : backups.first;
                      return Text(
                        latest == null
                            ? 'No automatic backups yet.'
                            : '${backups.length} saved • Latest ${_formatDateTime(latest.modifiedAt)}',
                        style: const TextStyle(
                          color: BrandColors.muted,
                          fontSize: 12,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _busy
                              ? null
                              : () => _run(
                                  () => widget.store.createAutomaticBackup(
                                    reason: 'manual',
                                    required: true,
                                  ),
                                  success: 'Automatic backup created.',
                                ),
                          icon: const Icon(Icons.backup_rounded),
                          label: const Text('Back up now'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _busy
                              ? null
                              : () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => AutomaticBackupsScreen(
                                      controller: controller,
                                    ),
                                  ),
                                ).then((_) => _refreshBackups()),
                          icon: const Icon(Icons.history_rounded),
                          label: const Text('View backups'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const BrandSectionLabel('Back up & restore'),
            const SizedBox(height: 10),
            _ActionTile(
              icon: Icons.save_alt_rounded,
              title: 'Save a full backup',
              subtitle:
                  'A .plab file with your programs, logs, unfinished sessions, fitness checks, measurements, settings, and imports. Body photos and private notes use the separate encrypted backup above.',
              badge: 'Full',
              onTap: _busy
                  ? null
                  : () => _run(() async {
                      await controller.saveBackup();
                    }, success: 'Backup ready in the selected location.'),
            ),
            _ActionTile(
              icon: Icons.ios_share_rounded,
              title: 'Share full backup',
              subtitle:
                  'Share a .plab backup using your phone. Body photos and private notes use their separate encrypted backup.',
              badge: 'Share',
              onTap: _busy
                  ? null
                  : () => _run(
                      controller.shareBackup,
                      success: 'Backup ready to share.',
                    ),
            ),
            _ActionTile(
              icon: Icons.restore_rounded,
              title: 'Restore or import a file',
              subtitle:
                  'Choose a .plab or .fitnotes backup, or a CSV, TSV, JSON, TXT, or ZIP export from Strong, Hevy, Fitbod, JEFIT, or another app.',
              badge: 'Import',
              onTap: _busy ? null : _pickImport,
            ),
            const SizedBox(height: 24),
            const BrandSectionLabel('Take your data with you'),
            const SizedBox(height: 10),
            _ActionTile(
              icon: Icons.folder_zip_rounded,
              title: 'Export CSV files',
              subtitle:
                  'Workouts, sets, custom exercises, Functional Training sessions, and fitness checks as CSV files.',
              badge: 'Open',
              onTap: _busy
                  ? null
                  : () => _run(() async {
                      await controller.savePortableCsv();
                    }, success: 'Portable CSV package exported.'),
            ),
            _ActionTile(
              icon: Icons.sync_alt_rounded,
              title: 'Export Strong-compatible CSV',
              subtitle:
                  'Save workouts in the Strong CSV format for apps that support it, including Hevy.',
              badge: 'Migrate',
              onTap: _busy
                  ? null
                  : () => _run(() async {
                      await controller.saveStrongCompatibleCsv();
                    }, success: 'Strong-compatible CSV exported.'),
            ),
            const SizedBox(height: 24),
            BrandSectionLabel(
              'Import history',
              trailing: widget.store.lastImportBatch == null
                  ? null
                  : TextButton(
                      onPressed: _busy
                          ? null
                          : () => _confirmUndoImport(context),
                      child: const Text('Undo last'),
                    ),
            ),
            const SizedBox(height: 10),
            if (widget.store.importHistory.isEmpty)
              const LabPanel(
                child: Text(
                  'Your imported workouts will appear here.',
                  style: TextStyle(color: BrandColors.muted),
                ),
              )
            else
              ...widget.store.importHistory.reversed
                  .take(5)
                  .map((batch) => _ImportHistoryTile(batch: batch)),
            const SizedBox(height: 18),
            const LabPanel(
              accent: BrandColors.violet,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.verified_user_outlined, color: BrandColors.cyan),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Files are imported on your device. We back up your current data before restoring or importing, and skip detected duplicates by default.',
                      style: TextStyle(color: BrandColors.muted, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Future<void> _confirmUndoImport(BuildContext context) async {
    final batch = widget.store.lastImportBatch;
    if (batch == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Undo the last import?'),
        content: Text(
          'Remove ${batch.workoutCount} workouts and ${batch.setCount} sets imported from ${batch.source}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Undo import'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _run(
      widget.store.undoLastImport,
      success: 'The last import was removed.',
    );
  }
}

class CsvMappingScreen extends StatefulWidget {
  const CsvMappingScreen({super.key, required this.inspection});

  final CsvInspection inspection;

  @override
  State<CsvMappingScreen> createState() => _CsvMappingScreenState();
}

class _CsvMappingScreenState extends State<CsvMappingScreen> {
  static const _unmapped = '__not_mapped__';

  String? date;
  String? endDate;
  String? workout;
  String? exercise;
  String? setOrder;
  String? weight;
  String? alternateWeight;
  String? weightUnit;
  String? reps;
  String? notes;
  String? workoutNotes;
  String? workoutDuration;
  String? setDuration;
  String? distance;
  String? distanceUnit;
  String? setType;
  String? rpe;
  String? rir;
  String? supersetId;
  String? sourceId;

  @override
  void initState() {
    super.initState();
    final suggested = widget.inspection.suggestedMapping;
    date = suggested?.date;
    endDate = suggested?.endDate;
    workout = suggested?.workout;
    exercise = suggested?.exercise;
    setOrder = suggested?.setOrder;
    weight = suggested?.weight;
    alternateWeight = suggested?.alternateWeight;
    weightUnit = suggested?.weightUnit;
    reps = suggested?.reps;
    notes = suggested?.notes;
    workoutNotes = suggested?.workoutNotes;
    workoutDuration = suggested?.workoutDuration;
    setDuration = suggested?.setDuration;
    distance = suggested?.distance;
    distanceUnit = suggested?.distanceUnit;
    setType = suggested?.setType;
    rpe = suggested?.rpe;
    rir = suggested?.rir;
    supersetId = suggested?.supersetId;
    sourceId = suggested?.sourceId;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Match workout fields')),
    body: BrandBackdrop(
      child: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
          children: [
            Text(
              '${widget.inspection.source.label} format • ${widget.inspection.rows.length} rows',
              style: const TextStyle(color: BrandColors.cyan),
            ),
            const SizedBox(height: 8),
            const Text(
              'Match the columns in your file to the fields below. Choose a workout date, exercise, and at least one result: reps, time, or distance.',
              style: TextStyle(color: BrandColors.muted),
            ),
            const SizedBox(height: 20),
            _mapping('Workout date *', date, (value) => date = value),
            _mapping('Workout end date', endDate, (value) => endDate = value),
            _mapping('Workout name', workout, (value) => workout = value),
            _mapping('Exercise *', exercise, (value) => exercise = value),
            _mapping('Set order', setOrder, (value) => setOrder = value),
            _mapping('Weight', weight, (value) => weight = value),
            _mapping(
              'Alternate weight',
              alternateWeight,
              (value) => alternateWeight = value,
            ),
            _mapping('Weight unit', weightUnit, (value) => weightUnit = value),
            _mapping('Repetitions', reps, (value) => reps = value),
            _mapping('Set notes', notes, (value) => notes = value),
            _mapping(
              'Workout notes',
              workoutNotes,
              (value) => workoutNotes = value,
            ),
            _mapping(
              'Workout duration',
              workoutDuration,
              (value) => workoutDuration = value,
            ),
            _mapping(
              'Set duration',
              setDuration,
              (value) => setDuration = value,
            ),
            _mapping('Distance', distance, (value) => distance = value),
            _mapping(
              'Distance unit',
              distanceUnit,
              (value) => distanceUnit = value,
            ),
            _mapping('Set type', setType, (value) => setType = value),
            _mapping('RPE', rpe, (value) => rpe = value),
            _mapping('RIR', rir, (value) => rir = value),
            _mapping('Superset ID', supersetId, (value) => supersetId = value),
            _mapping('Source ID', sourceId, (value) => sourceId = value),
            const SizedBox(height: 18),
            GradientAction(
              label: 'Preview import',
              icon: Icons.preview_rounded,
              onPressed:
                  date == null ||
                      exercise == null ||
                      (reps == null && setDuration == null && distance == null)
                  ? null
                  : () => Navigator.pop(
                      context,
                      CsvImportMapping(
                        date: date!,
                        exercise: exercise!,
                        reps: reps,
                        endDate: endDate,
                        workout: workout,
                        setOrder: setOrder,
                        weight: weight,
                        alternateWeight: alternateWeight,
                        weightUnit: weightUnit,
                        notes: notes,
                        workoutNotes: workoutNotes,
                        workoutDuration: workoutDuration,
                        setDuration: setDuration,
                        distance: distance,
                        distanceUnit: distanceUnit,
                        setType: setType,
                        rpe: rpe,
                        rir: rir,
                        supersetId: supersetId,
                        sourceId: sourceId,
                      ),
                    ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _mapping(String label, String? value, ValueChanged<String?> changed) {
    final selected = value ?? _unmapped;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        initialValue: selected,
        isExpanded: true,
        decoration: InputDecoration(labelText: label),
        items: [
          const DropdownMenuItem<String>(
            value: _unmapped,
            child: Text('Not selected'),
          ),
          for (final header in widget.inspection.headers)
            DropdownMenuItem<String>(
              value: header,
              child: Text(header, overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: (next) =>
            setState(() => changed(next == _unmapped ? null : next)),
      ),
    );
  }
}

class ImportPreviewScreen extends StatefulWidget {
  const ImportPreviewScreen({
    super.key,
    required this.controller,
    required this.plan,
  });

  final DataPortabilityController controller;
  final WorkoutImportPlan plan;

  @override
  State<ImportPreviewScreen> createState() => _ImportPreviewScreenState();
}

class _ImportPreviewScreenState extends State<ImportPreviewScreen> {
  bool includeDuplicates = false;
  bool importing = false;
  Map<String, String> exerciseMappings = const {};

  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;
    final count = includeDuplicates
        ? plan.workouts.length
        : plan.importableCount;
    final mappedCount = exerciseMappings.length;
    return Scaffold(
      appBar: AppBar(title: const Text('Preview import')),
      body: BrandBackdrop(
        child: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
            children: [
              const LabMark(size: 68),
              const SizedBox(height: 16),
              Text(
                plan.source.label.toUpperCase(),
                style: const TextStyle(
                  color: BrandColors.cyan,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                plan.fileName,
                style: const TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                'Source weights: ${plan.sourceWeightUnit == 'kg' ? 'kilograms' : 'pounds'}',
                style: const TextStyle(color: BrandColors.muted),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _PreviewMetric(
                      value: '${plan.workouts.length}',
                      label: 'Workouts',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _PreviewMetric(
                      value: '${plan.setCount}',
                      label: 'Sets',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _PreviewMetric(
                      value: '${plan.duplicateCount}',
                      label: 'Duplicates',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              if (plan.duplicateCount > 0)
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: includeDuplicates,
                  title: const Text('Import detected duplicates'),
                  subtitle: const Text(
                    'Leave this off to skip workouts already found in your imported history.',
                  ),
                  onChanged: importing
                      ? null
                      : (value) => setState(() => includeDuplicates = value),
                ),
              if (plan.unknownExercises.isNotEmpty) ...[
                const SizedBox(height: 12),
                LabPanel(
                  accent: BrandColors.violet,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${plan.unknownExercises.length} unmatched exercises',
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        mappedCount == 0
                            ? 'Match these to exercises in your library, or keep them as new custom exercises.'
                            : '$mappedCount mapped • ${plan.unknownExercises.length - mappedCount} will be saved as custom exercises.',
                        style: const TextStyle(color: BrandColors.muted),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: importing ? null : _mapExercises,
                        icon: const Icon(Icons.account_tree_outlined),
                        label: const Text('Match exercises'),
                      ),
                    ],
                  ),
                ),
              ],
              if (plan.invalidRows > 0) ...[
                const SizedBox(height: 12),
                Text(
                  '${plan.invalidRows} invalid rows will be skipped.',
                  style: const TextStyle(color: BrandColors.warning),
                ),
              ],
              const SizedBox(height: 22),
              GradientAction(
                label: importing ? 'Importing' : 'IMPORT $count WORKOUTS',
                icon: Icons.download_done_rounded,
                onPressed: importing || count <= 0 ? null : _import,
              ),
              const SizedBox(height: 10),
              const Text(
                'We back up your current data first. You can undo your latest import in Backup & data.',
                textAlign: TextAlign.center,
                style: TextStyle(color: BrandColors.muted, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _mapExercises() async {
    final values = await Navigator.push<Map<String, String>>(
      context,
      MaterialPageRoute(
        builder: (_) => ExerciseMappingScreen(
          sourceExercises: widget.plan.unknownExercises.toList()..sort(),
          targetExercises: widget.controller.store.knownExerciseNames.toList()
            ..sort(),
          initialMappings: exerciseMappings,
        ),
      ),
    );
    if (values != null && mounted) {
      setState(() => exerciseMappings = values);
    }
  }

  Future<void> _import() async {
    setState(() => importing = true);
    try {
      final batch = await widget.controller.importPlan(
        widget.plan,
        skipDuplicates: !includeDuplicates,
        exerciseMappings: exerciseMappings,
      );
      if (mounted) Navigator.pop(context, batch);
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(dataOperationErrorMessage(error))));
      setState(() => importing = false);
    }
  }
}

class ExerciseMappingScreen extends StatefulWidget {
  const ExerciseMappingScreen({
    super.key,
    required this.sourceExercises,
    required this.targetExercises,
    required this.initialMappings,
  });

  final List<String> sourceExercises;
  final List<String> targetExercises;
  final Map<String, String> initialMappings;

  @override
  State<ExerciseMappingScreen> createState() => _ExerciseMappingScreenState();
}

class _ExerciseMappingScreenState extends State<ExerciseMappingScreen> {
  static const _createCustom = '__create_custom__';
  late final Map<String, String> selections;

  @override
  void initState() {
    super.initState();
    selections = {
      for (final source in widget.sourceExercises)
        source: widget.initialMappings[source] ?? _createCustom,
    };
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Match exercises'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, {
            for (final entry in selections.entries)
              if (entry.value != _createCustom) entry.key: entry.value,
          }),
          child: const Text('Done'),
        ),
      ],
    ),
    body: BrandBackdrop(
      child: SafeArea(
        top: false,
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
          itemCount: widget.sourceExercises.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final source = widget.sourceExercises[index];
            return LabPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    source,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: selections[source],
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Import as'),
                    items: [
                      DropdownMenuItem<String>(
                        value: _createCustom,
                        child: Text('Create custom: $source'),
                      ),
                      for (final target in widget.targetExercises)
                        DropdownMenuItem<String>(
                          value: target,
                          child: Text(target, overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => selections[source] = value);
                    },
                  ),
                ],
              ),
            );
          },
        ),
      ),
    ),
  );
}

class AutomaticBackupsScreen extends StatefulWidget {
  const AutomaticBackupsScreen({super.key, required this.controller});

  final DataPortabilityController controller;

  @override
  State<AutomaticBackupsScreen> createState() => _AutomaticBackupsScreenState();
}

class _AutomaticBackupsScreenState extends State<AutomaticBackupsScreen> {
  late Future<List<AutomaticBackupInfo>> backups;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    backups = widget.controller.automaticBackups();
  }

  void refresh() {
    final nextBackups = widget.controller.automaticBackups();
    setState(() {
      backups = nextBackups;
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Automatic backups')),
    body: BrandBackdrop(
      child: FutureBuilder<List<AutomaticBackupInfo>>(
        future: backups,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final values = snapshot.data!;
          if (values.isEmpty) {
            return const Center(child: Text('No automatic backups yet.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
            itemCount: values.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final item = values[index];
              return LabPanel(
                accent: index == 0 ? BrandColors.cyan : BrandColors.violet,
                child: Row(
                  children: [
                    const Icon(Icons.inventory_2_outlined),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${_formatDateTime(item.modifiedAt)} • ${_formatBytes(item.size)}',
                            style: const TextStyle(
                              color: BrandColors.muted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      enabled: !busy,
                      onSelected: (value) => _action(value, item),
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: 'test',
                          child: Text('Test backup'),
                        ),
                        PopupMenuItem(value: 'restore', child: Text('Restore')),
                        PopupMenuItem(
                          value: 'export',
                          child: Text('Export copy'),
                        ),
                        PopupMenuItem(value: 'delete', child: Text('Delete')),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    ),
  );

  Future<void> _action(String action, AutomaticBackupInfo item) async {
    setState(() => busy = true);
    try {
      switch (action) {
        case 'test':
          final document = await widget.controller.validateAutomaticBackup(
            item,
          );
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Verified backup from ${_formatDateTime(document.createdAt.toLocal())}.',
              ),
            ),
          );
          break;
        case 'restore':
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: const Text('Restore automatic backup?'),
              content: Text(item.name),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('Restore'),
                ),
              ],
            ),
          );
          if (confirmed == true) {
            await widget.controller.restoreAutomaticBackup(item);
            if (mounted) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Backup restored.')));
            }
          }
          break;
        case 'export':
          await widget.controller.exportAutomaticBackup(item);
          break;
        case 'delete':
          await widget.controller.deleteAutomaticBackup(item);
          refresh();
          break;
      }
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(dataOperationErrorMessage(error))),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
}

class _DataHeader extends StatelessWidget {
  const _DataHeader();

  @override
  Widget build(BuildContext context) => const Row(
    children: [
      LabMark(size: 62),
      SizedBox(width: 14),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your data goes with you',
              style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900),
            ),
            SizedBox(height: 4),
            Text(
              'Back it up, bring it in, or take it with you.',
              style: TextStyle(color: BrandColors.muted),
            ),
          ],
        ),
      ),
    ],
  );
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String badge;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: LabPanel(
      onTap: onTap,
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: BrandColors.cyan.withValues(alpha: .1),
            child: Icon(icon, color: BrandColors.cyan),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: BrandColors.muted,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            badge,
            style: const TextStyle(
              color: BrandColors.violet,
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: .8,
            ),
          ),
        ],
      ),
    ),
  );
}

class _ImportHistoryTile extends StatelessWidget {
  const _ImportHistoryTile({required this.batch});

  final DataImportBatch batch;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 9),
    child: LabPanel(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          const Icon(Icons.download_done_rounded, color: BrandColors.cyan),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${batch.source} • ${batch.workoutCount} workouts',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 3),
                Text(
                  '${_formatDateTime(batch.importedAt)} • ${batch.fileName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: BrandColors.muted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _PreviewMetric extends StatelessWidget {
  const _PreviewMetric({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => LabPanel(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
    child: Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: const TextStyle(
            color: BrandColors.muted,
            fontSize: 9,
            fontWeight: FontWeight.w900,
            letterSpacing: .7,
          ),
        ),
      ],
    ),
  );
}

String _formatDateTime(DateTime value) {
  final local = value.toLocal();
  return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} '
      '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}

String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}
