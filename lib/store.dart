import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'athletic_history.dart';
import 'athletic_program.dart';
import 'daily_inputs.dart';
import 'exercise_library.dart';
import 'program.dart';

enum TrainingTrack { strength, athletic }

class SetLog {
  SetLog({
    required this.exercise,
    required this.weight,
    required this.reps,
    required this.date,
    required this.workout,
    this.notes = '',
    this.sessionId,
    this.exerciseIndex,
  });
  final String exercise;
  final double weight;
  final int reps;
  final DateTime date;
  final String workout;
  final String notes;
  final String? sessionId;
  final int? exerciseIndex;
  double get e1rm => weight * (1 + reps / 30);

  SetLog copyWith({
    String? exercise,
    double? weight,
    int? reps,
    DateTime? date,
    String? workout,
    String? notes,
    String? sessionId,
    int? exerciseIndex,
  }) => SetLog(
    exercise: exercise ?? this.exercise,
    weight: weight ?? this.weight,
    reps: reps ?? this.reps,
    date: date ?? this.date,
    workout: workout ?? this.workout,
    notes: notes ?? this.notes,
    sessionId: sessionId ?? this.sessionId,
    exerciseIndex: exerciseIndex ?? this.exerciseIndex,
  );

  Map<String, dynamic> toJson() => {
    'e': exercise,
    'w': weight,
    'r': reps,
    'd': date.toIso8601String(),
    'o': workout,
    'n': notes,
    if (sessionId != null) 's': sessionId,
    if (exerciseIndex != null) 'i': exerciseIndex,
  };
  factory SetLog.fromJson(Map<String, dynamic> j) => SetLog(
    exercise: j['e'],
    weight: (j['w'] as num).toDouble(),
    reps: j['r'],
    date: DateTime.parse(j['d']),
    workout: j['o'],
    notes: j['n'] is String ? j['n'] as String : '',
    sessionId: j['s'] is String ? j['s'] as String : null,
    exerciseIndex: j['i'] is num ? (j['i'] as num).toInt() : null,
  );
}

enum WorkoutStatus { completed, skipped }

class WorkoutRecord {
  const WorkoutRecord({
    required this.week,
    required this.workoutIndex,
    required this.workout,
    required this.date,
    required this.status,
    this.programRun = 1,
    this.days = 4,
    DateTime? scheduledDate,
    DateTime? loggedAt,
    this.retroactive = false,
    this.sessionId,
    this.substitutions = const {},
  }) : scheduledDate = scheduledDate ?? date,
       loggedAt = loggedAt ?? date;

  final int week;
  final int workoutIndex;
  final String workout;
  final DateTime date;
  final WorkoutStatus status;
  final int programRun;
  final int days;
  final DateTime scheduledDate;
  final DateTime loggedAt;
  final bool retroactive;
  final String? sessionId;
  final Map<int, String> substitutions;

  Map<String, dynamic> toJson() => {
    'week': week,
    'workoutIndex': workoutIndex,
    'workout': workout,
    'date': date.toIso8601String(),
    'status': status.name,
    'programRun': programRun,
    'days': days,
    'scheduledDate': scheduledDate.toIso8601String(),
    'loggedAt': loggedAt.toIso8601String(),
    'retroactive': retroactive,
    if (sessionId != null) 'sessionId': sessionId,
    'substitutions': {
      for (final entry in substitutions.entries) '${entry.key}': entry.value,
    },
  };

  factory WorkoutRecord.fromJson(Map<String, dynamic> json) => WorkoutRecord(
    week: json['week'] as int,
    workoutIndex: json['workoutIndex'] as int,
    workout: json['workout'] as String,
    date: DateTime.parse(json['date'] as String),
    status: WorkoutStatus.values.byName(json['status'] as String),
    programRun: json['programRun'] is num
        ? (json['programRun'] as num).toInt()
        : 1,
    days: json['days'] is num ? (json['days'] as num).toInt() : 4,
    scheduledDate: json['scheduledDate'] is String
        ? DateTime.parse(json['scheduledDate'] as String)
        : null,
    loggedAt: json['loggedAt'] is String
        ? DateTime.parse(json['loggedAt'] as String)
        : null,
    retroactive: json['retroactive'] == true,
    sessionId: json['sessionId'] is String ? json['sessionId'] as String : null,
    substitutions: _readSubstitutions(json['substitutions']),
  );

  static Map<int, String> _readSubstitutions(Object? value) {
    if (value is! Map) return const {};
    return {
      for (final entry in value.entries)
        if (int.tryParse('${entry.key}') case final int index)
          if (entry.value is String) index: entry.value as String,
    };
  }
}

class DraftSetInput {
  const DraftSetInput({
    required this.week,
    required this.workoutIndex,
    required this.workout,
    required this.exerciseIndex,
    required this.setNumber,
    required this.sessionId,
    required this.weight,
    required this.reps,
    required this.notes,
    this.programRun = 1,
    this.days = 4,
    this.retroactive = false,
    this.scheduledDate,
    this.substitutions = const {},
  });

  final int week;
  final int workoutIndex;
  final String workout;
  final int exerciseIndex;
  final int setNumber;
  final String sessionId;
  final String weight;
  final String reps;
  final String notes;
  final int programRun;
  final int days;
  final bool retroactive;
  final DateTime? scheduledDate;
  final Map<int, String> substitutions;

  Map<String, dynamic> toJson() => {
    'week': week,
    'workoutIndex': workoutIndex,
    'workout': workout,
    'exerciseIndex': exerciseIndex,
    'setNumber': setNumber,
    'sessionId': sessionId,
    'weight': weight,
    'reps': reps,
    'notes': notes,
    'programRun': programRun,
    'days': days,
    'retroactive': retroactive,
    if (scheduledDate != null)
      'scheduledDate': scheduledDate!.toIso8601String(),
    'substitutions': {
      for (final entry in substitutions.entries) '${entry.key}': entry.value,
    },
  };

  factory DraftSetInput.fromJson(Map<String, dynamic> json) => DraftSetInput(
    week: json['week'] as int,
    workoutIndex: json['workoutIndex'] as int,
    workout: json['workout'] as String,
    exerciseIndex: json['exerciseIndex'] as int,
    setNumber: json['setNumber'] as int,
    sessionId: json['sessionId'] as String,
    weight: json['weight'] as String,
    reps: json['reps'] as String,
    notes: json['notes'] is String ? json['notes'] as String : '',
    programRun: json['programRun'] is num
        ? (json['programRun'] as num).toInt()
        : 1,
    days: json['days'] is num ? (json['days'] as num).toInt() : 4,
    retroactive: json['retroactive'] == true,
    scheduledDate: json['scheduledDate'] is String
        ? DateTime.parse(json['scheduledDate'] as String)
        : null,
    substitutions: WorkoutRecord._readSubstitutions(json['substitutions']),
  );
}

class AppStore extends ChangeNotifier {
  static const _channel = MethodChannel('iron_cadence/storage');
  static const int schemaVersion = 10;
  static const double poundsToKilograms = 0.45359237;
  bool isLoaded = false;
  int days = 4;
  int week = 1;
  int workoutIndex = 0;
  String unit = 'lb';
  List<SetLog> logs = [];
  List<WorkoutRecord> workoutHistory = [];
  List<CustomExercise> customExercises = [];
  DraftSetInput? draft;
  List<DraftSetInput> drafts = [];
  DateTime programStartDate = _dateOnly(DateTime.now());
  int strengthProgramRun = 1;

  int athleticProgramRun = 1;
  int athleticWeek = 1;
  int athleticSessionIndex = 0;
  DateTime athleticStartDate = _dateOnly(DateTime.now());
  List<AthleticSessionRecord> athleticHistory = [];
  List<AthleticAssessment> athleticAssessments = [];
  int onboardingVersionSeen = 0;
  TrainingTrack preferredTrack = TrainingTrack.strength;

  List<SupplementPreset> supplementPresets = SupplementPreset.defaults();
  List<SupplementEvent> supplementEvents = [];
  List<MealEvent> mealEvents = [];
  List<HydrationEvent> hydrationEvents = [];
  List<RecoveryCheckIn> recoveryCheckIns = [];
  List<WorkoutResponse> workoutResponses = [];
  bool aiAnalysisEnabled = false;
  Set<LabDataDomain> labDataDomains = Set.of(LabDataDomain.values);
  List<LabMessage> labMessages = [];

  Future<void> load() async {
    try {
      final raw = await _channel.invokeMethod<String>('read');
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          final original = Map<String, dynamic>.from(decoded);
          final originalVersion = _readInt(original['schemaVersion']) ?? 1;
          final data = _migrate(original);
          final storedDays = _readInt(data['days']) ?? 4;
          days = ProgramEngine.isSupportedDays(storedDays) ? storedDays : 4;
          week = ProgramEngine.clampWeek(_readInt(data['week']) ?? 1);
          workoutIndex = ProgramEngine.clampWorkoutIndex(
            _readInt(data['workout']) ?? 0,
            days,
          );
          final storedUnit = data['unit'];
          unit = storedUnit == 'kg' ? 'kg' : 'lb';
          final storedLogs = data['logs'];
          if (storedLogs is List) {
            logs = storedLogs.map(_readLog).whereType<SetLog>().toList();
          }
          final storedWorkouts = data['workoutHistory'];
          if (storedWorkouts is List) {
            workoutHistory = storedWorkouts
                .map(_readWorkout)
                .whereType<WorkoutRecord>()
                .toList();
          }
          final storedCustomExercises = data['customExercises'];
          if (storedCustomExercises is List) {
            customExercises = storedCustomExercises
                .map(_readCustomExercise)
                .whereType<CustomExercise>()
                .toList();
          }
          draft = _readDraft(data['draft']);
          final storedDrafts = data['drafts'];
          if (storedDrafts is List) {
            drafts = storedDrafts
                .map(_readDraft)
                .whereType<DraftSetInput>()
                .toList();
          }
          if (draft != null &&
              !drafts.any((item) => item.sessionId == draft!.sessionId)) {
            drafts.add(draft!);
          }
          programStartDate = data['programStartDate'] is String
              ? DateTime.parse(data['programStartDate'] as String)
              : _inferredProgramStartDate();
          strengthProgramRun = (_readInt(data['strengthProgramRun']) ?? 1)
              .clamp(1, 1000000)
              .toInt();
          athleticProgramRun = (_readInt(data['athleticProgramRun']) ?? 1)
              .clamp(1, 1000000)
              .toInt();
          athleticWeek = (_readInt(data['athleticWeek']) ?? 1)
              .clamp(1, AthleticProgram.totalWeeks)
              .toInt();
          athleticSessionIndex = (_readInt(data['athleticSessionIndex']) ?? 0)
              .clamp(0, AthleticProgram.sessionsPerWeek - 1)
              .toInt();
          athleticStartDate = data['athleticStartDate'] is String
              ? DateTime.parse(data['athleticStartDate'] as String)
              : _dateOnly(DateTime.now());
          final storedAthleticHistory = data['athleticHistory'];
          if (storedAthleticHistory is List) {
            athleticHistory = storedAthleticHistory
                .map(_readAthleticRecord)
                .whereType<AthleticSessionRecord>()
                .toList();
          }
          final storedAthleticAssessments = data['athleticAssessments'];
          if (storedAthleticAssessments is List) {
            athleticAssessments = storedAthleticAssessments
                .map(_readAthleticAssessment)
                .whereType<AthleticAssessment>()
                .toList();
          }
          onboardingVersionSeen = (_readInt(data['onboardingVersionSeen']) ?? 0)
              .clamp(0, 1000000)
              .toInt();
          preferredTrack = switch (data['preferredTrack']) {
            'athletic' => TrainingTrack.athletic,
            _ => TrainingTrack.strength,
          };
          final storedPresets = data['supplementPresets'];
          if (storedPresets is List) {
            supplementPresets = storedPresets
                .map(_readSupplementPreset)
                .whereType<SupplementPreset>()
                .toList();
          }
          if (supplementPresets.isEmpty) {
            supplementPresets = SupplementPreset.defaults();
          }
          final storedSupplementEvents = data['supplementEvents'];
          if (storedSupplementEvents is List) {
            supplementEvents = storedSupplementEvents
                .map(_readSupplementEvent)
                .whereType<SupplementEvent>()
                .toList();
          }
          final storedMeals = data['mealEvents'];
          if (storedMeals is List) {
            mealEvents = storedMeals
                .map(_readMealEvent)
                .whereType<MealEvent>()
                .toList();
          }
          final storedHydration = data['hydrationEvents'];
          if (storedHydration is List) {
            hydrationEvents = storedHydration
                .map(_readHydrationEvent)
                .whereType<HydrationEvent>()
                .toList();
          }
          final storedRecovery = data['recoveryCheckIns'];
          if (storedRecovery is List) {
            recoveryCheckIns = storedRecovery
                .map(_readRecoveryCheckIn)
                .whereType<RecoveryCheckIn>()
                .toList();
          }
          final storedResponses = data['workoutResponses'];
          if (storedResponses is List) {
            workoutResponses = storedResponses
                .map(_readWorkoutResponse)
                .whereType<WorkoutResponse>()
                .toList();
          }
          aiAnalysisEnabled = data['aiAnalysisEnabled'] == true;
          final storedDomains = data['labDataDomains'];
          if (storedDomains is List) {
            labDataDomains = {
              for (final value in storedDomains)
                if (value is String)
                  for (final domain in LabDataDomain.values)
                    if (domain.name == value) domain,
            };
          }
          final storedMessages = data['labMessages'];
          if (storedMessages is List) {
            labMessages = storedMessages
                .map(_readLabMessage)
                .whereType<LabMessage>()
                .toList();
          }
          if (originalVersion < schemaVersion) {
            try {
              await _channel.invokeMethod('write', jsonEncode(data));
            } on PlatformException {
              // The in-memory migration is still usable; retry on next save.
            }
          }
        }
      }
    } on FormatException {
      // Keep the last usable in-memory state if local JSON is incomplete.
    } on PlatformException {
      // Storage being temporarily unavailable must not prevent app startup.
    } on Object {
      // Ignore structurally invalid legacy state and keep usable defaults.
    }
    isLoaded = true;
    notifyListeners();
  }

  Future<void> save() async {
    await _channel.invokeMethod(
      'write',
      jsonEncode({
        'days': days,
        'week': week,
        'workout': workoutIndex,
        'unit': unit,
        'logs': logs.map((e) => e.toJson()).toList(),
        'schemaVersion': schemaVersion,
        'workoutHistory': workoutHistory.map((e) => e.toJson()).toList(),
        'customExercises': customExercises
            .map((exercise) => exercise.toJson())
            .toList(),
        'draft': draft?.toJson(),
        'drafts': _draftsForSave.map((item) => item.toJson()).toList(),
        'programStartDate': programStartDate.toIso8601String(),
        'strengthProgramRun': strengthProgramRun,
        'athleticProgramRun': athleticProgramRun,
        'athleticWeek': athleticWeek,
        'athleticSessionIndex': athleticSessionIndex,
        'athleticStartDate': athleticStartDate.toIso8601String(),
        'athleticHistory': athleticHistory
            .map((record) => record.toJson())
            .toList(),
        'athleticAssessments': athleticAssessments
            .map((assessment) => assessment.toJson())
            .toList(),
        'onboardingVersionSeen': onboardingVersionSeen,
        'preferredTrack': preferredTrack.name,
        'supplementPresets': supplementPresets
            .map((preset) => preset.toJson())
            .toList(),
        'supplementEvents': supplementEvents
            .map((event) => event.toJson())
            .toList(),
        'mealEvents': mealEvents.map((event) => event.toJson()).toList(),
        'hydrationEvents': hydrationEvents
            .map((event) => event.toJson())
            .toList(),
        'recoveryCheckIns': recoveryCheckIns
            .map((item) => item.toJson())
            .toList(),
        'workoutResponses': workoutResponses
            .map((item) => item.toJson())
            .toList(),
        'aiAnalysisEnabled': aiAnalysisEnabled,
        'labDataDomains': labDataDomains.map((domain) => domain.name).toList(),
        'labMessages': labMessages.map((message) => message.toJson()).toList(),
      }),
    );
  }

  Future<void> setPreferredTrack(TrainingTrack value) async {
    if (preferredTrack == value) return;
    final previous = preferredTrack;
    preferredTrack = value;
    notifyListeners();
    try {
      await save();
    } on Object {
      preferredTrack = previous;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> markOnboardingSeen(int version) async {
    if (version <= onboardingVersionSeen) return;
    final previous = onboardingVersionSeen;
    onboardingVersionSeen = version;
    notifyListeners();
    try {
      await save();
    } on Object {
      onboardingVersionSeen = previous;
      notifyListeners();
      rethrow;
    }
  }

  List<SupplementPreset> get activeSupplementPresets => supplementPresets
      .where((preset) => !preset.archived)
      .toList()
    ..sort((a, b) => a.name.compareTo(b.name));

  List<SupplementEvent> supplementEventsForDay(DateTime day) => supplementEvents
      .where((event) => sameLocalDay(event.takenAt, day))
      .toList()
    ..sort((a, b) => b.takenAt.compareTo(a.takenAt));

  List<MealEvent> mealEventsForDay(DateTime day) => mealEvents
      .where((event) => sameLocalDay(event.occurredAt, day))
      .toList()
    ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));

  List<HydrationEvent> hydrationEventsForDay(DateTime day) => hydrationEvents
      .where((event) => sameLocalDay(event.occurredAt, day))
      .toList()
    ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));

  double caffeineForDay(DateTime day) => supplementEvents
      .where((event) => sameLocalDay(event.takenAt, day))
      .fold(0.0, (sum, event) => sum + event.caffeineMg);

  double hydrationForDay(DateTime day) => hydrationEvents
      .where((event) => sameLocalDay(event.occurredAt, day))
      .fold(0.0, (sum, event) => sum + event.amountMl);

  RecoveryCheckIn? recoveryForDay(DateTime day) {
    for (final item in recoveryCheckIns.reversed) {
      if (sameLocalDay(item.localDate, day)) return item;
    }
    return null;
  }

  WorkoutResponse? responseForSession(String sessionId) {
    for (final item in workoutResponses.reversed) {
      if (item.workoutSessionId == sessionId) return item;
    }
    return null;
  }

  Future<void> saveSupplementPreset(SupplementPreset value) async {
    final name = value.name.trim();
    final unitValue = value.unit.trim();
    if (name.isEmpty || unitValue.isEmpty || !value.dose.isFinite || value.dose <= 0) {
      throw ArgumentError('Supplement name, dose, and unit are required.');
    }
    if (!value.caffeineMg.isFinite || value.caffeineMg < 0) {
      throw ArgumentError('Caffeine must be zero or greater.');
    }
    final previous = List<SupplementPreset>.of(supplementPresets);
    final index = supplementPresets.indexWhere((preset) => preset.id == value.id);
    if (index < 0) {
      supplementPresets.add(value);
    } else {
      supplementPresets[index] = value;
    }
    try {
      await save();
    } on Object {
      supplementPresets = previous;
      rethrow;
    }
    notifyListeners();
  }

  Future<void> archiveSupplementPreset(String id) async {
    final index = supplementPresets.indexWhere((preset) => preset.id == id);
    if (index < 0) return;
    final previous = List<SupplementPreset>.of(supplementPresets);
    supplementPresets[index] = supplementPresets[index].copyWith(
      archived: true,
      updatedAt: DateTime.now(),
    );
    try {
      await save();
    } on Object {
      supplementPresets = previous;
      rethrow;
    }
    notifyListeners();
  }

  Future<void> logSupplementPreset(
    SupplementPreset preset, {
    DateTime? takenAt,
    String notes = '',
  }) => saveSupplementEvent(
    SupplementEvent(
      id: createRecordId('supplement'),
      presetId: preset.id,
      name: preset.name,
      brand: preset.brand,
      dose: preset.dose,
      unit: preset.unit,
      caffeineMg: preset.caffeineMg,
      takenAt: takenAt ?? DateTime.now(),
      notes: notes.trim(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
  );

  Future<void> saveSupplementEvent(SupplementEvent value) async {
    if (value.name.trim().isEmpty || value.unit.trim().isEmpty) {
      throw ArgumentError('Supplement name and unit are required.');
    }
    if (!value.dose.isFinite || value.dose <= 0) {
      throw ArgumentError('Dose must be above zero.');
    }
    if (!value.caffeineMg.isFinite || value.caffeineMg < 0) {
      throw ArgumentError('Caffeine must be zero or greater.');
    }
    final previous = List<SupplementEvent>.of(supplementEvents);
    final index = supplementEvents.indexWhere((event) => event.id == value.id);
    if (index < 0) {
      supplementEvents.add(value);
    } else {
      supplementEvents[index] = value;
    }
    try {
      await save();
    } on Object {
      supplementEvents = previous;
      rethrow;
    }
    notifyListeners();
  }

  Future<void> deleteSupplementEvent(String id) async {
    final previous = List<SupplementEvent>.of(supplementEvents);
    supplementEvents.removeWhere((event) => event.id == id);
    try {
      await save();
    } on Object {
      supplementEvents = previous;
      rethrow;
    }
    notifyListeners();
  }

  Future<void> saveMealEvent(MealEvent value) async {
    if (value.name.trim().isEmpty) throw ArgumentError('Meal name is required.');
    final previous = List<MealEvent>.of(mealEvents);
    final index = mealEvents.indexWhere((event) => event.id == value.id);
    if (index < 0) {
      mealEvents.add(value);
    } else {
      mealEvents[index] = value;
    }
    try {
      await save();
    } on Object {
      mealEvents = previous;
      rethrow;
    }
    notifyListeners();
  }

  Future<void> deleteMealEvent(String id) async {
    final previous = List<MealEvent>.of(mealEvents);
    mealEvents.removeWhere((event) => event.id == id);
    try {
      await save();
    } on Object {
      mealEvents = previous;
      rethrow;
    }
    notifyListeners();
  }

  Future<void> addHydration({
    required double amountMl,
    bool electrolytes = false,
    String notes = '',
    DateTime? occurredAt,
  }) async {
    if (!amountMl.isFinite || amountMl <= 0) {
      throw ArgumentError('Hydration amount must be above zero.');
    }
    final now = DateTime.now();
    final previous = List<HydrationEvent>.of(hydrationEvents);
    hydrationEvents.add(
      HydrationEvent(
        id: createRecordId('hydration'),
        occurredAt: occurredAt ?? now,
        amountMl: amountMl,
        electrolytes: electrolytes,
        notes: notes.trim(),
        createdAt: now,
        updatedAt: now,
      ),
    );
    try {
      await save();
    } on Object {
      hydrationEvents = previous;
      rethrow;
    }
    notifyListeners();
  }

  Future<void> deleteHydrationEvent(String id) async {
    final previous = List<HydrationEvent>.of(hydrationEvents);
    hydrationEvents.removeWhere((event) => event.id == id);
    try {
      await save();
    } on Object {
      hydrationEvents = previous;
      rethrow;
    }
    notifyListeners();
  }

  Future<void> saveRecoveryCheckIn(RecoveryCheckIn value) async {
    final ratings = [value.sleepQuality, value.stress, value.soreness];
    if (ratings.whereType<int>().any((rating) => rating < 1 || rating > 5)) {
      throw RangeError('Recovery ratings must be between 1 and 5.');
    }
    if (value.sleepHours != null &&
        (!value.sleepHours!.isFinite || value.sleepHours! < 0 || value.sleepHours! > 24)) {
      throw ArgumentError('Sleep hours must be between 0 and 24.');
    }
    final previous = List<RecoveryCheckIn>.of(recoveryCheckIns);
    recoveryCheckIns.removeWhere((item) => sameLocalDay(item.localDate, value.localDate));
    recoveryCheckIns.add(value);
    try {
      await save();
    } on Object {
      recoveryCheckIns = previous;
      rethrow;
    }
    notifyListeners();
  }

  Future<void> saveWorkoutResponse(WorkoutResponse value) async {
    final ratings = [
      value.energy,
      value.focus,
      value.pump,
      value.effort,
      value.discomfort,
    ];
    if (ratings.any((rating) => rating < 1 || rating > 5)) {
      throw RangeError('Workout ratings must be between 1 and 5.');
    }
    final previous = List<WorkoutResponse>.of(workoutResponses);
    workoutResponses.removeWhere(
      (item) => item.workoutSessionId == value.workoutSessionId,
    );
    workoutResponses.add(value);
    try {
      await save();
    } on Object {
      workoutResponses = previous;
      rethrow;
    }
    notifyListeners();
  }

  Future<void> setAiAnalysisEnabled(bool value) async {
    if (aiAnalysisEnabled == value) return;
    final previous = aiAnalysisEnabled;
    aiAnalysisEnabled = value;
    notifyListeners();
    try {
      await save();
    } on Object {
      aiAnalysisEnabled = previous;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> setLabDataDomain(LabDataDomain domain, bool enabled) async {
    final previous = Set<LabDataDomain>.of(labDataDomains);
    if (enabled) {
      labDataDomains.add(domain);
    } else {
      labDataDomains.remove(domain);
    }
    notifyListeners();
    try {
      await save();
    } on Object {
      labDataDomains = previous;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> addLabMessage(LabMessage message) async {
    final previous = List<LabMessage>.of(labMessages);
    labMessages.add(message);
    if (labMessages.length > 40) {
      labMessages = labMessages.sublist(labMessages.length - 40);
    }
    try {
      await save();
    } on Object {
      labMessages = previous;
      rethrow;
    }
    notifyListeners();
  }

  Future<void> clearLabMessages() async {
    if (labMessages.isEmpty) return;
    final previous = List<LabMessage>.of(labMessages);
    labMessages.clear();
    try {
      await save();
    } on Object {
      labMessages = previous;
      rethrow;
    }
    notifyListeners();
  }

  bool isPr(SetLog candidate) => !logs
      .where((l) => l.exercise == candidate.exercise)
      .any((l) => l.weight >= candidate.weight && l.e1rm >= candidate.e1rm);
  SetLog? best(String exercise) {
    final items = logs.where((l) => l.exercise == exercise).toList()
      ..sort((a, b) => b.e1rm.compareTo(a.e1rm));
    return items.isEmpty ? null : items.first;
  }

  List<ExerciseOption> get selectableExercises =>
      ExerciseLibrary.selectable(customExercises);

  Future<CustomExercise> addCustomExercise(String value) async {
    final name = _validatedExerciseName(value);
    final exercise = CustomExercise(
      id: 'custom-${DateTime.now().microsecondsSinceEpoch}',
      name: name,
    );
    customExercises.add(exercise);
    try {
      await save();
    } on Object {
      customExercises.removeLast();
      rethrow;
    }
    notifyListeners();
    return exercise;
  }

  Future<void> renameCustomExercise(String id, String value) async {
    final index = customExercises.indexWhere((exercise) => exercise.id == id);
    if (index < 0) throw StateError('The custom exercise no longer exists.');
    final name = _validatedExerciseName(value, exceptId: id);
    final previous = customExercises[index];
    customExercises[index] = previous.copyWith(name: name);
    try {
      await save();
    } on Object {
      customExercises[index] = previous;
      rethrow;
    }
    notifyListeners();
  }

  Future<void> archiveCustomExercise(String id) async {
    final index = customExercises.indexWhere((exercise) => exercise.id == id);
    if (index < 0) throw StateError('The custom exercise no longer exists.');
    final previous = customExercises[index];
    customExercises[index] = previous.copyWith(isArchived: true);
    try {
      await save();
    } on Object {
      customExercises[index] = previous;
      rethrow;
    }
    notifyListeners();
  }

  String _validatedExerciseName(String value, {String? exceptId}) {
    final name = value.trim();
    if (name.isEmpty) throw ArgumentError('Exercise name cannot be empty.');
    final normalized = name.toLowerCase();
    final builtInCollision = BuiltInExercises.values.any(
      (exercise) => exercise.name.toLowerCase() == normalized,
    );
    final customCollision = customExercises.any(
      (exercise) =>
          exercise.id != exceptId && exercise.name.toLowerCase() == normalized,
    );
    if (builtInCollision || customCollision) {
      throw ArgumentError('An exercise with that name already exists.');
    }
    return name;
  }

  Future<bool> add(SetLog log) async {
    final pr = isPr(log);
    logs.add(log);
    try {
      await save();
    } on Object {
      logs.removeLast();
      rethrow;
    }
    notifyListeners();
    return pr;
  }

  Future<void> updateSet(
    SetLog original, {
    required double weight,
    required int reps,
    required String notes,
  }) async {
    if (!weight.isFinite || weight <= 0 || reps <= 0) {
      throw ArgumentError('Weight and reps must be above zero.');
    }
    final index = logs.indexOf(original);
    if (index < 0) throw StateError('The set no longer exists.');
    final updated = original.copyWith(weight: weight, reps: reps, notes: notes);
    logs[index] = updated;
    try {
      await save();
    } on Object {
      logs[index] = original;
      rethrow;
    }
    notifyListeners();
  }

  Future<void> setDraft(DraftSetInput value) async {
    final previousDraft = draft;
    final previousDrafts = List<DraftSetInput>.of(drafts);
    drafts.removeWhere((item) => _sameDraftTarget(item, value));
    drafts.add(value);
    draft = value;
    try {
      await save();
    } on Object {
      draft = previousDraft;
      drafts = previousDrafts;
      rethrow;
    }
  }

  Future<void> clearDraft() async {
    final previous = draft;
    final previousDrafts = List<DraftSetInput>.of(drafts);
    if (draft != null) {
      drafts.removeWhere((item) => item.sessionId == draft!.sessionId);
    } else {
      drafts.clear();
    }
    draft = null;
    try {
      await save();
    } on Object {
      draft = previous;
      drafts = previousDrafts;
      rethrow;
    }
    notifyListeners();
  }

  Future<void> complete(int workoutsThisWeek) async {
    assert(workoutsThisWeek > 0, 'Workout count must be positive.');
    // The store cadence is authoritative. A workout screen can remain open
    // across a settings change and pass a stale count from the old cadence.
    final previousWeek = week;
    final previousWorkoutIndex = workoutIndex;
    final previousProgramStartDate = programStartDate;
    _advanceWorkout();
    try {
      await save();
    } on Object {
      week = previousWeek;
      workoutIndex = previousWorkoutIndex;
      programStartDate = previousProgramStartDate;
      rethrow;
    }
    notifyListeners();
  }

  Future<void> completeWorkout({required String workout}) => recordWorkout(
    weekNumber: week,
    targetWorkoutIndex: workoutIndex,
    workout: workout,
    status: WorkoutStatus.completed,
    sessionId: draft?.sessionId,
    substitutions: draft?.substitutions ?? const {},
  );

  Future<void> skipWorkout({required String workout}) => recordWorkout(
    weekNumber: week,
    targetWorkoutIndex: workoutIndex,
    workout: workout,
    status: WorkoutStatus.skipped,
    sessionId: draft?.sessionId,
    substitutions: draft?.substitutions ?? const {},
  );

  Future<void> recordWorkout({
    required int weekNumber,
    required int targetWorkoutIndex,
    required String workout,
    required WorkoutStatus status,
    required String? sessionId,
    Map<int, String> substitutions = const {},
    bool retroactive = false,
    DateTime? scheduledDate,
  }) async {
    final previousWeek = week;
    final previousWorkoutIndex = workoutIndex;
    final previousProgramStartDate = programStartDate;
    final previousDraft = draft;
    final previousDrafts = List<DraftSetInput>.of(drafts);
    final record = WorkoutRecord(
      week: weekNumber,
      workoutIndex: targetWorkoutIndex,
      workout: workout,
      date: DateTime.now(),
      status: status,
      programRun: strengthProgramRun,
      days: days,
      scheduledDate:
          scheduledDate ?? dateForSlot(weekNumber, targetWorkoutIndex),
      loggedAt: DateTime.now(),
      retroactive: retroactive,
      sessionId: sessionId,
      substitutions: Map.unmodifiable(substitutions),
    );
    workoutHistory.add(record);
    drafts.removeWhere(
      (item) =>
          item.sessionId == sessionId ||
          (item.week == weekNumber &&
              item.workoutIndex == targetWorkoutIndex &&
              item.days == days &&
              item.retroactive == retroactive),
    );
    if (!retroactive) _advanceWorkout();
    draft = draftFor(
      weekNumber: week,
      targetWorkoutIndex: workoutIndex,
      cadence: days,
      retroactive: false,
    );
    try {
      await save();
    } on Object {
      week = previousWeek;
      workoutIndex = previousWorkoutIndex;
      programStartDate = previousProgramStartDate;
      draft = previousDraft;
      drafts = previousDrafts;
      workoutHistory.removeLast();
      rethrow;
    }
    notifyListeners();
  }

  DateTime dateForSlot(int weekNumber, int targetWorkoutIndex) {
    final offsets = switch (days) {
      3 => const [0, 2, 4],
      4 => const [0, 1, 3, 4],
      5 => const [0, 1, 2, 3, 4],
      _ => throw ArgumentError.value(days, 'days'),
    };
    final index = targetWorkoutIndex.clamp(0, offsets.length - 1);
    return _dateOnly(
      programStartDate.add(
        Duration(days: (weekNumber - 1) * 7 + offsets[index]),
      ),
    );
  }

  bool isPastSlot(int weekNumber, int targetWorkoutIndex) {
    if (weekNumber < week) return true;
    if (weekNumber > week) return false;
    return targetWorkoutIndex < workoutIndex;
  }

  List<WorkoutRecord> recordsForSlot(int weekNumber, int targetWorkoutIndex) =>
      workoutHistory
          .where(
            (record) =>
                record.programRun == strengthProgramRun &&
                record.week == weekNumber &&
                record.workoutIndex == targetWorkoutIndex &&
                record.days == days,
          )
          .toList()
        ..sort((a, b) => b.loggedAt.compareTo(a.loggedAt));

  DraftSetInput? draftFor({
    required int weekNumber,
    required int targetWorkoutIndex,
    required int cadence,
    required bool retroactive,
  }) {
    for (final item in drafts.reversed) {
      if (item.programRun == strengthProgramRun &&
          item.week == weekNumber &&
          item.workoutIndex == targetWorkoutIndex &&
          item.days == cadence &&
          item.retroactive == retroactive) {
        return item;
      }
    }
    final legacy = draft;
    if (legacy != null &&
        legacy.programRun == strengthProgramRun &&
        legacy.week == weekNumber &&
        legacy.workoutIndex == targetWorkoutIndex &&
        legacy.days == cadence &&
        legacy.retroactive == retroactive) {
      return legacy;
    }
    return null;
  }

  void _advanceWorkout() {
    final currentWorkoutCount = ProgramEngine.workoutCount(days);
    workoutIndex = ProgramEngine.clampWorkoutIndex(workoutIndex, days) + 1;
    if (workoutIndex >= currentWorkoutCount) {
      workoutIndex = 0;
      if (week >= ProgramEngine.totalWeeks) {
        week = 1;
        programStartDate = programStartDate.add(
          const Duration(days: ProgramEngine.totalWeeks * 7),
        );
      } else {
        week++;
      }
    }
  }

  AthleticWeek get currentAthleticWeek => AthleticProgram.week(athleticWeek);

  AthleticSession get currentAthleticSession =>
      currentAthleticWeek.sessions[athleticSessionIndex];

  List<AthleticSessionRecord> get currentAthleticRunHistory => athleticHistory
      .where((record) => record.programRun == athleticProgramRun)
      .toList()
    ..sort((a, b) => a.completedAt.compareTo(b.completedAt));

  int get athleticCompletedSessions => currentAthleticRunHistory.length;

  bool get athleticProgramComplete => isAthleticSessionCompleted(
    AthleticProgram.totalWeeks,
    AthleticProgram.sessionsPerWeek - 1,
  );

  double get athleticProgress =>
      (athleticCompletedSessions /
              (AthleticProgram.totalWeeks * AthleticProgram.sessionsPerWeek))
          .clamp(0.0, 1.0);

  bool isAthleticSessionCompleted(int weekNumber, int sessionIndex) =>
      athleticHistory.any(
        (record) =>
            record.programRun == athleticProgramRun &&
            record.week == weekNumber &&
            record.sessionIndex == sessionIndex,
      );

  DateTime athleticDateForSlot(int weekNumber, int sessionIndex) {
    const offsets = [0, 2, 4, 5];
    final safeWeek = weekNumber.clamp(1, AthleticProgram.totalWeeks).toInt();
    final safeIndex = sessionIndex
        .clamp(0, AthleticProgram.sessionsPerWeek - 1)
        .toInt();
    return _dateOnly(
      athleticStartDate.add(
        Duration(days: (safeWeek - 1) * 7 + offsets[safeIndex]),
      ),
    );
  }

  Future<void> completeAthleticSession({
    required int effort,
    required String notes,
    String? sessionId,
  }) async {
    if (effort < 1 || effort > 10) {
      throw RangeError.range(effort, 1, 10, 'effort');
    }
    if (isAthleticSessionCompleted(athleticWeek, athleticSessionIndex)) {
      throw StateError('This athletic session is already complete.');
    }
    final previousWeek = athleticWeek;
    final previousSessionIndex = athleticSessionIndex;
    final record = AthleticSessionRecord(
      programRun: athleticProgramRun,
      week: athleticWeek,
      sessionIndex: athleticSessionIndex,
      completedAt: DateTime.now(),
      effort: effort,
      notes: notes.trim(),
      sessionId: sessionId,
    );
    athleticHistory.add(record);
    if (!(athleticWeek == AthleticProgram.totalWeeks &&
        athleticSessionIndex == AthleticProgram.sessionsPerWeek - 1)) {
      athleticSessionIndex++;
      if (athleticSessionIndex >= AthleticProgram.sessionsPerWeek) {
        athleticSessionIndex = 0;
        athleticWeek++;
      }
    }
    try {
      await save();
    } on Object {
      athleticWeek = previousWeek;
      athleticSessionIndex = previousSessionIndex;
      athleticHistory.removeLast();
      rethrow;
    }
    notifyListeners();
  }

  Future<void> saveAthleticAssessment(AthleticAssessment assessment) async {
    if (assessment.programRun != athleticProgramRun) {
      throw ArgumentError('Assessment run does not match the active program.');
    }
    if (assessment.movementQuality < 1 || assessment.movementQuality > 5) {
      throw RangeError.range(
        assessment.movementQuality,
        1,
        5,
        'movementQuality',
      );
    }
    athleticAssessments.add(assessment);
    try {
      await save();
    } on Object {
      athleticAssessments.removeLast();
      rethrow;
    }
    notifyListeners();
  }

  Future<void> restartAthleticProgram() async {
    final previousRun = athleticProgramRun;
    final previousWeek = athleticWeek;
    final previousSessionIndex = athleticSessionIndex;
    final previousStartDate = athleticStartDate;
    athleticProgramRun++;
    athleticWeek = 1;
    athleticSessionIndex = 0;
    athleticStartDate = _dateOnly(DateTime.now());
    try {
      await save();
    } on Object {
      athleticProgramRun = previousRun;
      athleticWeek = previousWeek;
      athleticSessionIndex = previousSessionIndex;
      athleticStartDate = previousStartDate;
      rethrow;
    }
    notifyListeners();
  }

  Future<void> setStrengthProgramPosition({
    required int phase,
    required int microcycle,
    required int cadence,
    required int nextWorkoutIndex,
    required DateTime nextWorkoutDate,
    required bool startNewRun,
  }) async {
    if (phase < 1 || phase > ProgramEngine.phaseCount) {
      throw RangeError.range(phase, 1, ProgramEngine.phaseCount, 'phase');
    }
    if (microcycle < 1 || microcycle > ProgramEngine.weeksPerPhase) {
      throw RangeError.range(
        microcycle,
        1,
        ProgramEngine.weeksPerPhase,
        'microcycle',
      );
    }
    ProgramEngine.validateDays(cadence);
    if (nextWorkoutIndex < 0 || nextWorkoutIndex >= cadence) {
      throw RangeError.range(
        nextWorkoutIndex,
        0,
        cadence - 1,
        'nextWorkoutIndex',
      );
    }
    final targetWeek =
        ProgramEngine.firstWeekOfPhase(phase) + microcycle - 1;
    if (!startNewRun &&
        workoutHistory.any(
          (record) =>
              record.programRun == strengthProgramRun &&
              record.week == targetWeek &&
              record.workoutIndex == nextWorkoutIndex &&
              record.days == cadence,
        )) {
      throw StateError(
        'That workout already has history in the current run. Start a new run instead.',
      );
    }

    final previousRun = strengthProgramRun;
    final previousDays = days;
    final previousWeek = week;
    final previousWorkoutIndex = workoutIndex;
    final previousStartDate = programStartDate;
    final previousDraft = draft;
    final previousDrafts = List<DraftSetInput>.of(drafts);

    if (startNewRun) strengthProgramRun++;
    days = cadence;
    week = targetWeek;
    workoutIndex = nextWorkoutIndex;
    final offsets = _strengthOffsetsForCadence(cadence);
    programStartDate = _dateOnly(nextWorkoutDate).subtract(
      Duration(
        days: (targetWeek - 1) * 7 + offsets[nextWorkoutIndex],
      ),
    );
    drafts = drafts.where((item) => item.retroactive).toList();
    draft = null;

    try {
      await save();
    } on Object {
      strengthProgramRun = previousRun;
      days = previousDays;
      week = previousWeek;
      workoutIndex = previousWorkoutIndex;
      programStartDate = previousStartDate;
      draft = previousDraft;
      drafts = previousDrafts;
      rethrow;
    }
    notifyListeners();
  }

  Future<void> setAthleticProgramPosition({
    required int weekNumber,
    required int sessionIndex,
    required DateTime nextSessionDate,
    required bool startNewRun,
  }) async {
    if (weekNumber < 1 || weekNumber > AthleticProgram.totalWeeks) {
      throw RangeError.range(
        weekNumber,
        1,
        AthleticProgram.totalWeeks,
        'weekNumber',
      );
    }
    if (sessionIndex < 0 ||
        sessionIndex >= AthleticProgram.sessionsPerWeek) {
      throw RangeError.range(
        sessionIndex,
        0,
        AthleticProgram.sessionsPerWeek - 1,
        'sessionIndex',
      );
    }
    if (!startNewRun &&
        isAthleticSessionCompleted(weekNumber, sessionIndex)) {
      throw StateError(
        'That session is already complete in the current run. Start a new run instead.',
      );
    }

    final previousRun = athleticProgramRun;
    final previousWeek = athleticWeek;
    final previousSessionIndex = athleticSessionIndex;
    final previousStartDate = athleticStartDate;

    if (startNewRun) athleticProgramRun++;
    athleticWeek = weekNumber;
    athleticSessionIndex = sessionIndex;
    const offsets = [0, 2, 4, 5];
    athleticStartDate = _dateOnly(nextSessionDate).subtract(
      Duration(days: (weekNumber - 1) * 7 + offsets[sessionIndex]),
    );

    try {
      await save();
    } on Object {
      athleticProgramRun = previousRun;
      athleticWeek = previousWeek;
      athleticSessionIndex = previousSessionIndex;
      athleticStartDate = previousStartDate;
      rethrow;
    }
    notifyListeners();
  }

  /// Changes cadence without moving the user to another program week.
  ///
  /// With no override, the engine selects the new cadence workout that most
  /// closely matches the current next workout. A UI-provided
  /// [nextWorkoutIndex] always wins after it passes range validation.
  Future<void> setDays(int value, {int? nextWorkoutIndex}) async {
    ProgramEngine.validateDays(value);
    if (nextWorkoutIndex != null &&
        (nextWorkoutIndex < 0 || nextWorkoutIndex >= value)) {
      throw RangeError.range(
        nextWorkoutIndex,
        0,
        value - 1,
        'nextWorkoutIndex',
      );
    }
    final safeWeek = ProgramEngine.clampWeek(week);
    final sourceDays = ProgramEngine.isSupportedDays(days) ? days : 4;
    final destinationIndex =
        nextWorkoutIndex ??
        ProgramEngine.defaultWorkoutIndexForCadenceSwitch(
          week: safeWeek,
          fromDays: sourceDays,
          toDays: value,
          currentWorkoutIndex: workoutIndex,
        );
    final previousDays = days;
    final previousWorkoutIndex = workoutIndex;
    days = value;
    // This is unchanged for valid state; clamping only repairs corrupt legacy
    // values. The week still encodes the same phase and microcycle.
    week = safeWeek;
    workoutIndex = destinationIndex;
    try {
      await save();
    } on Object {
      days = previousDays;
      workoutIndex = previousWorkoutIndex;
      rethrow;
    }
    notifyListeners();
  }

  Future<void> setUnit(String value) async {
    if (value != 'lb' && value != 'kg') {
      throw ArgumentError.value(value, 'value', 'Must be lb or kg');
    }
    if (value == unit) return;

    // Interim persistence model: stored weights use the user's active display
    // unit, so changing units must convert every historical value exactly once.
    // A future database migration should store a canonical base unit and only
    // convert at display/input boundaries.
    final factor = unit == 'lb' ? poundsToKilograms : 1 / poundsToKilograms;
    final previousUnit = unit;
    final previousLogs = logs;
    logs = [for (final log in logs) log.copyWith(weight: log.weight * factor)];
    unit = value;
    try {
      await save();
    } on Object {
      unit = previousUnit;
      logs = previousLogs;
      rethrow;
    }
    notifyListeners();
  }

  static int? _readInt(Object? value) {
    if (value is int) return value;
    if (value is num && value.isFinite) return value.toInt();
    return null;
  }

  static SetLog? _readLog(Object? value) {
    if (value is! Map) return null;
    try {
      return SetLog.fromJson(Map<String, dynamic>.from(value));
    } on Object {
      return null;
    }
  }

  static WorkoutRecord? _readWorkout(Object? value) {
    if (value is! Map) return null;
    try {
      return WorkoutRecord.fromJson(Map<String, dynamic>.from(value));
    } on Object {
      return null;
    }
  }

  static DraftSetInput? _readDraft(Object? value) {
    if (value is! Map) return null;
    try {
      return DraftSetInput.fromJson(Map<String, dynamic>.from(value));
    } on Object {
      return null;
    }
  }

  static CustomExercise? _readCustomExercise(Object? value) {
    if (value is! Map) return null;
    try {
      final exercise = CustomExercise.fromJson(
        Map<String, dynamic>.from(value),
      );
      if (exercise.id.isEmpty || exercise.name.trim().isEmpty) return null;
      return exercise;
    } on Object {
      return null;
    }
  }

  static AthleticSessionRecord? _readAthleticRecord(Object? value) {
    if (value is! Map) return null;
    try {
      final record = AthleticSessionRecord.fromJson(
        Map<String, dynamic>.from(value),
      );
      if (record.week < 1 ||
          record.week > AthleticProgram.totalWeeks ||
          record.sessionIndex < 0 ||
          record.sessionIndex >= AthleticProgram.sessionsPerWeek ||
          record.effort < 1 ||
          record.effort > 10) {
        return null;
      }
      return record;
    } on Object {
      return null;
    }
  }

  static AthleticAssessment? _readAthleticAssessment(Object? value) {
    if (value is! Map) return null;
    try {
      final assessment = AthleticAssessment.fromJson(
        Map<String, dynamic>.from(value),
      );
      if (assessment.movementQuality < 1 ||
          assessment.movementQuality > 5) {
        return null;
      }
      return assessment;
    } on Object {
      return null;
    }
  }

  static SupplementPreset? _readSupplementPreset(Object? value) {
    if (value is! Map) return null;
    try {
      final preset = SupplementPreset.fromJson(Map<String, dynamic>.from(value));
      if (preset.id.isEmpty || preset.name.trim().isEmpty || preset.dose <= 0) {
        return null;
      }
      return preset;
    } on Object {
      return null;
    }
  }

  static SupplementEvent? _readSupplementEvent(Object? value) {
    if (value is! Map) return null;
    try {
      final event = SupplementEvent.fromJson(Map<String, dynamic>.from(value));
      if (event.id.isEmpty || event.name.trim().isEmpty || event.dose <= 0) {
        return null;
      }
      return event;
    } on Object {
      return null;
    }
  }

  static MealEvent? _readMealEvent(Object? value) {
    if (value is! Map) return null;
    try {
      final event = MealEvent.fromJson(Map<String, dynamic>.from(value));
      if (event.id.isEmpty || event.name.trim().isEmpty) return null;
      return event;
    } on Object {
      return null;
    }
  }

  static HydrationEvent? _readHydrationEvent(Object? value) {
    if (value is! Map) return null;
    try {
      final event = HydrationEvent.fromJson(Map<String, dynamic>.from(value));
      if (event.id.isEmpty || event.amountMl <= 0) return null;
      return event;
    } on Object {
      return null;
    }
  }

  static RecoveryCheckIn? _readRecoveryCheckIn(Object? value) {
    if (value is! Map) return null;
    try {
      final item = RecoveryCheckIn.fromJson(Map<String, dynamic>.from(value));
      if (item.id.isEmpty) return null;
      return item;
    } on Object {
      return null;
    }
  }

  static WorkoutResponse? _readWorkoutResponse(Object? value) {
    if (value is! Map) return null;
    try {
      final item = WorkoutResponse.fromJson(Map<String, dynamic>.from(value));
      if (item.id.isEmpty || item.workoutSessionId.isEmpty) return null;
      return item;
    } on Object {
      return null;
    }
  }

  static LabMessage? _readLabMessage(Object? value) {
    if (value is! Map) return null;
    try {
      final item = LabMessage.fromJson(Map<String, dynamic>.from(value));
      if (item.id.isEmpty || item.text.trim().isEmpty) return null;
      return item;
    } on Object {
      return null;
    }
  }

  static Map<String, dynamic> _migrate(Map<String, dynamic> source) {
    final data = Map<String, dynamic>.from(source);
    var version = _readInt(data['schemaVersion']) ?? 1;
    if (version < 2) {
      final storedLogs = data['logs'];
      if (storedLogs is List) {
        data['logs'] = [
          for (final value in storedLogs)
            if (value is Map)
              Map<String, dynamic>.from(value)..putIfAbsent('n', () => '')
            else
              value,
        ];
      }
      version = 2;
      data['schemaVersion'] = version;
    }
    if (version < 3) {
      data.putIfAbsent('workoutHistory', () => <Object>[]);
      data.putIfAbsent('draft', () => null);
      version = 3;
      data['schemaVersion'] = version;
    }
    if (version < 4) {
      final storedDays = _readInt(data['days']) ?? 4;
      final storedWeek = ProgramEngine.clampWeek(_readInt(data['week']) ?? 1);
      final storedWorkout = ProgramEngine.clampWorkoutIndex(
        _readInt(data['workout']) ?? 0,
        ProgramEngine.isSupportedDays(storedDays) ? storedDays : 4,
      );
      final now = _dateOnly(DateTime.now());
      final offsets = switch (storedDays) {
        3 => const [0, 2, 4],
        5 => const [0, 1, 2, 3, 4],
        _ => const [0, 1, 3, 4],
      };
      final slotOffset = offsets[storedWorkout.clamp(0, offsets.length - 1)];
      data.putIfAbsent(
        'programStartDate',
        () => now
            .subtract(Duration(days: (storedWeek - 1) * 7 + slotOffset))
            .toIso8601String(),
      );
      final history = data['workoutHistory'];
      if (history is List) {
        data['workoutHistory'] = [
          for (final value in history)
            if (value is Map)
              Map<String, dynamic>.from(value)
                ..putIfAbsent('days', () => storedDays)
                ..putIfAbsent('scheduledDate', () => value['date'])
                ..putIfAbsent('loggedAt', () => value['date'])
                ..putIfAbsent('retroactive', () => false)
                ..putIfAbsent('substitutions', () => <String, String>{})
            else
              value,
        ];
      }
      version = 4;
      data['schemaVersion'] = version;
    }
    if (version < 5) {
      final legacyDraft = data['draft'];
      data.putIfAbsent(
        'drafts',
        () => legacyDraft is Map ? <Object>[legacyDraft] : <Object>[],
      );
      version = 5;
      data['schemaVersion'] = version;
    }
    if (version < 6) {
      data.putIfAbsent('customExercises', () => <Object>[]);
      version = 6;
      data['schemaVersion'] = version;
    }
    if (version < 7) {
      data.putIfAbsent('athleticProgramRun', () => 1);
      data.putIfAbsent('athleticWeek', () => 1);
      data.putIfAbsent('athleticSessionIndex', () => 0);
      data.putIfAbsent(
        'athleticStartDate',
        () => _dateOnly(DateTime.now()).toIso8601String(),
      );
      data.putIfAbsent('athleticHistory', () => <Object>[]);
      data.putIfAbsent('athleticAssessments', () => <Object>[]);
      version = 7;
      data['schemaVersion'] = version;
    }
    if (version < 8) {
      data.putIfAbsent('onboardingVersionSeen', () => 0);
      data.putIfAbsent('preferredTrack', () => 'strength');
      version = 8;
      data['schemaVersion'] = version;
    }
    if (version < 9) {
      data.putIfAbsent(
        'supplementPresets',
        () => SupplementPreset.defaults()
            .map((preset) => preset.toJson())
            .toList(),
      );
      data.putIfAbsent('supplementEvents', () => <Object>[]);
      data.putIfAbsent('mealEvents', () => <Object>[]);
      data.putIfAbsent('hydrationEvents', () => <Object>[]);
      data.putIfAbsent('recoveryCheckIns', () => <Object>[]);
      data.putIfAbsent('workoutResponses', () => <Object>[]);
      data.putIfAbsent('aiAnalysisEnabled', () => false);
      data.putIfAbsent(
        'labDataDomains',
        () => LabDataDomain.values.map((domain) => domain.name).toList(),
      );
      data.putIfAbsent('labMessages', () => <Object>[]);
      version = 9;
      data['schemaVersion'] = version;
    }
    if (version < 10) {
      data.putIfAbsent('strengthProgramRun', () => 1);
      final history = data['workoutHistory'];
      if (history is List) {
        data['workoutHistory'] = [
          for (final value in history)
            if (value is Map)
              Map<String, dynamic>.from(value)
                ..putIfAbsent('programRun', () => 1)
            else
              value,
        ];
      }
      final legacyDraft = data['draft'];
      if (legacyDraft is Map) {
        data['draft'] = Map<String, dynamic>.from(legacyDraft)
          ..putIfAbsent('programRun', () => 1);
      }
      final storedDrafts = data['drafts'];
      if (storedDrafts is List) {
        data['drafts'] = [
          for (final value in storedDrafts)
            if (value is Map)
              Map<String, dynamic>.from(value)
                ..putIfAbsent('programRun', () => 1)
            else
              value,
        ];
      }
      version = 10;
      data['schemaVersion'] = version;
    }
    return data;
  }

  List<DraftSetInput> get _draftsForSave {
    final values = List<DraftSetInput>.of(drafts);
    final legacy = draft;
    if (legacy != null &&
        !values.any((item) => item.sessionId == legacy.sessionId)) {
      values.add(legacy);
    }
    return values;
  }

  static bool _sameDraftTarget(DraftSetInput a, DraftSetInput b) =>
      a.programRun == b.programRun &&
      a.week == b.week &&
      a.workoutIndex == b.workoutIndex &&
      a.days == b.days &&
      a.retroactive == b.retroactive;

  static List<int> _strengthOffsetsForCadence(int cadence) => switch (cadence) {
    3 => const [0, 2, 4],
    4 => const [0, 1, 3, 4],
    5 => const [0, 1, 2, 3, 4],
    _ => throw ArgumentError.value(cadence, 'cadence'),
  };

  DateTime _inferredProgramStartDate() {
    final today = _dateOnly(DateTime.now());
    final offsets = _strengthOffsetsForCadence(days);
    return today.subtract(
      Duration(days: (week - 1) * 7 + offsets[workoutIndex]),
    );
  }

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);
}
