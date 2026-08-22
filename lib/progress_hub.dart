import 'package:flutter/material.dart';

import 'athletic_history.dart';
import 'athletic_program.dart';
import 'brand.dart';
import 'progress_dashboard.dart';
import 'store.dart';

enum _ProgressView { strength, functional }

class ProgressHub extends StatefulWidget {
  const ProgressHub({super.key, required this.store});

  final AppStore store;

  @override
  State<ProgressHub> createState() => _ProgressHubState();
}

class _ProgressHubState extends State<ProgressHub> {
  late _ProgressView view;

  @override
  void initState() {
    super.initState();
    view = widget.store.preferredTrack == TrainingTrack.athletic
        ? _ProgressView.functional
        : _ProgressView.strength;
  }

  @override
  Widget build(BuildContext context) => Material(
    color: BrandColors.ink,
    child: SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<_ProgressView>(
                key: const ValueKey('progress-track-selector'),
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: _ProgressView.strength,
                    icon: Icon(Icons.fitness_center_rounded, size: 18),
                    label: Text('STRENGTH'),
                  ),
                  ButtonSegment(
                    value: _ProgressView.functional,
                    icon: Icon(Icons.directions_run_rounded, size: 18),
                    label: Text('FUNCTIONAL'),
                  ),
                ],
                selected: {view},
                onSelectionChanged: (value) =>
                    setState(() => view = value.first),
              ),
            ),
          ),
          Expanded(
            child: IndexedStack(
              index: view.index,
              children: [
                ProgressDashboard(store: widget.store),
                AthleticProgressDashboard(store: widget.store),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class AthleticProgressDashboard extends StatefulWidget {
  const AthleticProgressDashboard({super.key, required this.store});

  final AppStore store;

  @override
  State<AthleticProgressDashboard> createState() =>
      _AthleticProgressDashboardState();
}

class _AthleticProgressDashboardState extends State<AthleticProgressDashboard> {
  String? selectedDrill;

  @override
  void initState() {
    super.initState();
    widget.store.addListener(_refresh);
  }

  @override
  void didUpdateWidget(covariant AthleticProgressDashboard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.store != widget.store) {
      oldWidget.store.removeListener(_refresh);
      widget.store.addListener(_refresh);
      selectedDrill = null;
    }
  }

  @override
  void dispose() {
    widget.store.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final catalog = _catalog();
    final names = catalog.keys.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    if (names.isEmpty) {
      return const Center(child: Text('Functional drill catalog unavailable.'));
    }
    final active = _activeName(catalog, names);
    final planned = catalog[active]!;
    final completed = _completed(active)
      ..sort((a, b) => b.record.completedAt.compareTo(a.record.completedAt));
    final currentRun = completed
        .where(
          (item) => item.record.programRun == widget.store.athleticProgramRun,
        )
        .length;
    final averageEffort = completed.isEmpty
        ? null
        : completed.fold<int>(0, (sum, item) => sum + item.record.effort) /
              completed.length;
    final reference = planned.firstWhere(
      (item) => item.week.number >= widget.store.athleticWeek,
      orElse: () => planned.last,
    );

    return ListView(
      key: const PageStorageKey('functional-progress-dashboard'),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 36),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'FUNCTIONAL PROGRESS',
                    style: TextStyle(
                      color: BrandColors.cyan,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Movement signal',
                    style: TextStyle(
                      fontSize: 32,
                      height: 1.05,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    '${names.length} programmed drills • ${widget.store.athleticHistory.length} completed sessions',
                    style: const TextStyle(color: BrandColors.muted),
                  ),
                ],
              ),
            ),
            const LabMark(size: 50),
          ],
        ),
        const SizedBox(height: 18),
        LabPanel(
          accent: BrandColors.cyan,
          child: const Text(
            'The drill list comes from the complete 12-week functional program. Finishing a session records every drill because the app requires every drill to be checked before completion.',
            style: TextStyle(color: BrandColors.muted, height: 1.45),
          ),
        ),
        const SizedBox(height: 16),
        LabPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const BrandSectionLabel('Drill'),
              const SizedBox(height: 9),
              DropdownButtonFormField<String>(
                key: const ValueKey('functional-drill-dropdown'),
                initialValue: active,
                isExpanded: true,
                dropdownColor: BrandColors.panelHigh,
                items: [
                  for (final name in names)
                    DropdownMenuItem(
                      value: name,
                      child: Text(name, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => selectedDrill = value);
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _Metric(
              label: 'COMPLETIONS',
              value: '${completed.length}',
              keyName: 'functional-completions-value',
            ),
            _Metric(
              label: 'CURRENT RUN',
              value: '$currentRun',
              keyName: 'functional-current-run-value',
            ),
            _Metric(
              label: 'AVG EFFORT',
              value: averageEffort == null
                  ? '—'
                  : '${averageEffort.toStringAsFixed(1)} / 10',
              keyName: 'functional-average-effort-value',
            ),
            _Metric(
              label: 'LAST DONE',
              value: completed.isEmpty
                  ? '—'
                  : _date(completed.first.record.completedAt),
              keyName: 'functional-last-done-value',
            ),
          ],
        ),
        const SizedBox(height: 16),
        LabPanel(
          accent: BrandColors.violet,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                active.toUpperCase(),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                '${planned.length} programmed appearances',
                style: const TextStyle(color: BrandColors.cyan),
              ),
              const SizedBox(height: 12),
              Text(
                reference.drill.purpose,
                style: const TextStyle(color: BrandColors.muted, height: 1.4),
              ),
              const SizedBox(height: 12),
              _detail(
                'REFERENCE',
                'Week ${reference.week.number} • ${reference.session.day} • ${reference.session.name}',
              ),
              _detail('PRESCRIPTION', reference.drill.prescription),
              _detail('EQUIPMENT', reference.drill.equipment),
              _detail('REGRESSION', reference.drill.regression),
              _detail('PROGRESSION', reference.drill.progression),
            ],
          ),
        ),
        const SizedBox(height: 22),
        BrandSectionLabel(
          'Completed history',
          trailing: Text(
            '${completed.length} TOTAL',
            style: const TextStyle(color: BrandColors.cyan, fontSize: 10),
          ),
        ),
        const SizedBox(height: 10),
        if (completed.isEmpty)
          LabPanel(
            child: Text(
              '$active is programmed but has not been completed yet. Its first appearance is week ${planned.first.week.number}, ${planned.first.session.day}.',
              style: const TextStyle(color: BrandColors.muted, height: 1.4),
            ),
          )
        else
          for (final item in completed.take(10))
            Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: LabPanel(
                padding: const EdgeInsets.all(14),
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.check_circle_rounded,
                    color: BrandColors.success,
                  ),
                  title: Text(item.appearance.session.name),
                  subtitle: Text(
                    'Run ${item.record.programRun} • Week ${item.record.week} • ${_date(item.record.completedAt)}\n${item.appearance.drill.prescription}',
                  ),
                  trailing: Text(
                    '${item.record.effort}/10',
                    style: const TextStyle(
                      color: BrandColors.violet,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ),
        const SizedBox(height: 14),
        LabPanel(
          padding: EdgeInsets.zero,
          child: ExpansionTile(
            key: PageStorageKey('functional-program-appearances-$active'),
            title: const Text(
              'PROGRAM APPEARANCES',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            subtitle: Text('${planned.length} scheduled exposures'),
            children: [
              for (final item in planned)
                ListTile(
                  title: Text('Week ${item.week.number} • ${item.session.day}'),
                  subtitle: Text(
                    '${item.session.name}\n${item.drill.prescription}',
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Map<String, List<_Appearance>> _catalog() {
    final values = <String, List<_Appearance>>{};
    for (var number = 1; number <= AthleticProgram.totalWeeks; number++) {
      final week = AthleticProgram.week(number);
      for (final sessionEntry in week.sessions.asMap().entries) {
        for (final drill in sessionEntry.value.drills) {
          values
              .putIfAbsent(drill.name, () => [])
              .add(_Appearance(week, sessionEntry.value, drill));
        }
      }
    }
    return values;
  }

  String _activeName(
    Map<String, List<_Appearance>> catalog,
    List<String> names,
  ) {
    if (selectedDrill != null && catalog.containsKey(selectedDrill)) {
      return selectedDrill!;
    }
    if (widget.store.athleticHistory.isNotEmpty) {
      final latest = widget.store.athleticHistory.reduce(
        (a, b) => a.completedAt.isAfter(b.completedAt) ? a : b,
      );
      final session = _session(latest);
      if (session != null && session.drills.isNotEmpty) {
        return session.drills.first.name;
      }
    }
    return widget.store.currentAthleticSession.drills.isNotEmpty
        ? widget.store.currentAthleticSession.drills.first.name
        : names.first;
  }

  AthleticSession? _session(AthleticSessionRecord record) {
    if (record.week < 1 || record.week > AthleticProgram.totalWeeks) {
      return null;
    }
    final week = AthleticProgram.week(record.week);
    if (record.sessionIndex < 0 ||
        record.sessionIndex >= week.sessions.length) {
      return null;
    }
    return week.sessions[record.sessionIndex];
  }

  List<_Completion> _completed(String drillName) {
    final result = <_Completion>[];
    for (final record in widget.store.athleticHistory) {
      final session = _session(record);
      if (session == null) continue;
      final week = AthleticProgram.week(record.week);
      for (final drill in session.drills) {
        if (drill.name == drillName) {
          result.add(_Completion(record, _Appearance(week, session, drill)));
          break;
        }
      }
    }
    return result;
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.keyName,
  });

  final String label;
  final String value;
  final String keyName;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 160,
    child: LabPanel(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: BrandColors.muted)),
          const SizedBox(height: 6),
          Text(
            value,
            key: ValueKey(keyName),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    ),
  );
}

Widget _detail(String label, String value) => Padding(
  padding: const EdgeInsets.only(bottom: 10),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(
          color: BrandColors.violet,
          fontSize: 9,
          fontWeight: FontWeight.w900,
        ),
      ),
      const SizedBox(height: 3),
      Text(value),
    ],
  ),
);

class _Appearance {
  const _Appearance(this.week, this.session, this.drill);

  final AthleticWeek week;
  final AthleticSession session;
  final AthleticDrill drill;
}

class _Completion {
  const _Completion(this.record, this.appearance);

  final AthleticSessionRecord record;
  final _Appearance appearance;
}

const _month = [
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

String _date(DateTime value) => '${_month[value.month - 1]} ${value.day}';
