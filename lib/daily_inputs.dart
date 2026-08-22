import 'dart:math' as math;

String createRecordId(String prefix) =>
    '$prefix-${DateTime.now().microsecondsSinceEpoch}-${math.Random().nextInt(1 << 20)}';

DateTime dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

bool sameLocalDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

class SupplementPreset {
  const SupplementPreset({
    required this.id,
    required this.name,
    required this.dose,
    required this.unit,
    required this.createdAt,
    required this.updatedAt,
    this.brand = '',
    this.caffeineMg = 0,
    this.archived = false,
  });

  final String id;
  final String name;
  final String brand;
  final double dose;
  final String unit;
  final double caffeineMg;
  final bool archived;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get containsCreatine => name.toLowerCase().contains('creatine');

  SupplementPreset copyWith({
    String? name,
    String? brand,
    double? dose,
    String? unit,
    double? caffeineMg,
    bool? archived,
    DateTime? updatedAt,
  }) => SupplementPreset(
    id: id,
    name: name ?? this.name,
    brand: brand ?? this.brand,
    dose: dose ?? this.dose,
    unit: unit ?? this.unit,
    caffeineMg: caffeineMg ?? this.caffeineMg,
    archived: archived ?? this.archived,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'brand': brand,
    'dose': dose,
    'unit': unit,
    'caffeineMg': caffeineMg,
    'archived': archived,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory SupplementPreset.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now();
    return SupplementPreset(
      id: _string(json['id']),
      name: _string(json['name']),
      brand: _string(json['brand']),
      dose: _double(json['dose']) ?? 0,
      unit: _string(json['unit'], fallback: 'serving'),
      caffeineMg: _double(json['caffeineMg']) ?? 0,
      archived: json['archived'] == true,
      createdAt: _date(json['createdAt']) ?? now,
      updatedAt: _date(json['updatedAt']) ?? now,
    );
  }

  static List<SupplementPreset> defaults({DateTime? now}) {
    final created = now ?? DateTime.now();
    return [
      SupplementPreset(
        id: 'preset-creatine',
        name: 'Creatine',
        dose: 5,
        unit: 'g',
        createdAt: created,
        updatedAt: created,
      ),
      SupplementPreset(
        id: 'preset-coffee',
        name: 'Coffee',
        dose: 1,
        unit: 'serving',
        caffeineMg: 180,
        createdAt: created,
        updatedAt: created,
      ),
      SupplementPreset(
        id: 'preset-preworkout',
        name: 'Pre-workout',
        dose: 1,
        unit: 'scoop',
        caffeineMg: 250,
        createdAt: created,
        updatedAt: created,
      ),
      SupplementPreset(
        id: 'preset-electrolytes',
        name: 'Electrolytes',
        dose: 1,
        unit: 'serving',
        createdAt: created,
        updatedAt: created,
      ),
      SupplementPreset(
        id: 'preset-protein',
        name: 'Protein shake',
        dose: 30,
        unit: 'g protein',
        createdAt: created,
        updatedAt: created,
      ),
    ];
  }
}

class SupplementEvent {
  const SupplementEvent({
    required this.id,
    required this.name,
    required this.dose,
    required this.unit,
    required this.takenAt,
    required this.createdAt,
    required this.updatedAt,
    this.presetId,
    this.brand = '',
    this.caffeineMg = 0,
    this.notes = '',
    this.workoutSessionId,
  });

  final String id;
  final String? presetId;
  final String name;
  final String brand;
  final double dose;
  final String unit;
  final double caffeineMg;
  final DateTime takenAt;
  final String notes;
  final String? workoutSessionId;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get containsCreatine => name.toLowerCase().contains('creatine');

  SupplementEvent copyWith({
    String? name,
    String? brand,
    double? dose,
    String? unit,
    double? caffeineMg,
    DateTime? takenAt,
    String? notes,
    String? workoutSessionId,
    DateTime? updatedAt,
  }) => SupplementEvent(
    id: id,
    presetId: presetId,
    name: name ?? this.name,
    brand: brand ?? this.brand,
    dose: dose ?? this.dose,
    unit: unit ?? this.unit,
    caffeineMg: caffeineMg ?? this.caffeineMg,
    takenAt: takenAt ?? this.takenAt,
    notes: notes ?? this.notes,
    workoutSessionId: workoutSessionId ?? this.workoutSessionId,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    if (presetId != null) 'presetId': presetId,
    'name': name,
    'brand': brand,
    'dose': dose,
    'unit': unit,
    'caffeineMg': caffeineMg,
    'takenAt': takenAt.toIso8601String(),
    'notes': notes,
    if (workoutSessionId != null) 'workoutSessionId': workoutSessionId,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory SupplementEvent.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now();
    return SupplementEvent(
      id: _string(json['id']),
      presetId: _nullableString(json['presetId']),
      name: _string(json['name']),
      brand: _string(json['brand']),
      dose: _double(json['dose']) ?? 0,
      unit: _string(json['unit'], fallback: 'serving'),
      caffeineMg: _double(json['caffeineMg']) ?? 0,
      takenAt: _date(json['takenAt']) ?? now,
      notes: _string(json['notes']),
      workoutSessionId: _nullableString(json['workoutSessionId']),
      createdAt: _date(json['createdAt']) ?? now,
      updatedAt: _date(json['updatedAt']) ?? now,
    );
  }
}

enum MealSize { small, medium, large }

enum MealTiming { general, preWorkout, postWorkout }

class MealEvent {
  const MealEvent({
    required this.id,
    required this.occurredAt,
    required this.createdAt,
    required this.updatedAt,
    this.name = 'Meal',
    this.size = MealSize.medium,
    this.timing = MealTiming.general,
    this.calories,
    this.proteinGrams,
    this.carbohydrateGrams,
    this.fatGrams,
    this.notes = '',
    this.workoutSessionId,
  });

  final String id;
  final String name;
  final DateTime occurredAt;
  final MealSize size;
  final MealTiming timing;
  final double? calories;
  final double? proteinGrams;
  final double? carbohydrateGrams;
  final double? fatGrams;
  final String notes;
  final String? workoutSessionId;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'occurredAt': occurredAt.toIso8601String(),
    'size': size.name,
    'timing': timing.name,
    if (calories != null) 'calories': calories,
    if (proteinGrams != null) 'proteinGrams': proteinGrams,
    if (carbohydrateGrams != null) 'carbohydrateGrams': carbohydrateGrams,
    if (fatGrams != null) 'fatGrams': fatGrams,
    'notes': notes,
    if (workoutSessionId != null) 'workoutSessionId': workoutSessionId,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory MealEvent.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now();
    return MealEvent(
      id: _string(json['id']),
      name: _string(json['name'], fallback: 'Meal'),
      occurredAt: _date(json['occurredAt']) ?? now,
      size: _enumByName(MealSize.values, json['size']) ?? MealSize.medium,
      timing:
          _enumByName(MealTiming.values, json['timing']) ?? MealTiming.general,
      calories: _double(json['calories']),
      proteinGrams: _double(json['proteinGrams']),
      carbohydrateGrams: _double(json['carbohydrateGrams']),
      fatGrams: _double(json['fatGrams']),
      notes: _string(json['notes']),
      workoutSessionId: _nullableString(json['workoutSessionId']),
      createdAt: _date(json['createdAt']) ?? now,
      updatedAt: _date(json['updatedAt']) ?? now,
    );
  }
}

class HydrationEvent {
  const HydrationEvent({
    required this.id,
    required this.occurredAt,
    required this.amountMl,
    required this.createdAt,
    required this.updatedAt,
    this.electrolytes = false,
    this.notes = '',
  });

  final String id;
  final DateTime occurredAt;
  final double amountMl;
  final bool electrolytes;
  final String notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'occurredAt': occurredAt.toIso8601String(),
    'amountMl': amountMl,
    'electrolytes': electrolytes,
    'notes': notes,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory HydrationEvent.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now();
    return HydrationEvent(
      id: _string(json['id']),
      occurredAt: _date(json['occurredAt']) ?? now,
      amountMl: _double(json['amountMl']) ?? 0,
      electrolytes: json['electrolytes'] == true,
      notes: _string(json['notes']),
      createdAt: _date(json['createdAt']) ?? now,
      updatedAt: _date(json['updatedAt']) ?? now,
    );
  }
}

class RecoveryCheckIn {
  const RecoveryCheckIn({
    required this.id,
    required this.localDate,
    required this.createdAt,
    required this.updatedAt,
    this.sleepHours,
    this.sleepQuality,
    this.stress,
    this.soreness,
    this.bodyWeight,
    this.weightUnit,
    this.illness = false,
    this.notes = '',
  });

  final String id;
  final DateTime localDate;
  final double? sleepHours;
  final int? sleepQuality;
  final int? stress;
  final int? soreness;
  final double? bodyWeight;
  final String? weightUnit;
  final bool illness;
  final String notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'localDate': dateOnly(localDate).toIso8601String(),
    if (sleepHours != null) 'sleepHours': sleepHours,
    if (sleepQuality != null) 'sleepQuality': sleepQuality,
    if (stress != null) 'stress': stress,
    if (soreness != null) 'soreness': soreness,
    if (bodyWeight != null) 'bodyWeight': bodyWeight,
    if (weightUnit != null) 'weightUnit': weightUnit,
    'illness': illness,
    'notes': notes,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory RecoveryCheckIn.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now();
    return RecoveryCheckIn(
      id: _string(json['id']),
      localDate: dateOnly(_date(json['localDate']) ?? now),
      sleepHours: _double(json['sleepHours']),
      sleepQuality: _rating(json['sleepQuality']),
      stress: _rating(json['stress']),
      soreness: _rating(json['soreness']),
      bodyWeight: _double(json['bodyWeight']),
      weightUnit: _nullableString(json['weightUnit']),
      illness: json['illness'] == true,
      notes: _string(json['notes']),
      createdAt: _date(json['createdAt']) ?? now,
      updatedAt: _date(json['updatedAt']) ?? now,
    );
  }
}

class WorkoutResponse {
  const WorkoutResponse({
    required this.id,
    required this.workoutSessionId,
    required this.recordedAt,
    required this.energy,
    required this.focus,
    required this.pump,
    required this.effort,
    required this.discomfort,
    required this.createdAt,
    required this.updatedAt,
    this.track = 'strength',
    this.notes = '',
  });

  final String id;
  final String workoutSessionId;
  final String track;
  final DateTime recordedAt;
  final int energy;
  final int focus;
  final int pump;
  final int effort;
  final int discomfort;
  final String notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'workoutSessionId': workoutSessionId,
    'track': track,
    'recordedAt': recordedAt.toIso8601String(),
    'energy': energy,
    'focus': focus,
    'pump': pump,
    'effort': effort,
    'discomfort': discomfort,
    'notes': notes,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory WorkoutResponse.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now();
    return WorkoutResponse(
      id: _string(json['id']),
      workoutSessionId: _string(json['workoutSessionId']),
      track: _string(json['track'], fallback: 'strength'),
      recordedAt: _date(json['recordedAt']) ?? now,
      energy: _rating(json['energy']) ?? 3,
      focus: _rating(json['focus']) ?? 3,
      pump: _rating(json['pump']) ?? 3,
      effort: _rating(json['effort']) ?? 3,
      discomfort: _rating(json['discomfort']) ?? 1,
      notes: _string(json['notes']),
      createdAt: _date(json['createdAt']) ?? now,
      updatedAt: _date(json['updatedAt']) ?? now,
    );
  }
}

enum LabDataDomain {
  workouts,
  supplements,
  meals,
  hydration,
  recovery,
  bodyMetrics,
  athletic,
}

class LabMessage {
  const LabMessage({
    required this.id,
    required this.role,
    required this.text,
    required this.createdAt,
  });

  final String id;
  final String role;
  final String text;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'role': role,
    'text': text,
    'createdAt': createdAt.toIso8601String(),
  };

  factory LabMessage.fromJson(Map<String, dynamic> json) => LabMessage(
    id: _string(json['id']),
    role: _string(json['role'], fallback: 'assistant'),
    text: _string(json['text']),
    createdAt: _date(json['createdAt']) ?? DateTime.now(),
  );
}

String _string(Object? value, {String fallback = ''}) =>
    value is String ? value : fallback;

String? _nullableString(Object? value) =>
    value is String && value.isNotEmpty ? value : null;

double? _double(Object? value) =>
    value is num && value.isFinite ? value.toDouble() : null;

int? _rating(Object? value) {
  if (value is! num || !value.isFinite) return null;
  return value.toInt().clamp(1, 5);
}

DateTime? _date(Object? value) {
  if (value is! String) return null;
  return DateTime.tryParse(value);
}

T? _enumByName<T extends Enum>(Iterable<T> values, Object? raw) {
  if (raw is! String) return null;
  for (final value in values) {
    if (value.name == raw) return value;
  }
  return null;
}
