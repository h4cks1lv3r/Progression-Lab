import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'integration_settings.dart';

class ShareStudioDimensions {
  const ShareStudioDimensions(this.width, this.height);

  final int width;
  final int height;
}

/// Renders original Progression Lab social cards without depending on a social
/// network SDK. The input is dynamic so the generator can consume the existing
/// `WorkoutShareData` model without creating a circular library dependency.
abstract final class AdvancedWorkoutShareGenerator {
  static ShareStudioDimensions dimensionsFor(String template) => switch (
    template
  ) {
    'square' => const ShareStudioDimensions(1080, 1080),
    'portrait' => const ShareStudioDimensions(1080, 1350),
    _ => const ShareStudioDimensions(1080, 1920),
  };

  static Future<ui.Image> render(
    dynamic data,
    IntegrationSettings settings,
  ) async {
    final dimensions = dimensionsFor(settings.shareTemplate);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final size = Size(dimensions.width.toDouble(), dimensions.height.toDouble());

    final background = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          Color(0xFF05060D),
          Color(0xFF120924),
          Color(0xFF07131E),
        ],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, background);

    final glow = Paint()
      ..shader = RadialGradient(
        colors: <Color>[
          const Color(0xFF7C3AED).withValues(alpha: .36),
          Colors.transparent,
        ],
      ).createShader(
        Rect.fromCircle(
          center: Offset(size.width * .78, size.height * .18),
          radius: size.width * .75,
        ),
      );
    canvas.drawRect(Offset.zero & size, glow);

    final cyanGlow = Paint()
      ..shader = RadialGradient(
        colors: <Color>[
          const Color(0xFF22D3EE).withValues(alpha: .18),
          Colors.transparent,
        ],
      ).createShader(
        Rect.fromCircle(
          center: Offset(size.width * .12, size.height * .82),
          radius: size.width * .62,
        ),
      );
    canvas.drawRect(Offset.zero & size, cyanGlow);

    final margin = size.width * .075;
    final contentWidth = size.width - margin * 2;
    var y = size.height * .075;

    _text(
      canvas,
      'PROGRESSION LAB',
      Offset(margin, y),
      width: contentWidth,
      fontSize: size.width * .055,
      weight: FontWeight.w900,
      color: Colors.white,
      letterSpacing: 3,
    );
    y += size.width * .075;
    _text(
      canvas,
      'TEST. TRAIN. TRANSFORM.',
      Offset(margin, y),
      width: contentWidth,
      fontSize: size.width * .021,
      weight: FontWeight.w700,
      color: const Color(0xFF22D3EE),
      letterSpacing: 2,
    );
    y += size.height * .10;

    final achievement = '${data.achievementLabel ?? ''}'.trim();
    final achievementMode = settings.shareTemplate == 'achievement' &&
        achievement.isNotEmpty;
    _text(
      canvas,
      achievementMode ? achievement.toUpperCase() : 'WORKOUT COMPLETE',
      Offset(margin, y),
      width: contentWidth,
      fontSize: size.width * (achievementMode ? .085 : .045),
      weight: FontWeight.w900,
      color: achievementMode ? const Color(0xFFA855F7) : Colors.white70,
      maxLines: 2,
    );
    y += size.height * (achievementMode ? .12 : .07);

    _text(
      canvas,
      '${data.title}',
      Offset(margin, y),
      width: contentWidth,
      fontSize: size.width * .096,
      weight: FontWeight.w900,
      color: Colors.white,
      maxLines: 3,
      height: 1.0,
    );
    y += size.height * .18;

    _text(
      canvas,
      '${data.program} · ${data.contextLine}',
      Offset(margin, y),
      width: contentWidth,
      fontSize: size.width * .028,
      weight: FontWeight.w600,
      color: Colors.white60,
      maxLines: 2,
    );
    y += size.height * .075;

    if (!settings.shareCompletionOnly) {
      final metrics = <dynamic>[
        for (final metric in (data.metrics as Iterable)) metric,
      ].where((metric) {
        final label = '${metric.label}'.toLowerCase();
        if (settings.shareHideDuration && label.contains('duration')) return false;
        if (settings.shareHideWeights &&
            (label.contains('volume') || label.contains('weight'))) {
          return false;
        }
        if (settings.shareHideBodyMetrics &&
            (label.contains('body') || label.contains('weight'))) {
          return false;
        }
        return true;
      }).take(4).toList();

      final gap = size.width * .025;
      final cardWidth = (contentWidth - gap) / 2;
      for (var index = 0; index < metrics.length; index++) {
        final row = index ~/ 2;
        final column = index % 2;
        final left = margin + column * (cardWidth + gap);
        final top = y + row * size.height * .105;
        final rect = RRect.fromRectAndRadius(
          Rect.fromLTWH(left, top, cardWidth, size.height * .085),
          Radius.circular(size.width * .025),
        );
        canvas.drawRRect(
          rect,
          Paint()..color = Colors.white.withValues(alpha: .055),
        );
        canvas.drawRRect(
          rect,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = const Color(0xFF7C3AED).withValues(alpha: .35),
        );
        _text(
          canvas,
          '${metrics[index].label}'.toUpperCase(),
          Offset(left + size.width * .025, top + size.height * .016),
          width: cardWidth - size.width * .05,
          fontSize: size.width * .019,
          weight: FontWeight.w700,
          color: Colors.white54,
          letterSpacing: 1,
        );
        _text(
          canvas,
          '${metrics[index].value}',
          Offset(left + size.width * .025, top + size.height * .043),
          width: cardWidth - size.width * .05,
          fontSize: size.width * .037,
          weight: FontWeight.w900,
          color: Colors.white,
        );
      }
      y += metrics.isEmpty
          ? 0
          : ((metrics.length + 1) ~/ 2) * size.height * .105 +
                size.height * .035;

      final highlight = '${data.highlightValue ?? ''}'.trim();
      if (highlight.isNotEmpty && !settings.shareHideWeights) {
        final rect = RRect.fromRectAndRadius(
          Rect.fromLTWH(margin, y, contentWidth, size.height * .115),
          Radius.circular(size.width * .03),
        );
        canvas.drawRRect(
          rect,
          Paint()..color = const Color(0xFF7C3AED).withValues(alpha: .16),
        );
        _text(
          canvas,
          '${data.highlightLabel ?? 'HIGHLIGHT'}'.toUpperCase(),
          Offset(margin + size.width * .035, y + size.height * .023),
          width: contentWidth - size.width * .07,
          fontSize: size.width * .02,
          weight: FontWeight.w800,
          color: const Color(0xFF22D3EE),
          letterSpacing: 1.4,
        );
        _text(
          canvas,
          highlight,
          Offset(margin + size.width * .035, y + size.height * .055),
          width: contentWidth - size.width * .07,
          fontSize: size.width * .038,
          weight: FontWeight.w800,
          color: Colors.white,
          maxLines: 2,
        );
      }
    }

    final footerY = size.height - size.height * .11;
    canvas.drawLine(
      Offset(margin, footerY),
      Offset(size.width - margin, footerY),
      Paint()
        ..strokeWidth = 2
        ..color = Colors.white.withValues(alpha: .12),
    );
    _text(
      canvas,
      'BUILT, NOT GUESSED.',
      Offset(margin, footerY + size.height * .035),
      width: contentWidth,
      fontSize: size.width * .022,
      weight: FontWeight.w800,
      color: Colors.white60,
      letterSpacing: 2,
    );

    final picture = recorder.endRecording();
    return picture.toImage(dimensions.width, dimensions.height);
  }

  static Future<Uint8List> generatePng(
    dynamic data,
    IntegrationSettings settings,
  ) async {
    final image = await render(data, settings);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null) throw StateError('The share image could not be encoded.');
    return bytes.buffer.asUint8List();
  }

  static void _text(
    Canvas canvas,
    String value,
    Offset offset, {
    required double width,
    required double fontSize,
    required FontWeight weight,
    required Color color,
    double letterSpacing = 0,
    int maxLines = 1,
    double height = 1.15,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: weight,
          color: color,
          letterSpacing: letterSpacing,
          height: height,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: maxLines,
      ellipsis: '…',
    )..layout(maxWidth: width);
    painter.paint(canvas, offset);
  }
}
