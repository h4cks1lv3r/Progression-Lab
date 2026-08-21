class AthleticSessionRecord {
  const AthleticSessionRecord({
    required this.programRun,
    required this.week,
    required this.sessionIndex,
    required this.completedAt,
    required this.effort,
    this.notes = '',
    this.sessionId,
  });

  final int programRun;
  final int week;
  final int sessionIndex;
  final DateTime completedAt;
  final int effort;
  final String notes;
  final String? sessionId;

  Map<String, dynamic> toJson() => {
    'programRun': programRun,
    'week': week,
    'sessionIndex': sessionIndex,
    'completedAt': completedAt.toIso8601String(),
    'effort': effort,
    'notes': notes,
    if (sessionId != null) 'sessionId': sessionId,
  };

  factory AthleticSessionRecord.fromJson(Map<String, dynamic> json) =>
      AthleticSessionRecord(
        programRun: _int(json['programRun'], fallback: 1),
        week: _int(json['week'], fallback: 1),
        sessionIndex: _int(json['sessionIndex'], fallback: 0),
        completedAt: DateTime.parse(json['completedAt'] as String),
        effort: _int(json['effort'], fallback: 5),
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
    if (leftBalanceSeconds != null)
      'leftBalanceSeconds': leftBalanceSeconds,
    if (rightBalanceSeconds != null)
      'rightBalanceSeconds': rightBalanceSeconds,
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
