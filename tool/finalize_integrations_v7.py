from __future__ import annotations

from pathlib import Path

# Run the complete canonical/native finalization first.
import finalize_integrations_v6  # noqa: F401


def repair_integrations_health_ui() -> None:
    path = Path("lib/integrations_hub.dart")
    text = path.read_text()

    completed_markers = <str>[
        "import 'daily_inputs.dart';",
        "final List<HealthBodyMetric> healthBodyMetrics",
        "final rawHealthMetrics = map['healthBodyMetrics'];",
        "'healthBodyMetrics': healthBodyMetrics",
        "Future<void> addHealthBodyMetrics(",
        "final localWeights =",
        "IMPORT RECENT BODY METRICS",
        "WRITE LATEST LOCAL BODYWEIGHT",
        "ADD & WRITE BODY-FAT READING",
        "Future<void> _writeBodyFatReading()",
    ]
    if all(marker in text for marker in completed_markers):
        return

    if "import 'daily_inputs.dart';" not in text:
        text = text.replace(
            "import 'cloud_sync.dart';\n",
            "import 'cloud_sync.dart';\nimport 'daily_inputs.dart';\n",
            1,
        )

    field = (
        "  final List<ExternalWorkout> externalWorkouts = <ExternalWorkout>[];\n"
    )
    health_field = (
        "  final List<HealthBodyMetric> healthBodyMetrics = <HealthBodyMetric>[];\n"
    )
    if health_field not in text:
        if field not in text:
            raise RuntimeError("The external workout preference field was not found")
        text = text.replace(field, field + health_field, 1)

    load_marker = (
        "          weeklyReviewEnabled = map['weeklyReviewEnabled'] == true;\n"
        "          AdvancedWorkoutShareCardGenerator.currentPreferences =\n"
    )
    if "final rawHealthMetrics = map['healthBodyMetrics'];" not in text:
        load_block = """          weeklyReviewEnabled = map['weeklyReviewEnabled'] == true;
          final rawHealthMetrics = map['healthBodyMetrics'];
          if (rawHealthMetrics is List) {
            healthBodyMetrics
              ..clear()
              ..addAll(
                rawHealthMetrics.whereType<Map>().map(
                  (raw) => HealthBodyMetric.fromJson(
                    Map<Object?, Object?>.from(raw),
                  ),
                ),
              );
          }
          AdvancedWorkoutShareCardGenerator.currentPreferences =
"""
        if load_marker not in text:
            raise RuntimeError("The integration preference load marker was not found")
        text = text.replace(load_marker, load_block, 1)

    save_marker = """      'weeklyReviewEnabled': weeklyReviewEnabled,
      'externalWorkouts': externalWorkouts
"""
    if "'healthBodyMetrics': healthBodyMetrics" not in text:
        save_block = """      'weeklyReviewEnabled': weeklyReviewEnabled,
      'healthBodyMetrics': healthBodyMetrics
          .map((item) => item.toJson())
          .toList(),
      'externalWorkouts': externalWorkouts
"""
        if save_marker not in text:
            raise RuntimeError("The integration preference save marker was not found")
        text = text.replace(save_marker, save_block, 1)

    method_marker = """  Future<void> addExternalWorkouts(Iterable<ExternalWorkout> values) async {
"""
    if "Future<void> addHealthBodyMetrics(" not in text:
        method = """  Future<void> addHealthBodyMetrics(
    Iterable<HealthBodyMetric> values,
  ) async {
    final incoming = values.toList()
      ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
    final keys = healthBodyMetrics
        .map(
          (item) =>
              '${item.type}|${item.recordedAt.toUtc().toIso8601String()}|${item.source}',
        )
        .toSet();
    for (final value in incoming) {
      final key =
          '${value.type}|${value.recordedAt.toUtc().toIso8601String()}|${value.source}';
      if (keys.add(key)) healthBodyMetrics.add(value);
      if (value.type != 'bodyWeight' ||
          !value.value.isFinite ||
          value.value <= 0) {
        continue;
      }
      final day = dateOnly(value.recordedAt.toLocal());
      final existing = _store.recoveryForDay(day);
      if (existing?.bodyWeight != null) continue;
      var bodyWeight = value.value;
      var weightUnit = value.unit;
      if (value.unit == 'kg' && _store.unit == 'lb') {
        bodyWeight = value.value / AppStore.poundsToKilograms;
        weightUnit = 'lb';
      } else if (value.unit == 'lb' && _store.unit == 'kg') {
        bodyWeight = value.value * AppStore.poundsToKilograms;
        weightUnit = 'kg';
      }
      final now = DateTime.now();
      await _store.saveRecoveryCheckIn(
        RecoveryCheckIn(
          id: existing?.id ?? createRecordId('recovery'),
          localDate: day,
          sleepHours: existing?.sleepHours,
          sleepQuality: existing?.sleepQuality,
          stress: existing?.stress,
          soreness: existing?.soreness,
          bodyWeight: bodyWeight,
          weightUnit: weightUnit,
          illness: existing?.illness ?? false,
          notes: existing?.notes ?? '',
          createdAt: existing?.createdAt ?? now,
          updatedAt: now,
        ),
      );
    }
    await save();
    notifyListeners();
  }

"""
        if method_marker not in text:
            raise RuntimeError("The external workout preference method was not found")
        text = text.replace(method_marker, method + method_marker, 1)

    name_marker = """    final name = switch (status.platform) {
      HealthPlatformKind.healthConnect => 'Health Connect',
      HealthPlatformKind.appleHealth => 'Apple Health',
      HealthPlatformKind.unavailable => 'Health platform',
    };
    return _ScrollSection(
"""
    if "final localWeights = widget.store.recoveryCheckIns" not in text:
        name_block = """    final name = switch (status.platform) {
      HealthPlatformKind.healthConnect => 'Health Connect',
      HealthPlatformKind.appleHealth => 'Apple Health',
      HealthPlatformKind.unavailable => 'Health platform',
    };
    final localWeights = widget.store.recoveryCheckIns
        .where((item) => item.bodyWeight != null)
        .toList()
      ..sort((a, b) => a.updatedAt.compareTo(b.updatedAt));
    final latestLocalWeight = localWeights.isEmpty ? null : localWeights.last;
    final recentHealthMetrics = List<HealthBodyMetric>.of(
      _preferences.healthBodyMetrics,
    )..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
    return _ScrollSection(
"""
        if name_marker not in text:
            raise RuntimeError("The health tab platform-name block was not found")
        text = text.replace(name_marker, name_block, 1)

    text = text.replace(
        "'Share workout summaries and read bodyweight, heart rate, sleep, steps, and recovery context. Progression Lab remains the source of truth for detailed sets.',",
        "'Read and write workout summaries, bodyweight, and body-fat percentage. Progression Lab remains the source of truth for detailed sets and private daily inputs.',",
        1,
    )

    workout_button_marker = """          icon: const Icon(Icons.sync_rounded),
          label: const Text('IMPORT RECENT WORKOUT SUMMARIES'),
        ),
        const SizedBox(height: 20),
"""
    if "IMPORT RECENT BODY METRICS" not in text:
        health_actions = """          icon: const Icon(Icons.sync_rounded),
          label: const Text('IMPORT RECENT WORKOUT SUMMARIES'),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _health.busy || !status.available
              ? null
              : () => _run(() async {
                  final now = DateTime.now();
                  final metrics = await _health.readBodyMetrics(
                    start: now.subtract(const Duration(days: 365)),
                    end: now,
                  );
                  await _preferences.addHealthBodyMetrics(metrics);
                  _message =
                      '${metrics.length} body metric records reviewed. Existing local bodyweight entries were preserved.';
                }),
          icon: const Icon(Icons.monitor_weight_outlined),
          label: const Text('IMPORT RECENT BODY METRICS'),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _health.busy ||
                  !status.available ||
                  latestLocalWeight == null
              ? null
              : () => _run(() async {
                  final entry = latestLocalWeight!;
                  final written = await _health.writeBodyWeight(
                    HealthBodyMetric(
                      type: 'bodyWeight',
                      value: entry.bodyWeight!,
                      unit: entry.weightUnit ?? widget.store.unit,
                      recordedAt: entry.updatedAt.toUtc(),
                    ),
                  );
                  _message = written
                      ? 'Latest local bodyweight was written to $name.'
                      : 'The latest local bodyweight was not written.';
                }),
          icon: const Icon(Icons.upload_rounded),
          label: const Text('WRITE LATEST LOCAL BODYWEIGHT'),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _health.busy || !status.available
              ? null
              : _writeBodyFatReading,
          icon: const Icon(Icons.percent_rounded),
          label: const Text('ADD & WRITE BODY-FAT READING'),
        ),
        if (recentHealthMetrics.isNotEmpty) ...<Widget>[
          const SizedBox(height: 18),
          _Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'BODY METRIC ARCHIVE',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 6),
                Text(
                  '${recentHealthMetrics.length} unique records',
                  style: const TextStyle(color: Colors.white60),
                ),
                const Divider(height: 24),
                for (final metric in recentHealthMetrics.take(6))
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      metric.type == 'bodyWeight'
                          ? Icons.monitor_weight_outlined
                          : Icons.percent_rounded,
                    ),
                    title: Text(
                      metric.type == 'bodyWeight'
                          ? 'Bodyweight'
                          : 'Body-fat percentage',
                    ),
                    subtitle: Text(
                      metric.recordedAt.toLocal().toString().split('.').first,
                    ),
                    trailing: Text(
                      '${metric.value.toStringAsFixed(metric.type == 'bodyWeight' ? 1 : 1)} ${metric.unit}',
                    ),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 20),
"""
        if workout_button_marker not in text:
            raise RuntimeError("The health workout import button was not found")
        text = text.replace(workout_button_marker, health_actions, 1)

    text = text.replace(
        "'Workout title, activity type, time, duration, optional energy, distance, and session effort. Set-by-set loads, notes, substitutions, and supplement records stay in Progression Lab.',",
        "'Workout summaries can be read or written. Bodyweight and body-fat percentage can be imported or written after you approve access. Imported bodyweight fills only an empty Daily Inputs bodyweight field; existing local values, detailed sets, notes, substitutions, supplements, meals, hydration, and recovery ratings stay unchanged.',",
        1,
    )

    write_method_marker = """  Future<void> _saveShare(WorkoutSharePreferences value) =>
"""
    if "Future<void> _writeBodyFatReading()" not in text:
        write_method = """  Future<void> _writeBodyFatReading() async {
    final controller = TextEditingController();
    final raw = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add body-fat reading'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'BODY-FAT PERCENTAGE',
            suffixText: '%',
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              dialogContext,
              controller.text.trim(),
            ),
            child: const Text('SAVE & WRITE'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (raw == null) return;
    final value = double.tryParse(raw);
    if (value == null || !value.isFinite || value < 0 || value > 100) {
      if (mounted) {
        setState(
          () => _message = 'Enter a body-fat percentage from 0 to 100.',
        );
      }
      return;
    }
    await _run(() async {
      final metric = HealthBodyMetric(
        type: 'bodyFatPercentage',
        value: value,
        unit: '%',
        recordedAt: DateTime.now().toUtc(),
        source: 'Progression Lab',
      );
      await _preferences.addHealthBodyMetrics(<HealthBodyMetric>[metric]);
      final written = await _health.writeBodyFat(metric);
      _message = written
          ? 'Body-fat reading was saved locally and written to the health platform.'
          : 'Body-fat reading was saved locally but was not written.';
    });
  }

"""
        if write_method_marker not in text:
            raise RuntimeError("The share preference method marker was not found")
        text = text.replace(write_method_marker, write_method + write_method_marker, 1)

    path.write_text(text)


repair_integrations_health_ui()
