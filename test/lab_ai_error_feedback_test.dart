import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:progression_lab/brand.dart';
import 'package:progression_lab/gemini_nano.dart';
import 'package:progression_lab/lab_screen.dart';
import 'package:progression_lab/store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('progression_lab/gemini');
  const diagnostic =
      'native/checksum/path=/data/private/token=SECRET_DIAGNOSTIC';
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  for (final availability in GeminiNanoAvailability.values) {
    test('fixed status copy ignores diagnostic text: ${availability.name}', () {
      final status = GeminiNanoStatus(
        availability: availability,
        modelName: diagnostic,
        message: diagnostic,
      );
      expect(status.userMessage, isNot(contains(diagnostic)));
      expect(status.userMessage, isNot(contains('checksum')));
    });
  }

  test(
    'native status and download errors do not retain raw screen messages',
    () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        throw PlatformException(code: 'genai_failed', message: diagnostic);
      });
      const service = GeminiNanoService();
      for (final status in [await service.status(), await service.download()]) {
        expect(status.availability, GeminiNanoAvailability.error);
        expect(status.message, isNot(contains(diagnostic)));
        expect(status.userMessage, contains('Check status'));
      }
    },
  );

  for (final status in ['error', 'unavailable', 'unsupported']) {
    testWidgets(
      'Lab screen replaces native $status detail with safe instructions',
      (tester) async {
        messenger.setMockMethodCallHandler(
          channel,
          (call) async => call.method == 'status'
              ? {'status': status, 'message': diagnostic}
              : null,
        );
        final store = AppStore()..aiAnalysisEnabled = true;
        addTearDown(store.dispose);
        await tester.pumpWidget(
          MaterialApp(
            theme: ProgressionBrand.theme(),
            home: LabScreen(store: store),
          ),
        );
        await tester.pumpAndSettle();
        final expected = GeminiNanoStatus.fromMap({
          'status': status,
        }).userMessage;
        expect(find.text(expected), findsOneWidget);
        expect(find.textContaining(diagnostic), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      },
    );
  }

  testWidgets(
    'failed AI generation shows retry instructions instead of exception detail',
    (tester) async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        switch (call.method) {
          case 'status':
            return {'status': 'available', 'modelName': diagnostic};
          case 'generate':
            throw PlatformException(code: 'genai_failed', message: diagnostic);
          default:
            return null;
        }
      });
      final store = AppStore()..aiAnalysisEnabled = true;
      addTearDown(store.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: ProgressionBrand.theme(),
          home: LabScreen(store: store),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Explain my results'), 600);
      await tester.tap(find.text('Explain my results'));
      await tester.pumpAndSettle();
      expect(find.text(geminiNanoUserError('genai_failed')), findsOneWidget);
      expect(find.textContaining(diagnostic), findsNothing);
      expect(store.labMessages, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );

  test(
    'known failure instructions are actionable and use no supplied error text',
    () {
      expect(geminiNanoUserError('busy'), contains('Wait briefly'));
      expect(
        geminiNanoUserError('battery_low'),
        contains('Charge your device'),
      );
      expect(
        geminiNanoUserError('background_blocked'),
        contains('Keep Training insights open'),
      );
      expect(
        geminiNanoUserError('download_failed'),
        contains('Check your connection'),
      );
      expect(
        geminiNanoUserError('unsupported'),
        contains('training insights still work'),
      );
    },
  );
}
