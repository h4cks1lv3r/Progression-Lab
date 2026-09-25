import 'package:flutter/material.dart';

import 'brand.dart';
import 'program.dart';
import 'store.dart';

/// Shows recorded progress without treating a selected day as a completed day.
String strengthWorkoutDayStatus(
  AppStore store,
  int weekNumber,
  int workoutIndex,
) {
  final records = store.recordsForSlot(weekNumber, workoutIndex);
  if (records.any((record) => record.status == WorkoutStatus.completed)) {
    return 'Completed';
  }
  if (records.isNotEmpty) {
    return records.first.status == WorkoutStatus.partial
        ? 'Partial'
        : 'Skipped';
  }
  if (store.draftFor(
        weekNumber: weekNumber,
        targetWorkoutIndex: workoutIndex,
        cadence: store.days,
        retroactive: false,
      ) !=
      null) {
    return 'In progress';
  }
  if (weekNumber == store.week &&
      store.pendingStrengthWorkoutIndices.contains(workoutIndex)) {
    return 'Ready';
  }
  return weekNumber > store.week ? 'Planned' : 'Not logged';
}

/// Returns a choice only. The caller saves the active session before selecting
/// the returned workout, so a live workout can pause without losing its inputs.
Future<int?> showStrengthWorkoutPicker(
  BuildContext context,
  AppStore store,
) => showModalBottomSheet<int>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  backgroundColor: BrandColors.panel,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
  ),
  clipBehavior: Clip.antiAlias,
  builder: (sheetContext) => FractionallySizedBox(
    heightFactor: .92,
    child: AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final week = ProgramEngine.week(store.week, store.days);
        return ListView(
          key: const ValueKey('strength-workout-picker-scroll'),
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            24 + MediaQuery.paddingOf(context).bottom,
          ),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Expanded(
                  child: Text(
                    'Switch workout',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Phase ${week.phase} · Microcycle ${week.microcycle} · Week ${week.number}',
              style: const TextStyle(
                color: BrandColors.cyan,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Equipment busy? Choose another workout in this cycle. Your current session stays saved so you can come back to it.',
              style: TextStyle(color: Colors.white70, height: 1.4),
            ),
            const SizedBox(height: 12),
            Text(
              '${store.strengthCompletedWorkouts(week.number)} of ${week.workouts.length} workouts completed',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 20),
            for (final entry in week.workouts.asMap().entries)
              _WorkoutChoice(
                index: entry.key,
                workout: entry.value,
                status: strengthWorkoutDayStatus(store, week.number, entry.key),
                selected: store.workoutIndex == entry.key,
                enabled:
                    store.workoutIndex != entry.key &&
                    !store.isStrengthWorkoutResolved(week.number, entry.key),
                onSelected: () => Navigator.of(sheetContext).pop(entry.key),
              ),
          ],
        );
      },
    ),
  ),
);

class _WorkoutChoice extends StatelessWidget {
  const _WorkoutChoice({
    required this.index,
    required this.workout,
    required this.status,
    required this.selected,
    required this.enabled,
    required this.onSelected,
  });

  final int index;
  final WorkoutPlan workout;
  final String status;
  final bool selected;
  final bool enabled;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final icon = switch (status) {
      'Completed' => Icons.check_circle_rounded,
      'Partial' => Icons.incomplete_circle_rounded,
      'Skipped' => Icons.skip_next_rounded,
      'In progress' => Icons.pause_circle_outline_rounded,
      _ => Icons.radio_button_unchecked_rounded,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Semantics(
        selected: selected,
        button: true,
        enabled: enabled,
        child: Material(
          color: selected
              ? BrandColors.cyan.withValues(alpha: .09)
              : BrandColors.panelHigh,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(
              color: selected
                  ? BrandColors.cyan.withValues(alpha: .5)
                  : Colors.white12,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: ValueKey('strength-workout-choice-$index'),
            onTap: enabled ? onSelected : null,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    icon,
                    color: status == 'Completed' || selected
                        ? BrandColors.cyan
                        : Colors.white54,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Day ${index + 1} · ${workout.name}',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          selected ? '$status · Selected' : status,
                          style: const TextStyle(color: Colors.white70),
                        ),
                        if (status == 'Not logged') ...[
                          const SizedBox(height: 5),
                          const Text(
                            'Choose this day to add it to your remaining workouts.',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (enabled) ...[
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.white54,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
