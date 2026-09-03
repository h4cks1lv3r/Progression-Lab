import 'package:flutter/material.dart';

import 'brand.dart';
import 'data_management_screen.dart';
import 'data_portability.dart';
import 'data_portability_bridge.dart';
import 'store.dart';

enum _StartupDataChoice { restore, import, fresh, later }

abstract final class FirstLaunchDataFlow {
  static const int version = 1;

  static Future<void> present(BuildContext context, AppStore store) async {
    if (!store.isLoaded || store.dataOnboardingVersionSeen >= version) return;

    final controller = DataPortabilityController(store);
    List<AutomaticBackupInfo> backups = const [];
    AutomaticBackupInfo? verifiedBackup;
    try {
      backups = await controller.automaticBackups();
      for (final backup in backups.take(5)) {
        try {
          await controller.validateAutomaticBackup(backup);
          verifiedBackup = backup;
          break;
        } on Object {
          // Continue to an older retained backup. Corrupt archives are never offered.
        }
      }
    } on Object {
      // A file provider failure must not lock the user out of the app.
    }
    if (!context.mounted) return;

    final hasValidState = store.primaryStateLoaded;
    final damagedState = store.hadPersistedState && !hasValidState;
    final choice = await showDialog<_StartupDataChoice>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        icon: Icon(
          damagedState
              ? Icons.health_and_safety_outlined
              : verifiedBackup != null && !hasValidState
              ? Icons.restore_rounded
              : Icons.storage_rounded,
          color: BrandColors.cyan,
          size: 34,
        ),
        title: Text(
          damagedState
              ? 'Saved data needs recovery'
              : verifiedBackup != null && !hasValidState
              ? 'A Progression Lab backup was found'
              : hasValidState
              ? 'Your saved data is ready'
              : 'Bring your workout history?',
        ),
        content: Text(
          damagedState
              ? '${store.loadFailure ?? 'The primary state could not be validated.'}\n\n'
                    '${verifiedBackup == null ? 'No verified automatic backup was found. You can import another backup or start fresh. The damaged file will be preserved before reset.' : 'A verified automatic backup is available. Restore it before starting fresh whenever possible.'}'
              : verifiedBackup != null && !hasValidState
              ? 'The primary state is empty, but ${verifiedBackup.name} passed checksum validation. Restore it, import another file, or explicitly start fresh.'
              : hasValidState
              ? 'Progression Lab loaded the data already stored on this device. You can also import older history from Strong, Hevy, FitNotes, Fitbod, JEFIT, or a custom export. Nothing is replaced without confirmation.'
              : 'Import a native FitNotes .fitnotes backup or a CSV, TSV, JSON, TXT, or ZIP export. Progression Lab previews the result, detects duplicates, and creates a safety backup before import.',
        ),
        actions: [
          if (hasValidState)
            TextButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, _StartupDataChoice.later),
              child: const Text('NOT NOW'),
            )
          else
            TextButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, _StartupDataChoice.fresh),
              child: const Text('START FRESH'),
            ),
          OutlinedButton(
            onPressed: () =>
                Navigator.pop(dialogContext, _StartupDataChoice.import),
            child: const Text('IMPORT HISTORY'),
          ),
          if (verifiedBackup != null && !hasValidState)
            FilledButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, _StartupDataChoice.restore),
              child: const Text('RESTORE BACKUP'),
            ),
        ],
      ),
    );
    if (!context.mounted || choice == null) return;

    try {
      switch (choice) {
        case _StartupDataChoice.restore:
          final backup = verifiedBackup;
          if (backup == null) return;
          if (damagedState) await store.quarantineDamagedState();
          await controller.restoreAutomaticBackup(backup);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${backup.name} was restored.')),
            );
          }
          break;
        case _StartupDataChoice.import:
          await Navigator.push<void>(
            context,
            MaterialPageRoute(
              builder: (_) => DataManagementScreen(store: store),
            ),
          );
          break;
        case _StartupDataChoice.fresh:
          await store.startFreshDataState();
          break;
        case _StartupDataChoice.later:
          break;
      }
      await store.markDataOnboardingSeen(version);
    } on Object catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$error'
                .replaceFirst('Exception: ', '')
                .replaceFirst('Bad state: ', ''),
          ),
        ),
      );
    }
  }
}
