import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'body_media.dart';
import 'body_privacy.dart';
import 'body_progress.dart';
import 'body_photo_widgets.dart';
import 'share_card.dart';
import 'store.dart';

enum BodyShareLayout { comparison, milestone, recap, withoutPhoto }

enum BodyShareSize { portrait, square, story }

/// Only explicitly selected fields reach the renderer and caption. Never pass
/// a complete check-in, private note, or health record to either output.
class BodyShareSnapshot {
  const BodyShareSnapshot({
    required this.title,
    required this.interval,
    required this.lines,
    this.earlierLabel = 'Earlier',
    this.latestLabel = 'Latest',
  });
  final String title, interval, earlierLabel, latestLabel;
  final List<String> lines;
  String get caption => [
    title,
    interval,
    ...lines,
    'Progression Lab',
  ].where((v) => v.isNotEmpty).join('\n');
  static BodyShareSnapshot build({
    required String title,
    required String start,
    required String end,
    required List<BodyMeasurement> measurements,
    required String weightUnit,
    required String lengthUnit,
    bool dates = false,
    bool weight = false,
    bool waist = false,
    String training = '',
  }) {
    final days = DateTime.parse(
      '${end}T00:00:00Z',
    ).difference(DateTime.parse('${start}T00:00:00Z')).inDays;
    final lines = <String>[];
    BodyMeasurement? read(BodyMetric metric, String day) => measurements
        .where((r) => r.metric == metric && r.date == day)
        .firstOrNull;
    for (final metric in [
      if (weight) BodyMetric.weight,
      if (waist) BodyMetric.waist,
    ]) {
      final a = read(metric, start), b = read(metric, end);
      if (a != null && b != null && start != end) {
        final diff =
            b.displayValue(weightUnit, lengthUnit) -
            a.displayValue(weightUnit, lengthUnit);
        lines.add(
          '${metric.label} change: ${diff > 0 ? '+' : ''}${diff.toStringAsFixed(1)} ${b.displayUnit(weightUnit, lengthUnit)}',
        );
      } else if (b != null)
        lines.add(
          '${metric.label}: ${b.displayValue(weightUnit, lengthUnit).toStringAsFixed(1)} ${b.displayUnit(weightUnit, lengthUnit)}',
        );
    }
    if (training.isNotEmpty) lines.add(training);
    return BodyShareSnapshot(
      title: title.trim().isEmpty ? 'My progress' : title.trim(),
      interval: dates
          ? (days == 0 ? end : '$start → $end · $days days')
          : (days == 0 ? 'One check-in' : '$days days of progress'),
      lines: lines,
      earlierLabel: dates ? start : 'Earlier',
      latestLabel: dates ? end : 'Latest',
    );
  }
}

class BodyShareScreen extends StatefulWidget {
  const BodyShareScreen({
    super.key,
    required this.store,
    required this.first,
    required this.last,
    this.firstPhoto,
    this.lastPhoto,
  });
  final AppStore store;
  final BodyCheckIn first, last;
  final BodyPhoto? firstPhoto, lastPhoto;
  @override
  State<BodyShareScreen> createState() => _BodyShareScreenState();
}

class _BodyShareScreenState extends State<BodyShareScreen> {
  final boundary = GlobalKey();
  final title = TextEditingController(text: 'My progress');
  BodyShareLayout layout = BodyShareLayout.comparison;
  BodyShareSize size = BodyShareSize.portrait;
  bool dates = false, weight = false, waist = false, busy = false;
  String training = '';
  late BodyPhoto? firstPhoto = widget.firstPhoto, lastPhoto = widget.lastPhoto;
  @override
  void initState() {
    super.initState();
    if (widget.first.id == widget.last.id) layout = BodyShareLayout.milestone;
    if (widget.firstPhoto == null || widget.lastPhoto == null)
      layout = BodyShareLayout.withoutPhoto;
    title.addListener(refresh);
  }

  void refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    title.dispose();
    super.dispose();
  }

  List<BodyMeasurement> get selectedMeasurements {
    // Only same-day measurements are candidates. Prefer explicitly linked
    // check-in values and the chosen daily weight source; never use nearest dates.
    final result = <BodyMeasurement>[];
    for (final c in [widget.first, widget.last])
      for (final m in [BodyMetric.weight, BodyMetric.waist]) {
        final linked = widget.store.bodyMeasurements
            .where(
              (r) => r.checkInId == c.id && r.metric == m && r.date == c.date,
            )
            .firstOrNull;
        final daily = m == BodyMetric.weight
            ? widget.store.bodyWeightForDay(DateTime.parse(c.date))
            : widget.store.bodyMeasurements
                  .where((r) => r.metric == m && r.date == c.date)
                  .firstOrNull;
        if ((linked ?? daily) != null) result.add((linked ?? daily)!);
      }
    return result;
  }

  BodyShareSnapshot get snapshot => BodyShareSnapshot.build(
    title: title.text,
    start: widget.first.date,
    end: widget.last.date,
    measurements: selectedMeasurements,
    weightUnit: widget.store.unit,
    lengthUnit: widget.store.bodySettings['lengthUnit'] as String? ?? 'cm',
    dates: dates,
    weight: weight,
    waist: waist,
    training: training,
  );
  double get height => switch (size) {
    BodyShareSize.square => 360,
    BodyShareSize.portrait => 450,
    BodyShareSize.story => 640,
  };
  Future<void> preview() async {
    if (busy) return;
    setState(() => busy = true);
    final capturedSnapshot = snapshot;
    try {
      if (layout != BodyShareLayout.withoutPhoto) {
        for (final p in [
          if ((layout == BodyShareLayout.comparison)) firstPhoto!,
          lastPhoto!,
        ]) {
          final bytes = await File(
            widget.store.bodyMedia.path(p),
          ).readAsBytes();
          final codec = await ui.instantiateImageCodec(bytes);
          final frame = await codec.getNextFrame();
          frame.image.dispose();
          codec.dispose();
        }
        await precacheImage(
          FileImage(File(widget.store.bodyMedia.path(firstPhoto!))),
          context,
        );
        if (!mounted) return;
        await precacheImage(
          FileImage(File(widget.store.bodyMedia.path(lastPhoto!))),
          context,
        );
      }
      await WidgetsBinding.instance.endOfFrame;
      final render =
          boundary.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (render == null) throw StateError('The preview is not ready.');
      final image = await render.toImage(pixelRatio: 3);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (data == null) throw StateError('The image could not be generated.');
      if (mounted)
        await Navigator.push(
          context,
          bodyRoute(
            widget.store.bodyMedia,
            (_) => _FinalBodyShare(
              bytes: data.buffer.asUint8List(),
              caption: capturedSnapshot.caption,
              aspectRatio: 360 / height,
            ),
          ),
        );
    } on Object catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not generate the image: $e')),
        );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final start = DateTime.parse(widget.first.date),
        end = DateTime.parse(widget.last.date).add(const Duration(days: 1));
    final sessions = widget.store.workoutHistory
        .where(
          (r) =>
              r.status == WorkoutStatus.completed &&
              !r.date.isBefore(start) &&
              r.date.isBefore(end),
        )
        .length;
    final options = ['', '$sessions logged strength sessions in this interval'];
    return Scaffold(
      appBar: AppBar(title: const Text('Create share image')),
      body: SafeArea(
        child: AbsorbPointer(
          absorbing: busy,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              TextField(
                controller: title,
                maxLength: 60,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              DropdownButtonFormField<BodyShareLayout>(
                initialValue: layout,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Layout'),
                items: BodyShareLayout.values
                    .where(
                      (l) =>
                          (firstPhoto != null && lastPhoto != null) ||
                          l == BodyShareLayout.withoutPhoto,
                    )
                    .map(
                      (l) => DropdownMenuItem(
                        value: l,
                        child: Text(switch (l) {
                          BodyShareLayout.comparison => 'Photo comparison',
                          BodyShareLayout.milestone => 'Single-photo milestone',
                          BodyShareLayout.recap => 'Photo and progress recap',
                          BodyShareLayout.withoutPhoto => 'Without a photo',
                        }),
                      ),
                    )
                    .toList(),
                onChanged: (l) => setState(() => layout = l!),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<BodyShareSize>(
                initialValue: size,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Image shape'),
                items: BodyShareSize.values
                    .map(
                      (s) => DropdownMenuItem(
                        value: s,
                        child: Text(switch (s) {
                          BodyShareSize.portrait => 'Portrait • 1080 × 1350',
                          BodyShareSize.square => 'Square • 1080 × 1080',
                          BodyShareSize.story => 'Story • 1080 × 1920',
                        }),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => size = v!),
              ),
              const SizedBox(height: 18),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Show exact dates'),
                value: dates,
                onChanged: (v) => setState(() => dates = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Show weight'),
                subtitle: const Text(
                  'Only readings from the selected photo dates.',
                ),
                value: weight,
                onChanged: (v) => setState(() => weight = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Show waist'),
                value: waist,
                onChanged: (v) => setState(() => waist = v),
              ),
              DropdownButtonFormField<String>(
                initialValue: training,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Optional training fact',
                ),
                items: options
                    .map(
                      (s) => DropdownMenuItem(
                        value: s,
                        child: Text(s.isEmpty ? 'None' : s, maxLines: 2),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => training = v!),
              ),
              if (layout != BodyShareLayout.withoutPhoto)
                Wrap(
                  spacing: 10,
                  children: [
                    if ((layout == BodyShareLayout.comparison))
                      TextButton(
                        onPressed: () async {
                          final p = await editBodyPhoto(
                            context,
                            firstPhoto!,
                            widget.store.bodyMedia.path(firstPhoto!),
                            media: widget.store.bodyMedia,
                          );
                          if (p != null) setState(() => firstPhoto = p);
                        },
                        child: const Text('Frame / cover earlier photo'),
                      ),
                    TextButton(
                      onPressed: () async {
                        final p = await editBodyPhoto(
                          context,
                          lastPhoto!,
                          widget.store.bodyMedia.path(lastPhoto!),
                          media: widget.store.bodyMedia,
                        );
                        if (p != null) setState(() => lastPhoto = p);
                      },
                      child: const Text('Frame / cover latest photo'),
                    ),
                  ],
                ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: AspectRatio(
                  aspectRatio: 360 / height,
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: RepaintBoundary(
                      key: boundary,
                      child: SizedBox(
                        width: 360,
                        height: height,
                        child: BodyShareArtwork(
                          snapshot: snapshot,
                          layout: layout,
                          firstPhoto: firstPhoto,
                          lastPhoto: lastPhoto,
                          media: widget.store.bodyMedia,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Private notes and BMI are never included. Review faces, tattoos, and background details. Image shapes are presets; the receiving app may crop them.',
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: busy ? null : preview,
                icon: const Icon(Icons.visibility_outlined),
                label: Text(busy ? 'Generating…' : 'Preview final image'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class BodyShareArtwork extends StatelessWidget {
  const BodyShareArtwork({
    super.key,
    required this.snapshot,
    required this.layout,
    this.firstPhoto,
    this.lastPhoto,
    required this.media,
  });
  final BodyShareSnapshot snapshot;
  final BodyShareLayout layout;
  final BodyPhoto? firstPhoto, lastPhoto;
  final BodyMediaStore media;
  @override
  Widget build(BuildContext context) => MediaQuery.withNoTextScaling(
    child: DefaultTextStyle(
      style: const TextStyle(
        color: Color(0xFFE5E7EB),
        fontSize: 13,
        fontFamily: 'sans-serif',
      ),
      child: ColoredBox(
        color: const Color(0xFF0C0E19),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'PROGRESSION LAB',
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 2,
                  color: Color(0xFF22D3EE),
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                snapshot.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 25,
                  height: 1.05,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                snapshot.interval,
                style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: layout == BodyShareLayout.withoutPhoto
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.insights,
                              size: 64,
                              color: Color(0xFF22D3EE),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              snapshot.lines.isEmpty
                                  ? 'Every check-in counts.'
                                  : snapshot.lines.first,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      )
                    : (layout == BodyShareLayout.milestone ||
                          layout == BodyShareLayout.recap)
                    ? Center(
                        child: AspectRatio(
                          aspectRatio: 3 / 4,
                          child: BodyPhotoFrame(
                            photo: lastPhoto!,
                            path: media.path(lastPhoto!),
                          ),
                        ),
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: _tile(firstPhoto!, snapshot.earlierLabel),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _tile(lastPhoto!, snapshot.latestLabel),
                          ),
                        ],
                      ),
              ),
              if (snapshot.lines.isNotEmpty) ...[
                const SizedBox(height: 12),
                for (final line
                    in (layout == BodyShareLayout.withoutPhoto
                        ? snapshot.lines.skip(1)
                        : snapshot.lines))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      line,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
              ],
              const SizedBox(height: 10),
              const Text(
                'MY PACE. MY PROGRESS.',
                style: TextStyle(
                  fontSize: 9,
                  letterSpacing: 1.3,
                  color: Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  Widget _tile(BodyPhoto photo, String label) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Flexible(
        child: BodyPhotoFrame(photo: photo, path: media.path(photo)),
      ),
      const SizedBox(height: 6),
      Text(label, style: const TextStyle(fontSize: 11)),
    ],
  );
}

class _FinalBodyShare extends StatefulWidget {
  const _FinalBodyShare({
    required this.bytes,
    required this.caption,
    required this.aspectRatio,
  });
  final double aspectRatio;
  final Uint8List bytes;
  final String caption;
  @override
  State<_FinalBodyShare> createState() => _FinalBodyShareState();
}

class _FinalBodyShareState extends State<_FinalBodyShare> {
  bool busy = false;
  Future<void> action(Future<void> Function() work, String? message) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await work();
      if (mounted && message != null)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
    } on Object catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not complete this action: $e')),
        );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Ready to share')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          AspectRatio(
            aspectRatio: widget.aspectRatio,
            child: Image.memory(
              widget.bytes,
              semanticLabel:
                  'Final image. The same pixels will be saved or shared.',
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'This is the exact image that will leave the app. You finish posting in the destination app.',
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: busy
                    ? null
                    : () => action(
                        () => ShareImageBridge.sharePng(
                          widget.bytes,
                          'body-${bodyId()}.png',
                          caption: widget.caption,
                        ),
                        null,
                      ),
                icon: const Icon(Icons.share),
                label: const Text('Share'),
              ),
              OutlinedButton.icon(
                onPressed: busy
                    ? null
                    : () => action(() async {
                        final path = await ShareImageBridge.savePng(
                          widget.bytes,
                          'body-${bodyId()}.png',
                        );
                        if (path == null)
                          throw StateError('Saving is unavailable.');
                      }, 'Image saved to your gallery.'),
                icon: const Icon(Icons.download),
                label: const Text('Save image'),
              ),
              OutlinedButton.icon(
                onPressed: busy
                    ? null
                    : () => action(
                        () => Clipboard.setData(
                          ClipboardData(text: widget.caption),
                        ),
                        'Caption copied.',
                      ),
                icon: const Icon(Icons.copy),
                label: const Text('Copy caption'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text('Caption', style: TextStyle(fontWeight: FontWeight.bold)),
          SelectableText(widget.caption),
          const SizedBox(height: 12),
          const Text(
            'Some apps accept only the image. Use Copy caption to add the text separately. Saving to Gallery creates a copy outside Progression Lab.',
          ),
        ],
      ),
    ),
  );
}
