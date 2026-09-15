import 'package:flutter/material.dart';

import 'brand.dart';
import 'strength_history_backfill.dart';

class StrengthHistoryReviewScreen extends StatefulWidget {
  const StrengthHistoryReviewScreen({
    super.key,
    required this.preview,
    this.initialAssignments,
  });

  final StrengthHistoryPreview preview;
  final Map<String, String>? initialAssignments;

  @override
  State<StrengthHistoryReviewScreen> createState() =>
      _StrengthHistoryReviewState();
}

class _StrengthHistoryReviewState extends State<StrengthHistoryReviewScreen> {
  late Map<String, String> assignments = widget.initialAssignments == null
      ? widget.preview.suggest()
      : Map.of(widget.initialAssignments!);

  Future<void> choose(StrengthHistorySlot slot) async {
    final used = assignments.entries
        .where((entry) => entry.key != slot.id)
        .map((entry) => entry.value)
        .toSet();
    final candidates = widget.preview.sessions
        .where(
          (session) =>
              !used.contains(session.id) && slot.matchedExercises(session) > 0,
        )
        .toList();
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: .75,
        minChildSize: .4,
        maxChildSize: .95,
        builder: (context, controller) => SafeArea(
          child: ListView(
            controller: controller,
            padding: const EdgeInsets.all(20),
            children: [
              Text(slot.label, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.remove_circle_outline),
                title: const Text('Leave this workout unfilled'),
                onTap: () => Navigator.pop(context, ''),
              ),
              if (candidates.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'No unused imported session has a matching exercise. Check exercise names in your import.',
                  ),
                ),
              for (final session in candidates.reversed)
                ListTile(
                  selected: assignments[slot.id] == session.id,
                  title: Text('${_date(session.date)} · ${session.name}'),
                  subtitle: Text(
                    '${session.source} · ${slot.matchedExercises(session)}/${slot.workout.exercises.length} exercises\n${session.workingSets.values.fold<int>(0, (sum, count) => sum + count)} working sets',
                  ),
                  isThreeLine: true,
                  onTap: () => Navigator.pop(context, session.id),
                ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || selected == null) return;
    setState(() {
      if (selected.isEmpty) {
        assignments.remove(slot.id);
      } else {
        assignments[slot.id] = selected;
      }
    });
  }

  void confirm() {
    try {
      widget.preview.validate(assignments);
      Navigator.pop(
        context,
        StrengthHistorySelection(widget.preview, assignments),
      );
    } on StateError catch (error) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${error.message}')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final sources = {
      for (final session in widget.preview.sessions) session.id: session,
    };
    final empty = widget.preview.slots
        .where((slot) => !slot.blocked && !assignments.containsKey(slot.id))
        .length;
    return Scaffold(
      appBar: AppBar(title: const Text('Review earlier workouts')),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        itemCount: widget.preview.slots.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${assignments.length} matched · $empty unfilled',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 10),
                const Text(
                  'Suggestions use matching exercises and dates within 3 days of your schedule. Tap a workout to change its match. Keep sessions in date order. Missing workouts stay unfilled.',
                ),
                const SizedBox(height: 10),
                const Text(
                  'Original dates, weights, reps, and notes are kept. Fewer working sets than planned are marked partial. Matches do not prove that the original workout followed the prescribed loads or rep targets.',
                  style: TextStyle(color: BrandColors.muted),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  children: [
                    TextButton(
                      onPressed: () => setState(
                        () => assignments = widget.preview.suggest(),
                      ),
                      child: const Text('Reset suggestions'),
                    ),
                    TextButton(
                      onPressed: () => setState(() => assignments.clear()),
                      child: const Text('Clear matches'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
            );
          }
          final slot = widget.preview.slots[index - 1];
          final source = sources[assignments[slot.id]];
          return Card(
            child: ListTile(
              key: ValueKey('history-slot-${slot.id}'),
              enabled: !slot.blocked,
              leading: Icon(
                slot.blocked
                    ? Icons.lock_outline
                    : source == null
                    ? Icons.radio_button_unchecked
                    : Icons.link,
              ),
              title: Text(slot.label),
              subtitle: Text(
                slot.blocked
                    ? 'Existing workout or draft kept'
                    : source == null
                    ? '${_date(slot.date)} · Unfilled'
                    : '${_date(source.date)} · ${source.name} (${source.source})\n${slot.matchedExercises(source)}/${slot.workout.exercises.length} exercises · ${slot.hasAllWorkingSets(source) ? 'Working sets covered' : 'Partial'}',
              ),
              isThreeLine: source != null,
              trailing: slot.blocked ? null : const Icon(Icons.edit_outlined),
              onTap: slot.blocked ? null : () => choose(slot),
            ),
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: FilledButton.icon(
          key: const ValueKey('confirm-history-matches'),
          onPressed: confirm,
          icon: const Icon(Icons.check),
          label: Text('USE ${assignments.length} MATCHES'),
        ),
      ),
    );
  }
}

String _date(DateTime value) {
  final local = value.toLocal();
  return '${local.month}/${local.day}/${local.year}';
}
