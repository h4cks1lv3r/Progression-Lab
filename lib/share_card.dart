import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'brand.dart';

import 'share_options.dart';

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
    int metricInt(String label) {
      for (final metric in data.metrics) {
        if (metric.label.toLowerCase() == label.toLowerCase()) {
          return int.tryParse(metric.value.replaceAll(RegExp(r'[^0-9]'), '')) ??
              0;
        }
      }
      return 0;
    }

    double? metricDouble(String label) {
      for (final metric in data.metrics) {
        if (metric.label.toLowerCase() == label.toLowerCase()) {
          final value = metric.value.toUpperCase();
          final number = double.tryParse(
            value.replaceAll(RegExp(r'[^0-9.]'), ''),
          );
          if (number == null) return null;
          if (value.contains('M')) return number * 1000000;
          if (value.contains('K')) return number * 1000;
          return number;
        }
      }
      return null;
    }

    final snapshot = ShareWorkoutSnapshot(
      program: data.program,
      workout: data.title,
      completedAt: data.completedAt,
      duration: Duration(minutes: metricInt('Duration')),
      sets: metricInt('Sets'),
      exercises: metricInt('Exercises'),
      volume: metricDouble('Volume'),
      phaseLabel: data.contextLine,
      achievement: data.achievementLabel ?? '',
      highlights: <ShareHighlight>[
        if (data.highlightValue.isNotEmpty)
          ShareHighlight(
            data.highlightLabel.isEmpty ? 'Highlight' : data.highlightLabel,
            data.highlightValue,
            sensitiveWeight: true,
          ),
      ],
    );
    return AdvancedWorkoutShareCardGenerator.generate(
      snapshot,
      AdvancedWorkoutShareCardGenerator.currentPreferences,
    );
  }
}

class ShareImageBridge {
  static const _channel = MethodChannel('progression_lab/share');

  static Future<String?> save(Uint8List bytes, String fileName) =>
      _channel.invokeMethod<String>('saveImage', {
        'bytes': bytes,
        'fileName': fileName,
      });

  static Future<void> share(Uint8List bytes, String fileName) => _channel
      .invokeMethod<void>('shareImage', {'bytes': bytes, 'fileName': fileName});
}

class WorkoutSharePreviewScreen extends StatefulWidget {
  const WorkoutSharePreviewScreen({super.key, required this.data});

  final WorkoutShareData data;

  @override
  State<WorkoutSharePreviewScreen> createState() =>
      _WorkoutSharePreviewScreenState();
}

class _WorkoutSharePreviewScreenState extends State<WorkoutSharePreviewScreen> {
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
