import 'package:flutter/material.dart';

import 'store.dart';

typedef SetLogPredicate = bool Function(SetLog log);

class LoggedSetsScreen extends StatelessWidget {
  const LoggedSetsScreen({
    super.key,
    required this.store,
    required this.exercise,
    this.workout,
  });

  final AppStore store;
  final String exercise;
  final String? workout;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Logged sets')),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        Text(
          exercise,
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
        ),
        if (workout != null) ...[
          const SizedBox(height: 4),
          Text(workout!, style: const TextStyle(color: Colors.white60)),
        ],
        const SizedBox(height: 18),
        LoggedSetsEditor(
          store: store,
          predicate: (log) =>
              log.exercise == exercise &&
              (workout == null || log.workout == workout),
          emptyMessage: 'No sets have been logged here yet.',
        ),
      ],
    ),
  );
}

class LoggedWorkoutScreen extends StatelessWidget {
  const LoggedWorkoutScreen({
    super.key,
    required this.store,
    required this.record,
  });

  final AppStore store;
  final WorkoutRecord record;

  @override
  Widget build(BuildContext context) {
    final logs = store.logs.where(_matches).toList();
    final exercises = logs.map((log) => log.exercise).toSet().toList();
    final state = record.retroactive
        ? 'RETROACTIVELY FILLED'
        : record.status == WorkoutStatus.skipped
        ? 'SKIPPED'
        : 'COMPLETED';
    return Scaffold(
      appBar: AppBar(title: const Text('Logged workout')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text(
            record.workout,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 5),
          Text(
            'WEEK ${record.week} • $state • ${_date(record.scheduledDate)}',
            style: const TextStyle(color: Colors.white60),
          ),
          Text(
            'Logged ${_dateTime(record.loggedAt)}',
            style: const TextStyle(color: Colors.white38, fontSize: 12),
          ),
          if (record.substitutions.isNotEmpty) ...[
            const SizedBox(height: 14),
            for (final replacement in record.substitutions.values)
              Text(
                'Substitution: $replacement',
                style: const TextStyle(color: Colors.white60),
              ),
          ],
          const SizedBox(height: 20),
          if (exercises.isEmpty)
            Text(
              record.status == WorkoutStatus.skipped
                  ? 'This workout was skipped; no sets were logged.'
                  : 'No sets were logged for this session.',
              style: const TextStyle(color: Colors.white54),
            ),
          for (final exercise in exercises) ...[
            Text(
              exercise.toUpperCase(),
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                letterSpacing: .8,
              ),
            ),
            const SizedBox(height: 8),
            LoggedSetsEditor(
              store: store,
              predicate: (log) => _matches(log) && log.exercise == exercise,
              emptyMessage: 'No sets logged.',
            ),
            const SizedBox(height: 20),
          ],
        ],
      ),
    );
  }

  bool _matches(SetLog log) {
    if (record.sessionId != null) return log.sessionId == record.sessionId;
    return log.workout == record.workout &&
        log.date.year == record.loggedAt.year &&
        log.date.month == record.loggedAt.month &&
        log.date.day == record.loggedAt.day;
  }
}

/// Shared explicit-save editor used by history and the active workout.
class LoggedSetsEditor extends StatefulWidget {
  const LoggedSetsEditor({
    super.key,
    required this.store,
    required this.predicate,
    required this.emptyMessage,
    this.compact = false,
  });

  final AppStore store;
  final SetLogPredicate predicate;
  final String emptyMessage;
  final bool compact;

  @override
  State<LoggedSetsEditor> createState() => _LoggedSetsEditorState();
}

class _LoggedSetsEditorState extends State<LoggedSetsEditor> {
  @override
  void initState() {
    super.initState();
    widget.store.addListener(_refresh);
  }

  @override
  void didUpdateWidget(covariant LoggedSetsEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.store != widget.store) {
      oldWidget.store.removeListener(_refresh);
      widget.store.addListener(_refresh);
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
    final logs = widget.store.logs.where(widget.predicate).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    if (logs.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text(
          widget.emptyMessage,
          style: const TextStyle(color: Colors.white54),
        ),
      );
    }
    return Column(
      children: [
        for (final log in logs) ...[
          _EditableSetCard(
            key: ValueKey(
              '${log.date.microsecondsSinceEpoch}|${log.sessionId}|'
              '${log.exercise}|${log.workout}',
            ),
            store: widget.store,
            log: log,
            compact: widget.compact,
          ),
          if (log != logs.last) const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _EditableSetCard extends StatefulWidget {
  const _EditableSetCard({
    super.key,
    required this.store,
    required this.log,
    required this.compact,
  });

  final AppStore store;
  final SetLog log;
  final bool compact;

  @override
  State<_EditableSetCard> createState() => _EditableSetCardState();
}

class _EditableSetCardState extends State<_EditableSetCard> {
  late final TextEditingController _weight;
  late final TextEditingController _reps;
  late final TextEditingController _notes;
  String? _error;
  bool _saving = false;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _weight = TextEditingController(text: _formatWeight(widget.log.weight));
    _reps = TextEditingController(text: '${widget.log.reps}');
    _notes = TextEditingController(text: widget.log.notes);
    for (final controller in [_weight, _reps, _notes]) {
      controller.addListener(_markChanged);
    }
  }

  void _markChanged() {
    if (_saved && mounted) setState(() => _saved = false);
  }

  @override
  void dispose() {
    _weight.dispose();
    _reps.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final weight = double.tryParse(_weight.text.trim());
    final reps = int.tryParse(_reps.text.trim());
    if (weight == null || reps == null || weight <= 0 || reps <= 0) {
      setState(() => _error = 'Enter weight and reps above zero.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.store.updateSet(
        widget.log,
        weight: weight,
        reps: reps,
        notes: _notes.text,
      );
      if (mounted) setState(() => _saved = true);
    } on Object {
      if (mounted) {
        setState(() => _error = 'Could not save this set. Try again.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.all(widget.compact ? 12 : 16),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .045),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.white.withValues(alpha: .08)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${_date(widget.log.date)}  •  ${widget.log.workout}',
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _weight,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'WEIGHT (${widget.store.unit})',
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _reps,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'REPS'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _notes,
          minLines: 1,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'NOTES',
            hintText: 'Optional set notes',
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: const TextStyle(color: Colors.redAccent)),
        ],
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: Icon(_saved ? Icons.check_rounded : Icons.save_rounded),
            label: Text(
              _saving
                  ? 'SAVING'
                  : _saved
                  ? 'SAVED'
                  : 'SAVE SET',
            ),
          ),
        ),
      ],
    ),
  );
}

String _formatWeight(double value) => value == value.roundToDouble()
    ? value.round().toString()
    : value.toStringAsFixed(1);

String _date(DateTime value) =>
    '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

String _dateTime(DateTime value) =>
    '${_date(value)} ${value.hour.toString().padLeft(2, '0')}:'
    '${value.minute.toString().padLeft(2, '0')}';
