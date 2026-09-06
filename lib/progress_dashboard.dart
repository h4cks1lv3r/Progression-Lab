import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'brand.dart';
import 'store.dart';
import 'contextual_guides.dart';
import 'exercise_metrics.dart';
import 'logged_sets.dart';

class ProgressDashboard extends StatefulWidget {
  const ProgressDashboard({super.key, required this.store});
  final AppStore store;
  @override
  State<ProgressDashboard> createState() => _ProgressDashboardState();
}

class _ProgressDashboardState extends State<ProgressDashboard> {
  String? selected;
  ExerciseMetric? metric;
  int range = 90;
  int? selectedPoint;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.store,
    builder: (context, _) {
      final groups = <String, List<SetLog>>{};
      for (final log in widget.store.logs) {
        final key = log.exerciseId ?? log.exercise.toLowerCase().trim();
        groups.putIfAbsent(key, () => []).add(log);
      }
      for (final logs in groups.values) {
        logs.sort((a, b) => a.date.compareTo(b.date));
      }
      final keys = groups.keys.toList()
        ..sort(
          (a, b) =>
              groups[a]!.last.exercise.compareTo(groups[b]!.last.exercise),
        );
      final key = keys.contains(selected)
          ? selected
          : keys.isEmpty
          ? null
          : keys.reduce(
              (a, b) =>
                  groups[a]!.last.date.isAfter(groups[b]!.last.date) ? a : b,
            );
      final all = groups[key] ?? <SetLog>[];
      final metrics = all.isEmpty
          ? <ExerciseMetric>[]
          : metricsFor(all.last.resolvedTrackingType);
      final active = metrics.contains(metric) ? metric : metrics.firstOrNull;
      final cutoff = range == 0
          ? null
          : DateTime.now().subtract(Duration(days: range));
      final points = all
          .where(
            (l) =>
                (cutoff == null || !l.date.isBefore(cutoff)) &&
                active != null &&
                active.value(l).isFinite,
          )
          .toList();
      final focus = points.isEmpty
          ? null
          : points[(selectedPoint ?? points.length - 1).clamp(
              0,
              points.length - 1,
            )];
      final records = <SetLog>[];
      final prior = <SetLog>[];
      for (final log in all) {
        if (!prior.any((p) => widget.store.dominates(p, log))) records.add(log);
        prior.add(log);
      }
      final unit = active?.unit(widget.store.unit) ?? widget.store.unit;
      return Material(
        child: ListView(
          key: const PageStorageKey('strength-progress-v2'),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            FeatureTip(
              store: widget.store,
              id: ContextualGuideId.progressCharts,
              message:
                  'Choose a movement and metric. Tap a chart point to inspect the saved set; personal records use the same rules as the workout logger.',
            ),
            Text(
              'Strength signal',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              '${groups.length} ${groups.length == 1 ? 'exercise' : 'exercises'} · ${widget.store.logs.length} logged sets',
              style: const TextStyle(color: BrandColors.muted),
            ),
            const SizedBox(height: 18),
            if (all.isEmpty)
              LabPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.show_chart,
                      size: 36,
                      color: BrandColors.cyan,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Your progress starts with a set',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Complete a workout or import your history. Each exercise will show the metrics that fit its tracking type.',
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'No exercises logged',
                      style: TextStyle(color: BrandColors.muted),
                    ),
                  ],
                ),
              )
            else ...[
              DropdownButtonFormField<String>(
                key: ValueKey('exercise-$key'),
                initialValue: key,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Exercise'),
                items: keys
                    .map(
                      (k) => DropdownMenuItem(
                        value: k,
                        child: Text(
                          groups[k]!.last.exercise,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() {
                  selected = v;
                  metric = null;
                  selectedPoint = null;
                }),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<ExerciseMetric>(
                key: ValueKey('metric-${active?.name}-$key'),
                initialValue: active,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Metric'),
                items: metrics
                    .map(
                      (m) => DropdownMenuItem(value: m, child: Text(m.label)),
                    )
                    .toList(),
                onChanged: (v) => setState(() {
                  metric = v;
                  selectedPoint = null;
                }),
              ),
              if (active == ExerciseMetric.assistance)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Less assistance is improvement when repetitions are maintained.',
                    style: TextStyle(color: BrandColors.cyan),
                  ),
                ),
              if (active == ExerciseMetric.volume &&
                  all.last.resolvedTrackingType.name == 'weightedBodyweight')
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Volume includes added load only. Bodyweight is excluded.',
                    style: TextStyle(color: BrandColors.muted),
                  ),
                ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  for (final days in [30, 90, 365, 0])
                    ChoiceChip(
                      label: Text(switch (days) {
                        0 => 'All',
                        365 => '1 year',
                        _ => '$days days',
                      }),
                      selected: range == days,
                      onSelected: (_) => setState(() {
                        range = days;
                        selectedPoint = null;
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              if (points.isEmpty)
                const LabPanel(
                  child: Text(
                    'No sets in this date range. Choose a longer range.',
                  ),
                )
              else
                LabPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        active!.label,
                        style: const TextStyle(color: BrandColors.muted),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${metricNumber(active.value(focus!))} $unit',
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        '${_date(focus.date)} · ${setDescription(focus, widget.store.unit)}',
                        style: const TextStyle(color: BrandColors.muted),
                      ),
                      const SizedBox(height: 16),
                      Semantics(
                        label:
                            '${active.label} trend: ${points.length} sets. Values are also listed below.',
                        child: LayoutBuilder(
                          builder: (context, c) => GestureDetector(
                            onTapDown: (d) {
                              if (points.length < 2) return;
                              final f =
                                  ((d.localPosition.dx - 10) /
                                          (c.maxWidth - 20))
                                      .clamp(0, 1);
                              final start =
                                  points.first.date.millisecondsSinceEpoch;
                              final duration =
                                  points.last.date.millisecondsSinceEpoch -
                                  start;
                              var nearest = 0;
                              var delta = double.infinity;
                              for (var i = 0; i < points.length; i++) {
                                final dist =
                                    (points[i].date.millisecondsSinceEpoch -
                                            (start + duration * f))
                                        .abs();
                                if (dist < delta) {
                                  nearest = i;
                                  delta = dist.toDouble();
                                }
                              }
                              setState(() => selectedPoint = nearest);
                            },
                            child: SizedBox(
                              height: 150,
                              width: double.infinity,
                              child: CustomPaint(
                                painter: _TrendPainter(
                                  points,
                                  active,
                                  points.indexOf(focus),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _date(points.first.date),
                            style: const TextStyle(
                              fontSize: 12,
                              color: BrandColors.muted,
                            ),
                          ),
                          Text(
                            _date(points.last.date),
                            style: const TextStyle(
                              fontSize: 12,
                              color: BrandColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Recent sets',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => LoggedSetsScreen(
                          store: widget.store,
                          exercise: all.last.exercise,
                        ),
                      ),
                    ),
                    child: const Text('Edit sets'),
                  ),
                ],
              ),
              for (final log in points.reversed.take(12))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(setDescription(log, widget.store.unit)),
                  subtitle: Text('${_date(log.date)} · ${log.workout}'),
                  trailing: Text(
                    '${metricNumber(active!.value(log))} $unit',
                    style: const TextStyle(color: BrandColors.cyan),
                  ),
                ),
              const Divider(),
              Text(
                'Personal records',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              for (final log in records.reversed.take(5))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.emoji_events_outlined,
                    color: BrandColors.violet,
                  ),
                  title: Text(setDescription(log, widget.store.unit)),
                  subtitle: Text(_date(log.date)),
                ),
            ],
          ],
        ),
      );
    },
  );
  String _date(DateTime d) => '${d.month}/${d.day}/${d.year}';
}

class _TrendPainter extends CustomPainter {
  _TrendPainter(this.logs, this.metric, this.selected);
  final List<SetLog> logs;
  final ExerciseMetric metric;
  final int selected;
  @override
  void paint(Canvas canvas, Size size) {
    if (logs.isEmpty) return;
    final values = logs.map(metric.value).toList();
    final lo = values.reduce(math.min), hi = values.reduce(math.max);
    final span = hi - lo;
    final grid = Paint()
      ..color = BrandColors.line
      ..strokeWidth = 1;
    for (var i = 0; i < 4; i++) {
      final y = 10 + (size.height - 20) * i / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    final elapsed = logs.last.date.difference(logs.first.date).inMilliseconds;
    Offset point(int i) => Offset(
      logs.length == 1
          ? size.width / 2
          : 10 +
                (size.width - 20) *
                    (elapsed == 0
                        ? i / (logs.length - 1)
                        : logs[i].date
                                  .difference(logs.first.date)
                                  .inMilliseconds /
                              elapsed),
      span == 0
          ? size.height / 2
          : size.height - 10 - (size.height - 20) * (values[i] - lo) / span,
    );
    final path = Path()..moveTo(point(0).dx, point(0).dy);
    for (var i = 1; i < logs.length; i++) {
      path.lineTo(point(i).dx, point(i).dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = BrandColors.cyan
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke,
    );
    for (var i = 0; i < logs.length; i++) {
      canvas.drawCircle(
        point(i),
        i == selected ? 6 : 3,
        Paint()..color = i == selected ? BrandColors.violet : BrandColors.cyan,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TrendPainter old) => true;
}
