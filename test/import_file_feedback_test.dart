import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:progression_lab/data_portability.dart';
import 'package:progression_lab/data_portability_core.dart';
import 'package:progression_lab/store.dart';
import 'package:progression_lab/user_feedback.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('progression_lab/data_portability');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  test(
    'unsupported file feedback explains accepted formats without its path',
    () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'pickFile') {
          return {
            'name': '/private/secret-file.unsupported',
            'mimeType': 'application/octet-stream',
            'bytes': Uint8List.fromList([1, 2, 3]),
          };
        }
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      final store = AppStore()..automaticBackupsEnabled = false;
      final controller = DataPortabilityController(store);
      Object? failure;
      try {
        await controller.pickImportFile();
      } catch (error) {
        failure = error;
      }
      expect(failure, isA<UnsupportedImportFileException>());
      final message = userFacingError(
        failure!,
        action: UserFeedbackAction.backup,
      );
      expect(message, startsWith('Choose a .plab backup'));
      expect(message, contains('.fitnotes'));
      expect(message, contains('CSV, TSV, JSON, TXT, or ZIP'));
      expect(message, isNot(contains('secret-file')));
      expect(message, isNot(contains('/private/')));
      expect(store.importHistory, isEmpty);
      expect(store.importedWorkouts, isEmpty);
    },
  );

  test('matching words in another format error cannot reveal its details', () {
    const error = FormatException(
      'Choose a .plab backup: /private/secret-file.json checksum contents',
    );
    final message = userFacingError(error, action: UserFeedbackAction.backup);
    expect(message, isNot(contains('/private/')));
    expect(message, isNot(contains('secret-file')));
    expect(message, isNot(contains('checksum')));
  });
}
