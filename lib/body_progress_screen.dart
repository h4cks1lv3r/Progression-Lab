import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'body_progress.dart';
import 'body_media.dart';
import 'body_privacy.dart';
import 'body_camera.dart';
import 'body_photo_widgets.dart';
import 'body_share.dart';
import 'brand.dart';
import 'store.dart';
import 'health_sync.dart';

String bodyNumber(double value) => value.toStringAsFixed(1);
void bodyError(BuildContext context, Object error) {
  final message = error is PlatformException ? error.message : '$error';
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message ?? 'The operation failed. Try again.')),
  );
}

class BodyProgressScreen extends StatefulWidget {
  const BodyProgressScreen({
    super.key,
    required this.store,
    this.embedded = false,
  });
  final AppStore store;
  final bool embedded;
  @override
  State<BodyProgressScreen> createState() => _BodyProgressScreenState();
}

class _BodyProgressScreenState extends State<BodyProgressScreen>
    with WidgetsBindingObserver {
  BodyMediaStore get media => widget.store.bodyMedia;
  int view = 0;
  bool unlocked = false, busy = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    load();
  }

  Future<void> load() async {
    await media.load();
    try {
      final lost = await ImagePicker().retrieveLostData();
      if (lost.files?.isNotEmpty == true) {
        final draft = Map<String, dynamic>.from(
          media.draft ??
              {
                'id': bodyId(),
                'date': bodyDay(DateTime.now()),
                'photos': <dynamic>[],
              },
        );
        final photos = List<dynamic>.from(draft['photos'] as List? ?? []);
        for (final file in lost.files!) {
          photos.add((await media.importPhoto(file.path)).toJson());
        }
        draft['photos'] = photos;
        await media.save({...media.journal, 'draft': draft});
      }
    } on MissingPluginException {
      /* No picker in widget tests or unsupported targets. */
    } on Object catch (e) {
      if (mounted) bodyError(context, e);
    }
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive && media.lockEnabled && mounted)
      setState(() => unlocked = false);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> openEditor({BodyCheckIn? checkIn, bool resume = false}) async {
    await Navigator.push(
      context,
      bodyRoute(
        media,
        (_) => BodyCheckInEditor(
          store: widget.store,
          checkIn: checkIn,
          resume: resume || (checkIn == null && media.draft != null),
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) =>
      BodyPrivacyGate(media: media, child: content(context));
  Widget content(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([widget.store, media]),
    builder: (context, _) {
      if (!media.loaded && media.error == null)
        return const Center(child: CircularProgressIndicator());
      if (media.error != null)
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(media.error!),
              TextButton(onPressed: load, child: const Text('Retry')),
            ],
          ),
        );
      final content = ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Your body, over time',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              IconButton(
                tooltip: 'Body settings and backup',
                onPressed: () => Navigator.push(
                  context,
                  bodyRoute(
                    media,
                    (_) => BodySettingsScreen(store: widget.store),
                  ),
                ),
                icon: const Icon(Icons.tune),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Photos, measurements, and training tell different parts of your story. Track what is useful to you.',
            style: TextStyle(color: BrandColors.muted),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                key: const ValueKey('add-body-checkin'),
                onPressed: () => openEditor(),
                icon: const Icon(Icons.add_a_photo_outlined),
                label: const Text('Add check-in'),
              ),
              OutlinedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  bodyRoute(
                    media,
                    (_) => BodyCompareScreen(store: widget.store),
                  ),
                ),
                icon: const Icon(Icons.compare_outlined),
                label: const Text('Compare / share'),
              ),
            ],
          ),
          if (media.draft != null) ...[
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const Icon(Icons.edit_note),
                title: const Text('Unfinished check-in'),
                subtitle: Text(
                  '${media.draft!['date']} • saved on this device',
                ),
                trailing: TextButton(
                  onPressed: () => openEditor(resume: true),
                  child: const Text('Resume'),
                ),
              ),
            ),
          ],
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            children: [
              for (final (i, label) in [
                'Overview',
                'Photos',
                'Measurements',
              ].indexed)
                ChoiceChip(
                  label: Text(label),
                  selected: view == i,
                  onSelected: (_) => setState(() => view = i),
                ),
            ],
          ),
          const SizedBox(height: 18),
          if (view == 0) ...[
            BodyOverview(store: widget.store),
            const SizedBox(height: 20),
            const Text(
              'Recent check-ins',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
          if (view != 2) ...[
            if (media.checkIns.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 30),
                child: Text(
                  'Start with one photo, a measurement, or a note. Every field is optional. Your photos stay private until you choose to share or export them.',
                ),
              ),
            for (final c
                in (view == 0 ? media.checkIns.take(4) : media.checkIns))
              Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  leading: const Icon(Icons.photo_library_outlined),
                  title: Text(c.date),
                  subtitle: Text(
                    '${c.photos.length} photo${c.photos.length == 1 ? '' : 's'}${c.notes.isEmpty ? '' : ' • Private note'}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => openEditor(checkIn: c),
                ),
              ),
            if (view == 0 && media.checkIns.length > 4)
              TextButton(
                onPressed: () => setState(() => view = 1),
                child: const Text('See all check-ins'),
              ),
          ],
          if (view == 2) BodyMeasurementHistory(store: widget.store),
        ],
      );
      return widget.embedded
          ? content
          : Scaffold(
              appBar: AppBar(title: const Text('Body progress')),
              body: SafeArea(child: content),
            );
    },
  );
}

class BodyOverview extends StatelessWidget {
  const BodyOverview({super.key, required this.store});
  final AppStore store;
  @override
  Widget build(BuildContext context) {
    final settings = store.bodySettings;
    final source = settings['weightSource'] as String? ?? 'manual';
    final end = DateTime.now();
    final trend = BodyAnalysis.window(
      store.bodyMeasurements,
      end,
      source: source,
    );
    final previous = BodyAnalysis.window(
      store.bodyMeasurements,
      DateTime(end.year, end.month, end.day - 7),
      source: source,
    );
    final weight = BodyAnalysis.dailyWeights(
      store.bodyMeasurements,
      source: source,
    ).where((r) => r.date.compareTo(bodyDay(end)) <= 0).lastOrNull;
    final waist = BodyAnalysis.atOrBefore(
      store.bodyMeasurements,
      BodyMetric.waist,
      bodyDay(end),
    );
    final height = BodyAnalysis.atOrBefore(
      store.bodyMeasurements,
      BodyMetric.height,
      waist?.date ?? bodyDay(end),
    );
    final length = settings['lengthUnit'] as String? ?? 'cm';
    final bmi = weight == null
        ? null
        : BodyAnalysis.bmi(weight, store.bodyMeasurements);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (settings['showWeight'] != false)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '7-DAY WEIGHT AVERAGE',
                    style: TextStyle(
                      color: BrandColors.muted,
                      fontSize: 12,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    trend.mean == null
                        ? 'Add readings when useful'
                        : '${bodyNumber(store.unit == 'lb' ? trend.mean! / .45359237 : trend.mean!)} ${store.unit}',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  Text(
                    '${bodyDay(trend.start)} to ${bodyDay(trend.end)} • ${trend.days} of 7 days',
                  ),
                  const SizedBox(height: 8),
                  Text(
                    trend.mean == null
                        ? 'Three distinct days are needed for this average. Weekly entries still appear in your history.'
                        : previous.mean == null
                        ? 'More prior readings are needed for a weekly comparison.'
                        : '${_signed((trend.mean! - previous.mean!) * (store.unit == 'lb' ? 1 / .45359237 : 1))} ${store.unit} vs the prior 7-day window (${previous.days} days logged).',
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Source: ${source == 'manual' ? 'Manual entries' : source}. Missing days are not filled.',
                    style: const TextStyle(color: BrandColors.muted),
                  ),
                ],
              ),
            ),
          ),
        if (settings['showWaist'] != false)
          Card(
            child: ListTile(
              title: const Text('Waist'),
              subtitle: Text(
                waist == null
                    ? 'Optional • measure at the same site each time'
                    : waist.date,
              ),
              trailing: Text(
                waist == null
                    ? '—'
                    : '${bodyNumber(waist.displayValue(store.unit, length))} $length',
                style: const TextStyle(fontSize: 19),
              ),
            ),
          ),
        if (settings['showBmi'] == true)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bmi == null
                        ? 'BMI • add height and weight'
                        : 'BMI ${bodyNumber(bmi)}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (bmi != null)
                    Text(
                      'Weight: ${weight!.date}. Height: ${BodyAnalysis.atOrBefore(store.bodyMeasurements, BodyMetric.height, weight.date)!.date}.',
                    ),
                  if (bmi != null && settings['adult20'] == true)
                    Text(BodyAnalysis.bmiCategory(bmi, adult20: true)!),
                  const Text(
                    'A screening ratio, not a fitness score. BMI cannot separate muscle from fat. CDC adult categories apply at age 20 or above.',
                  ),
                ],
              ),
            ),
          ),
        if (settings['showRatio'] == true)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    waist == null || height == null
                        ? 'Waist / height • add both measures'
                        : 'Waist / height ${(waist.value / height.value).toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 18),
                  ),
                  const Text(
                    'Screening context only. NICE guidance applies to adults with BMI below 35 and does not cover pregnancy. Use the same waist protocol.',
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 8),
        const Text(
          'Appearance and size do not prove exact fat loss or muscle gain. Review them with your training results.',
          style: TextStyle(color: BrandColors.muted),
        ),
      ],
    );
  }

  static String _signed(double v) => '${v > 0 ? '+' : ''}${bodyNumber(v)}';
}

class BodyMeasurementHistory extends StatefulWidget {
  const BodyMeasurementHistory({super.key, required this.store});
  final AppStore store;
  @override
  State<BodyMeasurementHistory> createState() => _BodyMeasurementHistoryState();
}

class _BodyMeasurementHistoryState extends State<BodyMeasurementHistory> {
  BodyMetric metric = BodyMetric.weight;
  String method = '';
  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final unit = store.bodySettings['lengthUnit'] as String? ?? 'cm';
    final rows =
        store.bodyMeasurements.where((r) => r.metric == metric).toList()
          ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
    final methods = rows.map((r) => r.method).toSet().toList();
    final selected = method.isEmpty ? (methods.firstOrNull ?? '') : method;
    final series = metric == BodyMetric.bodyFat
        ? rows.where((r) => r.method == selected).toList()
        : metric == BodyMetric.weight
        ? BodyAnalysis.dailyWeights(
            rows,
            source: store.bodySettings['weightSource'] as String? ?? 'manual',
          )
        : rows;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<BodyMetric>(
          initialValue: metric,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Measurement'),
          items: BodyMetric.values
              .map((m) => DropdownMenuItem(value: m, child: Text(m.label)))
              .toList(),
          onChanged: (m) => setState(() {
            metric = m!;
            method = '';
          }),
        ),
        if (metric == BodyMetric.bodyFat && methods.length > 1)
          DropdownButton<String>(
            value: selected,
            isExpanded: true,
            items: methods
                .map(
                  (m) => DropdownMenuItem(
                    value: m,
                    child: Text(m.isEmpty ? 'Unspecified method' : m),
                  ),
                )
                .toList(),
            onChanged: (m) => setState(() => method = m!),
          ),
        const SizedBox(height: 12),
        if (series.length > 1) ...[
          SizedBox(
            height: 140,
            child: CustomPaint(
              painter: _MeasurementChart(
                series
                    .map(
                      (r) => (
                        DateTime.parse(
                          r.date,
                        ).millisecondsSinceEpoch.toDouble(),
                        r.displayValue(store.unit, unit),
                      ),
                    )
                    .toList(),
                color: BrandColors.cyan,
              ),
            ),
          ),
          Text(
            '${series.map((r) => r.date).reduce((a, b) => a.compareTo(b) < 0 ? a : b)} to ${series.map((r) => r.date).reduce((a, b) => a.compareTo(b) > 0 ? a : b)} • ${series.first.displayUnit(store.unit, unit)}',
            style: const TextStyle(color: BrandColors.muted),
          ),
        ],
        if (metric == BodyMetric.bodyFat)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Estimates from different methods are shown separately. Repeatability does not guarantee accuracy.',
            ),
          ),
        if (rows.isEmpty)
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              'No entries yet. Add only the measurements you want to track.',
            ),
          ),
        for (final r in rows)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              '${bodyNumber(r.displayValue(store.unit, unit))} ${r.displayUnit(store.unit, unit)}',
            ),
            subtitle: Text(
              '${r.date} • ${r.source == 'manual' ? 'Manual' : r.source}\n${r.method}${r.preferred ? ' • Selected for this day' : ''}',
            ),
            isThreeLine: true,
            trailing: PopupMenuButton<String>(
              onSelected: (action) async {
                try {
                  if (action == 'delete') {
                    final confirm = await confirmBodyDelete(
                      context,
                      'Delete this measurement from Progression Lab? Imported source data is not deleted.',
                    );
                    if (confirm)
                      await store.saveBodyMeasurements(
                        store.bodyMeasurements
                            .where((v) => v.id != r.id)
                            .toList(),
                      );
                  }
                  if (action == 'edit')
                    await showBodyMeasurementEditor(
                      context,
                      store,
                      existing: r,
                    );
                  if (action == 'prefer')
                    await store.saveBodyMeasurements(
                      store.bodyMeasurements
                          .map(
                            (v) =>
                                v.metric == BodyMetric.weight &&
                                    v.date == r.date
                                ? v.withPreferred(v.id == r.id)
                                : v,
                          )
                          .toList(),
                    );
                  if (mounted) setState(() {});
                } on Object catch (e) {
                  if (context.mounted) bodyError(context, e);
                }
              },
              itemBuilder: (_) => [
                if (r.source == 'manual')
                  const PopupMenuItem(value: 'edit', child: Text('Edit')),
                if (r.metric == BodyMetric.weight)
                  const PopupMenuItem(
                    value: 'prefer',
                    child: Text('Use for this day'),
                  ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Text('Delete local entry'),
                ),
              ],
            ),
          ),
        OutlinedButton.icon(
          onPressed: () async {
            await showBodyMeasurementEditor(context, store, metric: metric);
            if (mounted) setState(() {});
          },
          icon: const Icon(Icons.add),
          label: const Text('Add measurement'),
        ),
      ],
    );
  }
}

class _MeasurementChart extends CustomPainter {
  _MeasurementChart(this.values, {required this.color});
  final List<(double, double)> values;
  final Color color;
  @override
  void paint(Canvas canvas, Size s) {
    if (values.isEmpty) return;
    final sorted = [...values]..sort((a, b) => a.$1.compareTo(b.$1));
    final min = values.map((v) => v.$2).reduce((a, b) => a < b ? a : b);
    final max = values.map((v) => v.$2).reduce((a, b) => a > b ? a : b);
    final span = (max - min).abs() < .01 ? 1.0 : max - min;
    final timeSpan = sorted.last.$1 - sorted.first.$1;
    final path = Path();
    for (final (i, v) in sorted.indexed) {
      final p = Offset(
        16 +
            (timeSpan == 0 ? 0.5 : (v.$1 - sorted.first.$1) / timeSpan) *
                (s.width - 32),
        s.height - 20 - (v.$2 - min) / span * (s.height - 40),
      );
      if (i == 0)
        path.moveTo(p.dx, p.dy);
      else
        path.lineTo(p.dx, p.dy);
      canvas.drawCircle(p, 3, Paint()..color = color);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke,
    );
    final label = TextPainter(
      text: TextSpan(
        text: '${bodyNumber(min)} – ${bodyNumber(max)}',
        style: TextStyle(color: color, fontSize: 11),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    label.paint(canvas, Offset.zero);
  }

  @override
  bool shouldRepaint(covariant _MeasurementChart old) => true;
}

Future<bool> confirmBodyDelete(BuildContext context, String message) async =>
    await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete entry?'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    ) ??
    false;

Future<void> showBodyMeasurementEditor(
  BuildContext context,
  AppStore store, {
  BodyMeasurement? existing,
  BodyMetric metric = BodyMetric.weight,
  DateTime? day,
}) async {
  var selected = existing?.metric ?? metric;
  var date = existing == null
      ? (day ?? DateTime.now())
      : DateTime.parse(existing.date);
  final length = store.bodySettings['lengthUnit'] as String? ?? 'cm';
  final input = TextEditingController(
    text: existing == null
        ? ''
        : bodyNumber(existing.displayValue(store.unit, length)),
  );
  final initialInput = input.text;
  final method = TextEditingController(text: existing?.method ?? '');
  String? error;
  bool busy = false;
  await showDialog<void>(
    context: context,
    builder: (dialog) => StatefulBuilder(
      builder: (c, set) => AlertDialog(
        title: const Text('Body measurement'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<BodyMetric>(
                initialValue: selected,
                isExpanded: true,
                items: BodyMetric.values
                    .map(
                      (m) => DropdownMenuItem(value: m, child: Text(m.label)),
                    )
                    .toList(),
                onChanged: existing != null
                    ? null
                    : (m) => set(() => selected = m!),
              ),
              TextButton.icon(
                onPressed: () async {
                  final d = await showDatePicker(
                    context: c,
                    initialDate: date,
                    firstDate: DateTime(1900),
                    lastDate: DateTime.now(),
                  );
                  if (d != null) set(() => date = d);
                },
                icon: const Icon(Icons.calendar_today, size: 18),
                label: Text(bodyDay(date)),
              ),
              TextField(
                controller: input,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: selected.unit == 'kg'
                      ? store.unit
                      : selected.unit == 'cm'
                      ? length
                      : '%',
                  errorText: error,
                ),
              ),
              if (selected == BodyMetric.waist)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text(
                    'Measure midway between your lowest rib and top of the hip, after a normal breath out. Keep the tape level.',
                  ),
                ),
              if (selected == BodyMetric.bodyFat)
                TextField(
                  controller: method,
                  decoration: const InputDecoration(
                    labelText: 'Method or device (required)',
                    hintText: 'For example, DXA or your scale model',
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: busy ? null : () => Navigator.pop(dialog),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: busy
                ? null
                : () async {
                    final v = double.tryParse(
                      input.text.trim().replaceAll(',', '.'),
                    );
                    if (v == null ||
                        !v.isFinite ||
                        v <= 0 ||
                        (selected == BodyMetric.bodyFat &&
                            (v > 100 || method.text.trim().isEmpty))) {
                      set(
                        () => error =
                            'Enter a valid value and measurement method.',
                      );
                      return;
                    }
                    set(() => busy = true);
                    final unit = selected.unit == 'kg'
                        ? store.unit
                        : selected.unit == 'cm'
                        ? length
                        : '%';
                    final value = BodyMeasurement(
                      id: existing?.id ?? bodyId(),
                      metric: selected,
                      value: existing != null && input.text == initialInput
                          ? existing.value
                          : BodyMeasurement.canonical(selected, v, unit),
                      date: bodyDay(date),
                      recordedAt: DateTime(date.year, date.month, date.day, 12),
                      method: selected == BodyMetric.waist
                          ? 'Rib-hip midpoint'
                          : selected == BodyMetric.bodyFat
                          ? method.text.trim()
                          : 'Manual',
                      originalValue: v,
                      originalUnit: unit,
                      checkInId: existing?.checkInId ?? '',
                      revision: (existing?.revision ?? 0) + 1,
                      preferred: existing?.preferred ?? false,
                    );
                    try {
                      await store.saveBodyMeasurements([
                        ...store.bodyMeasurements.where(
                          (r) => r.id != value.id,
                        ),
                        value,
                      ]);
                      if (dialog.mounted) Navigator.pop(dialog);
                    } on Object {
                      if (c.mounted)
                        set(() {
                          busy = false;
                          error =
                              'Could not save. Your previous entry is unchanged.';
                        });
                    }
                  },
            child: Text(busy ? 'Saving…' : 'Save'),
          ),
        ],
      ),
    ),
  );
  input.dispose();
  method.dispose();
}

class BodyCheckInEditor extends StatefulWidget {
  const BodyCheckInEditor({
    super.key,
    required this.store,
    this.checkIn,
    this.resume = false,
  });
  final AppStore store;
  final BodyCheckIn? checkIn;
  final bool resume;
  @override
  State<BodyCheckInEditor> createState() => _BodyCheckInEditorState();
}

class _BodyCheckInEditorState extends State<BodyCheckInEditor> {
  BodyMediaStore get media => widget.store.bodyMedia;
  late String id;
  late DateTime date;
  List<BodyPhoto> photos = [];
  final notes = TextEditingController(), setup = TextEditingController();
  final values = <BodyMetric, TextEditingController>{};
  final bodyFatMethod = TextEditingController();
  final initialValues = <BodyMetric, String>{};
  String? error;
  bool busy = false;
  bool finished = false;
  Timer? debounce;
  Future<void> draftWrite = Future.value();
  late String length;
  late String weightUnit;
  @override
  void initState() {
    super.initState();
    final draft = widget.resume ? media.draft : null;
    final entry = widget.checkIn;
    length =
        draft?['lengthUnit'] as String? ??
        widget.store.bodySettings['lengthUnit'] as String? ??
        'cm';
    weightUnit = draft?['weightUnit'] as String? ?? widget.store.unit;
    id = draft?['id'] as String? ?? entry?.id ?? bodyId();
    date = DateTime.parse(
      draft?['date'] as String? ?? entry?.date ?? bodyDay(DateTime.now()),
    );
    photos = draft == null
        ? [...?entry?.photos]
        : (draft['photos'] as List? ?? [])
              .whereType<Map>()
              .map((j) => BodyPhoto.fromJson(Map<String, dynamic>.from(j)))
              .toList();
    notes.text = draft?['notes'] as String? ?? entry?.notes ?? '';
    setup.text = draft?['setup'] as String? ?? entry?.setup ?? '';
    for (final m in BodyMetric.values) {
      final r = widget.store.bodyMeasurements
          .where((r) => r.checkInId == id && r.metric == m)
          .firstOrNull;
      final v = draft?['values'] is Map ? draft!['values'][m.name] : null;
      values[m] = TextEditingController(
        text: v is String
            ? v
            : r == null
            ? ''
            : bodyNumber(r.displayValue(weightUnit, length)),
      );
      initialValues[m] = values[m]!.text;
      values[m]!.addListener(queueDraft);
      if (m == BodyMetric.bodyFat)
        bodyFatMethod.text =
            draft?['bodyFatMethod'] as String? ?? r?.method ?? '';
    }
    notes.addListener(queueDraft);
    setup.addListener(queueDraft);
    bodyFatMethod.addListener(queueDraft);
  }

  Map<String, dynamic> get draft => {
    'id': id,
    'date': bodyDay(date),
    'photos': photos.map((p) => p.toJson()).toList(),
    'notes': notes.text,
    'setup': setup.text,
    'values': {
      for (final entry in values.entries) entry.key.name: entry.value.text,
    },
    'bodyFatMethod': bodyFatMethod.text,
    'weightUnit': weightUnit,
    'lengthUnit': length,
  };
  void queueDraft() {
    if (busy) return;
    debounce?.cancel();
    debounce = Timer(const Duration(milliseconds: 400), persistDraft);
  }

  Future<void> persistDraft() {
    final value = draft;
    draftWrite = draftWrite
        .catchError((Object _) {})
        .then((_) => media.save({...media.journal, 'draft': value}));
    return draftWrite.catchError((Object e) {
      if (mounted)
        setState(
          () => error =
              'The draft could not be saved. Keep this screen open and try again.',
        );
    });
  }

  @override
  void dispose() {
    debounce?.cancel();
    for (final c in values.values) c.dispose();
    notes.dispose();
    setup.dispose();
    bodyFatMethod.dispose();
    super.dispose();
  }

  Future<void> addPhoto(bool camera) async {
    if (busy) return;
    setState(() => busy = true);
    debounce?.cancel();
    await persistDraft();
    try {
      String? path;
      if (camera) {
        if (!mounted) return;
        path = await Navigator.push<String>(
          context,
          bodyRoute(
            media,
            (_) => BodyCameraScreen(
              reference: photos.isNotEmpty
                  ? media.path(photos.last)
                  : media.checkIns
                            .expand((c) => c.photos)
                            .where(
                              (p) => p.view == 'Front' && p.pose == 'Relaxed',
                            )
                            .firstOrNull ==
                        null
                  ? null
                  : media.path(
                      media.checkIns
                          .expand((c) => c.photos)
                          .firstWhere(
                            (p) => p.view == 'Front' && p.pose == 'Relaxed',
                          ),
                    ),
            ),
          ),
        );
      } else {
        path = (await ImagePicker().pickImage(
          source: ImageSource.gallery,
          requestFullMetadata: false,
        ))?.path;
      }
      if (path != null) {
        final photo = await media.importPhoto(path);
        if (mounted) setState(() => photos.add(photo));
        await persistDraft();
      }
    } on Object catch (e) {
      if (mounted) bodyError(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> save() async {
    if (busy) return;
    final measurements = <BodyMeasurement>[];
    for (final (m, c) in values.entries.map((e) => (e.key, e.value))) {
      if (c.text.trim().isEmpty) continue;
      final v = double.tryParse(c.text.trim().replaceAll(',', '.'));
      if (v == null ||
          !v.isFinite ||
          v <= 0 ||
          (m == BodyMetric.bodyFat &&
              (v > 100 || bodyFatMethod.text.trim().isEmpty))) {
        setState(
          () => error =
              'Check ${m.label.toLowerCase()}${m == BodyMetric.bodyFat ? ' and its method' : ''}.',
        );
        return;
      }
      final unit = m.unit == 'kg'
          ? weightUnit
          : m.unit == 'cm'
          ? length
          : '%';
      final previous = widget.store.bodyMeasurements
          .where((r) => r.checkInId == id && r.metric == m)
          .firstOrNull;
      measurements.add(
        BodyMeasurement(
          id: previous?.id ?? '$id-${m.name}',
          metric: m,
          value: previous != null && c.text == initialValues[m]
              ? previous.value
              : BodyMeasurement.canonical(m, v, unit),
          date: bodyDay(date),
          recordedAt: DateTime(date.year, date.month, date.day, 12),
          checkInId: id,
          originalValue: v,
          originalUnit: unit,
          method: m == BodyMetric.waist
              ? 'Rib-hip midpoint'
              : m == BodyMetric.bodyFat
              ? bodyFatMethod.text.trim()
              : 'Manual',
          revision: (previous?.revision ?? 0) + 1,
        ),
      );
    }
    if (photos.isEmpty && measurements.isEmpty && notes.text.trim().isEmpty) {
      setState(() => error = 'Add a photo, a measurement, or a note.');
      return;
    }
    setState(() => busy = true);
    debounce?.cancel();
    final next = BodyCheckIn(
      id: id,
      date: bodyDay(date),
      photos: photos,
      notes: notes.text.trim(),
      setup: setup.text.trim(),
    );
    try {
      await persistDraft();
      await draftWrite;
      await widget.store.commitBodyJournal(
        [
          ...widget.store.bodyMeasurements.where((r) => r.checkInId != id),
          ...measurements,
        ],
        {
          ...media.journal,
          'draft': null,
          'checkIns': [
            ...media.checkIns.where((c) => c.id != id).map((c) => c.toJson()),
            next.toJson(),
          ],
        },
      );
      finished = true;
      if (mounted) Navigator.pop(context);
    } on Object catch (e) {
      if (mounted) {
        bodyError(context, e);
        setState(() => busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    onPopInvokedWithResult: (didPop, result) {
      if (didPop && !finished) {
        debounce?.cancel();
        persistDraft();
      }
    },
    child: Scaffold(
      appBar: AppBar(
        title: Text(widget.checkIn == null ? 'New check-in' : 'Edit check-in'),
        actions: [
          TextButton(
            onPressed: busy ? null : save,
            child: Text(busy ? 'Saving…' : 'Save'),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextButton.icon(
              onPressed: busy
                  ? null
                  : () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: date,
                        firstDate: DateTime(1900),
                        lastDate: DateTime.now(),
                      );
                      if (d != null) {
                        setState(() => date = d);
                        queueDraft();
                      }
                    },
              icon: const Icon(Icons.calendar_today),
              label: Text(bodyDay(date)),
            ),
            const Text(
              'Everything below is optional. Photos and notes stay private on this device until you choose to export or share.',
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: busy ? null : () => addPhoto(true),
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: const Text('Take photo'),
                ),
                OutlinedButton.icon(
                  onPressed: busy ? null : () => addPhoto(false),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Import photo'),
                ),
              ],
            ),
            for (final (i, p) in photos.indexed) ...[
              const SizedBox(height: 20),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 280),
                  child: BodyPhotoFrame(photo: p, path: media.path(p)),
                ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: p.view,
                decoration: const InputDecoration(labelText: 'View'),
                items: ['Front', 'Left side', 'Right side', 'Back', 'Other']
                    .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                    .toList(),
                onChanged: (v) {
                  setState(() => photos[i] = p.edit({'view': v}));
                  queueDraft();
                },
              ),
              DropdownButtonFormField<String>(
                initialValue: p.pose,
                decoration: const InputDecoration(labelText: 'Pose'),
                items: ['Relaxed', 'Flexed', 'Seated', 'Other']
                    .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                    .toList(),
                onChanged: (v) {
                  setState(() => photos[i] = photos[i].edit({'pose': v}));
                  queueDraft();
                },
              ),
              Wrap(
                children: [
                  TextButton.icon(
                    onPressed: () async {
                      final edited = await editBodyPhoto(
                        context,
                        photos[i],
                        media.path(p),
                        media: media,
                      );
                      if (edited != null) {
                        setState(() => photos[i] = edited);
                        queueDraft();
                      }
                    },
                    icon: const Icon(Icons.crop),
                    label: const Text('Frame / cover'),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() => photos.removeAt(i));
                      queueDraft();
                    },
                    child: const Text('Remove photo'),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 22),
            Text('Measurements', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            for (final m in [BodyMetric.weight, BodyMetric.waist]) _field(m),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('More measurements'),
              children: [
                for (final m in BodyMetric.values.where(
                  (m) => m != BodyMetric.weight && m != BodyMetric.waist,
                ))
                  _field(m),
                TextField(
                  controller: bodyFatMethod,
                  decoration: const InputDecoration(
                    labelText: 'Body-fat method or device',
                    hintText: 'Required only with a body-fat estimate',
                  ),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Waist: use the midpoint between the lowest rib and top of the hip, after a normal breath out. Keep the method consistent.',
                style: TextStyle(color: BrandColors.muted),
              ),
            ),
            TextField(
              controller: setup,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Photo setup (optional)',
                hintText: 'Lighting, camera position, clothing, pose',
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: notes,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Private note (optional)',
              ),
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: busy ? null : save,
              child: Text(busy ? 'Saving…' : 'Save check-in'),
            ),
            TextButton(
              onPressed: busy
                  ? null
                  : () async {
                      final confirmed = await confirmBodyDelete(
                        context,
                        widget.checkIn == null
                            ? 'Discard this unfinished check-in?'
                            : 'Delete these app photos and the private note? Linked measurements stay in your history. Shared or exported copies are unaffected.',
                      );
                      if (!confirmed) return;
                      debounce?.cancel();
                      await draftWrite;
                      await widget.store
                          .commitBodyJournal(widget.store.bodyMeasurements, {
                            ...media.journal,
                            'draft': null,
                            'checkIns': media.checkIns
                                .where((c) => c.id != id)
                                .map((c) => c.toJson())
                                .toList(),
                          });
                      finished = true;
                      if (context.mounted) Navigator.pop(context);
                    },
              child: Text(
                widget.checkIn == null ? 'Discard draft' : 'Delete check-in',
              ),
            ),
          ],
        ),
      ),
    ),
  );
  Widget _field(BodyMetric m) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      controller: values[m],
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText:
            '${m.label} (${m.unit == 'kg'
                ? weightUnit
                : m.unit == 'cm'
                ? length
                : '%'})',
      ),
    ),
  );
}

class BodyCompareScreen extends StatefulWidget {
  const BodyCompareScreen({super.key, required this.store});
  final AppStore store;
  @override
  State<BodyCompareScreen> createState() => _BodyCompareScreenState();
}

class _BodyCompareScreenState extends State<BodyCompareScreen> {
  late List<BodyCheckIn> entries = _entries();
  List<BodyCheckIn> _entries() {
    final checks = [...widget.store.bodyMedia.checkIns];
    final dates = checks.map((c) => c.date).toSet();
    for (final r in widget.store.bodyMeasurements) {
      if (dates.add(r.date))
        checks.add(BodyCheckIn(id: 'day-${r.date}', date: r.date));
    }
    if (checks.isEmpty)
      checks.add(BodyCheckIn(id: 'today', date: bodyDay(DateTime.now())));
    return checks..sort((a, b) => a.date.compareTo(b.date));
  }

  late BodyCheckIn first = entries.first, last = entries.last;
  String? pair;
  bool overlay = false;
  double opacity = .5;
  @override
  Widget build(BuildContext context) {
    final pairs = first.photos
        .map((p) => '${p.view} • ${p.pose}')
        .where((key) => last.photos.any((p) => '${p.view} • ${p.pose}' == key))
        .toSet()
        .toList();
    if (!pairs.contains(pair)) pair = pairs.firstOrNull;
    BodyPhoto? photo(BodyCheckIn c) =>
        c.photos.where((p) => '${p.view} • ${p.pose}' == pair).firstOrNull;
    final a = photo(first), b = photo(last);
    final media = widget.store.bodyMedia;
    Widget tile(BodyPhoto p) => BodyPhotoFrame(photo: p, path: media.path(p));
    return Scaffold(
      appBar: AppBar(title: const Text('Compare and share')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Match the view and pose. Framing and lighting can still affect appearance.',
            ),
            const SizedBox(height: 14),
            _dateChoice('Earlier', first, (v) => setState(() => first = v)),
            const SizedBox(height: 12),
            _dateChoice('Latest', last, (v) => setState(() => last = v)),
            const SizedBox(height: 12),
            if (pairs.isNotEmpty)
              DropdownButtonFormField<String>(
                key: ValueKey(pair),
                initialValue: pair,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Matching view and pose',
                ),
                items: pairs
                    .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                    .toList(),
                onChanged: (p) => setState(() => pair = p),
              ),
            if (a == null || b == null)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'Choose check-ins with a matching view and pose for a photo comparison, or make a share image without photos.',
                ),
              )
            else ...[
              const SizedBox(height: 18),
              if (overlay)
                Stack(
                  children: [
                    tile(a),
                    Opacity(opacity: opacity, child: tile(b)),
                  ],
                )
              else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(children: [tile(a), Text(first.date)]),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(children: [tile(b), Text(last.date)]),
                    ),
                  ],
                ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Overlay comparison'),
                value: overlay,
                onChanged: (v) => setState(() => overlay = v),
              ),
              if (overlay)
                Slider(
                  label: 'Latest photo ${(opacity * 100).round()}%',
                  value: opacity,
                  onChanged: (v) => setState(() => opacity = v),
                ),
              if (first.date.compareTo(last.date) > 0)
                const Text(
                  'Choose the earlier date first before creating a comparison.',
                ),
              FilledButton.icon(
                onPressed: first.date.compareTo(last.date) > 0
                    ? null
                    : () => Navigator.push(
                        context,
                        bodyRoute(
                          media,
                          (_) => BodyShareScreen(
                            store: widget.store,
                            first: first,
                            last: last,
                            firstPhoto: a,
                            lastPhoto: b,
                          ),
                        ),
                      ),
                icon: const Icon(Icons.ios_share),
                label: const Text('Create share image'),
              ),
            ],
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: first.date.compareTo(last.date) > 0
                  ? null
                  : () => Navigator.push(
                      context,
                      bodyRoute(
                        media,
                        (_) => BodyShareScreen(
                          store: widget.store,
                          first: first,
                          last: last,
                        ),
                      ),
                    ),
              icon: const Icon(Icons.insights),
              label: const Text('Create image without photos'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dateChoice(
    String label,
    BodyCheckIn value,
    void Function(BodyCheckIn) change,
  ) => DropdownButtonFormField<String>(
    initialValue: value.id,
    isExpanded: true,
    decoration: InputDecoration(labelText: label),
    items: entries
        .map(
          (c) => DropdownMenuItem(
            value: c.id,
            child: Text('${c.date} • ${c.photos.length} views'),
          ),
        )
        .toList(),
    onChanged: (id) => change(entries.firstWhere((c) => c.id == id)),
  );
}

class BodySettingsScreen extends StatefulWidget {
  const BodySettingsScreen({super.key, required this.store});
  final AppStore store;
  @override
  State<BodySettingsScreen> createState() => _BodySettingsScreenState();
}

class _BodySettingsScreenState extends State<BodySettingsScreen> {
  bool busy = false;
  AppStore get store => widget.store;
  BodyMediaStore get media => store.bodyMedia;
  Future<void> run(Future<void> Function() action) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await action();
    } on Object catch (e) {
      if (mounted) bodyError(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> setting(String key, Object value) => run(
    () => store.saveBodyMeasurements(
      store.bodyMeasurements,
      settings: {...store.bodySettings, key: value},
    ),
  );
  Future<void> archive(bool restore) async {
    final password = TextEditingController();
    final repeat = TextEditingController();
    bool includePhotos = true;
    String? error;
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialog) => StatefulBuilder(
        builder: (context, set) => AlertDialog(
          title: Text(
            restore ? 'Restore body backup' : 'Encrypted body backup',
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  restore
                      ? 'Photos, check-ins, and measurements are merged by their saved IDs. Matching records are replaced.'
                      : 'Includes measurements and private notes. Keep the password: it cannot be reset. This backup is separate from workout backups.',
                ),
                TextField(
                  controller: password,
                  obscureText: true,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: InputDecoration(
                    labelText: 'Backup password',
                    errorText: error,
                  ),
                ),
                if (!restore) ...[
                  TextField(
                    controller: repeat,
                    obscureText: true,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: const InputDecoration(
                      labelText: 'Repeat password',
                    ),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Include progress photos'),
                    value: includePhotos,
                    onChanged: (v) => set(() => includePhotos = v),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (password.text.length < 10 ||
                    (!restore && password.text != repeat.text)) {
                  set(
                    () => error =
                        'Use 10 or more characters and matching passwords.',
                  );
                  return;
                }
                Navigator.pop(dialog, true);
              },
              child: const Text('Choose file'),
            ),
          ],
        ),
      ),
    );
    if (approved == true)
      await run(() async {
        if (restore) {
          final result = await media.importArchive(password.text);
          if (result == null) return;
          final bundle = Map<String, dynamic>.from(result['bundle'] as Map);
          final token = result['token'] as String;
          try {
            final imported = (bundle['measurements'] as List)
                .whereType<Map>()
                .map(
                  (j) => BodyMeasurement.fromJson(Map<String, dynamic>.from(j)),
                )
                .toList();
            final j = Map<String, dynamic>.from(bundle['journal'] as Map);
            final checks = (j['checkIns'] as List)
                .whereType<Map>()
                .map((c) => BodyCheckIn.fromJson(Map<String, dynamic>.from(c)))
                .toList();
            final ids = imported.map((r) => r.id).toSet(),
                checkIds = checks.map((c) => c.id).toSet();
            await store.commitBodyJournal(
              [
                ...store.bodyMeasurements.where((r) => !ids.contains(r.id)),
                ...imported,
              ],
              {
                ...media.journal,
                'checkIns': [
                  ...media.checkIns
                      .where((c) => !checkIds.contains(c.id))
                      .map((c) => c.toJson()),
                  ...checks.map(
                    (c) => {
                      ...c.toJson(),
                      if (bundle['photosIncluded'] == false &&
                          media.checkIns.any((old) => old.id == c.id))
                        'photos': media.checkIns
                            .firstWhere((old) => old.id == c.id)
                            .photos
                            .map((p) => p.toJson())
                            .toList(),
                    },
                  ),
                ],
              },
              token: token,
              settings: normalizeBodySettings(
                Map<String, dynamic>.from(
                  bundle['settings'] as Map? ?? store.bodySettings,
                ),
              ),
            );
          } on Object {
            await media.discardImport(token);
            rethrow;
          }
        } else {
          final path = await media.exportArchive(
            {
              'measurements': store.bodyMeasurements
                  .map((r) => r.toJson())
                  .toList(),
              'settings': store.bodySettings,
            },
            password.text,
            photos: includePhotos,
          );
          if (path == null) return;
          await media.save({
            ...media.journal,
            'lastBackup': bodyDay(DateTime.now()),
          });
        }
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                restore
                    ? 'Body backup restored.'
                    : 'Encrypted body backup saved.',
              ),
            ),
          );
      });
    password.dispose();
    repeat.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Body settings and backup')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (busy) const LinearProgressIndicator(),
          for (final (key, label) in [
            ('showWeight', 'Show weight trends'),
            ('showWaist', 'Show waist'),
            ('showBmi', 'Show BMI'),
            ('showRatio', 'Show waist-to-height ratio'),
          ])
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(label),
              value:
                  store.bodySettings[key] as bool? ??
                  (key == 'showWeight' || key == 'showWaist'),
              onChanged: busy ? null : (v) => setting(key, v),
            ),
          if (store.bodySettings['showBmi'] == true)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('I am age 20 or above'),
              subtitle: const Text(
                'Enable CDC adult category labels. BMI still cannot separate muscle from fat.',
              ),
              value: store.bodySettings['adult20'] == true,
              onChanged: busy ? null : (v) => setting('adult20', v),
            ),
          DropdownButtonFormField<String>(
            initialValue: store.bodySettings['lengthUnit'] as String? ?? 'cm',
            decoration: const InputDecoration(labelText: 'Length units'),
            items: ['cm', 'in']
                .map(
                  (v) => DropdownMenuItem(
                    value: v,
                    child: Text(v == 'cm' ? 'Centimetres' : 'Inches'),
                  ),
                )
                .toList(),
            onChanged: busy ? null : (v) => setting('lengthUnit', v!),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue:
                store.bodySettings['weightSource'] as String? ?? 'manual',
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Preferred weight source',
            ),
            items:
                {
                      'manual',
                      ...store.bodyMeasurements
                          .where((r) => r.metric == BodyMetric.weight)
                          .map((r) => r.source),
                      if (store.bodySettings['weightSource'] is String)
                        store.bodySettings['weightSource'] as String,
                    }
                    .map(
                      (v) => DropdownMenuItem(
                        value: v,
                        child: Text(
                          v == 'manual' ? 'Manual entries' : v,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
            onChanged: busy ? null : (v) => setting('weightSource', v!),
          ),
          const SizedBox(height: 18),
          DropdownButtonFormField<String>(
            initialValue: store.bodySettings['goal'] as String? ?? 'No target',
            decoration: const InputDecoration(labelText: 'My focus'),
            items: [
              'No target',
              'Gain',
              'Lose',
              'Maintain',
              'Performance',
            ].map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
            onChanged: busy ? null : (v) => setting('goal', v!),
          ),
          const Divider(height: 36),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Lock body photos with my device lock'),
            subtitle: const Text(
              'Uses your phone’s biometric or screen lock. Photos stay in private app storage.',
            ),
            value: media.lockEnabled,
            onChanged: busy
                ? null
                : (v) => run(() async {
                    if (await media.unlock())
                      await media.save({...media.journal, 'lockEnabled': v});
                  }),
          ),
          DropdownButtonFormField<int>(
            key: ValueKey(media.reminderDays),
            initialValue: media.reminderDays,
            decoration: const InputDecoration(
              labelText: 'Optional check-in reminder',
            ),
            items: [0, 7, 14, 30]
                .map(
                  (d) => DropdownMenuItem(
                    value: d,
                    child: Text(d == 0 ? 'Off' : 'Every $d days'),
                  ),
                )
                .toList(),
            onChanged: busy ? null : (d) => run(() => media.setReminder(d!)),
          ),
          const Divider(height: 36),
          Text(
            'Photos and backup',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 10),
          Text(
            '${media.checkIns.fold(0, (n, c) => n + c.photos.length)} saved photos • ${store.bodyMeasurements.length} measurements\nLast body backup: ${media.lastBackup ?? 'Not yet created'}',
          ),
          const SizedBox(height: 10),
          const Text(
            'Photos and private notes are excluded from automatic backup. Uninstalling the app removes them. Make an encrypted body backup to move or keep these records.',
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: busy ? null : () => archive(false),
            icon: const Icon(Icons.enhanced_encryption_outlined),
            label: const Text('Export body backup'),
          ),
          OutlinedButton.icon(
            onPressed: busy ? null : () => archive(true),
            icon: const Icon(Icons.restore),
            label: const Text('Restore body backup'),
          ),
          const Divider(height: 36),
          Text('Health Connect', style: Theme.of(context).textTheme.titleLarge),
          const Text(
            'Import selected measurements only. Imported records retain their source; the app does not send imported readings back as new measurements.',
          ),
          for (final (key, label) in [
            ('healthWeight', 'Weight'),
            ('healthHeight', 'Height'),
            ('healthFat', 'Body-fat estimates'),
          ])
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(label),
              value: store.bodySettings[key] == true,
              onChanged: busy ? null : (v) => setting(key, v!),
            ),
          OutlinedButton.icon(
            onPressed: busy
                ? null
                : () => run(() async {
                    final types = <String>[
                      if (store.bodySettings['healthWeight'] == true)
                        'bodyWeight',
                      if (store.bodySettings['healthHeight'] == true) 'height',
                      if (store.bodySettings['healthFat'] == true)
                        'bodyFatPercentage',
                    ];
                    if (types.isEmpty)
                      throw StateError('Select at least one measurement type.');
                    final service = HealthSyncService();
                    final granted = await service.requestBodyAuthorization(
                      types,
                    );
                    if (!granted)
                      throw StateError(
                        'The selected Health Connect access was not granted.',
                      );
                    final now = DateTime.now(),
                        start = DateTime.now().subtract(
                          const Duration(days: 29),
                        );
                    final result = await service.syncBodyMetrics(
                      start: start,
                      end: now,
                      types: types,
                      tokens: Map<String, String>.from(
                        store.bodySettings['healthTokens'] as Map? ?? {},
                      ),
                    );
                    service.dispose();
                    final incoming = (result['records'] as List)
                        .whereType<Map>()
                        .map(
                          (m) => measurementFromHealth(
                            Map<String, dynamic>.from(m),
                          ),
                        )
                        .whereType<BodyMeasurement>()
                        .toList();
                    final covered = (result['refreshedTypes'] as List)
                        .map(
                          (t) => switch (t) {
                            'bodyWeight' => BodyMetric.weight,
                            'height' => BodyMetric.height,
                            _ => BodyMetric.bodyFat,
                          },
                        )
                        .toSet();
                    final deleted = (result['deletedIds'] as List)
                        .cast<String>()
                        .toSet();
                    final ids = incoming.map((r) => r.id).toSet();
                    final kept = store.bodyMeasurements
                        .where(
                          (r) =>
                              !ids.contains(r.id) &&
                              !deleted.contains(r.sourceId) &&
                              !(r.sourceId.isNotEmpty &&
                                  covered.contains(r.metric) &&
                                  !r.recordedAt.isBefore(start) &&
                                  r.recordedAt.isBefore(now)),
                        )
                        .toList();
                    await store.saveBodyMeasurements(
                      [...kept, ...incoming],
                      settings: {
                        ...store.bodySettings,
                        'healthTokens': {
                          ...Map<String, dynamic>.from(
                            store.bodySettings['healthTokens'] as Map? ?? {},
                          ),
                          ...Map<String, dynamic>.from(result['tokens'] as Map),
                        },
                        'healthLastSync': now.toIso8601String(),
                      },
                    );
                    if (mounted)
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Measurements synced, including source updates and deletions.',
                          ),
                        ),
                      );
                  }),
            icon: const Icon(Icons.sync),
            label: const Text('Sync measurements'),
          ),
          const Text(
            'First sync imports the last 29 days. Later syncs apply source changes, including deletions. After 30 days without syncing, recent history is refreshed; older source changes may be unavailable. Photos and circumference records stay local.',
            style: TextStyle(color: BrandColors.muted),
          ),
        ],
      ),
    ),
  );
}
