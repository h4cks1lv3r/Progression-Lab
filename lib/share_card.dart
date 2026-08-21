import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'brand.dart';

class ShareMetric {
  const ShareMetric(this.label, this.value);

  final String label;
  final String value;
}

class WorkoutShareData {
  const WorkoutShareData({
    required this.program,
    required this.title,
    required this.contextLine,
    required this.completedAt,
    required this.metrics,
    required this.highlightLabel,
    required this.highlightValue,
    this.achievementLabel,
    this.footer = 'TEST · TRAIN · TRANSFORM',
  });

  final String program;
  final String title;
  final String contextLine;
  final DateTime completedAt;
  final List<ShareMetric> metrics;
  final String highlightLabel;
  final String highlightValue;
  final String? achievementLabel;
  final String footer;

  String get fileName {
    final date =
        '${completedAt.year}${completedAt.month.toString().padLeft(2, '0')}${completedAt.day.toString().padLeft(2, '0')}';
    final slug = title
        .toLowerCase()
        .replaceAll(RegExp('[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '')
        .replaceAll(RegExp(r'-{2,}'), '-');
    return 'progression-lab-$date-${slug.isEmpty ? 'workout' : slug}.png';
  }
}

class WorkoutShareCardGenerator {
  static const width = 1080;
  static const height = 1920;

  static Future<Uint8List> generate(WorkoutShareData data) async {
    final recorder = ui.PictureRecorder();
    final bounds = Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble());
    final canvas = Canvas(recorder, bounds);

    canvas.drawRect(
      bounds,
      Paint()
        ..shader = ui.Gradient.linear(
          const Offset(0, 0),
          Offset(width.toDouble(), height.toDouble()),
          const [Color(0xFF070811), Color(0xFF170D2B), Color(0xFF07131A)],
          const [0, .54, 1],
        ),
    );
    _drawGrid(canvas);
    _drawAmbientGlow(canvas);

    _drawMark(canvas, const Rect.fromLTWH(82, 86, 116, 116));
    _drawText(
      canvas,
      'PROGRESSION',
      const Offset(228, 100),
      maxWidth: 650,
      style: const TextStyle(
        color: BrandColors.white,
        fontSize: 48,
        fontWeight: FontWeight.w900,
        letterSpacing: 4.4,
      ),
    );
    _drawText(
      canvas,
      'LAB',
      const Offset(228, 151),
      maxWidth: 420,
      style: const TextStyle(
        color: BrandColors.violet,
        fontSize: 48,
        fontWeight: FontWeight.w900,
        letterSpacing: 12,
      ),
    );

    _drawPill(canvas, const Offset(82, 282), 'WORKOUT COMPLETE');
    if (data.achievementLabel case final String achievement) {
      _drawPill(
        canvas,
        const Offset(82, 350),
        achievement.toUpperCase(),
        accent: BrandColors.cyan,
      );
    }

    var titleY = data.achievementLabel == null ? 382.0 : 450.0;
    final titleHeight = _drawText(
      canvas,
      data.title.toUpperCase(),
      Offset(82, titleY),
      maxWidth: 916,
      maxLines: 3,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 91,
        height: .98,
        fontWeight: FontWeight.w900,
        letterSpacing: -2.2,
      ),
    );
    titleY += titleHeight + 32;
    _drawText(
      canvas,
      data.program.toUpperCase(),
      Offset(84, titleY),
      maxWidth: 900,
      style: const TextStyle(
        color: BrandColors.cyan,
        fontSize: 30,
        fontWeight: FontWeight.w900,
        letterSpacing: 2.2,
      ),
    );
    titleY += 48;
    _drawText(
      canvas,
      data.contextLine,
      Offset(84, titleY),
      maxWidth: 900,
      maxLines: 2,
      style: const TextStyle(
        color: BrandColors.muted,
        fontSize: 30,
        height: 1.25,
        fontWeight: FontWeight.w600,
      ),
    );

    const metricTop = 880.0;
    final metrics = data.metrics.take(4).toList();
    for (var index = 0; index < metrics.length; index++) {
      final row = index ~/ 2;
      final column = index % 2;
      final left = 82.0 + column * 468;
      final top = metricTop + row * 232;
      _drawMetricCard(
        canvas,
        Rect.fromLTWH(left, top, 438, 196),
        metrics[index],
      );
    }

    final highlightRect = const Rect.fromLTWH(82, 1372, 916, 302);
    canvas.drawRRect(
      RRect.fromRectAndRadius(highlightRect, const Radius.circular(38)),
      Paint()
        ..shader = ui.Gradient.linear(
          highlightRect.topLeft,
          highlightRect.bottomRight,
          [
            BrandColors.purple.withValues(alpha: .78),
            BrandColors.magenta.withValues(alpha: .36),
            BrandColors.panelHigh.withValues(alpha: .96),
          ],
          const [0, .52, 1],
        ),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(highlightRect, const Radius.circular(38)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..color = BrandColors.violet.withValues(alpha: .72),
    );
    _drawText(
      canvas,
      data.highlightLabel.toUpperCase(),
      const Offset(128, 1422),
      maxWidth: 820,
      style: const TextStyle(
        color: BrandColors.cyan,
        fontSize: 24,
        fontWeight: FontWeight.w900,
        letterSpacing: 2.2,
      ),
    );
    _drawText(
      canvas,
      data.highlightValue,
      const Offset(128, 1480),
      maxWidth: 820,
      maxLines: 2,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 58,
        height: 1.06,
        fontWeight: FontWeight.w900,
        letterSpacing: -1.1,
      ),
    );

    final date = _formatDate(data.completedAt);
    _drawText(
      canvas,
      date.toUpperCase(),
      const Offset(82, 1780),
      maxWidth: 550,
      style: const TextStyle(
        color: BrandColors.muted,
        fontSize: 24,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.8,
      ),
    );
    _drawText(
      canvas,
      data.footer,
      const Offset(560, 1780),
      maxWidth: 438,
      textAlign: TextAlign.right,
      style: const TextStyle(
        color: BrandColors.violet,
        fontSize: 22,
        fontWeight: FontWeight.w900,
        letterSpacing: 2.1,
      ),
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    picture.dispose();
    if (byteData == null) {
      throw StateError('Could not encode the workout share image.');
    }
    return byteData.buffer.asUint8List();
  }

  static void _drawGrid(Canvas canvas) {
    final paint = Paint()
      ..color = BrandColors.violet.withValues(alpha: .035)
      ..strokeWidth = 1.2;
    const step = 72.0;
    for (var x = 0.0; x <= width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, height.toDouble()), paint);
    }
    for (var y = 0.0; y <= height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(width.toDouble(), y), paint);
    }
  }

  static void _drawAmbientGlow(Canvas canvas) {
    canvas.drawCircle(
      const Offset(930, 250),
      430,
      Paint()
        ..shader = ui.Gradient.radial(
          const Offset(930, 250),
          430,
          [BrandColors.purple.withValues(alpha: .23), Colors.transparent],
        ),
    );
    canvas.drawCircle(
      const Offset(70, 1510),
      390,
      Paint()
        ..shader = ui.Gradient.radial(
          const Offset(70, 1510),
          390,
          [BrandColors.cyan.withValues(alpha: .12), Colors.transparent],
        ),
    );
  }

  static void _drawPill(
    Canvas canvas,
    Offset origin,
    String text, {
    Color accent = BrandColors.violet,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: accent,
          fontSize: 24,
          fontWeight: FontWeight.w900,
          letterSpacing: 2.1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final rect = Rect.fromLTWH(
      origin.dx,
      origin.dy,
      painter.width + 42,
      52,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(26)),
      Paint()..color = accent.withValues(alpha: .11),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(26)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..color = accent.withValues(alpha: .38),
    );
    painter.paint(canvas, Offset(origin.dx + 21, origin.dy + 11));
  }

  static void _drawMetricCard(Canvas canvas, Rect rect, ShareMetric metric) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(30)),
      Paint()..color = BrandColors.panel.withValues(alpha: .88),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(30)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..color = BrandColors.violet.withValues(alpha: .2),
    );
    _drawText(
      canvas,
      metric.label.toUpperCase(),
      Offset(rect.left + 30, rect.top + 28),
      maxWidth: rect.width - 60,
      style: const TextStyle(
        color: BrandColors.muted,
        fontSize: 20,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.8,
      ),
    );
    _drawText(
      canvas,
      metric.value,
      Offset(rect.left + 30, rect.top + 78),
      maxWidth: rect.width - 60,
      maxLines: 2,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 47,
        height: 1.02,
        fontWeight: FontWeight.w900,
        letterSpacing: -.8,
      ),
    );
  }

  static double _drawText(
    Canvas canvas,
    String text,
    Offset origin, {
    required double maxWidth,
    required TextStyle style,
    int? maxLines,
    TextAlign textAlign = TextAlign.left,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textAlign: textAlign,
      maxLines: maxLines,
      ellipsis: maxLines == null ? null : '…',
    )..layout(maxWidth: maxWidth);
    painter.paint(canvas, origin);
    return painter.height;
  }

  static void _drawMark(Canvas canvas, Rect rect) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(25)),
      Paint()
        ..shader = ui.Gradient.linear(
          rect.topLeft,
          rect.bottomRight,
          const [Color(0xFF11162B), Color(0xFF070811)],
        ),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.deflate(2), const Radius.circular(23)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..shader = ui.Gradient.linear(
          rect.topLeft,
          rect.bottomRight,
          const [BrandColors.cyan, BrandColors.violet, BrandColors.magenta],
          const [0, .5, 1],
        ),
    );
    final flask = Path()
      ..moveTo(rect.left + rect.width * .38, rect.top + rect.height * .20)
      ..lineTo(rect.left + rect.width * .62, rect.top + rect.height * .20)
      ..moveTo(rect.left + rect.width * .42, rect.top + rect.height * .25)
      ..lineTo(rect.left + rect.width * .42, rect.top + rect.height * .42)
      ..lineTo(rect.left + rect.width * .29, rect.top + rect.height * .69)
      ..quadraticBezierTo(
        rect.left + rect.width * .27,
        rect.top + rect.height * .75,
        rect.left + rect.width * .35,
        rect.top + rect.height * .76,
      )
      ..lineTo(rect.left + rect.width * .65, rect.top + rect.height * .76)
      ..quadraticBezierTo(
        rect.left + rect.width * .73,
        rect.top + rect.height * .75,
        rect.left + rect.width * .71,
        rect.top + rect.height * .69,
      )
      ..lineTo(rect.left + rect.width * .58, rect.top + rect.height * .42)
      ..lineTo(rect.left + rect.width * .58, rect.top + rect.height * .25);
    canvas.drawPath(
      flask,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = 6
        ..shader = ui.Gradient.linear(
          rect.topLeft,
          rect.bottomRight,
          const [BrandColors.cyan, BrandColors.violet],
        ),
    );
    canvas.drawLine(
      Offset(rect.left + 18, rect.top + rect.height * .62),
      Offset(rect.right - 18, rect.top + rect.height * .62),
      Paint()
        ..color = BrandColors.violet
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round,
    );
  }

  static String _formatDate(DateTime value) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[value.month - 1]} ${value.day}, ${value.year}';
  }
}

class ShareImageBridge {
  static const _channel = MethodChannel('progression_lab/share');

  static Future<String?> save(Uint8List bytes, String fileName) =>
      _channel.invokeMethod<String>('saveImage', {
        'bytes': bytes,
        'fileName': fileName,
      });

  static Future<void> share(Uint8List bytes, String fileName) =>
      _channel.invokeMethod<void>('shareImage', {
        'bytes': bytes,
        'fileName': fileName,
      });
}

class WorkoutSharePreviewScreen extends StatefulWidget {
  const WorkoutSharePreviewScreen({super.key, required this.data});

  final WorkoutShareData data;

  @override
  State<WorkoutSharePreviewScreen> createState() =>
      _WorkoutSharePreviewScreenState();
}

class _WorkoutSharePreviewScreenState
    extends State<WorkoutSharePreviewScreen> {
  late final Future<Uint8List> _image;
  bool _saving = false;
  bool _sharing = false;

  @override
  void initState() {
    super.initState();
    _image = WorkoutShareCardGenerator.generate(widget.data);
  }

  Future<void> _save(Uint8List bytes) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await ShareImageBridge.save(bytes, widget.data.fileName);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Share card saved to Pictures/Progression Lab.'),
        ),
      );
    } on PlatformException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message ?? 'Could not save the image.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _share(Uint8List bytes) async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      await ShareImageBridge.share(bytes, widget.data.fileName);
    } on PlatformException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message ?? 'Could not share the image.')),
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Share workout')),
    body: BrandBackdrop(
      child: FutureBuilder<Uint8List>(
        future: _image,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Could not generate the share card.\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          final bytes = snapshot.data;
          if (bytes == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return Column(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 18, 24, 12),
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: 9 / 16,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: Image.memory(bytes, fit: BoxFit.cover),
                      ),
                    ),
                  ),
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _saving ? null : () => _save(bytes),
                          icon: Icon(
                            _saving
                                ? Icons.hourglass_top_rounded
                                : Icons.download_rounded,
                          ),
                          label: Text(_saving ? 'SAVING' : 'SAVE IMAGE'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _sharing ? null : () => _share(bytes),
                          icon: Icon(
                            _sharing
                                ? Icons.hourglass_top_rounded
                                : Icons.share_rounded,
                          ),
                          label: Text(_sharing ? 'OPENING' : 'SHARE'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}

Future<void> showWorkoutCompleteSheet(
  BuildContext context,
  WorkoutShareData data,
) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  builder: (sheetContext) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const LabMark(size: 68),
          const SizedBox(height: 16),
          const Text(
            'WORKOUT COMPLETE',
            style: TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.w900,
              letterSpacing: .7,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            data.title,
            textAlign: TextAlign.center,
            style: const TextStyle(color: BrandColors.muted, fontSize: 16),
          ),
          const SizedBox(height: 20),
          GradientAction(
            label: 'CREATE STORY CARD',
            icon: Icons.auto_awesome_rounded,
            onPressed: () => Navigator.push(
              sheetContext,
              MaterialPageRoute(
                builder: (_) => WorkoutSharePreviewScreen(data: data),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.pop(sheetContext),
              child: const Text('DONE'),
            ),
          ),
        ],
      ),
    ),
  ),
);

String formatShareDuration(Duration value) {
  final minutes = value.inMinutes;
  if (minutes < 1) return '<1 MIN';
  if (minutes < 60) return '$minutes MIN';
  final hours = minutes ~/ 60;
  final remainder = minutes % 60;
  return remainder == 0 ? '$hours HR' : '$hours HR $remainder MIN';
}
