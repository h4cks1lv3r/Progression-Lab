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
                  color: Brand.accent,
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
                    color: Brand.accent.withValues(alpha: 0.5),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: <Widget>[
                      const Icon(Icons.auto_graph_rounded, color: Brand.accent),
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
                    color: Brand.accent,
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
