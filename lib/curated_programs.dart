// Actor-inspired programs adapted from the three research reports supplied
// with this feature request. These are original app arrangements, not paid
// trainer programs or promises of a particular physique. Source labels describe
// the supplied evidence; external source pages have not been independently
// verified by this catalog. Fixed doses added for incomplete source material,
// substitutions and volume changes are described in each program's notes.

enum CuratedMetric { reps, loadedReps, duration, distance, loadedDistance }

class CuratedSetTarget {
  const CuratedSetTarget({
    this.reps,
    this.seconds,
    this.meters,
    this.note = '',
  });
  final String? reps;
  final int? seconds;
  final double? meters;
  final String note;
}

class CuratedMovement {
  const CuratedMovement({
    required this.name,
    required this.metric,
    required this.targets,
    this.restSeconds = 60,
    this.instructions = '',
    this.group,
  });
  final String name;
  final CuratedMetric metric;
  final List<CuratedSetTarget> targets;
  final int restSeconds;
  final String instructions;

  /// Contiguous movements with this key alternate one set per movement.
  /// All movements in a group have the same number of targets (rounds).
  final String? group;
}

class CuratedDay {
  const CuratedDay({
    required this.title,
    required this.movements,
    this.notes = '',
  });
  final String title;
  final List<CuratedMovement> movements;
  final String notes;
}

class CuratedSource {
  const CuratedSource({required this.title, required this.url});
  final String title;

  /// Empty for supplied-report attribution that has no public URL.
  final String url;
}

class CuratedProgram {
  const CuratedProgram({
    required this.id,
    required this.actor,
    required this.role,
    required this.title,
    required this.focus,
    required this.evidence,
    required this.notes,
    required this.days,
    required this.sources,
  });
  final String id;
  final String actor;
  final String role;
  final String title;
  final String focus;
  final String evidence;
  final String notes;
  final List<CuratedDay> days;
  final List<CuratedSource> sources;
}

abstract final class CuratedPrograms {
  static CuratedProgram? byId(String id) {
    for (final program in all) {
      if (program.id == id) return program;
    }
    return null;
  }

  static const List<CuratedProgram> all = [
    CuratedProgram(
      id: 'hunnam_arthur',
      actor: 'Charlie Hunnam',
      role: 'King Arthur',
      title: 'Warrior Conditioning',
      focus: 'Full-body strength, bodyweight control and boxing fitness.',
      evidence:
          'Adapted reconstruction. The report documents Hunnam’s training style, not a trainer-published five-day routine.',
      notes:
          'Repeat these five sessions as a weekly sequence with two recovery days; they do not need to be consecutive. Use the first week to choose manageable loads. Keep about two clean reps in reserve; bodyweight work may use assistance. Add reps within the range before a small load increase. Repeat or reduce the load if form or recovery declines. Film preparation timelines are not targets for your results. These are app adaptations, not endorsed actor routines. Push-up and pulling volume is reduced from the report. Timed skill practice and core targets are supplied by the app. Grappling is replaced with timed solo skill work.',
      sources: [
        CuratedSource(
          title:
              'Supplied research: Eight Hollywood Transformations: Training Timelines and 5-Day Plans — Charlie Hunnam',
          url: '',
        ),
      ],
      days: [
        CuratedDay(
          title: 'Full-body strength',
          notes:
              'Before lifting, do 5–10 minutes of easy movement and lighter practice sets. Practice sets are not part of the listed working sets. Choose a comfortable range of motion. For one-sided movements, the target is per side and one logged set includes both sides.',
          movements: [
            CuratedMovement(
              name: 'Barbell Back Squat',
              metric: CuratedMetric.loadedReps,
              targets: _targets1,
              restSeconds: 150,
            ),
            CuratedMovement(
              name: 'Barbell Bench Press',
              metric: CuratedMetric.loadedReps,
              targets: _targets1,
              restSeconds: 150,
            ),
            CuratedMovement(
              name: 'Push-up',
              metric: CuratedMetric.reps,
              targets: _targets2,
              restSeconds: 60,
            ),
            CuratedMovement(
              name: 'Pull-up',
              metric: CuratedMetric.reps,
              targets: _targets3,
              restSeconds: 60,
              instructions: 'Use a band or assisted machine if needed.',
            ),
            CuratedMovement(
              name: 'Plank',
              metric: CuratedMetric.duration,
              targets: _targets4,
              restSeconds: 60,
            ),
          ],
        ),
        CuratedDay(
          title: 'Boxing and core',
          notes:
              'Complete one set of each core movement, then rest. Keep bag work at a pace you can control.',
          movements: [
            CuratedMovement(
              name: 'Jump Rope',
              metric: CuratedMetric.duration,
              targets: _targets5,
              restSeconds: 60,
            ),
            CuratedMovement(
              name: 'Heavy Bag or Shadowboxing',
              metric: CuratedMetric.duration,
              targets: _targets6,
              restSeconds: 60,
              instructions:
                  'Use controlled combinations; shadowbox if no bag is available.',
            ),
            CuratedMovement(
              name: 'Hanging Knee Raise',
              metric: CuratedMetric.reps,
              targets: _targets7,
              restSeconds: 0,
              group: 'core',
            ),
            CuratedMovement(
              name: 'Dead Bug',
              metric: CuratedMetric.reps,
              targets: _targets8,
              restSeconds: 0,
              instructions: 'Eight controlled reps per side.',
              group: 'core',
            ),
            CuratedMovement(
              name: 'Sit-up',
              metric: CuratedMetric.reps,
              targets: _targets2,
              restSeconds: 60,
              group: 'core',
            ),
          ],
        ),
        CuratedDay(
          title: 'Pull and posterior chain',
          notes:
              'Before lifting, do 5–10 minutes of easy movement and lighter practice sets. Practice sets are not part of the listed working sets. Choose a comfortable range of motion. For one-sided movements, the target is per side and one logged set includes both sides.',
          movements: [
            CuratedMovement(
              name: 'Deadlift',
              metric: CuratedMetric.loadedReps,
              targets: _targets9,
              restSeconds: 180,
            ),
            CuratedMovement(
              name: 'Pull-up',
              metric: CuratedMetric.reps,
              targets: _targets3,
              restSeconds: 90,
            ),
            CuratedMovement(
              name: 'One-arm Dumbbell Row',
              metric: CuratedMetric.loadedReps,
              targets: _targets10,
              restSeconds: 90,
              instructions: 'Ten reps per side.',
            ),
            CuratedMovement(
              name: 'Cable Face Pull',
              metric: CuratedMetric.loadedReps,
              targets: _targets11,
              restSeconds: 60,
            ),
            CuratedMovement(
              name: 'Farmer Carry',
              metric: CuratedMetric.loadedDistance,
              targets: _targets12,
              restSeconds: 90,
            ),
          ],
        ),
        CuratedDay(
          title: 'Skill and mobility',
          notes:
              'This lighter session replaces the unquantified grappling day in the report.',
          movements: [
            CuratedMovement(
              name: 'Shadowboxing Footwork',
              metric: CuratedMetric.duration,
              targets: _targets13,
              restSeconds: 60,
              instructions:
                  'Practice balance, direction changes and relaxed combinations.',
            ),
            CuratedMovement(
              name: 'Hip Mobility',
              metric: CuratedMetric.duration,
              targets: _targets14,
              restSeconds: 15,
              instructions:
                  'Gentle hip rotations and lunge transitions, without forcing range.',
            ),
            CuratedMovement(
              name: 'Shoulder Mobility',
              metric: CuratedMetric.duration,
              targets: _targets14,
              restSeconds: 15,
              instructions:
                  'Slow arm circles and controlled shoulder movement.',
            ),
            CuratedMovement(
              name: 'Easy Walk',
              metric: CuratedMetric.duration,
              targets: _targets15,
              restSeconds: 0,
            ),
          ],
        ),
        CuratedDay(
          title: 'Bodyweight and arms',
          notes:
              'Before lifting, do 5–10 minutes of easy movement and lighter practice sets. Practice sets are not part of the listed working sets. Choose a comfortable range of motion. For one-sided movements, the target is per side and one logged set includes both sides.',
          movements: [
            CuratedMovement(
              name: 'Dip',
              metric: CuratedMetric.reps,
              targets: _targets16,
              restSeconds: 60,
              instructions: 'Bodyweight is enough. Use assistance as needed.',
            ),
            CuratedMovement(
              name: 'Push-up',
              metric: CuratedMetric.reps,
              targets: _targets2,
              restSeconds: 60,
            ),
            CuratedMovement(
              name: 'Chin-up',
              metric: CuratedMetric.reps,
              targets: _targets3,
              restSeconds: 60,
            ),
            CuratedMovement(
              name: 'Dumbbell Curl',
              metric: CuratedMetric.loadedReps,
              targets: _targets17,
              restSeconds: 0,
              group: 'arms',
            ),
            CuratedMovement(
              name: 'Cable Triceps Pushdown',
              metric: CuratedMetric.loadedReps,
              targets: _targets17,
              restSeconds: 75,
              group: 'arms',
            ),
            CuratedMovement(
              name: 'Incline Walk Intervals',
              metric: CuratedMetric.duration,
              targets: _targets18,
              restSeconds: 90,
              instructions:
                  'Brisk uphill effort, followed by an easy walk during each rest.',
            ),
          ],
        ),
      ],
    ),
    CuratedProgram(
      id: 'cavill_superman',
      actor: 'Henry Cavill',
      role: 'Superman',
      title: 'Heavy Strength',
      focus:
          'Compound strength with rowing, carries and controlled conditioning.',
      evidence:
          'Adapted reconstruction of methods attributed to Mark Twight and Michael Blevins. It is not the complete Gym Jones program.',
      notes:
          'Repeat these five sessions as a weekly sequence with two recovery days; they do not need to be consecutive. Use the first week to choose manageable loads. Keep about two clean reps in reserve; bodyweight work may use assistance. Add reps within the range before a small load increase. Repeat or reduce the load if form or recovery declines. Film preparation timelines are not targets for your results. These are app adaptations, not endorsed actor routines. The app lowers the source’s 100-rep circuit and heavy-lift volume. Tailpipe is replaced with submaximal rows and timed rack holds. Gymnastics and max-effort work are replaced with accessible strength movements.',
      sources: [
        CuratedSource(
          title:
              'Supplied research: Eight Hollywood Transformations: Training Timelines and 5-Day Plans — Henry Cavill',
          url: '',
        ),
      ],
      days: [
        CuratedDay(
          title: 'Upper strength',
          notes:
              'Before lifting, do 5–10 minutes of easy movement and lighter practice sets. Practice sets are not part of the listed working sets. Choose a comfortable range of motion. For one-sided movements, the target is per side and one logged set includes both sides.',
          movements: [
            CuratedMovement(
              name: 'Incline Barbell Press',
              metric: CuratedMetric.loadedReps,
              targets: _targets9,
              restSeconds: 150,
            ),
            CuratedMovement(
              name: 'Barbell Bench Press',
              metric: CuratedMetric.loadedReps,
              targets: _targets9,
              restSeconds: 150,
            ),
            CuratedMovement(
              name: 'Pull-up',
              metric: CuratedMetric.reps,
              targets: _targets3,
              restSeconds: 90,
            ),
            CuratedMovement(
              name: 'Barbell Row',
              metric: CuratedMetric.loadedReps,
              targets: _targets1,
              restSeconds: 90,
            ),
            CuratedMovement(
              name: 'Rowing Ergometer',
              metric: CuratedMetric.distance,
              targets: _targets19,
              restSeconds: 0,
              instructions: 'Strong, controlled pace; not an all-out sprint.',
              group: 'row_hold',
            ),
            CuratedMovement(
              name: 'Kettlebell Front-rack Hold',
              metric: CuratedMetric.duration,
              targets: _targets4,
              restSeconds: 90,
              instructions:
                  'Use a load that permits normal breathing; stop before grip fails.',
              group: 'row_hold',
            ),
          ],
        ),
        CuratedDay(
          title: 'Lower strength',
          notes:
              'Before lifting, do 5–10 minutes of easy movement and lighter practice sets. Practice sets are not part of the listed working sets. Choose a comfortable range of motion. For one-sided movements, the target is per side and one logged set includes both sides.',
          movements: [
            CuratedMovement(
              name: 'Deadlift',
              metric: CuratedMetric.loadedReps,
              targets: _targets9,
              restSeconds: 180,
            ),
            CuratedMovement(
              name: 'Front Squat',
              metric: CuratedMetric.loadedReps,
              targets: _targets9,
              restSeconds: 150,
            ),
            CuratedMovement(
              name: 'Walking Lunge',
              metric: CuratedMetric.loadedReps,
              targets: _targets10,
              restSeconds: 90,
              instructions: 'Ten steps per leg.',
            ),
            CuratedMovement(
              name: 'Plank',
              metric: CuratedMetric.duration,
              targets: _targets4,
              restSeconds: 60,
            ),
            CuratedMovement(
              name: 'Farmer Carry',
              metric: CuratedMetric.loadedDistance,
              targets: _targets12,
              restSeconds: 90,
            ),
          ],
        ),
        CuratedDay(
          title: 'Conditioning circuit',
          notes:
              'Complete one set of each grouped movement before the round rest. Reduce pace before form degrades.',
          movements: [
            CuratedMovement(
              name: 'Kettlebell Swing',
              metric: CuratedMetric.loadedReps,
              targets: _targets17,
              restSeconds: 0,
              group: 'conditioning',
            ),
            CuratedMovement(
              name: 'Goblet Squat',
              metric: CuratedMetric.loadedReps,
              targets: _targets10,
              restSeconds: 0,
              group: 'conditioning',
            ),
            CuratedMovement(
              name: 'Squat Thrust',
              metric: CuratedMetric.reps,
              targets: _targets8,
              restSeconds: 0,
              group: 'conditioning',
            ),
            CuratedMovement(
              name: 'Jumping Jack',
              metric: CuratedMetric.reps,
              targets: _targets20,
              restSeconds: 90,
              group: 'conditioning',
            ),
            CuratedMovement(
              name: 'Rowing Ergometer',
              metric: CuratedMetric.distance,
              targets: _targets21,
              restSeconds: 90,
              instructions: 'Keep each interval at a repeatable pace.',
            ),
          ],
        ),
        CuratedDay(
          title: 'Upper muscle',
          notes:
              'Before lifting, do 5–10 minutes of easy movement and lighter practice sets. Practice sets are not part of the listed working sets. Choose a comfortable range of motion. For one-sided movements, the target is per side and one logged set includes both sides.',
          movements: [
            CuratedMovement(
              name: 'Seated Dumbbell Press',
              metric: CuratedMetric.loadedReps,
              targets: _targets22,
              restSeconds: 90,
            ),
            CuratedMovement(
              name: 'Dumbbell Renegade Row',
              metric: CuratedMetric.loadedReps,
              targets: _targets8,
              restSeconds: 90,
              instructions:
                  'Eight per side; widen the feet for support and keep the trunk stable.',
            ),
            CuratedMovement(
              name: 'Arnold Press',
              metric: CuratedMetric.loadedReps,
              targets: _targets23,
              restSeconds: 90,
            ),
            CuratedMovement(
              name: 'Hammer Curl',
              metric: CuratedMetric.loadedReps,
              targets: _targets17,
              restSeconds: 0,
              group: 'arms',
            ),
            CuratedMovement(
              name: 'Dip',
              metric: CuratedMetric.reps,
              targets: _targets16,
              restSeconds: 75,
              group: 'arms',
            ),
          ],
        ),
        CuratedDay(
          title: 'Full-body power',
          notes:
              'Before lifting, do 5–10 minutes of easy movement and lighter practice sets. Practice sets are not part of the listed working sets. Choose a comfortable range of motion. For one-sided movements, the target is per side and one logged set includes both sides.',
          movements: [
            CuratedMovement(
              name: 'Barbell Back Squat',
              metric: CuratedMetric.loadedReps,
              targets: _targets9,
              restSeconds: 150,
            ),
            CuratedMovement(
              name: 'Dumbbell Push Press',
              metric: CuratedMetric.loadedReps,
              targets: _targets24,
              restSeconds: 90,
              instructions: 'Use a light load and a controlled leg drive.',
            ),
            CuratedMovement(
              name: 'Sled Push',
              metric: CuratedMetric.loadedDistance,
              targets: _targets25,
              restSeconds: 90,
              instructions:
                  'Use a manageable sled load and move with controlled steps.',
            ),
            CuratedMovement(
              name: 'Dead Bug',
              metric: CuratedMetric.reps,
              targets: _targets8,
              restSeconds: 60,
              instructions: 'Eight per side.',
            ),
            CuratedMovement(
              name: 'Side Plank',
              metric: CuratedMetric.duration,
              targets: _targets4,
              restSeconds: 60,
              instructions:
                  'Fifteen seconds per side; one logged interval includes both sides.',
            ),
          ],
        ),
      ],
    ),
    CuratedProgram(
      id: 'reynolds_deadpool',
      actor: 'Ryan Reynolds',
      role: 'Deadpool',
      title: 'Athletic Muscle',
      focus: 'Balanced strength, single-leg work, carries and conditioning.',
      evidence:
          'Adapted reconstruction from Don Saladino’s public training principles. This does not reproduce his paid Deadpool program.',
      notes:
          'Repeat these five sessions as a weekly sequence with two recovery days; they do not need to be consecutive. Use the first week to choose manageable loads. Keep about two clean reps in reserve; bodyweight work may use assistance. Add reps within the range before a small load increase. Repeat or reduce the load if form or recovery declines. Film preparation timelines are not targets for your results. These are app adaptations, not endorsed actor routines. The supplied report leaves some arm and conditioning doses open. The app supplies those targets and a repeatable five-session sequence. Warm-ups use controlled jumps, throws or carries only where equipment and experience permit.',
      sources: [
        CuratedSource(
          title:
              'Supplied research: Eight Hollywood Transformations: Training Timelines and 5-Day Plans — Ryan Reynolds',
          url: '',
        ),
        CuratedSource(
          title: 'Don Saladino — Deadpool Trilogy program context',
          url: 'https://www.donsaladino.com/deadpool-trilogy',
        ),
      ],
      days: [
        CuratedDay(
          title: 'Leg strength',
          notes:
              'Before lifting, do 5–10 minutes of easy movement and lighter practice sets. Practice sets are not part of the listed working sets. Choose a comfortable range of motion. For one-sided movements, the target is per side and one logged set includes both sides.',
          movements: [
            CuratedMovement(
              name: 'Goblet Squat',
              metric: CuratedMetric.loadedReps,
              targets: _targets26,
              restSeconds: 120,
            ),
            CuratedMovement(
              name: 'Romanian Deadlift',
              metric: CuratedMetric.loadedReps,
              targets: _targets8,
              restSeconds: 120,
            ),
            CuratedMovement(
              name: 'Bulgarian Split Squat',
              metric: CuratedMetric.loadedReps,
              targets: _targets10,
              restSeconds: 90,
              instructions: 'Ten per leg; use hand support if needed.',
            ),
            CuratedMovement(
              name: 'Leg Press',
              metric: CuratedMetric.loadedReps,
              targets: _targets17,
              restSeconds: 90,
            ),
            CuratedMovement(
              name: 'Standing Calf Raise',
              metric: CuratedMetric.loadedReps,
              targets: _targets11,
              restSeconds: 60,
            ),
          ],
        ),
        CuratedDay(
          title: 'Chest and push',
          notes:
              'Before lifting, do 5–10 minutes of easy movement and lighter practice sets. Practice sets are not part of the listed working sets. Choose a comfortable range of motion. For one-sided movements, the target is per side and one logged set includes both sides.',
          movements: [
            CuratedMovement(
              name: 'Incline Dumbbell Press',
              metric: CuratedMetric.loadedReps,
              targets: _targets27,
              restSeconds: 120,
            ),
            CuratedMovement(
              name: 'Barbell Bench Press',
              metric: CuratedMetric.loadedReps,
              targets: _targets8,
              restSeconds: 120,
            ),
            CuratedMovement(
              name: 'One-arm Landmine Press',
              metric: CuratedMetric.loadedReps,
              targets: _targets10,
              restSeconds: 90,
              instructions: 'Ten per side.',
            ),
            CuratedMovement(
              name: 'Cable Fly',
              metric: CuratedMetric.loadedReps,
              targets: _targets17,
              restSeconds: 60,
            ),
            CuratedMovement(
              name: 'Farmer Carry',
              metric: CuratedMetric.loadedDistance,
              targets: _targets28,
              restSeconds: 90,
            ),
          ],
        ),
        CuratedDay(
          title: 'Back and pull',
          notes:
              'Before lifting, do 5–10 minutes of easy movement and lighter practice sets. Practice sets are not part of the listed working sets. Choose a comfortable range of motion. For one-sided movements, the target is per side and one logged set includes both sides.',
          movements: [
            CuratedMovement(
              name: 'Pull-up',
              metric: CuratedMetric.reps,
              targets: _targets29,
              restSeconds: 90,
            ),
            CuratedMovement(
              name: 'One-arm Dumbbell Row',
              metric: CuratedMetric.loadedReps,
              targets: _targets10,
              restSeconds: 90,
              instructions: 'Ten per side.',
            ),
            CuratedMovement(
              name: 'Seated Cable Row',
              metric: CuratedMetric.loadedReps,
              targets: _targets17,
              restSeconds: 90,
            ),
            CuratedMovement(
              name: 'Cable Face Pull',
              metric: CuratedMetric.loadedReps,
              targets: _targets11,
              restSeconds: 60,
            ),
          ],
        ),
        CuratedDay(
          title: 'Arms and core',
          notes:
              'Before lifting, do 5–10 minutes of easy movement and lighter practice sets. Practice sets are not part of the listed working sets. Choose a comfortable range of motion. For one-sided movements, the target is per side and one logged set includes both sides.',
          movements: [
            CuratedMovement(
              name: 'Dumbbell Triceps Kickback',
              metric: CuratedMetric.loadedReps,
              targets: _targets30,
              restSeconds: 0,
              group: 'arms_a',
            ),
            CuratedMovement(
              name: 'Dumbbell Curl',
              metric: CuratedMetric.loadedReps,
              targets: _targets17,
              restSeconds: 75,
              group: 'arms_a',
            ),
            CuratedMovement(
              name: 'Close-grip Push-up',
              metric: CuratedMetric.reps,
              targets: _targets7,
              restSeconds: 0,
              group: 'arms_b',
            ),
            CuratedMovement(
              name: 'Hammer Curl',
              metric: CuratedMetric.loadedReps,
              targets: _targets17,
              restSeconds: 75,
              group: 'arms_b',
            ),
            CuratedMovement(
              name: 'Hanging Knee Raise',
              metric: CuratedMetric.reps,
              targets: _targets8,
              restSeconds: 60,
            ),
            CuratedMovement(
              name: 'Reverse Crunch',
              metric: CuratedMetric.reps,
              targets: _targets2,
              restSeconds: 60,
            ),
          ],
        ),
        CuratedDay(
          title: 'Full-body conditioning',
          notes:
              'Before lifting, do 5–10 minutes of easy movement and lighter practice sets. Practice sets are not part of the listed working sets. Choose a comfortable range of motion. For one-sided movements, the target is per side and one logged set includes both sides.',
          movements: [
            CuratedMovement(
              name: 'Deadlift',
              metric: CuratedMetric.loadedReps,
              targets: _targets9,
              restSeconds: 180,
            ),
            CuratedMovement(
              name: 'Kettlebell Rack Carry',
              metric: CuratedMetric.loadedDistance,
              targets: _targets28,
              restSeconds: 90,
            ),
            CuratedMovement(
              name: 'Kettlebell Swing',
              metric: CuratedMetric.loadedReps,
              targets: _targets17,
              restSeconds: 0,
              group: 'complex',
            ),
            CuratedMovement(
              name: 'Goblet Squat',
              metric: CuratedMetric.loadedReps,
              targets: _targets10,
              restSeconds: 90,
              group: 'complex',
            ),
            CuratedMovement(
              name: 'Stationary Bike Intervals',
              metric: CuratedMetric.duration,
              targets: _targets18,
              restSeconds: 90,
              instructions:
                  'Ride hard but controlled, then pedal easily during each rest.',
            ),
          ],
        ),
      ],
    ),
    CuratedProgram(
      id: 'jackman_wolverine',
      actor: 'Hugh Jackman',
      role: 'Wolverine',
      title: 'Four-Lift Strength',
      focus:
          'Bench, squat, pull-up and deadlift practice with muscle-building accessories.',
      evidence:
          'Adapted from the report’s David Kingsbury structure. The app uses rep ranges, not his original percentage-based four-week wave.',
      notes:
          'Repeat these five sessions as a weekly sequence with two recovery days; they do not need to be consecutive. Use the first week to choose manageable loads. Keep about two clean reps in reserve; bodyweight work may use assistance. Add reps within the range before a small load increase. Repeat or reduce the load if form or recovery declines. Film preparation timelines are not targets for your results. These are app adaptations, not endorsed actor routines. Main sets use repeatable submaximal loads instead of a 1RM test. Accessory volume is reduced and behind-neck presses are replaced. No dehydration, film diet or automatic 5–10% max increase is part of this program.',
      sources: [
        CuratedSource(
          title:
              'Supplied research: Eight Hollywood Transformations: Training Timelines and 5-Day Plans — Hugh Jackman',
          url: '',
        ),
      ],
      days: [
        CuratedDay(
          title: 'Bench focus',
          notes:
              'Before lifting, do 5–10 minutes of easy movement and lighter practice sets. Practice sets are not part of the listed working sets. Choose a comfortable range of motion. For one-sided movements, the target is per side and one logged set includes both sides.',
          movements: [
            CuratedMovement(
              name: 'Barbell Bench Press',
              metric: CuratedMetric.loadedReps,
              targets: _targets31,
              restSeconds: 150,
            ),
            CuratedMovement(
              name: 'Dumbbell Shoulder Press',
              metric: CuratedMetric.loadedReps,
              targets: _targets10,
              restSeconds: 90,
            ),
            CuratedMovement(
              name: 'Cable Lateral Raise',
              metric: CuratedMetric.loadedReps,
              targets: _targets17,
              restSeconds: 60,
            ),
            CuratedMovement(
              name: 'Dip',
              metric: CuratedMetric.reps,
              targets: _targets16,
              restSeconds: 0,
              group: 'triceps',
            ),
            CuratedMovement(
              name: 'Cable Triceps Pushdown',
              metric: CuratedMetric.loadedReps,
              targets: _targets30,
              restSeconds: 75,
              group: 'triceps',
            ),
          ],
        ),
        CuratedDay(
          title: 'Squat focus',
          notes:
              'Before lifting, do 5–10 minutes of easy movement and lighter practice sets. Practice sets are not part of the listed working sets. Choose a comfortable range of motion. For one-sided movements, the target is per side and one logged set includes both sides.',
          movements: [
            CuratedMovement(
              name: 'Barbell Back Squat',
              metric: CuratedMetric.loadedReps,
              targets: _targets31,
              restSeconds: 150,
            ),
            CuratedMovement(
              name: 'Front Squat',
              metric: CuratedMetric.loadedReps,
              targets: _targets23,
              restSeconds: 120,
            ),
            CuratedMovement(
              name: 'Single-leg Press',
              metric: CuratedMetric.loadedReps,
              targets: _targets10,
              restSeconds: 90,
              instructions: 'Ten per leg.',
            ),
            CuratedMovement(
              name: 'Lateral Raise',
              metric: CuratedMetric.loadedReps,
              targets: _targets32,
              restSeconds: 0,
              group: 'shoulders',
            ),
            CuratedMovement(
              name: 'Rear-delt Fly',
              metric: CuratedMetric.loadedReps,
              targets: _targets32,
              restSeconds: 75,
              group: 'shoulders',
            ),
          ],
        ),
        CuratedDay(
          title: 'Pull focus',
          notes:
              'Before lifting, do 5–10 minutes of easy movement and lighter practice sets. Practice sets are not part of the listed working sets. Choose a comfortable range of motion. For one-sided movements, the target is per side and one logged set includes both sides.',
          movements: [
            CuratedMovement(
              name: 'Pull-up',
              metric: CuratedMetric.reps,
              targets: _targets29,
              restSeconds: 150,
              instructions:
                  'Use assistance if needed. Record clean bodyweight repetitions.',
            ),
            CuratedMovement(
              name: 'One-arm Dumbbell Row',
              metric: CuratedMetric.loadedReps,
              targets: _targets17,
              restSeconds: 90,
              instructions: 'Twelve per side.',
            ),
            CuratedMovement(
              name: 'Inverted Row',
              metric: CuratedMetric.reps,
              targets: _targets10,
              restSeconds: 60,
            ),
            CuratedMovement(
              name: 'Incline Dumbbell Curl',
              metric: CuratedMetric.loadedReps,
              targets: _targets8,
              restSeconds: 0,
              group: 'curls',
            ),
            CuratedMovement(
              name: 'Hammer Curl',
              metric: CuratedMetric.loadedReps,
              targets: _targets8,
              restSeconds: 75,
              group: 'curls',
            ),
          ],
        ),
        CuratedDay(
          title: 'Deadlift focus',
          notes:
              'Before lifting, do 5–10 minutes of easy movement and lighter practice sets. Practice sets are not part of the listed working sets. Choose a comfortable range of motion. For one-sided movements, the target is per side and one logged set includes both sides.',
          movements: [
            CuratedMovement(
              name: 'Deadlift',
              metric: CuratedMetric.loadedReps,
              targets: _targets31,
              restSeconds: 150,
            ),
            CuratedMovement(
              name: 'Romanian Deadlift',
              metric: CuratedMetric.loadedReps,
              targets: _targets33,
              restSeconds: 120,
              instructions:
                  'Use a moderate accessory load after the main lift.',
            ),
            CuratedMovement(
              name: 'Hack Squat',
              metric: CuratedMetric.loadedReps,
              targets: _targets10,
              restSeconds: 120,
            ),
            CuratedMovement(
              name: 'Hanging Knee Raise',
              metric: CuratedMetric.reps,
              targets: _targets7,
              restSeconds: 60,
            ),
            CuratedMovement(
              name: 'Dead Bug',
              metric: CuratedMetric.reps,
              targets: _targets8,
              restSeconds: 60,
              instructions: 'Eight per side.',
            ),
          ],
        ),
        CuratedDay(
          title: 'Upper muscle and arms',
          notes:
              'Before lifting, do 5–10 minutes of easy movement and lighter practice sets. Practice sets are not part of the listed working sets. Choose a comfortable range of motion. For one-sided movements, the target is per side and one logged set includes both sides.',
          movements: [
            CuratedMovement(
              name: 'Incline Dumbbell Press',
              metric: CuratedMetric.loadedReps,
              targets: _targets10,
              restSeconds: 120,
            ),
            CuratedMovement(
              name: 'Cable Fly',
              metric: CuratedMetric.loadedReps,
              targets: _targets10,
              restSeconds: 90,
            ),
            CuratedMovement(
              name: 'Close-grip Bench Press',
              metric: CuratedMetric.loadedReps,
              targets: _targets10,
              restSeconds: 120,
            ),
            CuratedMovement(
              name: 'Dumbbell Curl',
              metric: CuratedMetric.loadedReps,
              targets: _targets10,
              restSeconds: 0,
              group: 'arms',
            ),
            CuratedMovement(
              name: 'Cable Triceps Pushdown',
              metric: CuratedMetric.loadedReps,
              targets: _targets10,
              restSeconds: 75,
              group: 'arms',
            ),
            CuratedMovement(
              name: 'Easy Cardio',
              metric: CuratedMetric.duration,
              targets: _targets34,
              restSeconds: 0,
              instructions:
                  'Choose a walk, bike or row at a conversational pace.',
            ),
          ],
        ),
      ],
    ),
    CuratedProgram(
      id: 'hemsworth_thor',
      actor: 'Chris Hemsworth',
      role: 'Thor',
      title: 'Strength and Size',
      focus:
          'Chest, back, legs and shoulder strength with a functional finish.',
      evidence:
          'Adapted reconstruction blending Duffy Gaver’s first-film emphasis with later Luke Zocchi-style conditioning.',
      notes:
          'Repeat these five sessions as a weekly sequence with two recovery days; they do not need to be consecutive. Use the first week to choose manageable loads. Keep about two clean reps in reserve; bodyweight work may use assistance. Add reps within the range before a small load increase. Repeat or reduce the load if form or recovery declines. Film preparation timelines are not targets for your results. These are app adaptations, not endorsed actor routines. Heavy lower-body volume is reduced. The app supplies fixed conditioning doses and six accessible movements for a three-round version of the reported six-by-six format. It is not an exact Thor film routine.',
      sources: [
        CuratedSource(
          title:
              'Supplied research: Eight Hollywood Transformations: Training Timelines and 5-Day Plans — Chris Hemsworth',
          url: '',
        ),
        CuratedSource(
          title: 'Fitness Volt — reported Thor training context',
          url: 'https://fitnessvolt.com/chris-hemsworth-thor-program/',
        ),
      ],
      days: [
        CuratedDay(
          title: 'Chest and back',
          notes:
              'Before lifting, do 5–10 minutes of easy movement and lighter practice sets. Practice sets are not part of the listed working sets. Choose a comfortable range of motion. For one-sided movements, the target is per side and one logged set includes both sides.',
          movements: [
            CuratedMovement(
              name: 'Barbell Bench Press',
              metric: CuratedMetric.loadedReps,
              targets: _targets1,
              restSeconds: 150,
            ),
            CuratedMovement(
              name: 'Bent-over Barbell Row',
              metric: CuratedMetric.loadedReps,
              targets: _targets1,
              restSeconds: 120,
            ),
            CuratedMovement(
              name: 'Pull-up',
              metric: CuratedMetric.reps,
              targets: _targets1,
              restSeconds: 90,
            ),
            CuratedMovement(
              name: 'Dip',
              metric: CuratedMetric.reps,
              targets: _targets1,
              restSeconds: 90,
            ),
            CuratedMovement(
              name: 'Dumbbell Fly',
              metric: CuratedMetric.loadedReps,
              targets: _targets32,
              restSeconds: 60,
            ),
          ],
        ),
        CuratedDay(
          title: 'Leg strength',
          notes:
              'Before lifting, do 5–10 minutes of easy movement and lighter practice sets. Practice sets are not part of the listed working sets. Choose a comfortable range of motion. For one-sided movements, the target is per side and one logged set includes both sides.',
          movements: [
            CuratedMovement(
              name: 'Barbell Back Squat',
              metric: CuratedMetric.loadedReps,
              targets: _targets9,
              restSeconds: 180,
            ),
            CuratedMovement(
              name: 'Romanian Deadlift',
              metric: CuratedMetric.loadedReps,
              targets: _targets8,
              restSeconds: 120,
            ),
            CuratedMovement(
              name: 'Walking Lunge',
              metric: CuratedMetric.loadedReps,
              targets: _targets10,
              restSeconds: 90,
              instructions: 'Ten per leg.',
            ),
            CuratedMovement(
              name: 'Hamstring Curl',
              metric: CuratedMetric.loadedReps,
              targets: _targets17,
              restSeconds: 90,
            ),
            CuratedMovement(
              name: 'Standing Calf Raise',
              metric: CuratedMetric.loadedReps,
              targets: _targets11,
              restSeconds: 60,
            ),
          ],
        ),
        CuratedDay(
          title: 'Shoulders and arms',
          notes:
              'Before lifting, do 5–10 minutes of easy movement and lighter practice sets. Practice sets are not part of the listed working sets. Choose a comfortable range of motion. For one-sided movements, the target is per side and one logged set includes both sides.',
          movements: [
            CuratedMovement(
              name: 'Overhead Press',
              metric: CuratedMetric.loadedReps,
              targets: _targets8,
              restSeconds: 120,
            ),
            CuratedMovement(
              name: 'Dumbbell Curl',
              metric: CuratedMetric.loadedReps,
              targets: _targets10,
              restSeconds: 0,
              group: 'arms_a',
            ),
            CuratedMovement(
              name: 'Dumbbell Triceps Extension',
              metric: CuratedMetric.loadedReps,
              targets: _targets10,
              restSeconds: 90,
              group: 'arms_a',
            ),
            CuratedMovement(
              name: 'Lateral Raise',
              metric: CuratedMetric.loadedReps,
              targets: _targets17,
              restSeconds: 0,
              group: 'arms_b',
            ),
            CuratedMovement(
              name: 'Hammer Curl',
              metric: CuratedMetric.loadedReps,
              targets: _targets17,
              restSeconds: 90,
              group: 'arms_b',
            ),
            CuratedMovement(
              name: 'Rope Triceps Pushdown',
              metric: CuratedMetric.loadedReps,
              targets: _targets17,
              restSeconds: 0,
              group: 'arms_c',
            ),
            CuratedMovement(
              name: 'Rear-delt Fly',
              metric: CuratedMetric.loadedReps,
              targets: _targets17,
              restSeconds: 90,
              group: 'arms_c',
            ),
          ],
        ),
        CuratedDay(
          title: 'Functional conditioning',
          notes:
              'Complete one set of each grouped movement, then rest. Use an easy pace for the first round.',
          movements: [
            CuratedMovement(
              name: 'Bear Crawl',
              metric: CuratedMetric.distance,
              targets: _targets35,
              restSeconds: 0,
              group: 'conditioning',
            ),
            CuratedMovement(
              name: 'Low Box Step-up',
              metric: CuratedMetric.reps,
              targets: _targets8,
              restSeconds: 0,
              instructions:
                  'Eight per leg; a controlled alternative to box jumps.',
              group: 'conditioning',
            ),
            CuratedMovement(
              name: 'Kettlebell Swing',
              metric: CuratedMetric.loadedReps,
              targets: _targets17,
              restSeconds: 90,
              group: 'conditioning',
            ),
            CuratedMovement(
              name: 'Boxing or Shadowboxing',
              metric: CuratedMetric.duration,
              targets: _targets36,
              restSeconds: 60,
            ),
          ],
        ),
        CuratedDay(
          title: 'Six-movement circuit',
          notes:
              'App adaptation: six exercises and six reps, for three rounds. This scales the six-round format described in the research.',
          movements: [
            CuratedMovement(
              name: 'Dumbbell Front Squat',
              metric: CuratedMetric.loadedReps,
              targets: _targets24,
              restSeconds: 0,
              group: 'six',
            ),
            CuratedMovement(
              name: 'Dumbbell Romanian Deadlift',
              metric: CuratedMetric.loadedReps,
              targets: _targets24,
              restSeconds: 0,
              group: 'six',
            ),
            CuratedMovement(
              name: 'Dumbbell Row',
              metric: CuratedMetric.loadedReps,
              targets: _targets24,
              restSeconds: 0,
              group: 'six',
            ),
            CuratedMovement(
              name: 'Dumbbell Floor Press',
              metric: CuratedMetric.loadedReps,
              targets: _targets24,
              restSeconds: 0,
              group: 'six',
            ),
            CuratedMovement(
              name: 'Dumbbell Push Press',
              metric: CuratedMetric.loadedReps,
              targets: _targets24,
              restSeconds: 0,
              group: 'six',
            ),
            CuratedMovement(
              name: 'Dumbbell Reverse Lunge',
              metric: CuratedMetric.loadedReps,
              targets: _targets24,
              restSeconds: 120,
              instructions:
                  'Six per leg. Keep loads light enough for the entire round.',
              group: 'six',
            ),
          ],
        ),
      ],
    ),
    CuratedProgram(
      id: 'evans_captain',
      actor: 'Chris Evans',
      role: 'Captain America',
      title: 'Athletic Strength',
      focus:
          'Compound lifts, balanced leg work and controlled athletic circuits.',
      evidence:
          'Adapted from the report’s Simon Waterson material. The leg-day exercise list is reported with specific sets; the full app week is an adaptation.',
      notes:
          'Repeat these five sessions as a weekly sequence with two recovery days; they do not need to be consecutive. Use the first week to choose manageable loads. Keep about two clean reps in reserve; bodyweight work may use assistance. Add reps within the range before a small load increase. Repeat or reduce the load if form or recovery declines. Film preparation timelines are not targets for your results. These are app adaptations, not endorsed actor routines. The app reduces overlapping press and hinge volume, supplies missing circuit doses, and replaces gymnastics and high-impact jumps with accessible movement options.',
      sources: [
        CuratedSource(
          title:
              'Supplied research: Eight Hollywood Transformations: Training Timelines and 5-Day Plans — Chris Evans',
          url: '',
        ),
        CuratedSource(
          title: 'Philippine Star — reproduced Waterson interview',
          url:
              'https://www.pressreader.com/philippines/the-philippine-star/20160510/282595967123888',
        ),
      ],
      days: [
        CuratedDay(
          title: 'Chest and back',
          notes:
              'Before lifting, do 5–10 minutes of easy movement and lighter practice sets. Practice sets are not part of the listed working sets. Choose a comfortable range of motion. For one-sided movements, the target is per side and one logged set includes both sides.',
          movements: [
            CuratedMovement(
              name: 'Incline Barbell Bench Press',
              metric: CuratedMetric.loadedReps,
              targets: _targets1,
              restSeconds: 120,
            ),
            CuratedMovement(
              name: 'Chin-up',
              metric: CuratedMetric.reps,
              targets: _targets1,
              restSeconds: 90,
            ),
            CuratedMovement(
              name: 'Close-grip Incline Press',
              metric: CuratedMetric.loadedReps,
              targets: _targets33,
              restSeconds: 90,
            ),
            CuratedMovement(
              name: 'Incline Dumbbell Fly',
              metric: CuratedMetric.loadedReps,
              targets: _targets23,
              restSeconds: 90,
            ),
            CuratedMovement(
              name: 'Bent-over Barbell Row',
              metric: CuratedMetric.loadedReps,
              targets: _targets1,
              restSeconds: 120,
            ),
            CuratedMovement(
              name: 'Plank',
              metric: CuratedMetric.duration,
              targets: _targets4,
              restSeconds: 60,
            ),
          ],
        ),
        CuratedDay(
          title: 'Leg strength',
          notes:
              'Before lifting, do 5–10 minutes of easy movement and lighter practice sets. Practice sets are not part of the listed working sets. Choose a comfortable range of motion. For one-sided movements, the target is per side and one logged set includes both sides.',
          movements: [
            CuratedMovement(
              name: 'Barbell Back Squat',
              metric: CuratedMetric.loadedReps,
              targets: _targets1,
              restSeconds: 150,
            ),
            CuratedMovement(
              name: 'Barbell Lunge',
              metric: CuratedMetric.loadedReps,
              targets: _targets1,
              restSeconds: 90,
              instructions:
                  'Target reps per leg. Use a manageable barbell load.',
            ),
            CuratedMovement(
              name: 'Leg Press',
              metric: CuratedMetric.loadedReps,
              targets: _targets1,
              restSeconds: 120,
            ),
            CuratedMovement(
              name: 'Standing Calf Raise',
              metric: CuratedMetric.loadedReps,
              targets: _targets1,
              restSeconds: 90,
            ),
            CuratedMovement(
              name: 'Hamstring Curl',
              metric: CuratedMetric.loadedReps,
              targets: _targets1,
              restSeconds: 90,
            ),
          ],
        ),
        CuratedDay(
          title: 'Shoulders and arms',
          notes:
              'Before lifting, do 5–10 minutes of easy movement and lighter practice sets. Practice sets are not part of the listed working sets. Choose a comfortable range of motion. For one-sided movements, the target is per side and one logged set includes both sides.',
          movements: [
            CuratedMovement(
              name: 'Overhead Press',
              metric: CuratedMetric.loadedReps,
              targets: _targets1,
              restSeconds: 120,
            ),
            CuratedMovement(
              name: 'Half-kneeling Dumbbell Press',
              metric: CuratedMetric.loadedReps,
              targets: _targets33,
              restSeconds: 90,
              instructions: 'Eight per side.',
            ),
            CuratedMovement(
              name: 'Dip',
              metric: CuratedMetric.reps,
              targets: _targets1,
              restSeconds: 60,
            ),
            CuratedMovement(
              name: 'Dumbbell Curl',
              metric: CuratedMetric.loadedReps,
              targets: _targets22,
              restSeconds: 0,
              group: 'arms',
            ),
            CuratedMovement(
              name: 'Cable Triceps Pushdown',
              metric: CuratedMetric.loadedReps,
              targets: _targets22,
              restSeconds: 75,
              group: 'arms',
            ),
            CuratedMovement(
              name: 'Low Box Step-up',
              metric: CuratedMetric.reps,
              targets: _targets8,
              restSeconds: 60,
              instructions: 'Eight per leg. Use controlled footing.',
            ),
          ],
        ),
        CuratedDay(
          title: 'Posterior chain and control',
          notes:
              'Before lifting, do 5–10 minutes of easy movement and lighter practice sets. Practice sets are not part of the listed working sets. Choose a comfortable range of motion. For one-sided movements, the target is per side and one logged set includes both sides.',
          movements: [
            CuratedMovement(
              name: 'Deadlift',
              metric: CuratedMetric.loadedReps,
              targets: _targets9,
              restSeconds: 180,
            ),
            CuratedMovement(
              name: 'Romanian Deadlift',
              metric: CuratedMetric.loadedReps,
              targets: _targets33,
              restSeconds: 120,
            ),
            CuratedMovement(
              name: 'Chin-up',
              metric: CuratedMetric.reps,
              targets: _targets24,
              restSeconds: 90,
            ),
            CuratedMovement(
              name: 'Inverted Row',
              metric: CuratedMetric.reps,
              targets: _targets8,
              restSeconds: 60,
            ),
            CuratedMovement(
              name: 'Dead Bug',
              metric: CuratedMetric.reps,
              targets: _targets8,
              restSeconds: 0,
              instructions: 'Eight per side.',
              group: 'core',
            ),
            CuratedMovement(
              name: 'Side Plank',
              metric: CuratedMetric.duration,
              targets: _targets4,
              restSeconds: 60,
              instructions: 'Fifteen seconds per side per logged interval.',
              group: 'core',
            ),
          ],
        ),
        CuratedDay(
          title: 'Athletic circuit',
          notes:
              'Complete one set of each grouped movement before resting. Keep the sled load manageable.',
          movements: [
            CuratedMovement(
              name: 'Sled Push',
              metric: CuratedMetric.loadedDistance,
              targets: _targets37,
              restSeconds: 0,
              group: 'athletic',
            ),
            CuratedMovement(
              name: 'Kettlebell Swing',
              metric: CuratedMetric.loadedReps,
              targets: _targets17,
              restSeconds: 0,
              group: 'athletic',
            ),
            CuratedMovement(
              name: 'Low Box Step-up',
              metric: CuratedMetric.reps,
              targets: _targets8,
              restSeconds: 0,
              instructions: 'Eight per leg.',
              group: 'athletic',
            ),
            CuratedMovement(
              name: 'Push-up',
              metric: CuratedMetric.reps,
              targets: _targets10,
              restSeconds: 90,
              group: 'athletic',
            ),
            CuratedMovement(
              name: 'Reverse Crunch',
              metric: CuratedMetric.reps,
              targets: _targets17,
              restSeconds: 60,
            ),
            CuratedMovement(
              name: 'Easy Walk',
              metric: CuratedMetric.duration,
              targets: _targets38,
              restSeconds: 0,
            ),
          ],
        ),
      ],
    ),
    CuratedProgram(
      id: 'bale_batman',
      actor: 'Christian Bale',
      role: 'Batman',
      title: 'Strength and Stamina',
      focus: 'Traditional strength, bodyweight practice and steady running.',
      evidence:
          'Adapted reconstruction. No official day-by-day Batman training log is supplied, and the reported trainer attribution is uncertain.',
      notes:
          'Repeat these five sessions as a weekly sequence with two recovery days; they do not need to be consecutive. Use the first week to choose manageable loads. Keep about two clean reps in reserve; bodyweight work may use assistance. Add reps within the range before a small load increase. Repeat or reduce the load if form or recovery declines. Film preparation timelines are not targets for your results. These are app adaptations, not endorsed actor routines. Extreme bodyweight changes from film preparation are not part of this plan. The app reduces shoulder volume, replaces clap push-ups and cleans, and supplies repeatable cardio and core targets.',
      sources: [
        CuratedSource(
          title:
              'Supplied research: Eight Hollywood Transformations: Training Timelines and 5-Day Plans — Christian Bale',
          url: '',
        ),
      ],
      days: [
        CuratedDay(
          title: 'Chest and triceps',
          notes:
              'Before lifting, do 5–10 minutes of easy movement and lighter practice sets. Practice sets are not part of the listed working sets. Choose a comfortable range of motion. For one-sided movements, the target is per side and one logged set includes both sides.',
          movements: [
            CuratedMovement(
              name: 'Barbell Bench Press',
              metric: CuratedMetric.loadedReps,
              targets: _targets1,
              restSeconds: 150,
            ),
            CuratedMovement(
              name: 'Incline Dumbbell Press',
              metric: CuratedMetric.loadedReps,
              targets: _targets8,
              restSeconds: 90,
            ),
            CuratedMovement(
              name: 'Dip',
              metric: CuratedMetric.reps,
              targets: _targets1,
              restSeconds: 60,
            ),
            CuratedMovement(
              name: 'Cable Fly',
              metric: CuratedMetric.loadedReps,
              targets: _targets32,
              restSeconds: 90,
            ),
            CuratedMovement(
              name: 'Cable Triceps Pushdown',
              metric: CuratedMetric.loadedReps,
              targets: _targets10,
              restSeconds: 90,
            ),
            CuratedMovement(
              name: 'Easy Run or Brisk Walk',
              metric: CuratedMetric.duration,
              targets: _targets34,
              restSeconds: 0,
              instructions: 'Use a conversational pace.',
            ),
          ],
        ),
        CuratedDay(
          title: 'Back and biceps',
          notes:
              'Before lifting, do 5–10 minutes of easy movement and lighter practice sets. Practice sets are not part of the listed working sets. Choose a comfortable range of motion. For one-sided movements, the target is per side and one logged set includes both sides.',
          movements: [
            CuratedMovement(
              name: 'Deadlift',
              metric: CuratedMetric.loadedReps,
              targets: _targets9,
              restSeconds: 180,
            ),
            CuratedMovement(
              name: 'Pull-up',
              metric: CuratedMetric.reps,
              targets: _targets3,
              restSeconds: 90,
            ),
            CuratedMovement(
              name: 'Barbell Row',
              metric: CuratedMetric.loadedReps,
              targets: _targets8,
              restSeconds: 90,
            ),
            CuratedMovement(
              name: 'Lat Pulldown',
              metric: CuratedMetric.loadedReps,
              targets: _targets23,
              restSeconds: 90,
            ),
            CuratedMovement(
              name: 'Barbell Curl',
              metric: CuratedMetric.loadedReps,
              targets: _targets10,
              restSeconds: 0,
              group: 'curls',
            ),
            CuratedMovement(
              name: 'Hammer Curl',
              metric: CuratedMetric.loadedReps,
              targets: _targets10,
              restSeconds: 75,
              group: 'curls',
            ),
            CuratedMovement(
              name: 'Easy Run or Brisk Walk',
              metric: CuratedMetric.duration,
              targets: _targets38,
              restSeconds: 0,
            ),
          ],
        ),
        CuratedDay(
          title: 'Leg strength',
          notes:
              'Before lifting, do 5–10 minutes of easy movement and lighter practice sets. Practice sets are not part of the listed working sets. Choose a comfortable range of motion. For one-sided movements, the target is per side and one logged set includes both sides.',
          movements: [
            CuratedMovement(
              name: 'Barbell Back Squat',
              metric: CuratedMetric.loadedReps,
              targets: _targets1,
              restSeconds: 150,
            ),
            CuratedMovement(
              name: 'Leg Press',
              metric: CuratedMetric.loadedReps,
              targets: _targets10,
              restSeconds: 120,
            ),
            CuratedMovement(
              name: 'Walking Lunge',
              metric: CuratedMetric.loadedReps,
              targets: _targets10,
              restSeconds: 90,
              instructions: 'Ten per leg.',
            ),
            CuratedMovement(
              name: 'Leg Curl',
              metric: CuratedMetric.loadedReps,
              targets: _targets39,
              restSeconds: 90,
            ),
            CuratedMovement(
              name: 'Standing Calf Raise',
              metric: CuratedMetric.loadedReps,
              targets: _targets39,
              restSeconds: 90,
            ),
          ],
        ),
        CuratedDay(
          title: 'Shoulders and control',
          notes:
              'Before lifting, do 5–10 minutes of easy movement and lighter practice sets. Practice sets are not part of the listed working sets. Choose a comfortable range of motion. For one-sided movements, the target is per side and one logged set includes both sides.',
          movements: [
            CuratedMovement(
              name: 'Seated Arnold Press',
              metric: CuratedMetric.loadedReps,
              targets: _targets10,
              restSeconds: 90,
            ),
            CuratedMovement(
              name: 'Cable Face Pull',
              metric: CuratedMetric.loadedReps,
              targets: _targets17,
              restSeconds: 90,
            ),
            CuratedMovement(
              name: 'Dumbbell Shrug',
              metric: CuratedMetric.loadedReps,
              targets: _targets17,
              restSeconds: 90,
            ),
            CuratedMovement(
              name: 'Lateral Raise',
              metric: CuratedMetric.loadedReps,
              targets: _targets17,
              restSeconds: 90,
            ),
            CuratedMovement(
              name: 'Push-up',
              metric: CuratedMetric.reps,
              targets: _targets2,
              restSeconds: 60,
            ),
            CuratedMovement(
              name: 'Side Plank',
              metric: CuratedMetric.duration,
              targets: _targets4,
              restSeconds: 60,
              instructions: 'Fifteen seconds per side per logged interval.',
            ),
          ],
        ),
        CuratedDay(
          title: 'Full-body conditioning',
          notes:
              'Before lifting, do 5–10 minutes of easy movement and lighter practice sets. Practice sets are not part of the listed working sets. Choose a comfortable range of motion. For one-sided movements, the target is per side and one logged set includes both sides.',
          movements: [
            CuratedMovement(
              name: 'Dumbbell Push Press',
              metric: CuratedMetric.loadedReps,
              targets: _targets9,
              restSeconds: 120,
              instructions: 'Use a light load and a controlled leg drive.',
            ),
            CuratedMovement(
              name: 'Push-up',
              metric: CuratedMetric.reps,
              targets: _targets10,
              restSeconds: 0,
              group: 'bodyweight',
            ),
            CuratedMovement(
              name: 'Pull-up',
              metric: CuratedMetric.reps,
              targets: _targets9,
              restSeconds: 0,
              group: 'bodyweight',
            ),
            CuratedMovement(
              name: 'Bodyweight Squat',
              metric: CuratedMetric.reps,
              targets: _targets11,
              restSeconds: 90,
              group: 'bodyweight',
            ),
            CuratedMovement(
              name: 'Dead Bug',
              metric: CuratedMetric.reps,
              targets: _targets8,
              restSeconds: 60,
              instructions: 'Eight per side.',
            ),
            CuratedMovement(
              name: 'Easy Run or Brisk Walk',
              metric: CuratedMetric.duration,
              targets: _targets40,
              restSeconds: 0,
              instructions:
                  'Keep a conversational pace; shorten as needed while building endurance.',
            ),
          ],
        ),
      ],
    ),
    CuratedProgram(
      id: 'hardy_bane',
      actor: 'Tom Hardy',
      role: 'Bane',
      title: 'Bodyweight and Muscle',
      focus:
          'Muscle-building lifts, bodyweight strength and boxing conditioning.',
      evidence:
          'Adapted reconstruction of Patrick “P-Nut” Monroe’s reported style. Conflicting reports do not establish an exact Bane split.',
      notes:
          'Repeat these five sessions as a weekly sequence with two recovery days; they do not need to be consecutive. Use the first week to choose manageable loads. Keep about two clean reps in reserve; bodyweight work may use assistance. Add reps within the range before a small load increase. Repeat or reduce the load if form or recovery declines. Film preparation timelines are not targets for your results. These are app adaptations, not endorsed actor routines. The app reduces high-volume weighted pull-ups and push-up matrices, uses ordinary deadlift technique, and sets fixed doses for the unspecified combat day. Sessions can be split into short blocks without repeating already logged sets.',
      sources: [
        CuratedSource(
          title:
              'Supplied research: Eight Hollywood Transformations: Training Timelines and 5-Day Plans — Tom Hardy',
          url: '',
        ),
        CuratedSource(
          title: 'Steel Supplements — secondary Bane routine reconstruction',
          url:
              'https://steelsupplements.com/blogs/steel-blog/tom-hardys-bane-workout-routine-diet-plan',
        ),
      ],
      days: [
        CuratedDay(
          title: 'Chest and triceps',
          notes:
              'Before lifting, do 5–10 minutes of easy movement and lighter practice sets. Practice sets are not part of the listed working sets. Choose a comfortable range of motion. For one-sided movements, the target is per side and one logged set includes both sides.',
          movements: [
            CuratedMovement(
              name: 'Barbell Bench Press',
              metric: CuratedMetric.loadedReps,
              targets: _targets7,
              restSeconds: 120,
            ),
            CuratedMovement(
              name: 'Incline Dumbbell Press',
              metric: CuratedMetric.loadedReps,
              targets: _targets30,
              restSeconds: 90,
            ),
            CuratedMovement(
              name: 'Dip',
              metric: CuratedMetric.reps,
              targets: _targets16,
              restSeconds: 60,
            ),
            CuratedMovement(
              name: 'Push-up',
              metric: CuratedMetric.reps,
              targets: _targets2,
              restSeconds: 60,
              instructions:
                  'Alternate standard and close-grip positions only if comfortable.',
            ),
            CuratedMovement(
              name: 'Cable Triceps Pushdown',
              metric: CuratedMetric.loadedReps,
              targets: _targets17,
              restSeconds: 90,
            ),
          ],
        ),
        CuratedDay(
          title: 'Back and biceps',
          notes:
              'Before lifting, do 5–10 minutes of easy movement and lighter practice sets. Practice sets are not part of the listed working sets. Choose a comfortable range of motion. For one-sided movements, the target is per side and one logged set includes both sides.',
          movements: [
            CuratedMovement(
              name: 'Pull-up',
              metric: CuratedMetric.reps,
              targets: _targets3,
              restSeconds: 90,
            ),
            CuratedMovement(
              name: 'Barbell Row',
              metric: CuratedMetric.loadedReps,
              targets: _targets30,
              restSeconds: 90,
            ),
            CuratedMovement(
              name: 'One-arm Dumbbell Row',
              metric: CuratedMetric.loadedReps,
              targets: _targets30,
              restSeconds: 90,
              instructions: 'Target reps per side.',
            ),
            CuratedMovement(
              name: 'Cable Face Pull',
              metric: CuratedMetric.loadedReps,
              targets: _targets39,
              restSeconds: 90,
            ),
            CuratedMovement(
              name: 'Barbell Curl',
              metric: CuratedMetric.loadedReps,
              targets: _targets17,
              restSeconds: 90,
            ),
          ],
        ),
        CuratedDay(
          title: 'Legs and core',
          notes:
              'Before lifting, do 5–10 minutes of easy movement and lighter practice sets. Practice sets are not part of the listed working sets. Choose a comfortable range of motion. For one-sided movements, the target is per side and one logged set includes both sides.',
          movements: [
            CuratedMovement(
              name: 'Barbell Back Squat',
              metric: CuratedMetric.loadedReps,
              targets: _targets22,
              restSeconds: 150,
            ),
            CuratedMovement(
              name: 'Romanian Deadlift',
              metric: CuratedMetric.loadedReps,
              targets: _targets8,
              restSeconds: 120,
            ),
            CuratedMovement(
              name: 'Leg Press',
              metric: CuratedMetric.loadedReps,
              targets: _targets17,
              restSeconds: 90,
            ),
            CuratedMovement(
              name: 'Walking Lunge',
              metric: CuratedMetric.loadedReps,
              targets: _targets23,
              restSeconds: 90,
              instructions: 'Ten per leg.',
            ),
            CuratedMovement(
              name: 'Hanging Knee Raise',
              metric: CuratedMetric.reps,
              targets: _targets30,
              restSeconds: 0,
              group: 'core',
            ),
            CuratedMovement(
              name: 'Crunch',
              metric: CuratedMetric.reps,
              targets: _targets11,
              restSeconds: 60,
              group: 'core',
            ),
          ],
        ),
        CuratedDay(
          title: 'Shoulders and arms',
          notes:
              'Before lifting, do 5–10 minutes of easy movement and lighter practice sets. Practice sets are not part of the listed working sets. Choose a comfortable range of motion. For one-sided movements, the target is per side and one logged set includes both sides.',
          movements: [
            CuratedMovement(
              name: 'Overhead Press',
              metric: CuratedMetric.loadedReps,
              targets: _targets22,
              restSeconds: 120,
            ),
            CuratedMovement(
              name: 'Dumbbell Front Raise',
              metric: CuratedMetric.loadedReps,
              targets: _targets32,
              restSeconds: 90,
            ),
            CuratedMovement(
              name: 'Lateral Raise',
              metric: CuratedMetric.loadedReps,
              targets: _targets39,
              restSeconds: 90,
            ),
            CuratedMovement(
              name: 'Dumbbell Curl',
              metric: CuratedMetric.loadedReps,
              targets: _targets17,
              restSeconds: 0,
              group: 'arms',
            ),
            CuratedMovement(
              name: 'Dumbbell Triceps Extension',
              metric: CuratedMetric.loadedReps,
              targets: _targets17,
              restSeconds: 75,
              group: 'arms',
            ),
          ],
        ),
        CuratedDay(
          title: 'Boxing and bodyweight',
          notes:
              'Complete one set of each bodyweight movement before resting. Use assistance when needed; no failure target is required.',
          movements: [
            CuratedMovement(
              name: 'Boxing or Shadowboxing',
              metric: CuratedMetric.duration,
              targets: _targets6,
              restSeconds: 60,
            ),
            CuratedMovement(
              name: 'Push-up',
              metric: CuratedMetric.reps,
              targets: _targets10,
              restSeconds: 0,
              group: 'bodyweight',
            ),
            CuratedMovement(
              name: 'Pull-up',
              metric: CuratedMetric.reps,
              targets: _targets9,
              restSeconds: 0,
              group: 'bodyweight',
            ),
            CuratedMovement(
              name: 'Dip',
              metric: CuratedMetric.reps,
              targets: _targets24,
              restSeconds: 0,
              group: 'bodyweight',
            ),
            CuratedMovement(
              name: 'Crunch',
              metric: CuratedMetric.reps,
              targets: _targets11,
              restSeconds: 90,
              group: 'bodyweight',
            ),
            CuratedMovement(
              name: 'Plank',
              metric: CuratedMetric.duration,
              targets: _targets4,
              restSeconds: 60,
            ),
          ],
        ),
      ],
    ),
    CuratedProgram(
      id: 'pitt_achilles',
      actor: 'Brad Pitt',
      role: 'Achilles in Troy',
      title: 'Back and Shoulders',
      focus:
          'Back, shoulders and arms with moderate chest work and steady cardio.',
      evidence:
          'Adapted reconstruction from Duffy Gaver’s reported exercises and pyramid method. No numbered Troy week was published in the supplied material.',
      notes:
          'Repeat these five sessions as a weekly sequence with two recovery days; they do not need to be consecutive. Use the first week to choose manageable loads. Keep about two clean reps in reserve; bodyweight work may use assistance. Add reps within the range before a small load increase. Repeat or reduce the load if form or recovery declines. Film preparation timelines are not targets for your results. These are app adaptations, not endorsed actor routines. Gaver has the stronger first-person trainer attribution in the report. The app fills missing doses, lowers failure-based work and replaces sword choreography with optional solo movement practice. Pyramid targets describe reps, not mandatory weight jumps.',
      sources: [
        CuratedSource(
          title:
              'Supplied research: Brad Pitt (Troy) and Jason Momoa (Aquaman): Verified Trainers, Timelines and Plans — Brad Pitt',
          url: '',
        ),
        CuratedSource(
          title: 'Men’s Health — Duffy Gaver on Troy training',
          url:
              'https://menshealth.com.au/the-workout-that-got-brad-pitt-in-god-like-shape-for-troy/',
        ),
      ],
      days: [
        CuratedDay(
          title: 'Back priority',
          notes:
              'Before lifting, do 5–10 minutes of easy movement and lighter practice sets. Practice sets are not part of the listed working sets. Choose a comfortable range of motion. For one-sided movements, the target is per side and one logged set includes both sides.',
          movements: [
            CuratedMovement(
              name: 'Lat Pulldown',
              metric: CuratedMetric.loadedReps,
              targets: _targets41,
              restSeconds: 90,
              instructions:
                  'Increase load only if form remains controlled as reps fall.',
            ),
            CuratedMovement(
              name: 'One-arm Dumbbell Row',
              metric: CuratedMetric.loadedReps,
              targets: _targets42,
              restSeconds: 90,
              instructions: 'Target reps per side.',
            ),
            CuratedMovement(
              name: 'T-bar Row',
              metric: CuratedMetric.loadedReps,
              targets: _targets22,
              restSeconds: 90,
            ),
            CuratedMovement(
              name: 'Pull-up',
              metric: CuratedMetric.reps,
              targets: _targets43,
              restSeconds: 90,
            ),
            CuratedMovement(
              name: 'Back Extension',
              metric: CuratedMetric.reps,
              targets: _targets44,
              restSeconds: 60,
              instructions: 'Use bodyweight and a controlled range.',
            ),
            CuratedMovement(
              name: 'Reverse Crunch',
              metric: CuratedMetric.reps,
              targets: _targets17,
              restSeconds: 60,
            ),
          ],
        ),
        CuratedDay(
          title: 'Shoulders and arms',
          notes:
              'Before lifting, do 5–10 minutes of easy movement and lighter practice sets. Practice sets are not part of the listed working sets. Choose a comfortable range of motion. For one-sided movements, the target is per side and one logged set includes both sides.',
          movements: [
            CuratedMovement(
              name: 'Overhead Press',
              metric: CuratedMetric.loadedReps,
              targets: _targets45,
              restSeconds: 120,
            ),
            CuratedMovement(
              name: 'Lateral Raise',
              metric: CuratedMetric.loadedReps,
              targets: _targets17,
              restSeconds: 90,
            ),
            CuratedMovement(
              name: 'Push-up',
              metric: CuratedMetric.reps,
              targets: _targets10,
              restSeconds: 60,
            ),
            CuratedMovement(
              name: 'Dumbbell Curl',
              metric: CuratedMetric.loadedReps,
              targets: _targets10,
              restSeconds: 90,
            ),
            CuratedMovement(
              name: 'Dip',
              metric: CuratedMetric.reps,
              targets: _targets16,
              restSeconds: 60,
            ),
            CuratedMovement(
              name: 'Rear-delt Fly',
              metric: CuratedMetric.loadedReps,
              targets: _targets11,
              restSeconds: 90,
            ),
          ],
        ),
        CuratedDay(
          title: 'Cardio and core',
          notes:
              'This is a lighter session. Add duration gradually if recovery supports it.',
          movements: [
            CuratedMovement(
              name: 'Steady Cardio',
              metric: CuratedMetric.duration,
              targets: _targets40,
              restSeconds: 0,
              instructions:
                  'Walk, cycle or use the elliptical at a conversational pace.',
            ),
            CuratedMovement(
              name: 'Shadowboxing Footwork',
              metric: CuratedMetric.duration,
              targets: _targets5,
              restSeconds: 60,
              instructions:
                  'Controlled footwork replaces specialist sword choreography.',
            ),
            CuratedMovement(
              name: 'Dead Bug',
              metric: CuratedMetric.reps,
              targets: _targets8,
              restSeconds: 0,
              instructions: 'Eight per side.',
              group: 'core',
            ),
            CuratedMovement(
              name: 'Reverse Crunch',
              metric: CuratedMetric.reps,
              targets: _targets17,
              restSeconds: 0,
              group: 'core',
            ),
            CuratedMovement(
              name: 'Plank',
              metric: CuratedMetric.duration,
              targets: _targets4,
              restSeconds: 60,
              group: 'core',
            ),
          ],
        ),
        CuratedDay(
          title: 'Leg strength',
          notes:
              'Before lifting, do 5–10 minutes of easy movement and lighter practice sets. Practice sets are not part of the listed working sets. Choose a comfortable range of motion. For one-sided movements, the target is per side and one logged set includes both sides.',
          movements: [
            CuratedMovement(
              name: 'Barbell Back Squat',
              metric: CuratedMetric.loadedReps,
              targets: _targets42,
              restSeconds: 150,
            ),
            CuratedMovement(
              name: 'Dumbbell Lunge',
              metric: CuratedMetric.loadedReps,
              targets: _targets17,
              restSeconds: 90,
              instructions: 'Twelve per leg.',
            ),
            CuratedMovement(
              name: 'Leg Press',
              metric: CuratedMetric.loadedReps,
              targets: _targets30,
              restSeconds: 120,
            ),
            CuratedMovement(
              name: 'Standing Calf Raise',
              metric: CuratedMetric.loadedReps,
              targets: _targets46,
              restSeconds: 90,
            ),
            CuratedMovement(
              name: 'Back Extension',
              metric: CuratedMetric.reps,
              targets: _targets32,
              restSeconds: 60,
            ),
          ],
        ),
        CuratedDay(
          title: 'Chest and arms',
          notes:
              'Before lifting, do 5–10 minutes of easy movement and lighter practice sets. Practice sets are not part of the listed working sets. Choose a comfortable range of motion. For one-sided movements, the target is per side and one logged set includes both sides.',
          movements: [
            CuratedMovement(
              name: 'Incline Dumbbell Press',
              metric: CuratedMetric.loadedReps,
              targets: _targets10,
              restSeconds: 90,
            ),
            CuratedMovement(
              name: 'Push-up',
              metric: CuratedMetric.reps,
              targets: _targets10,
              restSeconds: 60,
            ),
            CuratedMovement(
              name: 'Dumbbell Curl',
              metric: CuratedMetric.loadedReps,
              targets: _targets10,
              restSeconds: 0,
              group: 'arms',
            ),
            CuratedMovement(
              name: 'Dip',
              metric: CuratedMetric.reps,
              targets: _targets16,
              restSeconds: 75,
              group: 'arms',
            ),
            CuratedMovement(
              name: 'Steady Cardio',
              metric: CuratedMetric.duration,
              targets: _targets15,
              restSeconds: 0,
              instructions: 'Walk or cycle at an easy pace.',
            ),
          ],
        ),
      ],
    ),
    CuratedProgram(
      id: 'momoa_aquaman',
      actor: 'Jason Momoa',
      role: 'Aquaman',
      title: 'Climb and Strength',
      focus:
          'Climbing-oriented fitness, upper-body strength and kettlebell work.',
      evidence:
          'Adapted reconstruction of the Aquaman-era methods attributed to Mark Twight. A complete trainer-published week is not supplied.',
      notes:
          'Repeat these five sessions as a weekly sequence with two recovery days; they do not need to be consecutive. Use the first week to choose manageable loads. Keep about two clean reps in reserve; bodyweight work may use assistance. Add reps within the range before a small load increase. Repeat or reduce the load if form or recovery declines. Film preparation timelines are not targets for your results. These are app adaptations, not endorsed actor routines. The AR-7 protocol described in the report belongs to Conan, not Aquaman, and is not used here. The app puts climbing before pull training, scales the volume and supplies all missing doses. Keep climbing easy enough to recover for the next session.',
      sources: [
        CuratedSource(
          title:
              'Supplied research: Brad Pitt (Troy) and Jason Momoa (Aquaman): Verified Trainers, Timelines and Plans — Jason Momoa',
          url: '',
        ),
      ],
      days: [
        CuratedDay(
          title: 'Chest and conditioning',
          notes:
              'Before lifting, do 5–10 minutes of easy movement and lighter practice sets. Practice sets are not part of the listed working sets. Choose a comfortable range of motion. For one-sided movements, the target is per side and one logged set includes both sides.',
          movements: [
            CuratedMovement(
              name: 'Barbell Bench Press',
              metric: CuratedMetric.loadedReps,
              targets: _targets1,
              restSeconds: 150,
            ),
            CuratedMovement(
              name: 'Dip',
              metric: CuratedMetric.reps,
              targets: _targets16,
              restSeconds: 60,
            ),
            CuratedMovement(
              name: 'Push-up',
              metric: CuratedMetric.reps,
              targets: _targets10,
              restSeconds: 60,
            ),
            CuratedMovement(
              name: 'Battle Ropes',
              metric: CuratedMetric.duration,
              targets: _targets47,
              restSeconds: 60,
              instructions:
                  'Use steady alternating waves and a controlled pace.',
            ),
            CuratedMovement(
              name: 'Treadmill Walk',
              metric: CuratedMetric.duration,
              targets: _targets15,
              restSeconds: 0,
            ),
          ],
        ),
        CuratedDay(
          title: 'Climbing and movement',
          notes:
              'This lighter day precedes pulling work. Insert a recovery day afterward if grip or back remains fatigued.',
          movements: [
            CuratedMovement(
              name: 'Indoor Climbing or Brisk Hill Walk',
              metric: CuratedMetric.duration,
              targets: _targets40,
              restSeconds: 0,
              instructions:
                  'Use routes within your experience and take rests. A brisk hill walk is the no-climbing-gym alternative.',
            ),
            CuratedMovement(
              name: 'Dead Bug',
              metric: CuratedMetric.reps,
              targets: _targets8,
              restSeconds: 60,
              instructions: 'Eight per side.',
            ),
            CuratedMovement(
              name: 'Hip and Shoulder Mobility',
              metric: CuratedMetric.duration,
              targets: _targets48,
              restSeconds: 30,
              instructions:
                  'Gentle controlled movement; do not force end range.',
            ),
          ],
        ),
        CuratedDay(
          title: 'Back and biceps',
          notes:
              'Before lifting, do 5–10 minutes of easy movement and lighter practice sets. Practice sets are not part of the listed working sets. Choose a comfortable range of motion. For one-sided movements, the target is per side and one logged set includes both sides.',
          movements: [
            CuratedMovement(
              name: 'Pull-up',
              metric: CuratedMetric.reps,
              targets: _targets49,
              restSeconds: 120,
              instructions: 'A scaled ladder; use assistance if needed.',
            ),
            CuratedMovement(
              name: 'Dumbbell Renegade Row',
              metric: CuratedMetric.loadedReps,
              targets: _targets8,
              restSeconds: 90,
              instructions:
                  'Eight per side; widen the feet for support and keep the trunk stable.',
            ),
            CuratedMovement(
              name: 'Seated Cable Row',
              metric: CuratedMetric.loadedReps,
              targets: _targets10,
              restSeconds: 90,
            ),
            CuratedMovement(
              name: 'Chin-up',
              metric: CuratedMetric.reps,
              targets: _targets43,
              restSeconds: 90,
            ),
            CuratedMovement(
              name: 'Dumbbell Curl',
              metric: CuratedMetric.loadedReps,
              targets: _targets10,
              restSeconds: 90,
            ),
          ],
        ),
        CuratedDay(
          title: 'Shoulders and arms',
          notes:
              'Before lifting, do 5–10 minutes of easy movement and lighter practice sets. Practice sets are not part of the listed working sets. Choose a comfortable range of motion. For one-sided movements, the target is per side and one logged set includes both sides.',
          movements: [
            CuratedMovement(
              name: 'Overhead Press',
              metric: CuratedMetric.loadedReps,
              targets: _targets8,
              restSeconds: 120,
            ),
            CuratedMovement(
              name: 'Lateral Raise',
              metric: CuratedMetric.loadedReps,
              targets: _targets17,
              restSeconds: 0,
              group: 'raises',
            ),
            CuratedMovement(
              name: 'Rear-delt Fly',
              metric: CuratedMetric.loadedReps,
              targets: _targets17,
              restSeconds: 75,
              group: 'raises',
            ),
            CuratedMovement(
              name: 'Dip',
              metric: CuratedMetric.reps,
              targets: _targets16,
              restSeconds: 60,
            ),
            CuratedMovement(
              name: 'Hammer Curl',
              metric: CuratedMetric.loadedReps,
              targets: _targets10,
              restSeconds: 90,
            ),
            CuratedMovement(
              name: 'Battle Ropes',
              metric: CuratedMetric.duration,
              targets: _targets47,
              restSeconds: 60,
            ),
          ],
        ),
        CuratedDay(
          title: 'Legs and full-body power',
          notes:
              'Before lifting, do 5–10 minutes of easy movement and lighter practice sets. Practice sets are not part of the listed working sets. Choose a comfortable range of motion. For one-sided movements, the target is per side and one logged set includes both sides.',
          movements: [
            CuratedMovement(
              name: 'Kettlebell Swing',
              metric: CuratedMetric.loadedReps,
              targets: _targets17,
              restSeconds: 90,
            ),
            CuratedMovement(
              name: 'Goblet Squat',
              metric: CuratedMetric.loadedReps,
              targets: _targets10,
              restSeconds: 120,
            ),
            CuratedMovement(
              name: 'Dumbbell Split Squat',
              metric: CuratedMetric.loadedReps,
              targets: _targets10,
              restSeconds: 90,
              instructions: 'Ten per leg.',
            ),
            CuratedMovement(
              name: 'Leg Press',
              metric: CuratedMetric.loadedReps,
              targets: _targets10,
              restSeconds: 120,
            ),
            CuratedMovement(
              name: 'Step-back Burpee',
              metric: CuratedMetric.reps,
              targets: _targets24,
              restSeconds: 90,
              instructions: 'Step the feet back and forward. Omit the jump.',
            ),
            CuratedMovement(
              name: 'Farmer Carry',
              metric: CuratedMetric.loadedDistance,
              targets: _targets12,
              restSeconds: 90,
            ),
          ],
        ),
      ],
    ),
    CuratedProgram(
      id: 'lee_dragon',
      actor: 'Bruce Lee',
      role: 'Enter the Dragon',
      title: 'Martial Arts Fitness',
      focus:
          'Three brief strength sessions plus skill, cardio and core practice.',
      evidence:
          'Adapted arrangement of documented training elements reproduced by John Little. Lee’s actual schedule was not a five-day role-preparation split.',
      notes:
          'Repeat these five sessions as a weekly sequence with two recovery days; they do not need to be consecutive. Use the first week to choose manageable loads. Keep about two clean reps in reserve; bodyweight work may use assistance. Add reps within the range before a small load increase. Repeat or reduce the load if form or recovery declines. Film preparation timelines are not targets for your results. These are app adaptations, not endorsed actor routines. The app scales daily core and forearm volume, supplies skill intervals and replaces max-effort rack work, loaded neck work and dragon flags. Use light loads and practiced technique for cleans. Historic personal loads and extreme daily totals are not prescriptions.',
      sources: [
        CuratedSource(
          title:
              'Supplied research: Bruce Lee and Jason Statham: Documented Training Routines and 5-Day Plans — Bruce Lee',
          url: '',
        ),
        CuratedSource(
          title: 'The Bioneer — summaries of Lee’s training records',
          url: 'https://www.thebioneer.com/bruce-lee-training-routines/',
        ),
        CuratedSource(
          title: 'Art of Manliness — discussion of Lee’s training logs',
          url:
              'https://www.artofmanliness.com/strength/fitness/bruce-lee-workout/',
        ),
      ],
      days: [
        CuratedDay(
          title: 'Full-body strength and cardio',
          notes:
              'Before lifting, do 5–10 minutes of easy movement and lighter practice sets. Practice sets are not part of the listed working sets. Choose a comfortable range of motion. For one-sided movements, the target is per side and one logged set includes both sides.',
          movements: [
            CuratedMovement(
              name: 'Dumbbell Clean and Press',
              metric: CuratedMetric.loadedReps,
              targets: _targets33,
              restSeconds: 120,
              instructions: 'Use a light load and practiced technique.',
            ),
            CuratedMovement(
              name: 'Barbell Back Squat',
              metric: CuratedMetric.loadedReps,
              targets: _targets32,
              restSeconds: 120,
            ),
            CuratedMovement(
              name: 'Dumbbell Pullover',
              metric: CuratedMetric.loadedReps,
              targets: _targets33,
              restSeconds: 90,
              instructions:
                  'Use a comfortable shoulder range and a light, controlled load.',
            ),
            CuratedMovement(
              name: 'Barbell Bench Press',
              metric: CuratedMetric.loadedReps,
              targets: _targets50,
              restSeconds: 120,
            ),
            CuratedMovement(
              name: 'Barbell Curl',
              metric: CuratedMetric.loadedReps,
              targets: _targets33,
              restSeconds: 90,
            ),
            CuratedMovement(
              name: 'Easy Run or Brisk Walk',
              metric: CuratedMetric.duration,
              targets: _targets34,
              restSeconds: 0,
            ),
            CuratedMovement(
              name: 'Reverse Crunch',
              metric: CuratedMetric.reps,
              targets: _targets32,
              restSeconds: 60,
            ),
          ],
        ),
        CuratedDay(
          title: 'Conditioning and skill',
          notes:
              'Keep cycling easy and bag combinations controlled. This scales Lee’s much larger daily practice volume.',
          movements: [
            CuratedMovement(
              name: 'Easy Cycling',
              metric: CuratedMetric.duration,
              targets: _targets34,
              restSeconds: 0,
            ),
            CuratedMovement(
              name: 'Jump Rope',
              metric: CuratedMetric.duration,
              targets: _targets36,
              restSeconds: 60,
            ),
            CuratedMovement(
              name: 'Heavy Bag or Shadowboxing',
              metric: CuratedMetric.duration,
              targets: _targets36,
              restSeconds: 60,
            ),
            CuratedMovement(
              name: 'Dead Bug',
              metric: CuratedMetric.reps,
              targets: _targets33,
              restSeconds: 60,
              instructions: 'Eight per side.',
            ),
            CuratedMovement(
              name: 'Wrist Curl',
              metric: CuratedMetric.loadedReps,
              targets: _targets44,
              restSeconds: 60,
              instructions: 'Use a light load; no forced repetitions.',
            ),
          ],
        ),
        CuratedDay(
          title: 'Full-body strength and holds',
          notes:
              'Before lifting, do 5–10 minutes of easy movement and lighter practice sets. Practice sets are not part of the listed working sets. Choose a comfortable range of motion. For one-sided movements, the target is per side and one logged set includes both sides.',
          movements: [
            CuratedMovement(
              name: 'Dumbbell Clean and Press',
              metric: CuratedMetric.loadedReps,
              targets: _targets33,
              restSeconds: 120,
              instructions: 'Use a light load and practiced technique.',
            ),
            CuratedMovement(
              name: 'Barbell Back Squat',
              metric: CuratedMetric.loadedReps,
              targets: _targets32,
              restSeconds: 120,
            ),
            CuratedMovement(
              name: 'Dumbbell Pullover',
              metric: CuratedMetric.loadedReps,
              targets: _targets33,
              restSeconds: 90,
              instructions:
                  'Use a comfortable shoulder range and a light, controlled load.',
            ),
            CuratedMovement(
              name: 'Barbell Bench Press',
              metric: CuratedMetric.loadedReps,
              targets: _targets50,
              restSeconds: 120,
            ),
            CuratedMovement(
              name: 'Barbell Curl',
              metric: CuratedMetric.loadedReps,
              targets: _targets33,
              restSeconds: 90,
            ),
            CuratedMovement(
              name: 'Wall Sit',
              metric: CuratedMetric.duration,
              targets: _targets51,
              restSeconds: 45,
              instructions:
                  'Comfortable knee angle; this replaces maximal pinned-rack isometrics.',
            ),
            CuratedMovement(
              name: 'Plank',
              metric: CuratedMetric.duration,
              targets: _targets51,
              restSeconds: 45,
            ),
          ],
        ),
        CuratedDay(
          title: 'Alternating circuit',
          notes:
              'App adaptation of the PHA idea: alternate upper and lower movements. The original timed-to-failure stations are replaced with controlled rep targets.',
          movements: [
            CuratedMovement(
              name: 'Assisted Pull-up',
              metric: CuratedMetric.reps,
              targets: _targets50,
              restSeconds: 0,
              group: 'pha',
            ),
            CuratedMovement(
              name: 'Leg Press',
              metric: CuratedMetric.loadedReps,
              targets: _targets23,
              restSeconds: 0,
              group: 'pha',
            ),
            CuratedMovement(
              name: 'Dumbbell Shoulder Press',
              metric: CuratedMetric.loadedReps,
              targets: _targets33,
              restSeconds: 0,
              group: 'pha',
            ),
            CuratedMovement(
              name: 'Standing Calf Raise',
              metric: CuratedMetric.reps,
              targets: _targets52,
              restSeconds: 0,
              group: 'pha',
            ),
            CuratedMovement(
              name: 'Cable Curl',
              metric: CuratedMetric.loadedReps,
              targets: _targets23,
              restSeconds: 0,
              group: 'pha',
            ),
            CuratedMovement(
              name: 'Bodyweight Squat',
              metric: CuratedMetric.reps,
              targets: _targets32,
              restSeconds: 90,
              group: 'pha',
            ),
            CuratedMovement(
              name: 'Easy Run or Brisk Walk',
              metric: CuratedMetric.duration,
              targets: _targets34,
              restSeconds: 0,
            ),
          ],
        ),
        CuratedDay(
          title: 'Full-body strength and skill',
          notes:
              'Before lifting, do 5–10 minutes of easy movement and lighter practice sets. Practice sets are not part of the listed working sets. Choose a comfortable range of motion. For one-sided movements, the target is per side and one logged set includes both sides.',
          movements: [
            CuratedMovement(
              name: 'Dumbbell Clean and Press',
              metric: CuratedMetric.loadedReps,
              targets: _targets33,
              restSeconds: 120,
              instructions: 'Use a light load and practiced technique.',
            ),
            CuratedMovement(
              name: 'Barbell Back Squat',
              metric: CuratedMetric.loadedReps,
              targets: _targets32,
              restSeconds: 120,
            ),
            CuratedMovement(
              name: 'Dumbbell Pullover',
              metric: CuratedMetric.loadedReps,
              targets: _targets33,
              restSeconds: 90,
              instructions:
                  'Use a comfortable shoulder range and a light, controlled load.',
            ),
            CuratedMovement(
              name: 'Barbell Bench Press',
              metric: CuratedMetric.loadedReps,
              targets: _targets50,
              restSeconds: 120,
            ),
            CuratedMovement(
              name: 'Barbell Curl',
              metric: CuratedMetric.loadedReps,
              targets: _targets33,
              restSeconds: 90,
            ),
            CuratedMovement(
              name: 'Shadowboxing or Light Kick Practice',
              metric: CuratedMetric.duration,
              targets: _targets36,
              restSeconds: 60,
              instructions:
                  'Use practiced techniques and comfortable kick heights.',
            ),
            CuratedMovement(
              name: 'Reverse Crunch',
              metric: CuratedMetric.reps,
              targets: _targets32,
              restSeconds: 60,
            ),
            CuratedMovement(
              name: 'Reverse Curl',
              metric: CuratedMetric.loadedReps,
              targets: _targets32,
              restSeconds: 60,
            ),
          ],
        ),
      ],
    ),
    CuratedProgram(
      id: 'statham_action',
      actor: 'Jason Statham',
      role: 'Action roles',
      title: 'Action Conditioning',
      focus:
          'Rowing, practical strength, carries and a scaled descending circuit.',
      evidence:
          'Adapted from the first five days of a published single-week snapshot credited to Logan Hood. Repeating this as a program is an app adaptation; Big Five 55 is credited to Dan John.',
      notes:
          'Repeat these five sessions as a weekly sequence with two recovery days; they do not need to be consecutive. Use the first week to choose manageable loads. Keep about two clean reps in reserve; bodyweight work may use assistance. Add reps within the range before a small load increase. Repeat or reduce the load if form or recovery declines. Film preparation timelines are not targets for your results. These are app adaptations, not endorsed actor routines. The app removes the 1RM attempt and actor-specific loads, reduces large bodyweight totals, replaces specialist rope and ring work and scales the Big Five ladder to five through one reps. Every session starts with an easy ten-minute row.',
      sources: [
        CuratedSource(
          title:
              'Supplied research: Bruce Lee and Jason Statham: Documented Training Routines and 5-Day Plans — Jason Statham',
          url: '',
        ),
        CuratedSource(
          title: 'Men’s Health — published Statham workout snapshot',
          url: 'https://menshealth.com.au/jason-statham-workout-routine/',
        ),
        CuratedSource(
          title: 'Men’s Health — Statham training context',
          url:
              'https://menshealth.com.au/jason-statham-workout-burn-fat-gain-muscle/',
        ),
      ],
      days: [
        CuratedDay(
          title: 'Deadlift and bodyweight',
          notes:
              'The app replaces the original max deadlift and trampoline finish with controlled work.',
          movements: [
            CuratedMovement(
              name: 'Easy Row Warm-up',
              metric: CuratedMetric.duration,
              targets: _targets38,
              restSeconds: 0,
              instructions:
                  'Comfortable pace, around or below 20 strokes per minute.',
            ),
            CuratedMovement(
              name: 'Push-up',
              metric: CuratedMetric.reps,
              targets: _targets53,
              restSeconds: 0,
              group: 'warmup',
            ),
            CuratedMovement(
              name: 'Inverted Row',
              metric: CuratedMetric.reps,
              targets: _targets53,
              restSeconds: 0,
              group: 'warmup',
            ),
            CuratedMovement(
              name: 'Bodyweight Squat',
              metric: CuratedMetric.reps,
              targets: _targets53,
              restSeconds: 60,
              group: 'warmup',
            ),
            CuratedMovement(
              name: 'Deadlift',
              metric: CuratedMetric.loadedReps,
              targets: _targets54,
              restSeconds: 150,
              instructions:
                  'Ramp to a manageable working load. This is not a max test.',
            ),
            CuratedMovement(
              name: 'Easy Walk',
              metric: CuratedMetric.duration,
              targets: _targets38,
              restSeconds: 0,
            ),
          ],
        ),
        CuratedDay(
          title: 'Scaled Big Five ladder',
          notes:
              'Complete all five movements at five reps, then four, three, two and one. This scales the source’s 10-to-1 ladder and replaces power cleans.',
          movements: [
            CuratedMovement(
              name: 'Easy Row Warm-up',
              metric: CuratedMetric.duration,
              targets: _targets38,
              restSeconds: 0,
            ),
            CuratedMovement(
              name: 'Plank',
              metric: CuratedMetric.duration,
              targets: _targets55,
              restSeconds: 45,
            ),
            CuratedMovement(
              name: 'Bodyweight Squat Hold',
              metric: CuratedMetric.duration,
              targets: _targets55,
              restSeconds: 45,
            ),
            CuratedMovement(
              name: 'Front Squat',
              metric: CuratedMetric.loadedReps,
              targets: _targets56,
              restSeconds: 0,
              group: 'big_five',
            ),
            CuratedMovement(
              name: 'Pull-up',
              metric: CuratedMetric.reps,
              targets: _targets56,
              restSeconds: 0,
              group: 'big_five',
            ),
            CuratedMovement(
              name: 'Push-up',
              metric: CuratedMetric.reps,
              targets: _targets56,
              restSeconds: 0,
              group: 'big_five',
            ),
            CuratedMovement(
              name: 'Kettlebell Swing',
              metric: CuratedMetric.loadedReps,
              targets: _targets56,
              restSeconds: 0,
              group: 'big_five',
            ),
            CuratedMovement(
              name: 'Hanging Knee Raise',
              metric: CuratedMetric.reps,
              targets: _targets56,
              restSeconds: 90,
              group: 'big_five',
            ),
          ],
        ),
        CuratedDay(
          title: 'Rowing intervals and carries',
          notes:
              'Loads and pace are personal choices. Historical rowing splits and actor loads are not targets.',
          movements: [
            CuratedMovement(
              name: 'Easy Row Warm-up',
              metric: CuratedMetric.duration,
              targets: _targets38,
              restSeconds: 0,
            ),
            CuratedMovement(
              name: 'Rowing Ergometer',
              metric: CuratedMetric.distance,
              targets: _targets57,
              restSeconds: 180,
              instructions:
                  'Repeatable strong pace; easy movement during recovery. The source’s 500m intervals are scaled to 250m.',
            ),
            CuratedMovement(
              name: 'Farmer Carry',
              metric: CuratedMetric.loadedDistance,
              targets: _targets58,
              restSeconds: 90,
            ),
            CuratedMovement(
              name: 'Easy Walk',
              metric: CuratedMetric.duration,
              targets: _targets59,
              restSeconds: 0,
            ),
          ],
        ),
        CuratedDay(
          title: 'Front squat and push-ups',
          notes:
              'This uses four working squat sets and a short push-up ladder instead of the source’s 200-rep partner finish.',
          movements: [
            CuratedMovement(
              name: 'Easy Row Warm-up',
              metric: CuratedMetric.duration,
              targets: _targets38,
              restSeconds: 0,
            ),
            CuratedMovement(
              name: 'Bodyweight Squat',
              metric: CuratedMetric.reps,
              targets: _targets60,
              restSeconds: 60,
            ),
            CuratedMovement(
              name: 'Front Squat',
              metric: CuratedMetric.loadedReps,
              targets: _targets31,
              restSeconds: 120,
            ),
            CuratedMovement(
              name: 'Push-up',
              metric: CuratedMetric.reps,
              targets: _targets61,
              restSeconds: 60,
              instructions:
                  'A scaled solo ladder; stop with clean reps in reserve.',
            ),
            CuratedMovement(
              name: 'Hip Mobility',
              metric: CuratedMetric.duration,
              targets: _targets14,
              restSeconds: 15,
            ),
          ],
        ),
        CuratedDay(
          title: 'Full-body circuit',
          notes:
              'Two controlled rounds replace the original single pass with rope climbs and pulls. Complete one set of each grouped movement before resting.',
          movements: [
            CuratedMovement(
              name: 'Easy Row Warm-up',
              metric: CuratedMetric.duration,
              targets: _targets38,
              restSeconds: 0,
            ),
            CuratedMovement(
              name: 'Bear Crawl',
              metric: CuratedMetric.distance,
              targets: _targets62,
              restSeconds: 0,
              group: 'movement',
            ),
            CuratedMovement(
              name: 'Crab Walk',
              metric: CuratedMetric.distance,
              targets: _targets62,
              restSeconds: 60,
              instructions:
                  'Use a short, comfortable range and controlled steps.',
              group: 'movement',
            ),
            CuratedMovement(
              name: 'Front Squat',
              metric: CuratedMetric.loadedReps,
              targets: _targets63,
              restSeconds: 0,
              group: 'full_body',
            ),
            CuratedMovement(
              name: 'Medicine Ball Slam',
              metric: CuratedMetric.loadedReps,
              targets: _targets33,
              restSeconds: 0,
              group: 'full_body',
            ),
            CuratedMovement(
              name: 'Barbell Bench Press',
              metric: CuratedMetric.loadedReps,
              targets: _targets33,
              restSeconds: 0,
              group: 'full_body',
            ),
            CuratedMovement(
              name: 'Pull-up',
              metric: CuratedMetric.reps,
              targets: _targets63,
              restSeconds: 0,
              group: 'full_body',
            ),
            CuratedMovement(
              name: 'Dip',
              metric: CuratedMetric.reps,
              targets: _targets50,
              restSeconds: 0,
              group: 'full_body',
            ),
            CuratedMovement(
              name: 'Farmer Carry',
              metric: CuratedMetric.loadedDistance,
              targets: _targets64,
              restSeconds: 120,
              group: 'full_body',
            ),
          ],
        ),
      ],
    ),
  ];
}

const _targets1 = <CuratedSetTarget>[
  CuratedSetTarget(reps: '6–8'),
  CuratedSetTarget(reps: '6–8'),
  CuratedSetTarget(reps: '6–8'),
];

const _targets2 = <CuratedSetTarget>[
  CuratedSetTarget(reps: '10–15'),
  CuratedSetTarget(reps: '10–15'),
  CuratedSetTarget(reps: '10–15'),
];

const _targets3 = <CuratedSetTarget>[
  CuratedSetTarget(reps: '5–8'),
  CuratedSetTarget(reps: '5–8'),
  CuratedSetTarget(reps: '5–8'),
];

const _targets4 = <CuratedSetTarget>[
  CuratedSetTarget(seconds: 30),
  CuratedSetTarget(seconds: 30),
  CuratedSetTarget(seconds: 30),
];

const _targets5 = <CuratedSetTarget>[
  CuratedSetTarget(seconds: 120),
  CuratedSetTarget(seconds: 120),
  CuratedSetTarget(seconds: 120),
];

const _targets6 = <CuratedSetTarget>[
  CuratedSetTarget(seconds: 120),
  CuratedSetTarget(seconds: 120),
  CuratedSetTarget(seconds: 120),
  CuratedSetTarget(seconds: 120),
  CuratedSetTarget(seconds: 120),
];

const _targets7 = <CuratedSetTarget>[
  CuratedSetTarget(reps: '8–12'),
  CuratedSetTarget(reps: '8–12'),
  CuratedSetTarget(reps: '8–12'),
];

const _targets8 = <CuratedSetTarget>[
  CuratedSetTarget(reps: '8'),
  CuratedSetTarget(reps: '8'),
  CuratedSetTarget(reps: '8'),
];

const _targets9 = <CuratedSetTarget>[
  CuratedSetTarget(reps: '5'),
  CuratedSetTarget(reps: '5'),
  CuratedSetTarget(reps: '5'),
];

const _targets10 = <CuratedSetTarget>[
  CuratedSetTarget(reps: '10'),
  CuratedSetTarget(reps: '10'),
  CuratedSetTarget(reps: '10'),
];

const _targets11 = <CuratedSetTarget>[
  CuratedSetTarget(reps: '15'),
  CuratedSetTarget(reps: '15'),
  CuratedSetTarget(reps: '15'),
];

const _targets12 = <CuratedSetTarget>[
  CuratedSetTarget(meters: 30),
  CuratedSetTarget(meters: 30),
  CuratedSetTarget(meters: 30),
];

const _targets13 = <CuratedSetTarget>[
  CuratedSetTarget(seconds: 180),
  CuratedSetTarget(seconds: 180),
  CuratedSetTarget(seconds: 180),
  CuratedSetTarget(seconds: 180),
  CuratedSetTarget(seconds: 180),
];

const _targets14 = <CuratedSetTarget>[
  CuratedSetTarget(seconds: 60),
  CuratedSetTarget(seconds: 60),
];

const _targets15 = <CuratedSetTarget>[CuratedSetTarget(seconds: 900)];

const _targets16 = <CuratedSetTarget>[
  CuratedSetTarget(reps: '6–10'),
  CuratedSetTarget(reps: '6–10'),
  CuratedSetTarget(reps: '6–10'),
];

const _targets17 = <CuratedSetTarget>[
  CuratedSetTarget(reps: '12'),
  CuratedSetTarget(reps: '12'),
  CuratedSetTarget(reps: '12'),
];

const _targets18 = <CuratedSetTarget>[
  CuratedSetTarget(seconds: 30),
  CuratedSetTarget(seconds: 30),
  CuratedSetTarget(seconds: 30),
  CuratedSetTarget(seconds: 30),
  CuratedSetTarget(seconds: 30),
  CuratedSetTarget(seconds: 30),
];

const _targets19 = <CuratedSetTarget>[
  CuratedSetTarget(meters: 250),
  CuratedSetTarget(meters: 250),
  CuratedSetTarget(meters: 250),
];

const _targets20 = <CuratedSetTarget>[
  CuratedSetTarget(reps: '20'),
  CuratedSetTarget(reps: '20'),
  CuratedSetTarget(reps: '20'),
];

const _targets21 = <CuratedSetTarget>[
  CuratedSetTarget(meters: 250),
  CuratedSetTarget(meters: 250),
  CuratedSetTarget(meters: 250),
  CuratedSetTarget(meters: 250),
];

const _targets22 = <CuratedSetTarget>[
  CuratedSetTarget(reps: '8–10'),
  CuratedSetTarget(reps: '8–10'),
  CuratedSetTarget(reps: '8–10'),
];

const _targets23 = <CuratedSetTarget>[
  CuratedSetTarget(reps: '10'),
  CuratedSetTarget(reps: '10'),
];

const _targets24 = <CuratedSetTarget>[
  CuratedSetTarget(reps: '6'),
  CuratedSetTarget(reps: '6'),
  CuratedSetTarget(reps: '6'),
];

const _targets25 = <CuratedSetTarget>[
  CuratedSetTarget(meters: 20),
  CuratedSetTarget(meters: 20),
  CuratedSetTarget(meters: 20),
  CuratedSetTarget(meters: 20),
];

const _targets26 = <CuratedSetTarget>[
  CuratedSetTarget(reps: '6–8'),
  CuratedSetTarget(reps: '6–8'),
  CuratedSetTarget(reps: '6–8'),
  CuratedSetTarget(reps: '6–8'),
];

const _targets27 = <CuratedSetTarget>[
  CuratedSetTarget(reps: '8'),
  CuratedSetTarget(reps: '8'),
  CuratedSetTarget(reps: '8'),
  CuratedSetTarget(reps: '8'),
];

const _targets28 = <CuratedSetTarget>[
  CuratedSetTarget(meters: 25),
  CuratedSetTarget(meters: 25),
  CuratedSetTarget(meters: 25),
];

const _targets29 = <CuratedSetTarget>[
  CuratedSetTarget(reps: '5–8'),
  CuratedSetTarget(reps: '5–8'),
  CuratedSetTarget(reps: '5–8'),
  CuratedSetTarget(reps: '5–8'),
];

const _targets30 = <CuratedSetTarget>[
  CuratedSetTarget(reps: '10–12'),
  CuratedSetTarget(reps: '10–12'),
  CuratedSetTarget(reps: '10–12'),
];

const _targets31 = <CuratedSetTarget>[
  CuratedSetTarget(reps: '5'),
  CuratedSetTarget(reps: '5'),
  CuratedSetTarget(reps: '5'),
  CuratedSetTarget(reps: '5'),
];

const _targets32 = <CuratedSetTarget>[
  CuratedSetTarget(reps: '12'),
  CuratedSetTarget(reps: '12'),
];

const _targets33 = <CuratedSetTarget>[
  CuratedSetTarget(reps: '8'),
  CuratedSetTarget(reps: '8'),
];

const _targets34 = <CuratedSetTarget>[CuratedSetTarget(seconds: 1200)];

const _targets35 = <CuratedSetTarget>[
  CuratedSetTarget(meters: 15),
  CuratedSetTarget(meters: 15),
  CuratedSetTarget(meters: 15),
];

const _targets36 = <CuratedSetTarget>[
  CuratedSetTarget(seconds: 120),
  CuratedSetTarget(seconds: 120),
  CuratedSetTarget(seconds: 120),
  CuratedSetTarget(seconds: 120),
];

const _targets37 = <CuratedSetTarget>[
  CuratedSetTarget(meters: 20),
  CuratedSetTarget(meters: 20),
  CuratedSetTarget(meters: 20),
];

const _targets38 = <CuratedSetTarget>[CuratedSetTarget(seconds: 600)];

const _targets39 = <CuratedSetTarget>[
  CuratedSetTarget(reps: '12–15'),
  CuratedSetTarget(reps: '12–15'),
  CuratedSetTarget(reps: '12–15'),
];

const _targets40 = <CuratedSetTarget>[CuratedSetTarget(seconds: 1800)];

const _targets41 = <CuratedSetTarget>[
  CuratedSetTarget(reps: '15'),
  CuratedSetTarget(reps: '12'),
  CuratedSetTarget(reps: '10'),
  CuratedSetTarget(reps: '8'),
];

const _targets42 = <CuratedSetTarget>[
  CuratedSetTarget(reps: '12'),
  CuratedSetTarget(reps: '10'),
  CuratedSetTarget(reps: '8'),
];

const _targets43 = <CuratedSetTarget>[
  CuratedSetTarget(reps: '5–8'),
  CuratedSetTarget(reps: '5–8'),
];

const _targets44 = <CuratedSetTarget>[
  CuratedSetTarget(reps: '12–15'),
  CuratedSetTarget(reps: '12–15'),
];

const _targets45 = <CuratedSetTarget>[
  CuratedSetTarget(reps: '12'),
  CuratedSetTarget(reps: '10'),
  CuratedSetTarget(reps: '8'),
  CuratedSetTarget(reps: '8'),
];

const _targets46 = <CuratedSetTarget>[
  CuratedSetTarget(reps: '15–20'),
  CuratedSetTarget(reps: '15–20'),
  CuratedSetTarget(reps: '15–20'),
];

const _targets47 = <CuratedSetTarget>[
  CuratedSetTarget(seconds: 30),
  CuratedSetTarget(seconds: 30),
  CuratedSetTarget(seconds: 30),
  CuratedSetTarget(seconds: 30),
];

const _targets48 = <CuratedSetTarget>[
  CuratedSetTarget(seconds: 120),
  CuratedSetTarget(seconds: 120),
];

const _targets49 = <CuratedSetTarget>[
  CuratedSetTarget(reps: '4'),
  CuratedSetTarget(reps: '6'),
  CuratedSetTarget(reps: '4'),
];

const _targets50 = <CuratedSetTarget>[
  CuratedSetTarget(reps: '6'),
  CuratedSetTarget(reps: '6'),
];

const _targets51 = <CuratedSetTarget>[
  CuratedSetTarget(seconds: 20),
  CuratedSetTarget(seconds: 20),
  CuratedSetTarget(seconds: 20),
];

const _targets52 = <CuratedSetTarget>[
  CuratedSetTarget(reps: '15'),
  CuratedSetTarget(reps: '15'),
];

const _targets53 = <CuratedSetTarget>[
  CuratedSetTarget(reps: '3'),
  CuratedSetTarget(reps: '4'),
  CuratedSetTarget(reps: '5'),
];

const _targets54 = <CuratedSetTarget>[
  CuratedSetTarget(reps: '8'),
  CuratedSetTarget(reps: '6'),
  CuratedSetTarget(reps: '5'),
  CuratedSetTarget(reps: '5'),
];

const _targets55 = <CuratedSetTarget>[
  CuratedSetTarget(seconds: 20),
  CuratedSetTarget(seconds: 20),
];

const _targets56 = <CuratedSetTarget>[
  CuratedSetTarget(reps: '5'),
  CuratedSetTarget(reps: '4'),
  CuratedSetTarget(reps: '3'),
  CuratedSetTarget(reps: '2'),
  CuratedSetTarget(reps: '1'),
];

const _targets57 = <CuratedSetTarget>[
  CuratedSetTarget(meters: 250),
  CuratedSetTarget(meters: 250),
  CuratedSetTarget(meters: 250),
  CuratedSetTarget(meters: 250),
  CuratedSetTarget(meters: 250),
  CuratedSetTarget(meters: 250),
];

const _targets58 = <CuratedSetTarget>[
  CuratedSetTarget(meters: 25),
  CuratedSetTarget(meters: 25),
  CuratedSetTarget(meters: 25),
  CuratedSetTarget(meters: 25),
];

const _targets59 = <CuratedSetTarget>[CuratedSetTarget(seconds: 300)];

const _targets60 = <CuratedSetTarget>[CuratedSetTarget(reps: '20')];

const _targets61 = <CuratedSetTarget>[
  CuratedSetTarget(reps: '5'),
  CuratedSetTarget(reps: '8'),
  CuratedSetTarget(reps: '10'),
  CuratedSetTarget(reps: '8'),
];

const _targets62 = <CuratedSetTarget>[
  CuratedSetTarget(meters: 10),
  CuratedSetTarget(meters: 10),
  CuratedSetTarget(meters: 10),
];

const _targets63 = <CuratedSetTarget>[
  CuratedSetTarget(reps: '5'),
  CuratedSetTarget(reps: '5'),
];

const _targets64 = <CuratedSetTarget>[
  CuratedSetTarget(meters: 20),
  CuratedSetTarget(meters: 20),
];
