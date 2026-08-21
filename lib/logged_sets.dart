import 'package:flutter/material.dart';

import 'exercise_library.dart';
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
            'RUN ${record.programRun} • WEEK ${record.week} • $state • ${_date(record.scheduledDate)}',
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
  late final TextEditingController _duration;
  late final TextEditingController _distance;
  late final TextEditingController _calories;
  late final TextEditingController _notes;
  String? _error;
  bool _saving = false;
  bool _saved = false;

  ExerciseTrackingType get _type => widget.log.resolvedTrackingType;

  @override
  void initState() {
    super.initState();
    _weight = TextEditingController(
      text: _type.usesWeight ? _formatNumber(widget.log.weight) : '',
    );
    _reps = TextEditingController(
      text: _type.usesReps ? '${widget.log.reps}' : '',
    );
    _duration = TextEditingController(
      text: widget.log.durationSeconds == null
          ? ''
          : _formatDurationInput(widget.log.durationSeconds!),
    );
    _distance = TextEditingController(
      text: widget.log.distance == null
          ? ''
          : _formatNumber(widget.log.distance!),
    );
    _calories = TextEditingController(
      text: widget.log.calories == null
          ? ''
          : _formatNumber(widget.log.calories!),
    );
    _notes = TextEditingController(text: widget.log.notes);
    for (final controller in [
      _weight,
      _reps,
      _duration,
      _distance,
      _calories,
      _notes,
    ]) {
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
    _duration.dispose();
    _distance.dispose();
    _calories.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final type = _type;
    final weight = type.usesWeight
        ? double.tryParse(_weight.text.trim())
        : 0.0;
    final reps = type.usesReps ? int.tryParse(_reps.text.trim()) : 0;
    final duration = type.usesDuration
        ? _parseDuration(_duration.text)
        : null;
    final distance = type.usesDistance
        ? double.tryParse(_distance.text.trim())
        : null;
    final calories = type.usesCalories
        ? double.tryParse(_calories.text.trim())
        : null;

    final validation = _validate(
      type: type,
      weight: weight,
      reps: reps,
      duration: duration,
      distance: distance,
      calories: calories,
    );
    if (validation != null) {
      setState(() => _error = validation);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.store.updateSet(
        widget.log,
        weight: weight ?? 0,
        reps: reps ?? 0,
        durationSeconds: duration,
        distance: distance,
        distanceUnit: widget.log.distanceUnit,
        calories: calories,
        notes: _notes.text.trim(),
      );
      if (mounted) setState(() => _saved = true);
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _error = error
              .toString()
              .replaceFirst('Invalid argument(s): ', '')
              .replaceFirst('Exception: ', '');
        });
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _validate({
    required ExerciseTrackingType type,
    required double? weight,
    required int? reps,
    required int? duration,
    required double? distance,
    required double? calories,
  }) {
    if (type.usesWeight) {
      if (weight == null || !weight.isFinite) return 'Enter a valid value.';
      if (type.requiresPositiveWeight && weight <= 0) {
        return 'Enter a weight above zero.';
      }
      if (!type.requiresPositiveWeight && weight < 0) {
        return 'The value cannot be negative.';
      }
    }
    if (type.usesReps && (reps == null || reps <= 0)) {
      return 'Enter repetitions above zero.';
    }
    if (type.usesDuration && (duration == null || duration <= 0)) {
      return 'Enter duration in seconds or mm:ss.';
    }
    if (type.usesDistance &&
        (distance == null || !distance.isFinite || distance <= 0)) {
      return 'Enter distance above zero.';
    }
    if (type.usesCalories &&
        (calories == null || !calories.isFinite || calories <= 0)) {
      return 'Enter calories above zero.';
    }
    return null;
  }

  int? _parseDuration(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return null;
    if (!value.contains(':')) return int.tryParse(value);
    final parts = value.split(':');
    if (parts.length != 2) return null;
    final minutes = int.tryParse(parts[0]);
    final seconds = int.tryParse(parts[1]);
    if (minutes == null || seconds == null || seconds < 0 || seconds >= 60) {
      return null;
    }
    return minutes * 60 + seconds;
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
        Row(
          children: [
            Expanded(
              child: Text(
                '${_date(widget.log.date)}  •  ${widget.log.workout}',
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              _type.label.toUpperCase(),
              style: const TextStyle(
                color: Colors.white38,
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: .7,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _SetEditorFields(
          type: _type,
          unit: widget.store.unit,
          distanceUnit: widget.log.distanceUnit ??
              (widget.store.unit == 'kg' ? 'km' : 'mi'),
          weight: _weight,
          reps: _reps,
          duration: _duration,
          distance: _distance,
          calories: _calories,
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

class _SetEditorFields extends StatelessWidget {
  const _SetEditorFields({
    required this.type,
    required this.unit,
    required this.distanceUnit,
    required this.weight,
    required this.reps,
    required this.duration,
    required this.distance,
    required this.calories,
  });

  final ExerciseTrackingType type;
  final String unit;
  final String distanceUnit;
  final TextEditingController weight;
  final TextEditingController reps;
  final TextEditingController duration;
  final TextEditingController distance;
  final TextEditingController calories;

  @override
  Widget build(BuildContext context) {
    final fields = <Widget>[
      if (type.usesWeight)
        _SetField(
          controller: weight,
          label: '${type.weightLabel} ($unit)',
          decimal: true,
        ),
      if (type.usesReps)
        _SetField(controller: reps, label: 'REPS', decimal: false),
      if (type.usesDuration)
        _SetField(
          controller: duration,
          label: 'DURATION',
          hint: 'seconds or mm:ss',
          decimal: false,
        ),
      if (type.usesDistance)
        _SetField(
          controller: distance,
          label: 'DISTANCE ($distanceUnit)',
          decimal: true,
        ),
      if (type.usesCalories)
        _SetField(controller: calories, label: 'CALORIES', decimal: true),
    ];
    if (fields.length == 1) return fields.single;
    return LayoutBuilder(
      builder: (context, constraints) => Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final field in fields)
            SizedBox(
              width: fields.length == 2 || constraints.maxWidth >= 520
                  ? (constraints.maxWidth - 10) / 2
                  : constraints.maxWidth,
              child: field,
            ),
        ],
      ),
    );
  }
}

class _SetField extends StatelessWidget {
  const _SetField({
    required this.controller,
    required this.label,
    required this.decimal,
    this.hint,
  });

  final TextEditingController controller;
  final String label;
  final bool decimal;
  final String? hint;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    keyboardType: decimal
        ? const TextInputType.numberWithOptions(decimal: true)
        : TextInputType.number,
    decoration: InputDecoration(labelText: label, hintText: hint),
  );
}

String _formatNumber(double value) => value == value.roundToDouble()
    ? value.round().toString()
    : value.toStringAsFixed(1);

String _formatDurationInput(int seconds) => seconds >= 60
    ? '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}'
    : '$seconds';


String _date(DateTime value) =>
    '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

String _dateTime(DateTime value) =>
    '${_date(value)} ${value.hour.toString().padLeft(2, '0')}:'
    '${value.minute.toString().padLeft(2, '0')}';
