import 'dart:async';

import 'package:flutter/material.dart';

import 'brand.dart';
import 'data_management_screen.dart';
import 'data_portability.dart';
import 'data_portability_bridge.dart';
import 'integrations_hub.dart';
import 'store.dart';

class FirstLaunchDataSetupScreen extends StatefulWidget {
  const FirstLaunchDataSetupScreen({super.key, required this.store});

  static const int currentVersion = 1;

  final AppStore store;

  @override
  State<FirstLaunchDataSetupScreen> createState() =>
      _FirstLaunchDataSetupScreenState();
}

class _FirstLaunchDataSetupScreenState
    extends State<FirstLaunchDataSetupScreen> {
  late final DataPortabilityController _controller;
  late Future<List<AutomaticBackupInfo>> _backups;
  bool _busy = false;
  String? _status;

  @override
  void initState() {
    super.initState();
    _controller = DataPortabilityController(widget.store);
    _backups = _controller.automaticBackups();
  }

  bool get _loadedExistingData =>
      widget.store.hadStoredStateAtLaunch && widget.store.hasMeaningfulData;

  Future<void> _finish({String? status}) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _status = status;
    });
    try {
      await widget.store.markDataSetupSeen(
        FirstLaunchDataSetupScreen.currentVersion,
      );
      await widget.store.flushPendingSaves();
      if (mounted) Navigator.of(context).pop(true);
    } on Object {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _status = 'Progression Lab could not save your setup choice.';
      });
    }
  }

  Future<void> _restoreLatest(AutomaticBackupInfo backup) async {
    if (_busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Restore the latest device backup?'),
        content: Text(
          '${backup.name}\n\n'
          'The backup will be validated before it replaces the current empty state.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('RESTORE'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _busy = true;
      _status = 'Validating and restoring your backup…';
    });
    try {
      await _controller.restoreAutomaticBackup(backup);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _status = 'Your Progression Lab backup was restored.';
      });
      await _finish(status: 'Your Progression Lab backup was restored.');
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _status = _cleanError(error);
        _backups = _controller.automaticBackups();
      });
    }
  }

  Future<void> _importExportFile() async {
    if (_busy) return;
    final imported = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => DataManagementScreen(
          store: widget.store,
          startImportOnOpen: true,
          closeAfterImport: true,
        ),
      ),
    );
    if (imported == true && mounted) {
      await _finish(status: 'Your workout history was imported.');
    }
  }

  Future<void> _openHealthImport() async {
    if (_busy) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => IntegrationsHubScreen(store: widget.store),
      ),
    );
    if (mounted) {
      setState(() {
        _status =
            'Health-platform changes are saved automatically. Continue when you are finished.';
      });
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    child: Scaffold(
      body: BrandBackdrop(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 30),
            children: [
              const Center(child: LabMark(size: 76)),
              const SizedBox(height: 18),
              const Text(
                'BRING YOUR TRAINING HISTORY',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: BrandColors.cyan,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.55,
                ),
              ),
              const SizedBox(height: 7),
              const Text(
                'Start with your real data',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 29,
                  height: 1.05,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Progression Lab checks its private on-device state first. You can then restore a backup or import history exported from another workout app.',
                textAlign: TextAlign.center,
                style: TextStyle(color: BrandColors.muted, height: 1.45),
              ),
              const SizedBox(height: 22),
              _LocalStatePanel(
                existingDataLoaded: _loadedExistingData,
                hadStoredState: widget.store.hadStoredStateAtLaunch,
                setCount: widget.store.logs.length,
                strengthWorkouts: widget.store.workoutHistory.length,
                functionalSessions: widget.store.athleticHistory.length,
                importedWorkouts: widget.store.importedWorkouts.length,
              ),
              const SizedBox(height: 14),
              FutureBuilder<List<AutomaticBackupInfo>>(
                future: _backups,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const LabPanel(
                      child: Row(
                        children: [
                          SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 12),
                          Expanded(child: Text('Checking device backups…')),
                        ],
                      ),
                    );
                  }
                  final backups = snapshot.data ?? const [];
                  if (backups.isEmpty || _loadedExistingData) {
                    return const SizedBox.shrink();
                  }
                  final latest = backups.first;
                  return LabPanel(
                    accent: BrandColors.violet,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'DEVICE BACKUP FOUND',
                          style: TextStyle(
                            color: BrandColors.violet,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          latest.name,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '${_formatBytes(latest.size)} • ${_formatDate(latest.modifiedAt)}',
                          style: const TextStyle(
                            color: BrandColors.muted,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _busy
                                ? null
                                : () => unawaited(_restoreLatest(latest)),
                            icon: const Icon(Icons.restore_rounded),
                            label: const Text('RESTORE LATEST BACKUP'),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 18),
              const BrandSectionLabel('Import from another app'),
              const SizedBox(height: 10),
              LabPanel(
                accent: BrandColors.cyan,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: [
                        _SourceChip('STRONG'),
                        _SourceChip('HEVY'),
                        _SourceChip('FITNOTES'),
                        _SourceChip('CSV / ZIP'),
                      ],
                    ),
                    const SizedBox(height: 13),
                    const Text(
                      'Export your history from the source app, then choose that CSV or ZIP here. The importer detects supported formats, previews workouts, maps exercises, and skips duplicates by default.',
                      style: TextStyle(color: BrandColors.muted, height: 1.45),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _busy
                            ? null
                            : () => unawaited(_importExportFile()),
                        icon: const Icon(Icons.file_open_rounded),
                        label: const Text('CHOOSE AN EXPORT FILE'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              LabPanel(
                accent: BrandColors.violet,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'HEALTH & WEARABLE HISTORY',
                      style: TextStyle(
                        color: BrandColors.violet,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 7),
                    const Text(
                      'Import available workout summaries and body metrics from Health Connect or Apple Health after you approve platform access.',
                      style: TextStyle(color: BrandColors.muted, height: 1.45),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _busy
                            ? null
                            : () => unawaited(_openHealthImport()),
                        icon: const Icon(Icons.health_and_safety_rounded),
                        label: const Text('OPEN HEALTH IMPORT'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 13),
              const Text(
                'Android and iOS do not let Progression Lab read another app’s private database. Import uses a file you select or health records you explicitly authorize.',
                style: TextStyle(
                  color: BrandColors.muted,
                  fontSize: 11,
                  height: 1.45,
                ),
              ),
              if (_status != null) ...[
                const SizedBox(height: 14),
                Text(
                  _status!,
                  key: const ValueKey('first-launch-data-status'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: BrandColors.cyan,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
              const SizedBox(height: 22),
              SizedBox(
                height: 54,
                child: GradientAction(
                  label: _busy ? 'SAVING' : 'CONTINUE TO PROGRESSION LAB',
                  icon: Icons.arrow_forward_rounded,
                  onPressed: _busy ? null : () => unawaited(_finish()),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _busy
                    ? null
                    : () => unawaited(
                        _finish(status: 'Import skipped for now.'),
                      ),
                child: const Text('NOT NOW'),
              ),
              const Text(
                'You can import later from More → Backup & data.',
                textAlign: TextAlign.center,
                style: TextStyle(color: BrandColors.muted, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  static String _cleanError(Object error) =>
      '$error'.replaceFirst('Exception: ', '').replaceFirst('StateError: ', '');

  static String _formatDate(DateTime value) {
    final local = value.toLocal();
    return '${local.month}/${local.day}/${local.year} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

  static String _formatBytes(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '$bytes B';
  }
}

class _LocalStatePanel extends StatelessWidget {
  const _LocalStatePanel({
    required this.existingDataLoaded,
    required this.hadStoredState,
    required this.setCount,
    required this.strengthWorkouts,
    required this.functionalSessions,
    required this.importedWorkouts,
  });

  final bool existingDataLoaded;
  final bool hadStoredState;
  final int setCount;
  final int strengthWorkouts;
  final int functionalSessions;
  final int importedWorkouts;

  @override
  Widget build(BuildContext context) => LabPanel(
    accent: existingDataLoaded ? BrandColors.success : BrandColors.cyan,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              existingDataLoaded
                  ? Icons.check_circle_rounded
                  : hadStoredState
                  ? Icons.warning_amber_rounded
                  : Icons.phone_android_rounded,
              color: existingDataLoaded
                  ? BrandColors.success
                  : BrandColors.cyan,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                existingDataLoaded
                    ? 'EXISTING DATA LOADED'
                    : hadStoredState
                    ? 'STORED STATE FOUND'
                    : 'NO EXISTING APP DATA FOUND',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  letterSpacing: .45,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 9),
        Text(
          existingDataLoaded
              ? '$strengthWorkouts strength workouts • $functionalSessions functional sessions • $setCount logged sets • $importedWorkouts imported workouts'
              : hadStoredState
              ? 'Progression Lab found stored state, but it did not contain usable workout history. A valid automatic backup can still be restored below.'
              : 'This installation started with an empty Progression Lab database.',
          style: const TextStyle(color: BrandColors.muted, height: 1.4),
        ),
      ],
    ),
  );
}

class _SourceChip extends StatelessWidget {
  const _SourceChip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
    decoration: BoxDecoration(
      color: BrandColors.cyan.withValues(alpha: .08),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: BrandColors.cyan.withValues(alpha: .2)),
    ),
    child: Text(
      label,
      style: const TextStyle(
        color: BrandColors.cyan,
        fontSize: 9,
        fontWeight: FontWeight.w900,
        letterSpacing: .55,
      ),
    ),
  );
}
