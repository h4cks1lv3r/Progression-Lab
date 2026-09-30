import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:progression_lab/athletic_history.dart';
import 'package:progression_lab/brand.dart';
import 'package:progression_lab/main.dart' show WorkoutScreen;
import 'package:progression_lab/program.dart';
import 'package:progression_lab/store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('iron_cadence/storage');
  setUp(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => null),
  );
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );

  AthleticSessionDraft functional(String id, int day) => AthleticSessionDraft(
    sessionId: id,
    programRun: 1,
    week: 1,
    sessionIndex: day,
    startedAt: DateTime(2026, 9, 1),
    completedDrills: const [0, 1],
    elapsedSeconds: 120,
  );
  DraftSetInput strength({int cadence = 4, int week = 1, bool past = false}) =>
      DraftSetInput(
        week: week,
        workoutIndex: 0,
        workout: ProgramEngine.week(week, cadence).workouts.first.name,
        exerciseIndex: 0,
        setNumber: 1,
        sessionId: 'strength-$cadence-$week-$past',
        weight: '100',
        reps: '9',
        notes: 'Current entry',
        days: cadence,
        retroactive: past,
        startedAt: DateTime(2026, 9, 1),
        elapsedSeconds: 32,
        performedAt: past ? DateTime(2026, 8, 15, 9, 30) : null,
        inputsByExercise: const {
          '1:lat-pulldown': {
            'weight': '80',
            'reps': '11',
            'notes': 'Return here',
          },
        },
      );

  test(
    'restoring two Functional drafts retains both and finishing one removes only it',
    () async {
      final original = AppStore()..automaticBackupsEnabled = false;
      await original.saveAthleticDraft(functional('day-a', 0));
      await original.saveAthleticDraft(functional('day-b', 1));
      final restored = AppStore()..automaticBackupsEnabled = false;
      await restored.restoreState(original.exportState());
      expect(
        restored
            .athleticDraftFor(weekNumber: 1, sessionIndex: 0)!
            .completedDrills,
        [0, 1],
      );
      await restored.completeAthleticSession(
        effort: 6,
        notes: '',
        sessionId: 'day-a',
        weekNumber: 1,
        targetSessionIndex: 0,
        partial: true,
      );
      expect(restored.athleticHistory.single.sessionIndex, 0);
      expect(restored.athleticHistory.single.durationSeconds, 120);
      expect(restored.athleticDraftFor(weekNumber: 1, sessionIndex: 0), isNull);
      expect(
        restored.athleticDraftFor(weekNumber: 1, sessionIndex: 1)!.sessionId,
        'day-b',
      );
      original.dispose();
      restored.dispose();
    },
  );

  test(
    'resuming another cadence retains the calendar and other drafts',
    () async {
      final store = AppStore()..automaticBackupsEnabled = false;
      final calendar = store.programStartDate;
      await store.setDraft(strength());
      final other = strength(cadence: 3, week: 2);
      await store.setDraft(other);
      await store.resumeStrengthDraft(other);
      expect(store.days, 3);
      expect(store.week, 2);
      expect(store.workoutIndex, 0);
      expect(store.programStartDate, calendar);
      expect(
        store.drafts.map((item) => item.sessionId),
        contains('strength-4-1-false'),
      );
      expect(store.draft!.sessionId, other.sessionId);
      store.dispose();
    },
  );

  test(
    'failed draft resume rolls back cadence, active scope and inputs',
    () async {
      final store = AppStore()..automaticBackupsEnabled = false;
      final current = strength();
      final other = strength(cadence: 3, week: 2);
      await store.setDraft(current);
      await store.setDraft(other);
      await store.resumeStrengthDraft(current);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'write')
              throw PlatformException(code: 'write_failed');
            return null;
          });
      await expectLater(
        store.resumeStrengthDraft(other),
        throwsA(isA<PlatformException>()),
      );
      expect(store.days, 4);
      expect(store.week, 1);
      expect(store.draft!.sessionId, current.sessionId);
      expect(store.drafts.length, 2);
      store.dispose();
    },
  );

  test(
    'past workout records performed, planned and entered dates separately',
    () async {
      final store = AppStore()..automaticBackupsEnabled = false;
      final performed = DateTime(2026, 8, 15, 9, 30);
      final planned = DateTime(2026, 8, 12);
      await store.recordWorkout(
        weekNumber: 1,
        targetWorkoutIndex: 0,
        workout: 'Past session',
        status: WorkoutStatus.completed,
        sessionId: 'past',
        retroactive: true,
        scheduledDate: planned,
        performedAt: performed,
      );
      expect(store.workoutHistory.single.date, performed);
      expect(store.workoutHistory.single.scheduledDate, planned);
      expect(store.workoutHistory.single.loggedAt.isAfter(performed), isTrue);
      store.dispose();
    },
  );

  test('unit changes convert every pending exercise input', () async {
    final store = AppStore()..automaticBackupsEnabled = false;
    await store.setDraft(strength());
    await store.setUnit('kg');
    expect(double.parse(store.draft!.weight), closeTo(45.36, .01));
    expect(
      double.parse(store.draft!.inputsByExercise['1:lat-pulldown']!['weight']!),
      closeTo(36.29, .01),
    );
    expect(
      store.draft!.inputsByExercise['1:lat-pulldown']!['notes'],
      'Return here',
    );
    store.dispose();
  });

  testWidgets(
    'resumed Strength duration uses active time instead of its old start date',
    (tester) async {
      final store = AppStore()
        ..automaticBackupsEnabled = false
        ..integrationState = {
          'contextualGuides': {'tipsEnabled': false},
        };
      await store.setDraft(strength());
      final week = ProgramEngine.week(1, 4);
      await tester.pumpWidget(
        MaterialApp(
          theme: ProgressionBrand.theme(),
          home: WorkoutScreen(
            store: store,
            week: week,
            workout: week.workouts.first,
            workoutIndex: 0,
            scheduledDate: DateTime(2026, 9, 1),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(store.draft!.elapsedSeconds, inInclusiveRange(32, 60));
      expect(store.draft!.startedAt, DateTime(2026, 9, 1));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      store.dispose();
    },
  );
}
