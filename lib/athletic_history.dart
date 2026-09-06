class AthleticSessionDraft {
  const AthleticSessionDraft({
    required this.sessionId,
    required this.programRun,
    required this.week,
    required this.sessionIndex,
    required this.startedAt,
    this.completedDrills = const [],
    this.notes = '',
  });
  final String sessionId;
  final int programRun;
  final int week;
  final int sessionIndex;
  final DateTime startedAt;
  final List<int> completedDrills;
  final String notes;
  Map<String, dynamic> toJson() => {
    'sessionId': sessionId,
    'programRun': programRun,
    'week': week,
    'sessionIndex': sessionIndex,
    'startedAt': startedAt.toIso8601String(),
    'completedDrills': completedDrills,
    'notes': notes,
  };
  factory AthleticSessionDraft.fromJson(Map<String, dynamic> j) =>
      AthleticSessionDraft(
        sessionId: j['sessionId'] as String,
        programRun: j['programRun'] as int,
        week: j['week'] as int,
        sessionIndex: j['sessionIndex'] as int,
        startedAt: DateTime.parse(j['startedAt'] as String),
        completedDrills: (j['completedDrills'] as List? ?? [])
            .whereType<int>()
            .toSet()
            .toList(),
        notes: j['notes'] as String? ?? '',
      );
}

class AthleticSessionRecord {
  const AthleticSessionRecord({
    required this.programRun,
    required this.week,
    required this.sessionIndex,
    required this.completedAt,
    required this.effort,
    this.notes = '',
    this.sessionId,
    this.completedDrills,
    this.status = 'completed',
    this.startedAt,
    this.durationSeconds = 0,
  });

  final int programRun;
  final int week;
  final int sessionIndex;
  final DateTime completedAt;
  final int effort;
  final String notes;
  final String? sessionId;
  final List<int>? completedDrills;
  final String status;
  final DateTime? startedAt;
  final int durationSeconds;
  bool get isComplete => status == 'completed';

  Map<String, dynamic> toJson() => {
    'programRun': programRun,
    'week': week,
    'sessionIndex': sessionIndex,
    'completedAt': completedAt.toIso8601String(),
    'effort': effort,
    'notes': notes,
    if (sessionId != null) 'sessionId': sessionId,
    'completedDrills': completedDrills,
    'status': status,
    'durationSeconds': durationSeconds,
    if (startedAt != null) 'startedAt': startedAt!.toIso8601String(),
  };

  factory AthleticSessionRecord.fromJson(Map<String, dynamic> json) =>
      AthleticSessionRecord(
        programRun: _int(json['programRun'], fallback: 1),
        week: _int(json['week'], fallback: 1),
        sessionIndex: _int(json['sessionIndex'], fallback: 0),
        completedAt: DateTime.parse(json['completedAt'] as String),
        effort: _int(json['effort'], fallback: 5),
        completedDrills: json['completedDrills'] is List
            ? (json['completedDrills'] as List).whereType<int>().toList()
            : null,
        status: json['status'] as String? ?? 'completed',
        startedAt: DateTime.tryParse('${json['startedAt']}'),
        durationSeconds: _int(json['durationSeconds'], fallback: 0),
        notes: json['notes'] is String ? json['notes'] as String : '',
        sessionId: json['sessionId'] is String
            ? json['sessionId'] as String
            : null,
      );
}

class AthleticAssessment {
  const AthleticAssessment({
    required this.programRun,
    required this.recordedAt,
    this.leftBalanceSeconds,
    this.rightBalanceSeconds,
    this.broadJumpCentimeters,
    this.sprint10MetersSeconds,
    this.changeOfDirection505Seconds,
    this.movementQuality = 3,
    this.notes = '',
  });

  final int programRun;
  final DateTime recordedAt;
  final double? leftBalanceSeconds;
  final double? rightBalanceSeconds;
  final double? broadJumpCentimeters;
  final double? sprint10MetersSeconds;
  final double? changeOfDirection505Seconds;
  final int movementQuality;
  final String notes;

  Map<String, dynamic> toJson() => {
    'programRun': programRun,
    'recordedAt': recordedAt.toIso8601String(),
    if (leftBalanceSeconds != null) 'leftBalanceSeconds': leftBalanceSeconds,
    if (rightBalanceSeconds != null) 'rightBalanceSeconds': rightBalanceSeconds,
    if (broadJumpCentimeters != null)
      'broadJumpCentimeters': broadJumpCentimeters,
    if (sprint10MetersSeconds != null)
      'sprint10MetersSeconds': sprint10MetersSeconds,
    if (changeOfDirection505Seconds != null)
      'changeOfDirection505Seconds': changeOfDirection505Seconds,
    'movementQuality': movementQuality,
    'notes': notes,
  };

  factory AthleticAssessment.fromJson(Map<String, dynamic> json) =>
      AthleticAssessment(
        programRun: _int(json['programRun'], fallback: 1),
        recordedAt: DateTime.parse(json['recordedAt'] as String),
        leftBalanceSeconds: _double(json['leftBalanceSeconds']),
        rightBalanceSeconds: _double(json['rightBalanceSeconds']),
        broadJumpCentimeters: _double(json['broadJumpCentimeters']),
        sprint10MetersSeconds: _double(json['sprint10MetersSeconds']),
        changeOfDirection505Seconds: _double(
          json['changeOfDirection505Seconds'],
        ),
        movementQuality: _int(json['movementQuality'], fallback: 3),
        notes: json['notes'] is String ? json['notes'] as String : '',
      );
}

int _int(Object? value, {required int fallback}) {
  if (value is int) return value;
  if (value is num && value.isFinite) return value.toInt();
  return fallback;
}

double? _double(Object? value) {
  if (value is num && value.isFinite) return value.toDouble();
  return null;
}
