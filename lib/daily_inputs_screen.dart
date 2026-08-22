import 'dart:async';

import 'package:flutter/material.dart';

import 'brand.dart';
import 'daily_inputs.dart';
import 'store.dart';

class TodayInputsCard extends StatelessWidget {
  const TodayInputsCard({super.key, required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final supplements = store.supplementEventsForDay(now);
    final meals = store.mealEventsForDay(now);
    final caffeine = store.caffeineForDay(now);
    final hydration = store.hydrationForDay(now);
    final recovery = store.recoveryForDay(now);
    final summary = <String>[
      if (supplements.isNotEmpty) '${supplements.length} supplements',
      if (caffeine > 0) '${caffeine.round()} mg caffeine',
      if (meals.isNotEmpty) '${meals.length} meals',
      if (hydration > 0) '${_formatMl(hydration)} water',
      if (recovery?.sleepHours case final double hours)
        '${hours.toStringAsFixed(hours % 1 == 0 ? 0 : 1)} h sleep',
    ];

    return LabPanel(
      accent: BrandColors.cyan,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.science_rounded, color: BrandColors.cyan),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "TODAY'S INPUTS",
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        letterSpacing: .8,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Supplements, meals, hydration, and recovery',
                      style: TextStyle(color: BrandColors.muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Open daily inputs',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DailyInputsScreen(store: store),
                  ),
                ),
                icon: const Icon(Icons.arrow_forward_rounded),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            summary.isEmpty ? 'Nothing logged yet today.' : summary.join(' · '),
            style: const TextStyle(color: BrandColors.muted, height: 1.4),
          ),
          if (store.activeSupplementPresets.isNotEmpty) ...[
            const SizedBox(height: 13),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final preset in store.activeSupplementPresets.take(
                    4,
                  )) ...[
                    ActionChip(
                      avatar: const Icon(Icons.add_rounded, size: 16),
                      label: Text(preset.name),
                      onPressed: () => _quickLogPreset(context, store, preset),
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => showMealEntrySheet(context, store),
                  icon: const Icon(Icons.restaurant_rounded, size: 17),
                  label: const Text('MEAL'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _quickHydration(context, store, 500),
                  icon: const Icon(Icons.water_drop_rounded, size: 17),
                  label: const Text('+500 ML'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => showRecoveryCheckInSheet(context, store),
                  icon: const Icon(Icons.bedtime_rounded, size: 17),
                  label: const Text('RECOVERY'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class DailyInputsScreen extends StatelessWidget {
  const DailyInputsScreen({super.key, required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: store,
    builder: (context, _) {
      final now = DateTime.now();
      final supplements = store.supplementEventsForDay(now);
      final meals = store.mealEventsForDay(now);
      final hydration = store.hydrationEventsForDay(now);
      final recovery = store.recoveryForDay(now);
      return Scaffold(
        body: BrandBackdrop(
          child: SafeArea(
            child: CustomScrollView(
              slivers: [
                SliverAppBar(
                  pinned: true,
                  title: const Text('DAILY INPUTS & RECOVERY'),
                  backgroundColor: BrandColors.ink.withValues(alpha: .94),
                  actions: [
                    IconButton(
                      tooltip: 'Manage supplement presets',
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SupplementPresetsScreen(store: store),
                        ),
                      ),
                      icon: const Icon(Icons.tune_rounded),
                    ),
                  ],
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 36),
                  sliver: SliverList.list(
                    children: [
                      const BrandSectionLabel('Today at a glance'),
                      const SizedBox(height: 12),
                      _DailySummaryPanel(store: store, day: now),
                      const SizedBox(height: 22),
                      const BrandSectionLabel('Quick add'),
                      const SizedBox(height: 12),
                      _QuickAddPanel(store: store),
                      const SizedBox(height: 22),
                      BrandSectionLabel(
                        'Supplements',
                        trailing: TextButton.icon(
                          onPressed: () =>
                              showSupplementEntrySheet(context, store),
                          icon: const Icon(Icons.add_rounded, size: 17),
                          label: const Text('ADD'),
                        ),
                      ),
                      const SizedBox(height: 10),
                      _SupplementList(
                        events: supplements,
                        onEdit: (event) => showSupplementEntrySheet(
                          context,
                          store,
                          existing: event,
                        ),
                        onDelete: (event) => _confirmDelete(
                          context,
                          label: event.name,
                          onDelete: () => store.deleteSupplementEvent(event.id),
                        ),
                      ),
                      const SizedBox(height: 22),
                      BrandSectionLabel(
                        'Meals',
                        trailing: TextButton.icon(
                          onPressed: () => showMealEntrySheet(context, store),
                          icon: const Icon(Icons.add_rounded, size: 17),
                          label: const Text('ADD'),
                        ),
                      ),
                      const SizedBox(height: 10),
                      _MealList(
                        events: meals,
                        onEdit: (event) =>
                            showMealEntrySheet(context, store, existing: event),
                        onDelete: (event) => _confirmDelete(
                          context,
                          label: event.name,
                          onDelete: () => store.deleteMealEvent(event.id),
                        ),
                      ),
                      const SizedBox(height: 22),
                      BrandSectionLabel(
                        'Hydration',
                        trailing: TextButton.icon(
                          onPressed: () =>
                              showHydrationEntrySheet(context, store),
                          icon: const Icon(Icons.add_rounded, size: 17),
                          label: const Text('ADD'),
                        ),
                      ),
                      const SizedBox(height: 10),
                      _HydrationPanel(
                        events: hydration,
                        onDelete: (event) => _confirmDelete(
                          context,
                          label: '${event.amountMl.round()} mL hydration',
                          onDelete: () => store.deleteHydrationEvent(event.id),
                        ),
                      ),
                      const SizedBox(height: 22),
                      BrandSectionLabel(
                        'Recovery',
                        trailing: TextButton.icon(
                          onPressed: () => showRecoveryCheckInSheet(
                            context,
                            store,
                            existing: recovery,
                          ),
                          icon: Icon(
                            recovery == null
                                ? Icons.add_rounded
                                : Icons.edit_rounded,
                            size: 17,
                          ),
                          label: Text(recovery == null ? 'ADD' : 'EDIT'),
                        ),
                      ),
                      const SizedBox(height: 10),
                      _RecoveryPanel(checkIn: recovery),
                      const SizedBox(height: 18),
                      const Text(
                        'Progression Lab reports associations, not proof that a supplement, meal, or recovery factor caused a performance change.',
                        style: TextStyle(
                          color: BrandColors.muted,
                          fontSize: 11,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class SupplementPresetsScreen extends StatelessWidget {
  const SupplementPresetsScreen({super.key, required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: store,
    builder: (context, _) => Scaffold(
      body: BrandBackdrop(
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                title: const Text('SUPPLEMENT PRESETS'),
                backgroundColor: BrandColors.ink.withValues(alpha: .94),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
                sliver: SliverList.list(
                  children: [
                    const Text(
                      'Presets make daily logging fast. Caffeine stored inside a product is included once in your daily total.',
                      style: TextStyle(color: BrandColors.muted, height: 1.45),
                    ),
                    const SizedBox(height: 16),
                    GradientAction(
                      label: 'CREATE PRESET',
                      icon: Icons.add_rounded,
                      onPressed: () =>
                          showSupplementPresetSheet(context, store),
                    ),
                    const SizedBox(height: 18),
                    for (final preset in store.activeSupplementPresets) ...[
                      LabPanel(
                        accent: preset.caffeineMg > 0
                            ? BrandColors.cyan
                            : BrandColors.violet,
                        onTap: () => showSupplementPresetSheet(
                          context,
                          store,
                          existing: preset,
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.science_rounded),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    preset.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    '${_number(preset.dose)} ${preset.unit}'
                                    '${preset.caffeineMg > 0 ? ' · ${preset.caffeineMg.round()} mg caffeine' : ''}',
                                    style: const TextStyle(
                                      color: BrandColors.muted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'Archive preset',
                              onPressed: () => _confirmDelete(
                                context,
                                label: preset.name,
                                actionLabel: 'ARCHIVE',
                                onDelete: () =>
                                    store.archiveSupplementPreset(preset.id),
                              ),
                              icon: const Icon(Icons.archive_outlined),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _DailySummaryPanel extends StatelessWidget {
  const _DailySummaryPanel({required this.store, required this.day});

  final AppStore store;
  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final recovery = store.recoveryForDay(day);
    return LabPanel(
      accent: BrandColors.cyan,
      child: Wrap(
        spacing: 18,
        runSpacing: 16,
        children: [
          _SummaryMetric(
            icon: Icons.bolt_rounded,
            value: '${store.caffeineForDay(day).round()} mg',
            label: 'CAFFEINE',
          ),
          _SummaryMetric(
            icon: Icons.science_rounded,
            value: '${store.supplementEventsForDay(day).length}',
            label: 'SUPPLEMENTS',
          ),
          _SummaryMetric(
            icon: Icons.restaurant_rounded,
            value: '${store.mealEventsForDay(day).length}',
            label: 'MEALS',
          ),
          _SummaryMetric(
            icon: Icons.water_drop_rounded,
            value: _formatMl(store.hydrationForDay(day)),
            label: 'HYDRATION',
          ),
          _SummaryMetric(
            icon: Icons.bedtime_rounded,
            value: recovery?.sleepHours == null
                ? '—'
                : '${_number(recovery!.sleepHours!)} h',
            label: 'SLEEP',
          ),
        ],
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 104,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: BrandColors.cyan, size: 19),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            color: BrandColors.muted,
            fontSize: 9,
            fontWeight: FontWeight.w900,
            letterSpacing: .7,
          ),
        ),
      ],
    ),
  );
}

class _QuickAddPanel extends StatelessWidget {
  const _QuickAddPanel({required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) => LabPanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final preset in store.activeSupplementPresets)
              ActionChip(
                avatar: Icon(
                  preset.caffeineMg > 0
                      ? Icons.bolt_rounded
                      : Icons.add_rounded,
                  size: 16,
                ),
                label: Text(preset.name),
                onPressed: () => _quickLogPreset(context, store, preset),
              ),
          ],
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: () => showSupplementEntrySheet(context, store),
              icon: const Icon(Icons.science_rounded),
              label: const Text('CUSTOM SUPPLEMENT'),
            ),
            OutlinedButton.icon(
              onPressed: () => showMealEntrySheet(context, store),
              icon: const Icon(Icons.restaurant_rounded),
              label: const Text('MEAL'),
            ),
            OutlinedButton.icon(
              onPressed: () => showHydrationEntrySheet(context, store),
              icon: const Icon(Icons.water_drop_rounded),
              label: const Text('WATER'),
            ),
            OutlinedButton.icon(
              onPressed: () => showRecoveryCheckInSheet(context, store),
              icon: const Icon(Icons.bedtime_rounded),
              label: const Text('RECOVERY'),
            ),
          ],
        ),
      ],
    ),
  );
}

class _SupplementList extends StatelessWidget {
  const _SupplementList({
    required this.events,
    required this.onEdit,
    required this.onDelete,
  });

  final List<SupplementEvent> events;
  final ValueChanged<SupplementEvent> onEdit;
  final ValueChanged<SupplementEvent> onDelete;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty)
      return const _EmptyPanel('No supplements logged today.');
    return Column(
      children: [
        for (final event in events) ...[
          LabPanel(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
            accent: event.caffeineMg > 0
                ? BrandColors.cyan
                : BrandColors.violet,
            onTap: () => onEdit(event),
            child: Row(
              children: [
                Icon(
                  event.caffeineMg > 0
                      ? Icons.bolt_rounded
                      : Icons.science_rounded,
                  color: event.caffeineMg > 0
                      ? BrandColors.cyan
                      : BrandColors.violet,
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.name,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${_number(event.dose)} ${event.unit}'
                        '${event.caffeineMg > 0 ? ' · ${event.caffeineMg.round()} mg caffeine' : ''}'
                        ' · ${_time(event.takenAt)}',
                        style: const TextStyle(
                          color: BrandColors.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Delete entry',
                  onPressed: () => onDelete(event),
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _MealList extends StatelessWidget {
  const _MealList({
    required this.events,
    required this.onEdit,
    required this.onDelete,
  });

  final List<MealEvent> events;
  final ValueChanged<MealEvent> onEdit;
  final ValueChanged<MealEvent> onDelete;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) return const _EmptyPanel('No meals logged today.');
    return Column(
      children: [
        for (final event in events) ...[
          LabPanel(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
            accent: BrandColors.magenta,
            onTap: () => onEdit(event),
            child: Row(
              children: [
                const Icon(
                  Icons.restaurant_rounded,
                  color: BrandColors.magenta,
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.name,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${_mealSize(event.size)} · ${_mealTiming(event.timing)} · ${_time(event.occurredAt)}'
                        '${event.proteinGrams == null ? '' : ' · ${_number(event.proteinGrams!)} g protein'}',
                        style: const TextStyle(
                          color: BrandColors.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Delete entry',
                  onPressed: () => onDelete(event),
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _HydrationPanel extends StatelessWidget {
  const _HydrationPanel({required this.events, required this.onDelete});

  final List<HydrationEvent> events;
  final ValueChanged<HydrationEvent> onDelete;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) return const _EmptyPanel('No hydration logged today.');
    return LabPanel(
      accent: BrandColors.cyan,
      child: Column(
        children: [
          for (final event in events)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                event.electrolytes
                    ? Icons.electric_bolt_rounded
                    : Icons.water_drop_rounded,
                color: BrandColors.cyan,
              ),
              title: Text('${event.amountMl.round()} mL'),
              subtitle: Text(
                '${event.electrolytes ? 'Electrolytes · ' : ''}${_time(event.occurredAt)}',
              ),
              trailing: IconButton(
                tooltip: 'Delete entry',
                onPressed: () => onDelete(event),
                icon: const Icon(Icons.delete_outline_rounded),
              ),
            ),
        ],
      ),
    );
  }
}

class _RecoveryPanel extends StatelessWidget {
  const _RecoveryPanel({required this.checkIn});

  final RecoveryCheckIn? checkIn;

  @override
  Widget build(BuildContext context) {
    final value = checkIn;
    if (value == null) {
      return const _EmptyPanel(
        'Log sleep, stress, soreness, and bodyweight when useful.',
      );
    }
    return LabPanel(
      accent: BrandColors.violet,
      child: Wrap(
        spacing: 18,
        runSpacing: 16,
        children: [
          _RecoveryMetric(
            'SLEEP',
            value.sleepHours == null ? '—' : '${_number(value.sleepHours!)} h',
          ),
          _RecoveryMetric(
            'QUALITY',
            value.sleepQuality == null ? '—' : '${value.sleepQuality}/5',
          ),
          _RecoveryMetric(
            'STRESS',
            value.stress == null ? '—' : '${value.stress}/5',
          ),
          _RecoveryMetric(
            'SORENESS',
            value.soreness == null ? '—' : '${value.soreness}/5',
          ),
          _RecoveryMetric(
            'BODYWEIGHT',
            value.bodyWeight == null
                ? '—'
                : '${_number(value.bodyWeight!)} ${value.weightUnit ?? ''}',
          ),
          if (value.illness) const _RecoveryMetric('STATUS', 'ILLNESS'),
        ],
      ),
    );
  }
}

class _RecoveryMetric extends StatelessWidget {
  const _RecoveryMetric(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 104,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
        const SizedBox(height: 3),
        Text(
          label,
          style: const TextStyle(
            color: BrandColors.muted,
            fontSize: 9,
            fontWeight: FontWeight.w900,
            letterSpacing: .7,
          ),
        ),
      ],
    ),
  );
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel(this.message);

  final String message;

  @override
  Widget build(BuildContext context) => LabPanel(
    padding: const EdgeInsets.all(14),
    accent: BrandColors.line,
    child: Text(
      message,
      style: const TextStyle(color: BrandColors.muted, fontSize: 12),
    ),
  );
}

Future<void> showSupplementEntrySheet(
  BuildContext context,
  AppStore store, {
  SupplementEvent? existing,
}) async {
  final name = TextEditingController(text: existing?.name ?? '');
  final brand = TextEditingController(text: existing?.brand ?? '');
  final dose = TextEditingController(
    text: existing == null ? '' : _number(existing.dose),
  );
  final unit = TextEditingController(text: existing?.unit ?? 'serving');
  final caffeine = TextEditingController(
    text: existing == null || existing.caffeineMg == 0
        ? ''
        : _number(existing.caffeineMg),
  );
  final notes = TextEditingController(text: existing?.notes ?? '');
  var when = existing?.takenAt ?? DateTime.now();
  var savePreset = false;
  final value = await showModalBottomSheet<SupplementEvent>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => StatefulBuilder(
      builder: (context, setState) => _EntrySheet(
        title: existing == null ? 'LOG SUPPLEMENT' : 'EDIT SUPPLEMENT',
        children: [
          TextField(
            controller: name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: brand,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Brand or product (optional)',
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: dose,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Dose'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: unit,
                  decoration: const InputDecoration(labelText: 'Unit'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: caffeine,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Caffeine contained (mg)',
              helperText: 'Included once in the daily caffeine total.',
            ),
          ),
          const SizedBox(height: 10),
          _TimeRow(
            value: when,
            onChanged: (value) => setState(() => when = value),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: notes,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'Notes (optional)'),
          ),
          if (existing == null)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: savePreset,
              onChanged: (value) => setState(() => savePreset = value ?? false),
              title: const Text('Save as a quick-add preset'),
            ),
        ],
        onSave: () {
          final parsedDose = double.tryParse(dose.text.trim());
          final parsedCaffeine = caffeine.text.trim().isEmpty
              ? 0.0
              : double.tryParse(caffeine.text.trim());
          if (name.text.trim().isEmpty ||
              unit.text.trim().isEmpty ||
              parsedDose == null ||
              parsedDose <= 0 ||
              parsedCaffeine == null ||
              parsedCaffeine < 0) {
            _showInputError(
              context,
              'Enter a valid name, dose, unit, and caffeine amount.',
            );
            return;
          }
          final now = DateTime.now();
          Navigator.pop(
            sheetContext,
            SupplementEvent(
              id: existing?.id ?? createRecordId('supplement'),
              presetId: existing?.presetId,
              name: name.text.trim(),
              brand: brand.text.trim(),
              dose: parsedDose,
              unit: unit.text.trim(),
              caffeineMg: parsedCaffeine,
              takenAt: when,
              notes: notes.text.trim(),
              workoutSessionId: existing?.workoutSessionId,
              createdAt: existing?.createdAt ?? now,
              updatedAt: now,
            ),
          );
        },
      ),
    ),
  );
  try {
    if (value != null) {
      await store.saveSupplementEvent(value);
      if (savePreset) {
        await store.saveSupplementPreset(
          SupplementPreset(
            id: createRecordId('preset'),
            name: value.name,
            brand: value.brand,
            dose: value.dose,
            unit: value.unit,
            caffeineMg: value.caffeineMg,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
      }
    }
  } on Object {
    if (context.mounted)
      _showInputError(context, 'The supplement could not be saved.');
  } finally {
    name.dispose();
    brand.dispose();
    dose.dispose();
    unit.dispose();
    caffeine.dispose();
    notes.dispose();
  }
}

Future<void> showSupplementPresetSheet(
  BuildContext context,
  AppStore store, {
  SupplementPreset? existing,
}) async {
  final name = TextEditingController(text: existing?.name ?? '');
  final brand = TextEditingController(text: existing?.brand ?? '');
  final dose = TextEditingController(
    text: existing == null ? '' : _number(existing.dose),
  );
  final unit = TextEditingController(text: existing?.unit ?? 'serving');
  final caffeine = TextEditingController(
    text: existing == null || existing.caffeineMg == 0
        ? ''
        : _number(existing.caffeineMg),
  );
  final value = await showModalBottomSheet<SupplementPreset>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => _EntrySheet(
      title: existing == null ? 'CREATE PRESET' : 'EDIT PRESET',
      children: [
        TextField(
          controller: name,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Name'),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: brand,
          decoration: const InputDecoration(
            labelText: 'Brand or product (optional)',
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: dose,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: 'Dose'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: unit,
                decoration: const InputDecoration(labelText: 'Unit'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TextField(
          controller: caffeine,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Caffeine contained (mg)',
          ),
        ),
      ],
      onSave: () {
        final parsedDose = double.tryParse(dose.text.trim());
        final parsedCaffeine = caffeine.text.trim().isEmpty
            ? 0.0
            : double.tryParse(caffeine.text.trim());
        if (name.text.trim().isEmpty ||
            unit.text.trim().isEmpty ||
            parsedDose == null ||
            parsedDose <= 0 ||
            parsedCaffeine == null ||
            parsedCaffeine < 0) {
          _showInputError(
            context,
            'Enter a valid name, dose, unit, and caffeine amount.',
          );
          return;
        }
        final now = DateTime.now();
        Navigator.pop(
          sheetContext,
          SupplementPreset(
            id: existing?.id ?? createRecordId('preset'),
            name: name.text.trim(),
            brand: brand.text.trim(),
            dose: parsedDose,
            unit: unit.text.trim(),
            caffeineMg: parsedCaffeine,
            archived: existing?.archived ?? false,
            createdAt: existing?.createdAt ?? now,
            updatedAt: now,
          ),
        );
      },
    ),
  );
  try {
    if (value != null) await store.saveSupplementPreset(value);
  } on Object {
    if (context.mounted)
      _showInputError(context, 'The preset could not be saved.');
  } finally {
    name.dispose();
    brand.dispose();
    dose.dispose();
    unit.dispose();
    caffeine.dispose();
  }
}

Future<void> showMealEntrySheet(
  BuildContext context,
  AppStore store, {
  MealEvent? existing,
}) async {
  final name = TextEditingController(text: existing?.name ?? 'Meal');
  final calories = TextEditingController(
    text: existing?.calories == null ? '' : _number(existing!.calories!),
  );
  final protein = TextEditingController(
    text: existing?.proteinGrams == null
        ? ''
        : _number(existing!.proteinGrams!),
  );
  final carbs = TextEditingController(
    text: existing?.carbohydrateGrams == null
        ? ''
        : _number(existing!.carbohydrateGrams!),
  );
  final fat = TextEditingController(
    text: existing?.fatGrams == null ? '' : _number(existing!.fatGrams!),
  );
  final notes = TextEditingController(text: existing?.notes ?? '');
  var when = existing?.occurredAt ?? DateTime.now();
  var size = existing?.size ?? MealSize.medium;
  var timing = existing?.timing ?? MealTiming.general;
  var detailed =
      existing?.calories != null ||
      existing?.proteinGrams != null ||
      existing?.carbohydrateGrams != null ||
      existing?.fatGrams != null;
  final value = await showModalBottomSheet<MealEvent>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => StatefulBuilder(
      builder: (context, setState) => _EntrySheet(
        title: existing == null ? 'LOG MEAL' : 'EDIT MEAL',
        children: [
          TextField(
            controller: name,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Meal name'),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<MealSize>(
            initialValue: size,
            decoration: const InputDecoration(labelText: 'Meal size'),
            items: [
              for (final value in MealSize.values)
                DropdownMenuItem(value: value, child: Text(_mealSize(value))),
            ],
            onChanged: (value) => setState(() => size = value ?? size),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<MealTiming>(
            initialValue: timing,
            decoration: const InputDecoration(labelText: 'Timing'),
            items: [
              for (final value in MealTiming.values)
                DropdownMenuItem(value: value, child: Text(_mealTiming(value))),
            ],
            onChanged: (value) => setState(() => timing = value ?? timing),
          ),
          const SizedBox(height: 10),
          _TimeRow(
            value: when,
            onChanged: (value) => setState(() => when = value),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: detailed,
            title: const Text('Add calories and macros'),
            onChanged: (value) => setState(() => detailed = value),
          ),
          if (detailed) ...[
            Row(
              children: [
                Expanded(
                  child: _NumberField(controller: calories, label: 'Calories'),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _NumberField(controller: protein, label: 'Protein g'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _NumberField(controller: carbs, label: 'Carbs g'),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _NumberField(controller: fat, label: 'Fat g'),
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          TextField(
            controller: notes,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'Notes (optional)'),
          ),
        ],
        onSave: () {
          if (name.text.trim().isEmpty) {
            _showInputError(context, 'Enter a meal name.');
            return;
          }
          double? optional(TextEditingController controller) {
            if (!detailed || controller.text.trim().isEmpty) return null;
            return double.tryParse(controller.text.trim());
          }

          final parsed = [
            optional(calories),
            optional(protein),
            optional(carbs),
            optional(fat),
          ];
          if (parsed.whereType<double>().any(
            (value) => !value.isFinite || value < 0,
          )) {
            _showInputError(
              context,
              'Calories and macros must be zero or greater.',
            );
            return;
          }
          final now = DateTime.now();
          Navigator.pop(
            sheetContext,
            MealEvent(
              id: existing?.id ?? createRecordId('meal'),
              name: name.text.trim(),
              occurredAt: when,
              size: size,
              timing: timing,
              calories: parsed[0],
              proteinGrams: parsed[1],
              carbohydrateGrams: parsed[2],
              fatGrams: parsed[3],
              notes: notes.text.trim(),
              workoutSessionId: existing?.workoutSessionId,
              createdAt: existing?.createdAt ?? now,
              updatedAt: now,
            ),
          );
        },
      ),
    ),
  );
  try {
    if (value != null) await store.saveMealEvent(value);
  } on Object {
    if (context.mounted)
      _showInputError(context, 'The meal could not be saved.');
  } finally {
    name.dispose();
    calories.dispose();
    protein.dispose();
    carbs.dispose();
    fat.dispose();
    notes.dispose();
  }
}

Future<void> showHydrationEntrySheet(
  BuildContext context,
  AppStore store,
) async {
  final amount = TextEditingController(text: '500');
  final notes = TextEditingController();
  var electrolytes = false;
  var when = DateTime.now();
  final value = await showModalBottomSheet<HydrationEvent>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => StatefulBuilder(
      builder: (context, setState) => _EntrySheet(
        title: 'LOG HYDRATION',
        children: [
          TextField(
            controller: amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Amount (mL)'),
          ),
          const SizedBox(height: 10),
          _TimeRow(
            value: when,
            onChanged: (value) => setState(() => when = value),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: electrolytes,
            title: const Text('Included electrolytes'),
            onChanged: (value) => setState(() => electrolytes = value),
          ),
          TextField(
            controller: notes,
            decoration: const InputDecoration(labelText: 'Notes (optional)'),
          ),
        ],
        onSave: () {
          final parsed = double.tryParse(amount.text.trim());
          if (parsed == null || !parsed.isFinite || parsed <= 0) {
            _showInputError(context, 'Enter a hydration amount above zero.');
            return;
          }
          final now = DateTime.now();
          Navigator.pop(
            sheetContext,
            HydrationEvent(
              id: createRecordId('hydration'),
              occurredAt: when,
              amountMl: parsed,
              electrolytes: electrolytes,
              notes: notes.text.trim(),
              createdAt: now,
              updatedAt: now,
            ),
          );
        },
      ),
    ),
  );
  try {
    if (value != null) {
      await store.addHydration(
        amountMl: value.amountMl,
        electrolytes: value.electrolytes,
        notes: value.notes,
        occurredAt: value.occurredAt,
      );
    }
  } on Object {
    if (context.mounted)
      _showInputError(context, 'Hydration could not be saved.');
  } finally {
    amount.dispose();
    notes.dispose();
  }
}

Future<void> showRecoveryCheckInSheet(
  BuildContext context,
  AppStore store, {
  RecoveryCheckIn? existing,
}) async {
  final current = existing ?? store.recoveryForDay(DateTime.now());
  final sleep = TextEditingController(
    text: current?.sleepHours == null ? '' : _number(current!.sleepHours!),
  );
  final bodyweight = TextEditingController(
    text: current?.bodyWeight == null ? '' : _number(current!.bodyWeight!),
  );
  final notes = TextEditingController(text: current?.notes ?? '');
  var sleepQuality = current?.sleepQuality ?? 3;
  var stress = current?.stress ?? 3;
  var soreness = current?.soreness ?? 3;
  var illness = current?.illness ?? false;
  final value = await showModalBottomSheet<RecoveryCheckIn>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => StatefulBuilder(
      builder: (context, setState) => _EntrySheet(
        title: 'RECOVERY CHECK-IN',
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: sleep,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Sleep hours'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: bodyweight,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Bodyweight (${store.unit})',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _RatingInput(
            label: 'Sleep quality',
            value: sleepQuality,
            lowLabel: 'Poor',
            highLabel: 'Great',
            onChanged: (value) => setState(() => sleepQuality = value),
          ),
          _RatingInput(
            label: 'Stress',
            value: stress,
            lowLabel: 'Low',
            highLabel: 'High',
            onChanged: (value) => setState(() => stress = value),
          ),
          _RatingInput(
            label: 'Soreness',
            value: soreness,
            lowLabel: 'Low',
            highLabel: 'High',
            onChanged: (value) => setState(() => soreness = value),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: illness,
            title: const Text('Illness or unusual symptoms today'),
            onChanged: (value) => setState(() => illness = value),
          ),
          TextField(
            controller: notes,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'Notes (optional)'),
          ),
        ],
        onSave: () {
          final sleepValue = sleep.text.trim().isEmpty
              ? null
              : double.tryParse(sleep.text.trim());
          final weightValue = bodyweight.text.trim().isEmpty
              ? null
              : double.tryParse(bodyweight.text.trim());
          if (sleepValue != null &&
              (!sleepValue.isFinite || sleepValue < 0 || sleepValue > 24)) {
            _showInputError(context, 'Sleep hours must be between 0 and 24.');
            return;
          }
          if (weightValue != null &&
              (!weightValue.isFinite || weightValue <= 0)) {
            _showInputError(context, 'Bodyweight must be above zero.');
            return;
          }
          final now = DateTime.now();
          Navigator.pop(
            sheetContext,
            RecoveryCheckIn(
              id: current?.id ?? createRecordId('recovery'),
              localDate: dateOnly(now),
              sleepHours: sleepValue,
              sleepQuality: sleepQuality,
              stress: stress,
              soreness: soreness,
              bodyWeight: weightValue,
              weightUnit: weightValue == null ? null : store.unit,
              illness: illness,
              notes: notes.text.trim(),
              createdAt: current?.createdAt ?? now,
              updatedAt: now,
            ),
          );
        },
      ),
    ),
  );
  try {
    if (value != null) await store.saveRecoveryCheckIn(value);
  } on Object {
    if (context.mounted)
      _showInputError(context, 'The recovery check-in could not be saved.');
  } finally {
    sleep.dispose();
    bodyweight.dispose();
    notes.dispose();
  }
}

Future<void> showWorkoutResponseSheet(
  BuildContext context,
  AppStore store, {
  required String sessionId,
  required String track,
}) async {
  final current = store.responseForSession(sessionId);
  var energy = current?.energy ?? 3;
  var focus = current?.focus ?? 3;
  var pump = current?.pump ?? 3;
  var effort = current?.effort ?? 3;
  var discomfort = current?.discomfort ?? 1;
  final notes = TextEditingController(text: current?.notes ?? '');
  final value = await showModalBottomSheet<WorkoutResponse>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => StatefulBuilder(
      builder: (context, setState) => _EntrySheet(
        title: 'HOW DID THE SESSION FEEL?',
        saveLabel: 'SAVE CHECK-IN',
        secondaryLabel: 'SKIP',
        onSecondary: () => Navigator.pop(sheetContext),
        children: [
          const Text(
            'Optional ratings help the Lab compare supplements and recovery with matched workouts.',
            style: TextStyle(color: BrandColors.muted, height: 1.4),
          ),
          const SizedBox(height: 10),
          _RatingInput(
            label: 'Energy',
            value: energy,
            lowLabel: 'Low',
            highLabel: 'High',
            onChanged: (value) => setState(() => energy = value),
          ),
          _RatingInput(
            label: 'Focus',
            value: focus,
            lowLabel: 'Low',
            highLabel: 'High',
            onChanged: (value) => setState(() => focus = value),
          ),
          _RatingInput(
            label: 'Pump',
            value: pump,
            lowLabel: 'Low',
            highLabel: 'High',
            onChanged: (value) => setState(() => pump = value),
          ),
          _RatingInput(
            label: 'Effort',
            value: effort,
            lowLabel: 'Easy',
            highLabel: 'Max',
            onChanged: (value) => setState(() => effort = value),
          ),
          _RatingInput(
            label: 'Discomfort',
            value: discomfort,
            lowLabel: 'None',
            highLabel: 'High',
            onChanged: (value) => setState(() => discomfort = value),
          ),
          TextField(
            controller: notes,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'Notes (optional)'),
          ),
        ],
        onSave: () {
          final now = DateTime.now();
          Navigator.pop(
            sheetContext,
            WorkoutResponse(
              id: current?.id ?? createRecordId('response'),
              workoutSessionId: sessionId,
              track: track,
              recordedAt: now,
              energy: energy,
              focus: focus,
              pump: pump,
              effort: effort,
              discomfort: discomfort,
              notes: notes.text.trim(),
              createdAt: current?.createdAt ?? now,
              updatedAt: now,
            ),
          );
        },
      ),
    ),
  );
  try {
    if (value != null) await store.saveWorkoutResponse(value);
  } on Object {
    if (context.mounted) {
      _showInputError(context, 'The workout check-in could not be saved.');
    }
  } finally {
    notes.dispose();
  }
}

class _EntrySheet extends StatelessWidget {
  const _EntrySheet({
    required this.title,
    required this.children,
    required this.onSave,
    this.saveLabel = 'SAVE',
    this.secondaryLabel,
    this.onSecondary,
  });

  final String title;
  final List<Widget> children;
  final VoidCallback onSave;
  final String saveLabel;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    minimum: const EdgeInsets.only(bottom: 8),
    child: Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 18),
            ...children,
            const SizedBox(height: 20),
            if (secondaryLabel == null)
              GradientAction(label: saveLabel, onPressed: onSave)
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onSecondary,
                      child: Text(secondaryLabel!),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: onSave,
                      child: Text(saveLabel),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    ),
  );
}

class _TimeRow extends StatelessWidget {
  const _TimeRow({required this.value, required this.onChanged});

  final DateTime value;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: const Icon(Icons.schedule_rounded, color: BrandColors.cyan),
    title: const Text('Time'),
    subtitle: Text(_time(value)),
    trailing: TextButton(
      onPressed: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: TimeOfDay.fromDateTime(value),
        );
        if (picked == null) return;
        onChanged(
          DateTime(
            value.year,
            value.month,
            value.day,
            picked.hour,
            picked.minute,
          ),
        );
      },
      child: const Text('CHANGE'),
    ),
  );
}

class _NumberField extends StatelessWidget {
  const _NumberField({required this.controller, required this.label});

  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    decoration: InputDecoration(labelText: label),
  );
}

class _RatingInput extends StatelessWidget {
  const _RatingInput({
    required this.label,
    required this.value,
    required this.lowLabel,
    required this.highLabel,
    required this.onChanged,
  });

  final String label;
  final int value;
  final String lowLabel;
  final String highLabel;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            Text(
              '$value/5',
              style: const TextStyle(
                color: BrandColors.cyan,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        Slider(
          value: value.toDouble(),
          min: 1,
          max: 5,
          divisions: 4,
          onChanged: (value) => onChanged(value.round()),
        ),
        Row(
          children: [
            Text(
              lowLabel,
              style: const TextStyle(color: BrandColors.muted, fontSize: 10),
            ),
            const Spacer(),
            Text(
              highLabel,
              style: const TextStyle(color: BrandColors.muted, fontSize: 10),
            ),
          ],
        ),
      ],
    ),
  );
}

Future<void> _quickLogPreset(
  BuildContext context,
  AppStore store,
  SupplementPreset preset,
) async {
  try {
    await store.logSupplementPreset(preset);
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('${preset.name} logged.')));
  } on Object {
    if (context.mounted)
      _showInputError(context, 'The supplement could not be logged.');
  }
}

Future<void> _quickHydration(
  BuildContext context,
  AppStore store,
  double amount,
) async {
  try {
    await store.addHydration(amountMl: amount);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${amount.round()} mL hydration logged.')),
    );
  } on Object {
    if (context.mounted)
      _showInputError(context, 'Hydration could not be logged.');
  }
}

Future<void> _confirmDelete(
  BuildContext context, {
  required String label,
  required Future<void> Function() onDelete,
  String actionLabel = 'DELETE',
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('$actionLabel $label?'),
      content: const Text('This change is saved immediately.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('CANCEL'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(actionLabel),
        ),
      ],
    ),
  );
  if (confirmed != true) return;
  try {
    await onDelete();
  } on Object {
    if (context.mounted)
      _showInputError(context, 'The entry could not be changed.');
  }
}

void _showInputError(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

String _formatMl(double amount) => amount >= 1000
    ? '${(amount / 1000).toStringAsFixed(amount % 1000 == 0 ? 0 : 1)} L'
    : '${amount.round()} mL';

String _number(double value) => value.toStringAsFixed(value % 1 == 0 ? 0 : 1);

String _time(DateTime value) {
  final hour = value.hour == 0
      ? 12
      : value.hour > 12
      ? value.hour - 12
      : value.hour;
  final minute = value.minute.toString().padLeft(2, '0');
  final suffix = value.hour >= 12 ? 'PM' : 'AM';
  return '$hour:$minute $suffix';
}

String _mealSize(MealSize value) => switch (value) {
  MealSize.small => 'Small',
  MealSize.medium => 'Medium',
  MealSize.large => 'Large',
};

String _mealTiming(MealTiming value) => switch (value) {
  MealTiming.general => 'General',
  MealTiming.preWorkout => 'Pre-workout',
  MealTiming.postWorkout => 'Post-workout',
};
