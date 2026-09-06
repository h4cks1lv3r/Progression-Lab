import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'brand.dart';
import 'share_options.dart';
import 'store.dart';
import 'contextual_guides.dart';
import 'daily_inputs_screen.dart';

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
    this.snapshot,
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
  final ShareWorkoutSnapshot? snapshot;
}

class WorkoutShareCardGenerator {
  static Future<Uint8List> generate(
    WorkoutShareData data, {
    WorkoutSharePreferences? preferences,
  }) => AdvancedWorkoutShareCardGenerator.generate(
    toSnapshot(data),
    preferences ?? AdvancedWorkoutShareCardGenerator.currentPreferences,
  );

  // Legacy callers remain supported; active workouts supply typed snapshots.
  static ShareWorkoutSnapshot toSnapshot(WorkoutShareData data) {
    if (data.snapshot != null) return data.snapshot!;
    String metric(String name) =>
        data.metrics
            .where((m) => m.label.toLowerCase() == name)
            .firstOrNull
            ?.value ??
        '';
    double number(String text) {
      final m = RegExp(
        r'([0-9]+(?:\.[0-9]+)?)\s*([kKmM]?)',
      ).firstMatch(text.replaceAll(',', ''));
      if (m == null) return 0;
      return double.parse(m[1]!) *
          (m[2]!.toLowerCase() == 'k'
              ? 1000
              : m[2]!.toLowerCase() == 'm'
              ? 1000000
              : 1);
    }

    final duration = metric('duration').toUpperCase();
    final hours = RegExp(r'(\d+)\s*HR').firstMatch(duration);
    final minutes = RegExp(r'(\d+)\s*MIN').firstMatch(duration);
    final elapsed = duration.startsWith('<')
        ? Duration.zero
        : Duration(
            hours: int.tryParse(hours?[1] ?? '') ?? 0,
            minutes: int.tryParse(minutes?[1] ?? '') ?? 0,
          );
    return ShareWorkoutSnapshot(
      program: data.program,
      workout: data.title,
      completedAt: data.completedAt,
      duration: elapsed,
      sets: number(metric('sets')).toInt(),
      exercises: number(metric('exercises')).toInt(),
      volume: metric('volume').isEmpty ? null : number(metric('volume')),
      volumeUnit: metric('volume').toLowerCase().contains('kg') ? 'kg' : 'lb',
      drills: metric('drills').isEmpty
          ? null
          : number(metric('drills')).toInt(),
      effort: metric('effort').isEmpty
          ? null
          : number(metric('effort')).toInt(),
      phaseLabel: data.contextLine,
      achievement: data.achievementLabel ?? '',
      highlights: [
        ShareHighlight(
          data.highlightLabel,
          data.highlightValue,
          sensitiveWeight: true,
        ),
      ],
    );
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

  static Future<void> sharePng(
    Uint8List bytes,
    String fileName, {
    String? caption,
  }) async {
    try {
      await _channel.invokeMethod<void>('shareImage', <String, Object>{
        if (caption != null) 'caption': caption,
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
  const WorkoutSharePreviewScreen({super.key, required this.data, this.store});

  final WorkoutShareData data;
  final AppStore? store;

  @override
  State<WorkoutSharePreviewScreen> createState() =>
      _WorkoutSharePreviewScreenState();
}

class _WorkoutSharePreviewScreenState extends State<WorkoutSharePreviewScreen> {
  late Future<Uint8List> _image;
  late WorkoutSharePreferences _preferences;
  bool _saving = false;
  bool _sharing = false;

  @override
  void initState() {
    super.initState();
    _preferences =
        widget.store?.sharePreferences ?? const WorkoutSharePreferences();
    _image = WorkoutShareCardGenerator.generate(
      widget.data,
      preferences: _preferences,
    );
  }

  Future<void> _editOptions() async {
    var selected = _preferences;
    final result = await showModalBottomSheet<WorkoutSharePreferences>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Share settings',
                    style: Theme.of(ctx).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<WorkoutShareTemplate>(
                    initialValue: selected.template,
                    decoration: const InputDecoration(labelText: 'Template'),
                    items: WorkoutShareTemplate.values
                        .map(
                          (v) => DropdownMenuItem(
                            value: v,
                            child: Text(switch (v) {
                              WorkoutShareTemplate.cleanPerformance =>
                                'Performance',
                              WorkoutShareTemplate.achievement => 'Achievement',
                              WorkoutShareTemplate.sessionRecap =>
                                'Session recap',
                            }),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => update(
                      () => selected = WorkoutSharePreferences(
                        template: v!,
                        aspect: selected.aspect,
                        privacy: selected.privacy,
                        includeCaption: selected.includeCaption,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<WorkoutShareAspect>(
                    initialValue: selected.aspect,
                    decoration: const InputDecoration(labelText: 'Format'),
                    items: WorkoutShareAspect.values
                        .map(
                          (v) => DropdownMenuItem(
                            value: v,
                            child: Text(switch (v) {
                              WorkoutShareAspect.story => 'Story · 9:16',
                              WorkoutShareAspect.portraitFeed =>
                                'Portrait · 4:5',
                              WorkoutShareAspect.square => 'Square · 1:1',
                            }),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => update(
                      () => selected = WorkoutSharePreferences(
                        template: selected.template,
                        aspect: v!,
                        privacy: selected.privacy,
                        includeCaption: selected.includeCaption,
                      ),
                    ),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Show exact weights'),
                    value: selected.privacy.showExactWeights,
                    onChanged: (v) => update(
                      () => selected = _withPrivacy(selected, weights: v),
                    ),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Completion only'),
                    subtitle: const Text('Hide all performance metrics.'),
                    value: selected.privacy.completionOnly,
                    onChanged: (v) => update(
                      () => selected = _withPrivacy(selected, completion: v),
                    ),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Show duration'),
                    value: selected.privacy.showDuration,
                    onChanged: (v) => update(
                      () => selected = _withPrivacy(selected, duration: v),
                    ),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Show volume'),
                    value: selected.privacy.showVolume,
                    onChanged: (v) => update(
                      () => selected = _withPrivacy(selected, volume: v),
                    ),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Show date'),
                    value: selected.privacy.showDate,
                    onChanged: (v) => update(
                      () => selected = _withPrivacy(selected, date: v),
                    ),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx, selected),
                    child: const Text('Apply settings'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (result == null || !mounted) return;
    try {
      await widget.store?.setSharePreferences(result);
      if (!mounted) return;
      setState(() {
        _preferences = result;
        _image = WorkoutShareCardGenerator.generate(
          widget.data,
          preferences: result,
        );
      });
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Share settings could not be saved. Try again.'),
          ),
        );
    }
  }

  WorkoutSharePreferences _withPrivacy(
    WorkoutSharePreferences p, {
    bool? weights,
    bool? completion,
    bool? duration,
    bool? volume,
    bool? date,
  }) => WorkoutSharePreferences(
    template: p.template,
    aspect: p.aspect,
    includeCaption: p.includeCaption,
    privacy: WorkoutSharePrivacy(
      showExactWeights: weights ?? p.privacy.showExactWeights,
      completionOnly: completion ?? p.privacy.completionOnly,
      showDuration: duration ?? p.privacy.showDuration,
      showVolume: volume ?? p.privacy.showVolume,
      showDate: date ?? p.privacy.showDate,
      showBodyweight: p.privacy.showBodyweight,
    ),
  );

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
        caption: _preferences.includeCaption
            ? WorkoutShareCaptionBuilder.build(
                WorkoutShareCardGenerator.toSnapshot(widget.data),
                _preferences,
              )
            : null,
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
    appBar: AppBar(
      title: const Text('Share workout'),
      actions: [
        TextButton.icon(
          onPressed: _editOptions,
          icon: const Icon(Icons.tune),
          label: const Text('Format & privacy'),
        ),
      ],
    ),
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
              if (widget.store != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: FeatureTip(
                    store: widget.store!,
                    id: ContextualGuideId.workoutSharing,
                    message:
                        'Use Format & privacy above to choose exactly what appears in this image before saving or sharing.',
                  ),
                ),
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
  WorkoutShareData data, {
  AppStore? store,
  String? sessionId,
  String track = 'strength',
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  builder: (sheetContext) => SafeArea(
    child: SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 8, 22, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const LabMark(size: 68),
            const SizedBox(height: 16),
            const Text(
              'Workout saved',
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
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(sheetContext),
                child: const Text('Done'),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              label: const Text('Share workout'),
              icon: const Icon(Icons.share_outlined),
              onPressed: () => Navigator.push(
                sheetContext,
                MaterialPageRoute<void>(
                  builder: (_) =>
                      WorkoutSharePreviewScreen(data: data, store: store),
                ),
              ),
            ),
            if (store != null && sessionId != null)
              TextButton(
                onPressed: () => showWorkoutResponseSheet(
                  sheetContext,
                  store,
                  sessionId: sessionId,
                  track: track,
                ),
                child: const Text('Add how it felt'),
              ),
          ],
        ),
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
