import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:progression_lab/brand.dart';
import 'package:progression_lab/body_media.dart';
import 'package:progression_lab/body_share.dart';
import 'package:progression_lab/share_card.dart';
import 'package:progression_lab/store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const share = MethodChannel('progression_lab/share');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final image = File(
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@1x.png',
  ).readAsBytesSync();
  final data = WorkoutShareData(
    program: 'Year One',
    title: 'Upper',
    contextLine: 'Cycle 1',
    completedAt: DateTime(2026, 9, 30),
    metrics: const [],
    highlightLabel: 'Working sets',
    highlightValue: '3 sets',
  );

  tearDown(() => messenger.setMockMethodCallHandler(share, null));

  testWidgets('a failed share image shows safe feedback and can be retried', (
    tester,
  ) async {
    var attempts = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: ProgressionBrand.theme(),
        home: WorkoutSharePreviewScreen(
          data: data,
          imageGenerator: (_, _) async {
            attempts++;
            if (attempts == 1) {
              throw StateError('/private/render.png: secret renderer failure');
            }
            return image;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('The image could not be created. Try again.'),
      findsOneWidget,
    );
    expect(find.textContaining('/private/'), findsNothing);
    expect(find.textContaining('secret'), findsNothing);
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(find.text('Save image'), findsOneWidget);
    expect(find.text('Share'), findsOneWidget);
    expect(
      find.text('The image could not be created. Try again.'),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  for (final action in ['saveImage', 'shareImage']) {
    testWidgets('$action hides provider diagnostics and explains recovery', (
      tester,
    ) async {
      messenger.setMockMethodCallHandler(share, (call) async {
        throw PlatformException(
          code: 'native_error',
          message: '/private/share.png: secret provider details',
        );
      });
      await tester.pumpWidget(
        MaterialApp(
          theme: ProgressionBrand.theme(),
          home: WorkoutSharePreviewScreen(
            data: data,
            imageGenerator: (_, _) async => Uint8List.fromList(image),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.text(action == 'saveImage' ? 'Save image' : 'Share'),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('/private/'), findsNothing);
      expect(find.textContaining('secret'), findsNothing);
      expect(
        find.text(
          action == 'saveImage'
              ? 'The image could not be saved. Check your free storage space and photo access, then try again.'
              : 'The image could not be shared. Try again and choose a different app.',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }

  test('unsupported sharing does not report a silent success', () async {
    messenger.setMockMethodCallHandler(share, (_) async => null);
    messenger.setMockMethodCallHandler(share, null);
    await expectLater(
      ShareImageBridge.sharePng(image, 'image.png'),
      throwsA(isA<MissingPluginException>()),
    );
  });

  testWidgets('missing Body share photo gives recovery without a file path', (
    tester,
  ) async {
    const entry = BodyCheckIn(id: 'body-entry', date: '2026-09-30');
    const missing = BodyPhoto(
      id: 'missing-photo',
      asset: 'secret-missing-photo.jpg',
      thumbnail: 'secret-missing-thumbnail.jpg',
    );
    final store = AppStore()..automaticBackupsEnabled = false;
    store.bodyMedia.directory = '/private/nonexistent/body-share';
    await tester.pumpWidget(
      MaterialApp(
        theme: ProgressionBrand.theme(),
        home: BodyShareScreen(
          store: store,
          first: entry,
          last: entry,
          firstPhoto: missing,
          lastPhoto: missing,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Preview final image'),
      200,
      scrollable: find.byWidgetPredicate(
        (widget) =>
            widget is Scrollable && widget.axisDirection == AxisDirection.down,
      ),
    );
    await tester.tap(find.text('Preview final image'));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 30));
    });
    await tester.pumpAndSettle();
    expect(find.textContaining('use a layout without photos'), findsOneWidget);
    expect(find.textContaining('/private/'), findsNothing);
    expect(find.textContaining('secret-missing'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
