import 'dart:math' as math;

enum BodyMetric {
  weight('Weight', 'kg'),
  waist('Waist', 'cm'),
  height('Height', 'cm'),
  hips('Hips', 'cm'),
  chest('Chest', 'cm'),
  leftArm('Left upper arm', 'cm'),
  rightArm('Right upper arm', 'cm'),
  leftThigh('Left thigh', 'cm'),
  rightThigh('Right thigh', 'cm'),
  bodyFat('Body fat estimate', '%');

  const BodyMetric(this.label, this.unit);
  final String label;
  final String unit;
}

String bodyDay(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
String bodyId() =>
    '${DateTime.now().microsecondsSinceEpoch}-${math.Random.secure().nextInt(1 << 32)}';

class BodyMeasurement {
  const BodyMeasurement({
    required this.id,
    required this.metric,
    required this.value,
    required this.date,
    required this.recordedAt,
    this.source = 'manual',
    this.sourceId = '',
    this.method = '',
    this.checkInId = '',
    this.originalUnit = '',
    this.originalValue,
    this.revision = 1,
    this.preferred = false,
  });
  final String id, date, source, sourceId, method, checkInId, originalUnit;
  final BodyMetric metric;
  final double value;
  final double? originalValue;
  final DateTime recordedAt;
  final int revision;
  final bool preferred;
  bool get valid =>
      value.isFinite &&
      value > 0 &&
      (metric != BodyMetric.bodyFat || value <= 100) &&
      RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date) &&
      DateTime.tryParse(date) != null &&
      bodyDay(DateTime.parse(date)) == date &&
      id.isNotEmpty;
  Map<String, dynamic> toJson() => {
    'id': id,
    'metric': metric.name,
    'value': value,
    'date': date,
    'recordedAt': recordedAt.toIso8601String(),
    'source': source,
    'sourceId': sourceId,
    'method': method,
    'checkInId': checkInId,
    'originalUnit': originalUnit,
    'originalValue': originalValue,
    'revision': revision,
    'preferred': preferred,
  };
  factory BodyMeasurement.fromJson(Map<String, dynamic> j) => BodyMeasurement(
    id: j['id'] as String,
    metric: BodyMetric.values.byName(j['metric'] as String),
    value: (j['value'] as num).toDouble(),
    date: j['date'] as String,
    recordedAt: DateTime.parse(j['recordedAt'] as String),
    source: j['source'] as String? ?? 'manual',
    sourceId: j['sourceId'] as String? ?? '',
    method: j['method'] as String? ?? '',
    checkInId: j['checkInId'] as String? ?? '',
    originalUnit: j['originalUnit'] as String? ?? '',
    originalValue: (j['originalValue'] as num?)?.toDouble(),
    revision: (j['revision'] as num?)?.toInt() ?? 1,
    preferred: j['preferred'] == true,
  );
  BodyMeasurement withPreferred(bool v) =>
      BodyMeasurement.fromJson({...toJson(), 'preferred': v});
  double displayValue(String weightUnit, String lengthUnit) =>
      metric == BodyMetric.weight
      ? (weightUnit == 'lb' ? value / .45359237 : value)
      : metric.unit == 'cm' && lengthUnit == 'in'
      ? value / 2.54
      : value;
  String displayUnit(String weightUnit, String lengthUnit) =>
      metric == BodyMetric.weight
      ? weightUnit
      : metric.unit == 'cm'
      ? lengthUnit
      : '%';
  static double canonical(BodyMetric m, double v, String unit) =>
      m == BodyMetric.weight && unit == 'lb'
      ? v * .45359237
      : m.unit == 'cm' && unit == 'in'
      ? v * 2.54
      : v;
}

class BodyTrend {
  const BodyTrend(this.start, this.end, this.readings);
  final DateTime start, end;
  final List<BodyMeasurement> readings;
  int get days => readings.length;
  double? get mean =>
      days < 3 ? null : readings.fold(0.0, (s, r) => s + r.value) / days;
}

abstract final class BodyAnalysis {
  static List<BodyMeasurement> dailyWeights(
    Iterable<BodyMeasurement> all, {
    String source = 'manual',
  }) {
    final grouped = <String, List<BodyMeasurement>>{};
    for (final r in all.where(
      (r) => r.metric == BodyMetric.weight && r.valid,
    )) {
      grouped.putIfAbsent(r.date, () => []).add(r);
    }
    final result = <BodyMeasurement>[];
    for (final day in grouped.values) {
      day.sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
      final selected =
          day.where((r) => r.preferred).firstOrNull ??
          day.where((r) => r.source == source).firstOrNull ??
          day.where((r) => r.source == 'manual').firstOrNull;
      if (selected != null) result.add(selected);
    }
    return result..sort((a, b) => a.date.compareTo(b.date));
  }

  static BodyTrend window(
    Iterable<BodyMeasurement> all,
    DateTime end, {
    String source = 'manual',
  }) {
    final finish = DateTime(end.year, end.month, end.day);
    final start = DateTime(finish.year, finish.month, finish.day - 6);
    return BodyTrend(
      start,
      finish,
      dailyWeights(all, source: source)
          .where(
            (r) =>
                r.date.compareTo(bodyDay(start)) >= 0 &&
                r.date.compareTo(bodyDay(finish)) <= 0,
          )
          .toList(),
    );
  }

  static BodyMeasurement? atOrBefore(
    Iterable<BodyMeasurement> all,
    BodyMetric type,
    String date,
  ) {
    final values =
        all
            .where(
              (r) => r.metric == type && r.valid && r.date.compareTo(date) <= 0,
            )
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));
    return values.firstOrNull;
  }

  static double? bmi(BodyMeasurement weight, Iterable<BodyMeasurement> all) {
    final height = atOrBefore(all, BodyMetric.height, weight.date);
    return height == null
        ? null
        : weight.value / math.pow(height.value / 100, 2);
  }

  static String? bmiCategory(double value, {required bool adult20}) => !adult20
      ? null
      : value < 18.5
      ? 'Below adult reference range'
      : value < 25
      ? 'Within adult reference range'
      : value < 30
      ? 'Above adult reference range'
      : 'BMI obesity category';
}

/// Idempotent conversion of old recovery and integration values. No dates or
/// units are inferred from the current clock; source ambiguity is preserved.
List<BodyMeasurement> migrateBodyMeasurements(Map<String, dynamic> state) {
  if (state['bodyMeasurements'] is List) {
    return (state['bodyMeasurements'] as List)
        .whereType<Map>()
        .map((j) => BodyMeasurement.fromJson(Map<String, dynamic>.from(j)))
        .where((r) => r.valid)
        .toList();
  }
  final values = <BodyMeasurement>[];
  for (final raw
      in (state['recoveryCheckIns'] as List? ?? const []).whereType<Map>()) {
    final v = raw['bodyWeight'];
    final date = DateTime.tryParse('${raw['localDate']}');
    final unit = raw['weightUnit'] ?? state['unit'];
    if (v is! num || date == null || !['kg', 'lb'].contains(unit)) continue;
    final r = BodyMeasurement(
      id: 'recovery-${raw['id']}',
      metric: BodyMetric.weight,
      value: BodyMeasurement.canonical(
        BodyMetric.weight,
        v.toDouble(),
        '$unit',
      ),
      date: bodyDay(date),
      recordedAt: date,
      originalValue: v.toDouble(),
      originalUnit: '$unit',
      method: 'Legacy recovery entry',
    );
    if (r.valid) values.add(r);
  }
  final integrations = state['integrationState'] is Map
      ? state['integrationState']['integrations']
      : null;
  final metrics = integrations is Map
      ? integrations['healthBodyMetrics']
      : null;
  for (final raw in (metrics is List ? metrics : const []).whereType<Map>()) {
    final r = measurementFromHealth(Map<String, dynamic>.from(raw));
    if (r != null && !values.any((v) => v.id == r.id)) values.add(r);
  }
  return values;
}

BodyMeasurement? measurementFromHealth(Map<String, dynamic> j) {
  final metric = switch (j['type']) {
    'bodyWeight' => BodyMetric.weight,
    'bodyFatPercentage' => BodyMetric.bodyFat,
    'height' => BodyMetric.height,
    _ => null,
  };
  final date = DateTime.tryParse('${j['recordedAt']}');
  if (metric == null || date == null || j['value'] is! num) return null;
  final origin = '${j['source'] ?? ''}';
  final sourceId = '${j['recordId'] ?? ''}';
  final unit = '${j['unit'] ?? metric.unit}';
  final v = (j['value'] as num).toDouble();
  final result = BodyMeasurement(
    id: sourceId.isNotEmpty
        ? 'health-$origin-$sourceId'
        : 'health-$origin-${metric.name}-${date.toIso8601String()}',
    metric: metric,
    value: BodyMeasurement.canonical(metric, v, unit),
    date:
        (j['localDate'] is String && DateTime.tryParse(j['localDate']) != null)
        ? j['localDate']
        : bodyDay(date.toLocal()),
    recordedAt: date,
    source: origin.isEmpty ? 'manual' : origin,
    sourceId: sourceId,
    method: '${j['method'] ?? 'Imported estimate'}',
    originalValue: v,
    originalUnit: unit,
    revision: (j['revision'] as num?)?.toInt() ?? 1,
  );
  return result.valid ? result : null;
}

Map<String, dynamic> normalizeBodySettings(Map<String, dynamic> source) => {
  for (final key in [
    'showWeight',
    'showWaist',
    'showBmi',
    'showRatio',
    'adult20',
    'healthWeight',
    'healthHeight',
    'healthFat',
  ])
    if (source[key] is bool) key: source[key],
  'lengthUnit': source['lengthUnit'] == 'in' ? 'in' : 'cm',
  'weightSource': source['weightSource'] is String
      ? source['weightSource']
      : 'manual',
  'goal':
      [
        'No target',
        'Gain',
        'Lose',
        'Maintain',
        'Performance',
      ].contains(source['goal'])
      ? source['goal']
      : 'No target',
};
