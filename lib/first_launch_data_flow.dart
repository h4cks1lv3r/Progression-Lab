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
              ? 'Let us recover your saved data'
              : verifiedBackup != null && !hasValidState
              ? 'We found your backup'
              : hasValidState
              ? 'Your training data is ready'
              : 'Bring your training with you',
        ),
        content: Text(
          damagedState
              ? '${store.loadFailure ?? 'Your saved data could not be read.'}\n\n'
                    '${verifiedBackup == null ? 'No usable automatic backup was found. Import another backup or start fresh. We will keep a copy of the damaged file before resetting.' : 'A checked automatic backup is ready to restore. Restore it to recover your training.'}'
              : verifiedBackup != null && !hasValidState
              ? 'There is no training data on this device yet. ${verifiedBackup.name} passed its integrity check. Restore it, import another file, or start fresh.'
              : hasValidState
              ? 'Your data on this device is ready. Add past workouts from Strong, Hevy, FitNotes, Fitbod, JEFIT, or a custom export. You will review changes before anything is replaced.'
              : 'Pick a FitNotes .fitnotes backup or a CSV, TSV, JSON, TXT, or ZIP workout export. Review the workouts before importing. We check for duplicates and back up your current data first.',
        ),
        actions: [
          if (hasValidState)
            TextButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, _StartupDataChoice.later),
              child: const Text('Not now'),
            )
          else
            TextButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, _StartupDataChoice.fresh),
              child: const Text('Start fresh'),
            ),
          OutlinedButton(
            onPressed: () =>
                Navigator.pop(dialogContext, _StartupDataChoice.import),
            child: const Text('Import history'),
          ),
          if (verifiedBackup != null && !hasValidState)
            FilledButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, _StartupDataChoice.restore),
              child: const Text('Restore backup'),
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(dataOperationErrorMessage(error))));
    }
  }
}
