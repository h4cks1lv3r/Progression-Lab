import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'brand.dart';
import 'lab_screen.dart';
import 'logged_sets.dart';
import 'store.dart';

/// An exercise-specific progress surface backed only by real [AppStore] logs.
///
/// This widget owns its filters and chart interaction state. It listens to the
/// supplied store, so newly logged sets appear without recreating the page.
class ProgressDashboard extends StatefulWidget {
  const ProgressDashboard({super.key, required this.store});

  final AppStore store;

  @override
  State<ProgressDashboard> createState() => _ProgressDashboardState();
}

class _ProgressDashboardState extends State<ProgressDashboard>
    with SingleTickerProviderStateMixin {
  static const _ink = BrandColors.ink;
  static const _surface = BrandColors.panel;
  static const _surfaceHigh = BrandColors.panelHigh;
  static const _cyan = BrandColors.cyan;
  static const _violet = BrandColors.violet;
  static const _muted = BrandColors.muted;

  String? _selectedExercise;
  _ProgressMetric _metric = _ProgressMetric.estimatedOneRepMax;
  _TimeWindow _window = _TimeWindow.days90;
  int? _scrubbedIndex;
  int? _lastHapticIndex;
  late final AnimationController _revealController;
  late final Animation<double> _reveal;

  @override
  void initState() {
    super.initState();
    _revealController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );
    _reveal = CurvedAnimation(
      parent: _revealController,
      curve: Curves.easeOutCubic,
    );
    widget.store.addListener(_onStoreChanged);
    _revealController.forward();
  }

  @override
  void didUpdateWidget(covariant ProgressDashboard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.store != widget.store) {
      oldWidget.store.removeListener(_onStoreChanged);
      widget.store.addListener(_onStoreChanged);
      _scrubbedIndex = null;
      _restartReveal();
    }
  }

  @override
  void dispose() {
    widget.store.removeListener(_onStoreChanged);
    _revealController.dispose();
    super.dispose();
  }

  void _onStoreChanged() {
    if (!mounted) return;
    setState(() {
      _scrubbedIndex = null;
      _lastHapticIndex = null;
    });
    _restartReveal();
  }

  void _restartReveal() {
    _revealController.forward(from: 0);
  }

  List<String> get _exercises {
    final names = widget.store.logs.map((log) => log.exercise).toSet().toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return names;
  }

  String? _activeExercise(List<String> exercises) {
    if (exercises.isEmpty) return null;
    if (_selectedExercise != null && exercises.contains(_selectedExercise)) {
      return _selectedExercise;
    }
    final latest = widget.store.logs.reduce(
      (a, b) => a.date.isAfter(b.date) ? a : b,
    );
    return latest.exercise;
  }

  List<SetLog> _exerciseLogs(String exercise) =>
      widget.store.logs.where((log) => log.exercise == exercise).toList()
        ..sort((a, b) => a.date.compareTo(b.date));

  List<_ChartPoint> _pointsFor(String exercise) {
    final cutoff = _window.cutoff;
    return _exerciseLogs(exercise)
        .where((log) => cutoff == null || !log.date.isBefore(cutoff))
        .map((log) => _ChartPoint(log, _metric.valueOf(log)))
        .toList();
  }

  void _selectExercise(String? exercise) {
    if (exercise == null || exercise == _selectedExercise) return;
    setState(() {
      _selectedExercise = exercise;
      _scrubbedIndex = null;
      _lastHapticIndex = null;
    });
    _restartReveal();
  }

  void _selectMetric(_ProgressMetric metric) {
    if (metric == _metric) return;
    setState(() {
      _metric = metric;
      _scrubbedIndex = null;
      _lastHapticIndex = null;
    });
    _restartReveal();
  }

  void _selectWindow(_TimeWindow window) {
    if (window == _window) return;
    setState(() {
      _window = window;
      _scrubbedIndex = null;
      _lastHapticIndex = null;
    });
    _restartReveal();
  }

  void _scrub(Offset position, double width, int pointCount) {
    if (pointCount == 0 || width <= 70) return;
    const leftInset = 54.0;
    const rightInset = 18.0;
    final availableWidth = width - leftInset - rightInset;
    final usableWidth = availableWidth < 1.0 ? 1.0 : availableWidth;
    final fraction = ((position.dx - leftInset) / usableWidth).clamp(0.0, 1.0);
    final index = pointCount == 1 ? 0 : (fraction * (pointCount - 1)).round();
    if (index == _scrubbedIndex) return;
    setState(() => _scrubbedIndex = index);
    if (_lastHapticIndex != index) {
      _lastHapticIndex = index;
      HapticFeedback.selectionClick();
    }
  }

  @override
  Widget build(BuildContext context) {
    final exercises = _exercises;
    final exercise = _activeExercise(exercises);
    final points = exercise == null ? <_ChartPoint>[] : _pointsFor(exercise);
    final allExerciseLogs = exercise == null
        ? <SetLog>[]
        : _exerciseLogs(exercise);
    final selectedPoint = points.isEmpty
        ? null
        : points[(_scrubbedIndex ?? points.length - 1)
              .clamp(0, points.length - 1)
              .toInt()];

    return Material(
      color: _ink,
      child: SafeArea(
        child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 36),
        children: [
          _Header(
            exerciseCount: exercises.length,
            setCount: widget.store.logs.length,
          ),
          const SizedBox(height: 16),
          LabPanel(
            accent: BrandColors.cyan,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => InputsPerformanceScreen(store: widget.store),
              ),
            ),
            child: const Row(
              children: [
                Icon(Icons.science_rounded, color: BrandColors.cyan),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'INPUTS & PERFORMANCE',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          letterSpacing: .7,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Compare supplements, meals, and recovery with matched workouts.',
                        style: TextStyle(
                          color: BrandColors.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_rounded, color: BrandColors.muted),
              ],
            ),
          ),
          const SizedBox(height: 22),
          _ControlPanel(
            exercises: exercises,
            selectedExercise: exercise,
            selectedMetric: _metric,
            selectedWindow: _window,
            onExerciseChanged: _selectExercise,
            onMetricChanged: _selectMetric,
            onWindowChanged: _selectWindow,
          ),
          const SizedBox(height: 16),
          if (exercise == null)
            const _EmptyState(
              icon: Icons.query_stats_rounded,
              title: 'Your progress starts with a set',
              message:
                  'Log a completed set in a workout. Real strength and volume trends will appear here.',
            )
          else if (points.isEmpty)
            _EmptyState(
              icon: Icons.calendar_view_month_rounded,
              title: 'No sets in this time range',
              message:
                  '$exercise has no logged sets in ${_window.spokenLabel.toLowerCase()}.',
              actionLabel: 'SHOW ALL HISTORY',
              onAction: () => _selectWindow(_TimeWindow.all),
            )
          else ...[
            _StatsGrid(
              points: points,
              metric: _metric,
              unit: widget.store.unit,
            ),
            const SizedBox(height: 16),
            _ChartCard(
              exercise: exercise,
              metric: _metric,
              unit: widget.store.unit,
              window: _window,
              points: points,
              selectedIndex: _scrubbedIndex,
              selectedPoint: selectedPoint,
              reveal: _reveal,
              onScrub: _scrub,
            ),
          ],
          if (exercise != null) ...[
            const SizedBox(height: 24),
            LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 760;
                final recent = _RecentSetsCard(
                  logs: allExerciseLogs.reversed.take(8).toList(),
                  unit: widget.store.unit,
                  onEdit: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => LoggedSetsScreen(
                        store: widget.store,
                        exercise: exercise,
                      ),
                    ),
                  ),
                );
                final records = _PrRecordsCard(
                  records: _prRecords(
                    allExerciseLogs,
                  ).reversed.take(8).toList(),
                  unit: widget.store.unit,
                );
                if (!wide) {
                  return Column(
                    children: [recent, const SizedBox(height: 16), records],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: recent),
                    const SizedBox(width: 16),
                    Expanded(child: records),
                  ],
                );
              },
            ),
          ],
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.exerciseCount, required this.setCount});

  final int exerciseCount;
  final int setCount;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'PROGRESS LAB',
              style: TextStyle(
                color: _ProgressDashboardState._cyan,
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 2.1,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Strength signal',
              style: TextStyle(
                color: Colors.white,
                fontSize: 32,
                height: 1.05,
                fontWeight: FontWeight.w900,
                letterSpacing: -1.0,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              exerciseCount == 0
                  ? 'No recorded exercises yet'
                  : '$exerciseCount exercises  •  $setCount logged sets',
              style: const TextStyle(
                color: _ProgressDashboardState._muted,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(width: 16),
      const LabMark(size: 50),
    ],
  );
}

class _ControlPanel extends StatelessWidget {
  const _ControlPanel({
    required this.exercises,
    required this.selectedExercise,
    required this.selectedMetric,
    required this.selectedWindow,
    required this.onExerciseChanged,
    required this.onMetricChanged,
    required this.onWindowChanged,
  });

  final List<String> exercises;
  final String? selectedExercise;
  final _ProgressMetric selectedMetric;
  final _TimeWindow selectedWindow;
  final ValueChanged<String?> onExerciseChanged;
  final ValueChanged<_ProgressMetric> onMetricChanged;
  final ValueChanged<_TimeWindow> onWindowChanged;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: _panelDecoration(),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _ControlLabel('EXERCISE'),
        const SizedBox(height: 8),
        Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .045),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: .09)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: selectedExercise,
              isExpanded: true,
              icon: const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: _ProgressDashboardState._cyan,
              ),
              dropdownColor: _ProgressDashboardState._surfaceHigh,
              hint: const Text(
                'No exercises logged',
                style: TextStyle(color: _ProgressDashboardState._muted),
              ),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
              items: exercises
                  .map(
                    (exercise) => DropdownMenuItem(
                      value: exercise,
                      child: Text(exercise, overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(),
              onChanged: exercises.isEmpty ? null : onExerciseChanged,
            ),
          ),
        ),
        const SizedBox(height: 16),
        const _ControlLabel('METRIC'),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<_ProgressMetric>(
            showSelectedIcon: false,
            segments: [
              for (final metric in _ProgressMetric.values)
                ButtonSegment(
                  value: metric,
                  icon: Icon(metric.icon, size: 17),
                  label: Text(metric.shortLabel),
                ),
            ],
            selected: {selectedMetric},
            onSelectionChanged: (selection) => onMetricChanged(selection.first),
            style: ButtonStyle(
              minimumSize: const WidgetStatePropertyAll(Size(0, 46)),
              padding: const WidgetStatePropertyAll(
                EdgeInsets.symmetric(horizontal: 8),
              ),
              textStyle: const WidgetStatePropertyAll(
                TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
              ),
              foregroundColor: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.selected)
                    ? Colors.black
                    : Colors.white70,
              ),
              backgroundColor: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.selected)
                    ? _ProgressDashboardState._cyan
                    : Colors.transparent,
              ),
              side: WidgetStatePropertyAll(
                BorderSide(color: Colors.white.withValues(alpha: .12)),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        const _ControlLabel('RANGE'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final window in _TimeWindow.values)
              ChoiceChip(
                label: Text(window.label),
                selected: selectedWindow == window,
                showCheckmark: false,
                onSelected: (_) => onWindowChanged(window),
                selectedColor: _ProgressDashboardState._violet,
                backgroundColor: Colors.white.withValues(alpha: .045),
                side: BorderSide(
                  color: selectedWindow == window
                      ? _ProgressDashboardState._violet
                      : Colors.white.withValues(alpha: .09),
                ),
                labelStyle: TextStyle(
                  color: selectedWindow == window
                      ? Colors.black
                      : Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
          ],
        ),
      ],
    ),
  );
}

class _ControlLabel extends StatelessWidget {
  const _ControlLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      color: _ProgressDashboardState._muted,
      fontSize: 10,
      fontWeight: FontWeight.w900,
      letterSpacing: 1.5,
    ),
  );
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({
    required this.points,
    required this.metric,
    required this.unit,
  });

  final List<_ChartPoint> points;
  final _ProgressMetric metric;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final values = points.map((point) => point.value).toList();
    final first = values.first;
    final current = values.last;
    final minimum = values.reduce((a, b) => a < b ? a : b);
    final maximum = values.reduce((a, b) => a > b ? a : b);
    final delta = current - first;
    final percent = first == 0 ? null : delta / first * 100;
    final metricUnit = metric.unit(unit);

    final stats = [
      _StatData(
        'CURRENT',
        _formatValue(current),
        metricUnit,
        Icons.bolt_rounded,
      ),
      _StatData('HIGH', _formatValue(maximum), metricUnit, Icons.north_rounded),
      _StatData('LOW', _formatValue(minimum), metricUnit, Icons.south_rounded),
      _StatData(
        'CHANGE',
        percent == null
            ? '—'
            : '${percent >= 0 ? '+' : ''}${percent.toStringAsFixed(1)}%',
        points.length < 2 ? 'Need 2 sets' : 'First to latest',
        delta >= 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded,
        positive: delta >= 0,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 720 ? 4 : 2;
        final gap = 10.0;
        final width = (constraints.maxWidth - (columns - 1) * gap) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final stat in stats)
              SizedBox(width: width, child: _StatCard(stat)),
          ],
        );
      },
    );
  }
}

class _StatData {
  const _StatData(
    this.label,
    this.value,
    this.unit,
    this.icon, {
    this.positive,
  });
  final String label;
  final String value;
  final String unit;
  final IconData icon;
  final bool? positive;
}

class _StatCard extends StatelessWidget {
  const _StatCard(this.data);
  final _StatData data;

  @override
  Widget build(BuildContext context) {
    final accent = data.positive == false
        ? const Color(0xFFFF718A)
        : _ProgressDashboardState._cyan;
    return Container(
      constraints: const BoxConstraints(minHeight: 100),
      padding: const EdgeInsets.all(14),
      decoration: _panelDecoration(radius: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(data.icon, color: accent, size: 16),
              const SizedBox(width: 6),
              Text(
                data.label,
                style: const TextStyle(
                  color: _ProgressDashboardState._muted,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            data.value,
            maxLines: 1,
            overflow: TextOverflow.fade,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: -.6,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            data.unit,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _ProgressDashboardState._muted,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.exercise,
    required this.metric,
    required this.unit,
    required this.window,
    required this.points,
    required this.selectedIndex,
    required this.selectedPoint,
    required this.reveal,
    required this.onScrub,
  });

  final String exercise;
  final _ProgressMetric metric;
  final String unit;
  final _TimeWindow window;
  final List<_ChartPoint> points;
  final int? selectedIndex;
  final _ChartPoint? selectedPoint;
  final Animation<double> reveal;
  final void Function(Offset position, double width, int pointCount) onScrub;

  @override
  Widget build(BuildContext context) {
    final semanticValue = selectedPoint == null
        ? null
        : '${metric.label} ${_formatValue(selectedPoint!.value)} ${metric.unit(unit)}, '
              '${_longDate(selectedPoint!.log.date)}, '
              '${_formatWeight(selectedPoint!.log.weight)} $unit for ${selectedPoint!.log.reps} reps';
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
      decoration: BoxDecoration(
        color: _ProgressDashboardState._surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: .08)),
        boxShadow: [
          BoxShadow(
            color: _ProgressDashboardState._violet.withValues(alpha: .08),
            blurRadius: 32,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      metric.label.toUpperCase(),
                      style: const TextStyle(
                        color: _ProgressDashboardState._cyan,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.6,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      exercise,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _ProgressDashboardState._cyan.withValues(alpha: .09),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _ProgressDashboardState._cyan.withValues(alpha: .22),
                  ),
                ),
                child: Text(
                  '${points.length} ${points.length == 1 ? 'POINT' : 'POINTS'}',
                  style: const TextStyle(
                    color: _ProgressDashboardState._cyan,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) => Semantics(
              label:
                  '$exercise ${metric.label} chart for ${window.spokenLabel}. Drag across the chart to inspect a set.',
              value: semanticValue,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (details) => onScrub(
                  details.localPosition,
                  constraints.maxWidth,
                  points.length,
                ),
                onHorizontalDragStart: (details) => onScrub(
                  details.localPosition,
                  constraints.maxWidth,
                  points.length,
                ),
                onHorizontalDragUpdate: (details) => onScrub(
                  details.localPosition,
                  constraints.maxWidth,
                  points.length,
                ),
                child: AnimatedBuilder(
                  animation: reveal,
                  builder: (context, _) => CustomPaint(
                    painter: _NeonProgressPainter(
                      points: points,
                      metric: metric,
                      unit: unit,
                      progress: reveal.value,
                      selectedIndex: selectedIndex,
                    ),
                    child: const SizedBox(height: 270, width: double.infinity),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(
                Icons.swipe_rounded,
                color: _ProgressDashboardState._muted,
                size: 16,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  selectedPoint == null
                      ? 'Drag across the signal to inspect a set'
                      : '${_shortDate(selectedPoint!.log.date)}  •  '
                            '${_formatWeight(selectedPoint!.log.weight)} $unit × ${selectedPoint!.log.reps}  •  '
                            '${selectedPoint!.log.workout}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _ProgressDashboardState._muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NeonProgressPainter extends CustomPainter {
  const _NeonProgressPainter({
    required this.points,
    required this.metric,
    required this.unit,
    required this.progress,
    required this.selectedIndex,
  });

  final List<_ChartPoint> points;
  final _ProgressMetric metric;
  final String unit;
  final double progress;
  final int? selectedIndex;

  static const _left = 54.0;
  static const _right = 18.0;
  static const _top = 28.0;
  static const _bottom = 38.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final chartRight = size.width - _right > _left + 1
        ? size.width - _right
        : _left + 1;
    final chartBottom = size.height - _bottom > _top + 1
        ? size.height - _bottom
        : _top + 1;
    final chart = Rect.fromLTRB(_left, _top, chartRight, chartBottom);
    final values = points.map((point) => point.value).toList();
    final rawMin = values.reduce((a, b) => a < b ? a : b);
    final rawMax = values.reduce((a, b) => a > b ? a : b);
    final rawSpan = rawMax - rawMin;
    final flatPadding = rawMax.abs() * .08;
    final padding = rawSpan == 0
        ? (flatPadding > 1.0 ? flatPadding : 1.0)
        : rawSpan * .10;
    final paddedMinimum = rawMin - padding;
    final minimum = paddedMinimum > 0.0 ? paddedMinimum : 0.0;
    final maximum = rawMax + padding;
    final rawRange = maximum - minimum;
    final span = rawRange > 1.0 ? rawRange : 1.0;

    Offset location(int index) {
      final x = points.length == 1
          ? chart.center.dx
          : chart.left + chart.width * index / (points.length - 1);
      final normalized = (points[index].value - minimum) / span;
      return Offset(x, chart.bottom - chart.height * normalized);
    }

    _paintGrid(canvas, chart, minimum, maximum);

    final linePath = Path();
    for (var i = 0; i < points.length; i++) {
      final offset = location(i);
      if (i == 0) {
        linePath.moveTo(offset.dx, offset.dy);
      } else {
        linePath.lineTo(offset.dx, offset.dy);
      }
    }
    if (points.length == 1) {
      final point = location(0);
      linePath
        ..moveTo(chart.left, point.dy)
        ..lineTo(chart.right, point.dy);
    }

    final fillPath = Path.from(linePath)
      ..lineTo(chart.right, chart.bottom)
      ..lineTo(chart.left, chart.bottom)
      ..close();

    canvas.save();
    canvas.clipRect(
      Rect.fromLTRB(
        chart.left - 16,
        chart.top - 20,
        chart.left + (chart.width + 32) * progress,
        chart.bottom + 20,
      ),
    );

    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            _ProgressDashboardState._cyan.withValues(alpha: .28),
            _ProgressDashboardState._violet.withValues(alpha: .07),
            Colors.transparent,
          ],
        ).createShader(chart),
    );

    final shader = const LinearGradient(
      colors: [_ProgressDashboardState._violet, _ProgressDashboardState._cyan],
    ).createShader(chart);
    canvas.drawPath(
      linePath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = _ProgressDashboardState._cyan.withValues(alpha: .055)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );
    canvas.drawPath(
      linePath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..shader = shader
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawPath(
      linePath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.3
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..shader = shader,
    );

    if (points.length <= 36) {
      for (var i = 0; i < points.length; i++) {
        final point = location(i);
        canvas.drawCircle(point, 3.2, Paint()..color = const Color(0xFFCAFDF8));
      }
    }
    canvas.restore();

    final activeIndex = (selectedIndex ?? points.length - 1)
        .clamp(0, points.length - 1)
        .toInt();
    if (progress > .94) {
      _paintSelection(canvas, size, chart, location(activeIndex), activeIndex);
    }
  }

  void _paintGrid(Canvas canvas, Rect chart, double minimum, double maximum) {
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: .075)
      ..strokeWidth = 1;
    final dashPaint = Paint()
      ..color = _ProgressDashboardState._cyan.withValues(alpha: .035)
      ..strokeWidth = 1;

    for (var i = 0; i <= 4; i++) {
      final y = chart.top + chart.height * i / 4;
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), gridPaint);
      final value = maximum - (maximum - minimum) * i / 4;
      if (i.isEven) {
        _paintText(
          canvas,
          _compactNumber(value),
          Offset(0, y - 7),
          width: _left - 8,
          align: TextAlign.right,
          color: _ProgressDashboardState._muted,
          fontSize: 9,
        );
      }
    }
    for (var i = 0; i <= 4; i++) {
      final x = chart.left + chart.width * i / 4;
      canvas.drawLine(Offset(x, chart.top), Offset(x, chart.bottom), dashPaint);
    }

    _paintText(
      canvas,
      _shortDate(points.first.log.date).toUpperCase(),
      Offset(chart.left, chart.bottom + 11),
      width: chart.width / 2,
      color: _ProgressDashboardState._muted,
      fontSize: 9,
    );
    _paintText(
      canvas,
      _shortDate(points.last.log.date).toUpperCase(),
      Offset(chart.center.dx, chart.bottom + 11),
      width: chart.width / 2,
      align: TextAlign.right,
      color: _ProgressDashboardState._muted,
      fontSize: 9,
    );
  }

  void _paintSelection(
    Canvas canvas,
    Size size,
    Rect chart,
    Offset point,
    int index,
  ) {
    canvas.drawLine(
      Offset(point.dx, chart.top),
      Offset(point.dx, chart.bottom),
      Paint()
        ..color = Colors.white.withValues(alpha: .22)
        ..strokeWidth = 1,
    );
    canvas.drawCircle(
      point,
      12,
      Paint()
        ..color = _ProgressDashboardState._cyan.withValues(alpha: .22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
    );
    canvas.drawCircle(
      point,
      6.5,
      Paint()..color = _ProgressDashboardState._surface,
    );
    canvas.drawCircle(
      point,
      4.2,
      Paint()..color = _ProgressDashboardState._cyan,
    );

    final item = points[index];
    final value = '${_formatValue(item.value)} ${metric.unit(unit)}';
    final detail =
        '${_shortDate(item.log.date)}  •  '
        '${_formatWeight(item.log.weight)} $unit × ${item.log.reps}';
    const tooltipWidth = 154.0;
    const tooltipHeight = 52.0;
    final maximumLeft = size.width - tooltipWidth - 4 > chart.left
        ? size.width - tooltipWidth - 4
        : chart.left;
    final left = (point.dx - tooltipWidth / 2)
        .clamp(chart.left, maximumLeft)
        .toDouble();
    final preferAbove = point.dy - tooltipHeight - 14 >= chart.top;
    final top = preferAbove ? point.dy - tooltipHeight - 12 : point.dy + 12;
    final box = RRect.fromRectAndRadius(
      Rect.fromLTWH(left, top, tooltipWidth, tooltipHeight),
      const Radius.circular(11),
    );
    canvas.drawRRect(
      box,
      Paint()
        ..color = const Color(0xFF1B2632)
        ..style = PaintingStyle.fill,
    );
    canvas.drawRRect(
      box,
      Paint()
        ..color = _ProgressDashboardState._cyan.withValues(alpha: .42)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    _paintText(
      canvas,
      value,
      Offset(left + 10, top + 8),
      width: tooltipWidth - 20,
      color: Colors.white,
      fontSize: 13,
      fontWeight: FontWeight.w900,
    );
    _paintText(
      canvas,
      detail,
      Offset(left + 10, top + 29),
      width: tooltipWidth - 20,
      color: _ProgressDashboardState._muted,
      fontSize: 9,
      fontWeight: FontWeight.w700,
    );
  }

  void _paintText(
    Canvas canvas,
    String text,
    Offset offset, {
    required double width,
    required Color color,
    required double fontSize,
    TextAlign align = TextAlign.left,
    FontWeight fontWeight = FontWeight.w700,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: fontWeight,
        ),
      ),
      textAlign: align,
      maxLines: 1,
      ellipsis: '…',
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: width);
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _NeonProgressPainter oldDelegate) =>
      oldDelegate.points != points ||
      oldDelegate.metric != metric ||
      oldDelegate.unit != unit ||
      oldDelegate.progress != progress ||
      oldDelegate.selectedIndex != selectedIndex;
}

class _RecentSetsCard extends StatelessWidget {
  const _RecentSetsCard({
    required this.logs,
    required this.unit,
    required this.onEdit,
  });

  final List<SetLog> logs;
  final String unit;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) => _DataCard(
    eyebrow: 'LATEST OUTPUT',
    title: 'Recent sets',
    icon: Icons.history_rounded,
    emptyMessage: 'No sets recorded for this exercise.',
    children: [
      for (final log in logs)
        _DataRow(
          leading: '${log.reps}',
          title: '${_formatWeight(log.weight)} $unit × ${log.reps}',
          subtitle: '${_shortDate(log.date)}  •  ${log.workout}',
          trailing: '${log.e1rm.round()}\nE1RM',
        ),
      Align(
        alignment: Alignment.centerRight,
        child: TextButton.icon(
          onPressed: onEdit,
          icon: const Icon(Icons.edit_note_rounded),
          label: const Text('VIEW & EDIT ALL SETS'),
        ),
      ),
    ],
  );
}

class _PrRecordsCard extends StatelessWidget {
  const _PrRecordsCard({required this.records, required this.unit});

  final List<_PrRecord> records;
  final String unit;

  @override
  Widget build(BuildContext context) => _DataCard(
    eyebrow: 'MILESTONES',
    title: 'PR records',
    icon: Icons.emoji_events_rounded,
    emptyMessage: 'No PR records for this exercise yet.',
    children: [
      for (final record in records)
        _DataRow(
          leadingIcon: Icons.bolt_rounded,
          title:
              '${_formatWeight(record.log.weight)} $unit × ${record.log.reps}',
          subtitle: '${record.label}  •  ${_shortDate(record.log.date)}',
          trailing: '${record.log.e1rm.round()}\nE1RM',
          accent: true,
        ),
    ],
  );
}

class _DataCard extends StatelessWidget {
  const _DataCard({
    required this.eyebrow,
    required this.title,
    required this.icon,
    required this.emptyMessage,
    required this.children,
  });

  final String eyebrow;
  final String title;
  final IconData icon;
  final String emptyMessage;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: _panelDecoration(radius: 22),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: _ProgressDashboardState._cyan.withValues(alpha: .09),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: _ProgressDashboardState._cyan, size: 20),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    eyebrow,
                    style: const TextStyle(
                      color: _ProgressDashboardState._muted,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 13),
        if (children.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Text(
              emptyMessage,
              style: const TextStyle(
                color: _ProgressDashboardState._muted,
                fontSize: 13,
              ),
            ),
          )
        else
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              Divider(height: 1, color: Colors.white.withValues(alpha: .065)),
            children[i],
          ],
      ],
    ),
  );
}

class _DataRow extends StatelessWidget {
  const _DataRow({
    this.leading,
    this.leadingIcon,
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.accent = false,
  });

  final String? leading;
  final IconData? leadingIcon;
  final String title;
  final String subtitle;
  final String trailing;
  final bool accent;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 11),
    child: Row(
      children: [
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: accent
                ? _ProgressDashboardState._violet.withValues(alpha: .15)
                : Colors.white.withValues(alpha: .05),
            borderRadius: BorderRadius.circular(10),
          ),
          child: leadingIcon != null
              ? Icon(
                  leadingIcon,
                  size: 17,
                  color: _ProgressDashboardState._violet,
                )
              : Text(
                  leading ?? '',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _ProgressDashboardState._muted,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          trailing,
          textAlign: TextAlign.right,
          style: TextStyle(
            color: accent ? _ProgressDashboardState._cyan : Colors.white70,
            fontSize: 9,
            height: 1.25,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    ),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 38),
    decoration: _panelDecoration(radius: 24),
    child: Column(
      children: [
        Container(
          width: 62,
          height: 62,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                _ProgressDashboardState._cyan.withValues(alpha: .18),
                _ProgressDashboardState._violet.withValues(alpha: .14),
              ],
            ),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: _ProgressDashboardState._cyan, size: 28),
        ),
        const SizedBox(height: 18),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _ProgressDashboardState._muted,
              fontSize: 13,
              height: 1.45,
            ),
          ),
        ),
        if (actionLabel != null && onAction != null) ...[
          const SizedBox(height: 20),
          FilledButton.tonal(
            onPressed: onAction,
            style: FilledButton.styleFrom(
              foregroundColor: Colors.black,
              backgroundColor: _ProgressDashboardState._cyan,
            ),
            child: Text(
              actionLabel!,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ],
    ),
  );
}

enum _ProgressMetric {
  estimatedOneRepMax,
  workingWeight,
  setVolume;

  String get label => switch (this) {
    estimatedOneRepMax => 'Estimated 1RM',
    workingWeight => 'Working weight',
    setVolume => 'Set volume',
  };

  String get shortLabel => switch (this) {
    estimatedOneRepMax => 'E1RM',
    workingWeight => 'Weight',
    setVolume => 'Volume',
  };

  IconData get icon => switch (this) {
    estimatedOneRepMax => Icons.speed_rounded,
    workingWeight => Icons.fitness_center_rounded,
    setVolume => Icons.stacked_line_chart_rounded,
  };

  double valueOf(SetLog log) => switch (this) {
    estimatedOneRepMax => log.e1rm,
    workingWeight => log.weight,
    setVolume => log.weight * log.reps,
  };

  String unit(String weightUnit) => switch (this) {
    estimatedOneRepMax || workingWeight => weightUnit,
    setVolume => '$weightUnit·reps',
  };
}

enum _TimeWindow {
  days30,
  days90,
  year,
  all;

  String get label => switch (this) {
    days30 => '30D',
    days90 => '90D',
    year => '1Y',
    all => 'ALL',
  };

  String get spokenLabel => switch (this) {
    days30 => 'the last 30 days',
    days90 => 'the last 90 days',
    year => 'the last year',
    all => 'all recorded time',
  };

  DateTime? get cutoff {
    final now = DateTime.now();
    return switch (this) {
      days30 => now.subtract(const Duration(days: 30)),
      days90 => now.subtract(const Duration(days: 90)),
      year => now.subtract(const Duration(days: 365)),
      all => null,
    };
  }
}

class _ChartPoint {
  const _ChartPoint(this.log, this.value);
  final SetLog log;
  final double value;
}

class _PrRecord {
  const _PrRecord(this.log, this.label);
  final SetLog log;
  final String label;
}

List<_PrRecord> _prRecords(List<SetLog> chronologicalLogs) {
  var bestWeight = -double.infinity;
  var bestE1rm = -double.infinity;
  final records = <_PrRecord>[];
  for (final log in chronologicalLogs) {
    final weightRecord = log.weight > bestWeight;
    final strengthRecord = log.e1rm > bestE1rm;
    if (weightRecord || strengthRecord) {
      final label = weightRecord && strengthRecord
          ? 'WEIGHT + E1RM PR'
          : weightRecord
          ? 'WEIGHT PR'
          : 'E1RM PR';
      records.add(_PrRecord(log, label));
    }
    if (log.weight > bestWeight) bestWeight = log.weight;
    if (log.e1rm > bestE1rm) bestE1rm = log.e1rm;
  }
  return records;
}

BoxDecoration _panelDecoration({double radius = 20}) => BoxDecoration(
  gradient: const LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      _ProgressDashboardState._surfaceHigh,
      _ProgressDashboardState._surface,
    ],
  ),
  borderRadius: BorderRadius.circular(radius),
  border: Border.all(color: Colors.white.withValues(alpha: .075)),
);

String _formatValue(double value) {
  if (value.abs() >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
  if (value.abs() >= 10000) return '${(value / 1000).toStringAsFixed(1)}K';
  return _formatWeight(value);
}

String _compactNumber(double value) {
  if (value.abs() >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
  if (value.abs() >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
  return _formatWeight(value);
}

String _formatWeight(double value) => value == value.roundToDouble()
    ? value.round().toString()
    : value.toStringAsFixed(1);

String _shortDate(DateTime value) => '${_months[value.month - 1]} ${value.day}';

String _longDate(DateTime value) =>
    '${_months[value.month - 1]} ${value.day}, ${value.year}';

const _months = [
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
