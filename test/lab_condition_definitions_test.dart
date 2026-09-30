import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:progression_lab/brand.dart';
import 'package:progression_lab/daily_inputs.dart';
import 'package:progression_lab/lab_analysis.dart';
import 'package:progression_lab/lab_conditions.dart';
import 'package:progression_lab/lab_experiments.dart';
import 'package:progression_lab/lab_screen.dart';
import 'package:progression_lab/store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final boundary in <({String name, double dose, int lead, bool? group})>[
    (name: '25 mg at 20 minutes', dose: 25, lead: 20, group: true),
    (name: '25 mg at 180 minutes', dose: 25, lead: 180, group: true),
    (name: 'dose just below 25 mg', dose: 24.999, lead: 60, group: null),
    (name: 'dose above former 300 mg cap', dose: 301, lead: 60, group: true),
    (name: 'dose at 19 minutes', dose: 180, lead: 19, group: false),
    (name: 'dose at 181 minutes', dose: 180, lead: 181, group: false),
    (name: 'zero caffeine entry', dose: 0, lead: 60, group: false),
  ]) {
    test('both engines classify caffeine: ${boundary.name}', () {
      final store = _baseline();
      addTearDown(store.dispose);
      final start = _addSession(store, 6);
      _addCaffeine(store, 6, start, boundary.dose, boundary.lead);
      final a = 3 + (boundary.group == true ? 1 : 0);
      final b = 3 + (boundary.group == false ? 1 : 0);
      _expectCaffeineCounts(store, a, b);
    });
  }

  test('both engines sum positive caffeine entries in the same window', () {
    final store = _baseline();
    addTearDown(store.dispose);
    final start = _addSession(store, 6);
    _addCaffeine(store, 6, start, 12.5, 20);
    _addCaffeine(store, 7, start, 12.5, 180);
    // An out-of-window event cannot inflate this dose or change the baseline.
    _addCaffeine(store, 8, start, 200, 181);
    _expectCaffeineCounts(store, 4, 3);
  });

  for (final hours in <double?>[7, 6.999, 0, 24, null, -1, 24.1]) {
    test(
      'both engines classify sleep boundary $hours on workout local day',
      () {
        final store = _baseline();
        addTearDown(store.dispose);
        for (var i = 0; i < 6; i++) {
          final start = _sessionStart(i);
          _addSleep(store, i, start, i < 3 ? 8 : 6);
          // The previous calendar day says the opposite. It must not be used.
          _addSleep(
            store,
            100 + i,
            start.subtract(const Duration(days: 1)),
            i < 3 ? 5 : 9,
          );
        }
        final start = _addSession(store, 6);
        _addSleep(store, 6, start, hours);
        _addSleep(store, 106, start.subtract(const Duration(days: 1)), 10);
        final usable = hours != null && hours >= 0 && hours <= 24;
        final a = 3 + (usable && hours >= 7 ? 1 : 0);
        final b = 3 + (usable && hours < 7 ? 1 : 0);
        final evidence = _report(
          store,
        ).evidence.singleWhere((item) => item.id == 'sleep');
        final experiment = LabExperimentAnalyzer.analyze(
          LabExperimentTemplates.sleepTarget(start: DateTime(2026, 8, 1)),
          store.exportState(),
        );
        expect(evidence.sampleLabel, '$a at 7+ h · $b under 7 h');
        expect(experiment.samplesA, hasLength(a));
        expect(experiment.samplesB, hasLength(b));
        expect(evidence.comparison, contains('workout’s local date'));
        expect(
          experiment.experiment.conditionA.description,
          contains('workout’s local date'),
        );
      },
    );
  }

  test('local sleep join treats recovery date as a calendar label', () {
    final state = <String, dynamic>{
      'recoveryCheckIns': [
        {'localDate': '2026-09-30T00:00:00Z', 'sleepHours': 8},
        {'localDate': '2026-10-01T00:00:00Z', 'sleepHours': 5},
      ],
    };
    final instant = DateTime.utc(2026, 10, 1, 0, 30);
    // The same instant is Sep 30 at 8:30 PM in New York. Explicit conversion
    // makes this boundary check independent of the test machine's time zone.
    final hours = LabConditionDefinitions.sleepHoursForWorkout(
      state,
      instant,
      localize: (_) => DateTime(2026, 9, 30, 20, 30),
    );
    expect(hours, 8);
    // Stored date labels must not be passed through the instant converter.
    var conversions = 0;
    LabConditionDefinitions.sleepHoursForWorkout(
      state,
      instant,
      localize: (_) {
        conversions++;
        return DateTime(2026, 9, 30, 20, 30);
      },
    );
    expect(conversions, 1);
  });

  test('latest same-day recovery record wins for both engines', () {
    final store = _baseline();
    addTearDown(store.dispose);
    for (var i = 0; i < 6; i++) {
      _addSleep(store, i, _sessionStart(i), i < 3 ? 8 : 6);
    }
    final start = _addSession(store, 6);
    _addSleep(store, 6, start, 8);
    _addSleep(store, 7, start, 6);
    final evidence = _report(
      store,
    ).evidence.singleWhere((item) => item.id == 'sleep');
    final result = LabExperimentAnalyzer.analyze(
      LabExperimentTemplates.sleepTarget(start: DateTime(2026, 8, 1)),
      store.exportState(),
    );
    expect(evidence.sampleLabel, '3 at 7+ h · 4 under 7 h');
    expect(result.samplesA, hasLength(3));
    expect(result.samplesB, hasLength(4));
  });

  for (final weight in [80.0, 120.0]) {
    test(
      'both engines retain the direction of a matched performance association: $weight',
      () {
        final store = _baseline(withCaffeineWeight: weight);
        addTearDown(store.dispose);
        final evidence = _report(
          store,
        ).evidence.singleWhere((item) => item.id == 'caffeine');
        final result = LabExperimentAnalyzer.analyze(
          LabExperimentTemplates.caffeineTiming(start: DateTime(2026, 8, 1)),
          store.exportState(),
        );
        final expected = weight - 100;
        expect(evidence.effectPercent, closeTo(expected, .00001));
        expect(result.percentDifference, closeTo(expected, .00001));
        expect(evidence.positive, weight > 100);
        expect(evidence.comparison, contains('below 25 mg are excluded'));
        expect(
          result.summary,
          contains('Missing habit entries do not prove absence'),
        );
      },
    );
  }

  test('saved caffeine experiment retains custom threshold and windows', () {
    final legacy = _savedExperiment(
      template: LabExperimentTemplate.caffeineTiming,
      a: const LabExperimentCondition(
        id: 'a',
        label: 'My saved caffeine rule',
        kind: 'caffeineBeforeWorkout',
        minimum: 100,
        maximum: 300,
        windowMinutes: 120,
        metadata: {'minimumLeadMinutes': 30},
      ),
      b: const LabExperimentCondition(
        id: 'b',
        label: 'My saved baseline',
        kind: 'caffeineBeforeWorkout',
        maximum: 0,
        windowMinutes: 240,
      ),
    );
    final original = legacy.toJson();
    final restored = LabExperiment.fromJson(original);
    expect(restored.toJson(), original);
    expect(restored.conditionA.description, contains('100–300 mg'));
    expect(restored.conditionA.description, contains('30–120 minutes'));
    expect(restored.conditionB.description, contains('0–240 minutes'));
    final store = _baseline();
    addTearDown(store.dispose);
    final start = _addSession(store, 6);
    _addCaffeine(store, 6, start, 25, 20);
    final result = LabExperimentAnalyzer.analyze(restored, store.exportState());
    // The new default accepts it; the saved rules still exclude this session.
    expect(result.samplesA, hasLength(3));
    expect(result.samplesB, hasLength(3));
    _expectCaffeineCounts(store, 4, 3);
  });

  test('saved sleep experiment keeps previous UTC-date join and threshold', () {
    final legacy = _savedExperiment(
      template: LabExperimentTemplate.sleepTarget,
      a: const LabExperimentCondition(
        id: 'a',
        label: 'Saved 7.5-hour target',
        kind: 'previousNightSleep',
        minimum: 7.5,
      ),
      b: const LabExperimentCondition(
        id: 'b',
        label: 'Saved comparison',
        kind: 'previousNightSleep',
        maximum: 7.49,
      ),
    );
    final original = legacy.toJson();
    final restored = LabExperiment.fromJson(original);
    expect(restored.toJson(), original);
    expect(
      restored.conditionA.description,
      contains('previous UTC date (saved criteria)'),
    );
    final start = DateTime.utc(2026, 9, 10, 18);
    final state = <String, dynamic>{
      'workoutHistory': [
        {
          'sessionId': 's',
          'workout': 'Upper',
          'date': start.toIso8601String(),
          'startedAt': start.toIso8601String(),
        },
      ],
      'logs': [
        {
          's': 's',
          'e': 'Bench',
          'w': 100,
          'r': 5,
          'd': start.toIso8601String(),
        },
      ],
      'recoveryCheckIns': [
        {'localDate': '2026-09-09T00:00:00', 'sleepHours': 8},
        {'localDate': '2026-09-10T00:00:00', 'sleepHours': 6},
      ],
    };
    final result = LabExperimentAnalyzer.analyze(restored, state);
    expect(result.samplesA.single.sessionId, 's');
    expect(result.samplesB, isEmpty);
  });

  testWidgets('creatine shows unsigned adherence with no performance arrow', (
    tester,
  ) async {
    final store = AppStore();
    addTearDown(store.dispose);
    final end = DateTime(2026, 9, 30, 20);
    store.supplementEvents.add(
      SupplementEvent(
        id: 'creatine',
        name: 'Creatine',
        dose: 5,
        unit: 'g',
        takenAt: end,
        createdAt: end,
        updatedAt: end,
      ),
    );
    final evidence = const LabAnalysisEngine()
        .build(store, now: end)
        .evidence
        .singleWhere((item) => item.id == 'creatine');
    expect(evidence.effectPercent, isNull);
    expect(evidence.adherencePercent, closeTo(100 / 28, .00001));
    expect(evidence.neutral, isTrue);
    expect(evidence.toJson(), isNot(contains('positive')));
    await tester.pumpWidget(
      MaterialApp(
        theme: ProgressionBrand.theme(),
        home: Scaffold(body: LabEvidenceCard(evidence: evidence)),
      ),
    );
    expect(find.byIcon(Icons.trending_down_rounded), findsNothing);
    expect(find.byIcon(Icons.trending_up_rounded), findsNothing);
    expect(find.byIcon(Icons.calendar_month_rounded), findsOneWidget);
    expect(find.text('3.6% of days logged'), findsOneWidget);
    expect(find.text('Creatine consistency'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

DateTime _sessionStart(int index) =>
    DateTime(2026, 9, 1 + index * 3, 0, 30).toUtc();

AppStore _baseline({double withCaffeineWeight = 120}) {
  final store = AppStore();
  for (var i = 0; i < 6; i++) {
    final start = _addSession(
      store,
      i,
      weight: i < 3 ? withCaffeineWeight : 100,
    );
    if (i < 3) _addCaffeine(store, i, start, 180, 60);
  }
  return store;
}

DateTime _addSession(AppStore store, int index, {double weight = 100}) {
  final start = _sessionStart(index);
  store.workoutHistory.add(
    WorkoutRecord(
      week: 1,
      workoutIndex: 0,
      workout: 'Upper',
      date: start.add(const Duration(minutes: 45)),
      startedAt: start,
      status: WorkoutStatus.completed,
      sessionId: 's$index',
    ),
  );
  store.logs.add(
    SetLog(
      exercise: 'Bench',
      exerciseId: 'bench',
      weight: weight,
      reps: 5,
      date: start.add(const Duration(minutes: 10)),
      workout: 'Upper',
      sessionId: 's$index',
    ),
  );
  return start;
}

void _addCaffeine(
  AppStore store,
  int id,
  DateTime start,
  double dose,
  int lead,
) {
  store.supplementEvents.add(
    SupplementEvent(
      id: 'coffee$id',
      name: 'Coffee',
      dose: 1,
      unit: 'serving',
      caffeineMg: dose,
      takenAt: start.subtract(Duration(minutes: lead)),
      createdAt: start,
      updatedAt: start,
    ),
  );
}

void _addSleep(AppStore store, int id, DateTime start, double? hours) {
  final local = start.toLocal();
  store.recoveryCheckIns.add(
    RecoveryCheckIn(
      id: 'recovery$id',
      localDate: DateTime(local.year, local.month, local.day),
      sleepHours: hours,
      createdAt: start,
      updatedAt: start,
    ),
  );
}

LabReport _report(AppStore store) =>
    const LabAnalysisEngine().build(store, now: DateTime(2026, 10, 1));

void _expectCaffeineCounts(AppStore store, int a, int b) {
  final evidence = _report(
    store,
  ).evidence.singleWhere((item) => item.id == 'caffeine');
  final result = LabExperimentAnalyzer.analyze(
    LabExperimentTemplates.caffeineTiming(start: DateTime(2026, 8, 1)),
    store.exportState(),
  );
  expect(evidence.sampleLabel, '$a with · $b without');
  expect(result.samplesA, hasLength(a));
  expect(result.samplesB, hasLength(b));
}

LabExperiment _savedExperiment({
  required LabExperimentTemplate template,
  required LabExperimentCondition a,
  required LabExperimentCondition b,
}) => LabExperiment(
  id: 'saved',
  name: 'Saved criteria',
  template: template,
  metric: LabExperimentMetric.estimatedStrength,
  conditionA: a,
  conditionB: b,
  startedAt: DateTime.utc(2026, 8, 1),
  minimumSessionsPerCondition: 3,
);
