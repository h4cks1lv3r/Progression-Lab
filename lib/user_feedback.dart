import 'package:flutter/services.dart';

import 'data_portability_core.dart';

enum UserFeedbackAction {
  createImage,
  saveImage,
  shareImage,
  copyCaption,
  backup,
  connection,
  restore,
  importFile,
  saveData,
  deleteData,
}

/// Keep diagnostic details in logs. Screen messages come from this fixed set,
/// never from exception text, file paths, provider replies, or file contents.
String userFacingError(Object error, {required UserFeedbackAction action}) {
  if (error is UnsupportedImportFileException) {
    return 'Choose a .plab backup, a native FitNotes .fitnotes backup, or a CSV, TSV, JSON, TXT, or ZIP workout export.';
  }
  if (error is BackupValidationException) {
    return switch (error.problem) {
      BackupValidationProblem.couldNotCreate =>
        'The backup could not be created. Free some storage space and try again.',
      BackupValidationProblem.unsupportedVersion =>
        'This backup needs a newer version of Progression Lab. Update the app, then try again. Your current data has not been replaced.',
      BackupValidationProblem.wrongFormat =>
        'Choose a Progression Lab backup file (.plab). Your current data has not been replaced.',
      BackupValidationProblem.tooLarge =>
        'This backup is too large to open. Choose another backup. Your current data has not been replaced.',
      BackupValidationProblem.damaged =>
        'This backup is damaged or incomplete. Choose another backup. Your current data has not been replaced.',
    };
  }
  if (error is StateError) {
    // Match known app failures, but never display the supplied message. In
    // particular, a matching phrase in untrusted text cannot reveal the rest.
    if (error.message.startsWith(
      'This backup was created by a newer Progression Lab data schema ',
    )) {
      return 'This backup needs a newer version of Progression Lab. Update the app, then try again. Your current data has not been replaced.';
    }
    if (const {
      'Another save started after this backup was reviewed. Review the backup again. Your current data has not been replaced.',
      'Another save started during restore. Review the backup again. Your current data has not been replaced.',
      'Device data changed after this restore was reviewed. Review the backup again. Your current data has not been replaced.',
      'Device data changed while the safety backup was being saved. Review the backup again. Your current data has not been replaced.',
    }.contains(error.message)) {
      return 'Your data changed while you reviewed this backup. Review it again before restoring. Your current data has not been replaced.';
    }
    if (const {
      'A safety backup could not be saved. Your current data has not been replaced.',
      'The safety backup could not be verified. Your current data has not been replaced.',
    }.contains(error.message)) {
      return 'A safety copy could not be saved and checked. Free some storage space and try again. Your current data has not been replaced.';
    }
    if (error.message == 'No cloud backup folder is configured.' ||
        error.message ==
            'Choose a backup folder before enabling automatic sync.') {
      return 'Choose a backup folder first, then try again.';
    }
    if (error.message == 'A cloud-sync operation is already running.') {
      return 'Another backup action is in progress. Wait for it to finish, then try again.';
    }
    if (error.message == 'Saving is unavailable.') {
      return 'Saving images is unavailable on this device.';
    }
  }
  if (error is MissingPluginException) {
    return switch (action) {
      UserFeedbackAction.saveImage =>
        'Saving images is unavailable on this device.',
      UserFeedbackAction.shareImage =>
        'Sharing images is unavailable on this device.',
      _ => 'This action is unavailable on this device.',
    };
  }
  if (error is PlatformException &&
      action == UserFeedbackAction.deleteData &&
      error.code == 'local_data_delete_partial') {
    return 'App data was reset, but some private files could not be removed. Try Delete all data again.';
  }
  if (error is PlatformException &&
      action == UserFeedbackAction.deleteData &&
      error.code == 'local_data_delete_incomplete') {
    return 'Local data deletion could not finish. Try Delete all data again before using the app.';
  }
  if (error is PlatformException &&
      const {
        'permission_denied',
        'access_denied',
        'denied',
      }.contains(error.code)) {
    return switch (action) {
      UserFeedbackAction.saveImage =>
        'The image could not be saved. Allow photo access in your device settings, then try again.',
      UserFeedbackAction.backup || UserFeedbackAction.restore =>
        'The backup folder cannot be opened. Choose the folder again and allow access, then try again.',
      _ => 'Access was denied. Check this app’s permissions, then try again.',
    };
  }
  return switch (action) {
    UserFeedbackAction.createImage =>
      'The image could not be created. Try again.',
    UserFeedbackAction.saveImage =>
      'The image could not be saved. Check your free storage space and photo access, then try again.',
    UserFeedbackAction.shareImage =>
      'The image could not be shared. Try again and choose a different app.',
    UserFeedbackAction.copyCaption =>
      'The caption could not be copied. Try again.',
    UserFeedbackAction.backup =>
      'The backup could not finish. Check your storage space, connection, and folder access, then try again.',
    UserFeedbackAction.connection =>
      'This connection action could not finish. Check access and your connection, then try again.',
    UserFeedbackAction.restore =>
      'The backup could not be restored. Check the selected file and available storage, then try again.',
    UserFeedbackAction.importFile =>
      'This workout file could not be imported. Choose a supported export file and try again.',
    UserFeedbackAction.saveData =>
      'Your changes could not be saved. Check your free storage space and try again.',
    UserFeedbackAction.deleteData =>
      'Your data could not be deleted. Try again.',
  };
}
