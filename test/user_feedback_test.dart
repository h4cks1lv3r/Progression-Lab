import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:progression_lab/data_portability_core.dart';
import 'package:progression_lab/user_feedback.dart';

void main() {
  test(
    'damaged backup remains rejected and its file details stay off screen',
    () {
      final original = ProgressionBackupCodec.encode({'schemaVersion': 21});
      final contents = ZipDecoder().decodeBytes(original);
      final damaged = Archive();
      for (final file in contents) {
        final bytes = file.name == 'state.json'
            ? utf8.encode('{"schemaVersion":21,"private_note":"secret"}')
            : file.content as List<int>;
        damaged.addFile(ArchiveFile(file.name, bytes.length, bytes));
      }
      Object? failure;
      try {
        ProgressionBackupCodec.decode(ZipEncoder().encode(damaged)!);
      } catch (error) {
        failure = error;
      }
      expect(failure, isA<BackupValidationException>());
      expect('$failure', contains('checksum for state.json'));
      final visible = userFacingError(
        failure!,
        action: UserFeedbackAction.restore,
      );
      expect(visible, contains('damaged or incomplete'));
      expect(visible, contains('Choose another backup'));
      expect(visible, contains('Your current data has not been replaced'));
      expect(visible, isNot(contains('checksum')));
      expect(visible, isNot(contains('state.json')));
      expect(visible, isNot(contains('private_note')));
    },
  );

  test('new backup versions give update guidance without schema details', () {
    final encoded = ProgressionBackupCodec.encode({'schemaVersion': 21});
    final contents = ZipDecoder().decodeBytes(encoded);
    final updated = Archive();
    for (final file in contents) {
      var bytes = file.content as List<int>;
      if (file.name == 'manifest.json') {
        final manifest = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
        manifest['schemaVersion'] = 999;
        bytes = utf8.encode(jsonEncode(manifest));
      }
      updated.addFile(ArchiveFile(file.name, bytes.length, bytes));
    }
    Object? failure;
    try {
      ProgressionBackupCodec.decode(ZipEncoder().encode(updated)!);
    } catch (error) {
      failure = error;
    }
    expect(failure, isA<BackupValidationException>());
    final visible = userFacingError(
      failure!,
      action: UserFeedbackAction.restore,
    );
    expect(visible, contains('Update the app'));
    expect(visible, isNot(contains('999')));
    expect(visible, isNot(contains('schema')));
  });

  test('diagnostic text never reaches any feedback action', () {
    const diagnostics = '/private/state.json: checksum secret-token';
    final failures = <Object>[
      const FormatException(diagnostics),
      StateError(diagnostics),
      StateError('$diagnostics Your current data has not been replaced.'),
      PlatformException(code: 'native_failure', message: diagnostics),
      const BackupValidationException(diagnostics),
    ];
    for (final failure in failures) {
      for (final action in UserFeedbackAction.values) {
        final message = userFacingError(failure, action: action);
        expect(message, isNot(contains('private/')));
        expect(message, isNot(contains('checksum')));
        expect(message, isNot(contains('secret-token')));
        expect(message, isNot(contains('state.json')));
      }
    }
  });

  test('a rejected concurrent restore still explains how to recover', () {
    final error = StateError(
      'Another save started during restore. Review the backup again. Your current data has not been replaced.',
    );
    final message = userFacingError(error, action: UserFeedbackAction.restore);
    expect(message, contains('Review it again'));
    expect(message, contains('Your current data has not been replaced'));
  });
}
