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
}

class WorkoutShareCardGenerator {
  static Future<Uint8List> generate(WorkoutShareData data) =>
      AdvancedWorkoutShareCardGenerator.generate(
        ShareWorkoutSnapshot(
          program: data.program,
          workout: data.title,
          completedAt: data.completedAt,
          duration: _durationFromMetrics(data.metrics),
          sets: _intMetric(data.metrics, 'sets') ?? 0,
          exercises: _intMetric(data.metrics, 'exercises') ?? 0,
          volume: _doubleMetric(data.metrics, 'volume') ?? 0,
          achievement: data.achievementLabel ?? '',
          highlights: <ShareHighlight>[
            ShareHighlight(data.highlightLabel, data.highlightValue),
          ],
        ),
        AdvancedWorkoutShareCardGenerator.currentPreferences,
      );

  static int? _intMetric(List<ShareMetric> metrics, String label) {
    for (final metric in metrics) {
      if (metric.label.toLowerCase() == label) {
        return int.tryParse(metric.value.replaceAll(RegExp('[^0-9]'), ''));
      }
    }
    return null;
  }

  static double? _doubleMetric(List<ShareMetric> metrics, String label) {
    for (final metric in metrics) {
      if (metric.label.toLowerCase() == label) {
        return double.tryParse(metric.value.replaceAll(RegExp('[^0-9.]'), ''));
      }
    }
    return null;
  }

  static Duration _durationFromMetrics(List<ShareMetric> metrics) {
    for (final metric in metrics) {
      if (metric.label.toLowerCase() == 'duration') {
        final parts = metric.value.split(':');
        if (parts.length == 2) {
          final hours = int.tryParse(parts.first) ?? 0;
          final minutes = int.tryParse(parts.last) ?? 0;
          return Duration(hours: hours, minutes: minutes);
        }
        final minutes =
            int.tryParse(metric.value.replaceAll(RegExp('[^0-9]'), '')) ?? 0;
        return Duration(minutes: minutes);
      }
    }
    return Duration.zero;
  }
}

class ShareImageBridge {
  static const MethodChannel _channel = MethodChannel('progression_lab/share');

  static Future<String?> savePng(Uint8List bytes, String fileName) async {
    try {
      return await _channel.invokeMethod<String>('saveImage', <String, Object>{
        'bytes': bytes,
        'fileName': fileName,
      });
    } on MissingPluginException {
      return null;
    }
  }

  static Future<void> sharePng(Uint8List bytes, String fileName) async {
    try {
      await _channel.invokeMethod<void>('shareImage', <String, Object>{
        'bytes': bytes,
        'fileName': fileName,
      });
    } on MissingPluginException {
      return;
    }
  }
}

String shareFileName(DateTime date) {
  String two(int value) => value.toString().padLeft(2, '0');
  return 'progression-lab-${date.year}${two(date.month)}${two(date.day)}-${two(date.hour)}${two(date.minute)}.png';
}

class WorkoutSharePreview extends StatelessWidget {
  const WorkoutSharePreview({super.key, required this.data});

  final WorkoutShareData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AspectRatio(
      aspectRatio: 9 / 16,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              Color(0xFF0D1118),
              Color(0xFF151E2B),
              Color(0xFF201B34),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'PROGRESSION LAB',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: BrandColors.violet,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2.4,
                ),
              ),
              const Spacer(),
              Text(
                data.title,
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                data.contextLine,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: data.metrics
                    .map((metric) => _PreviewMetric(metric: metric))
                    .toList(growable: false),
              ),
              const SizedBox(height: 20),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: BrandColors.violet.withValues(alpha: 0.5),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: <Widget>[
                      const Icon(
                        Icons.auto_graph_rounded,
                        color: BrandColors.violet,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              data.highlightLabel.toUpperCase(),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: Colors.white60,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              data.highlightValue,
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (data.achievementLabel
                  case final String achievement) ...<Widget>[
                const SizedBox(height: 16),
                Text(
                  achievement,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: BrandColors.violet,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              const Spacer(),
              Text(
                data.footer,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: Colors.white54,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreviewMetric extends StatelessWidget {
  const _PreviewMetric({required this.metric});

  final ShareMetric metric;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            metric.label.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Colors.white54,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            metric.value,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    ),
  );
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
      final location = await ShareImageBridge.savePng(
        bytes,
        shareFileName(widget.data.completedAt),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            location == null
                ? 'Saving images is unavailable on this platform.'
                : 'Share card saved.',
          ),
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
      await ShareImageBridge.sharePng(
        bytes,
        shareFileName(widget.data.completedAt),
      );
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
            children: <Widget>[
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
                  child: Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: Image.memory(bytes, fit: BoxFit.contain),
                    ),
                  ),
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  child: Row(
                    children: <Widget>[
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
        children: <Widget>[
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
              MaterialPageRoute<void>(
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
