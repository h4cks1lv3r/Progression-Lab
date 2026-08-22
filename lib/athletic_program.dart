// Original, evidence-informed athletic movement program.
//
// This module is not affiliated with the commercial Functional Patterns
// organization. It organizes broadly accepted athletic qualities—gait,
// unilateral strength, rotation, elastic contacts, acceleration,
// deceleration, and repeat-effort capacity—into a progressive 12-week plan.

enum AthleticQuality {
  gait,
  mobility,
  unilateralStrength,
  trunkControl,
  rotation,
  elasticStrength,
  acceleration,
  deceleration,
  changeOfDirection,
  capacity,
}

extension AthleticQualityLabel on AthleticQuality {
  String get label => switch (this) {
    AthleticQuality.gait => 'Gait',
    AthleticQuality.mobility => 'Mobility',
    AthleticQuality.unilateralStrength => 'Unilateral strength',
    AthleticQuality.trunkControl => 'Trunk control',
    AthleticQuality.rotation => 'Rotation',
    AthleticQuality.elasticStrength => 'Elastic strength',
    AthleticQuality.acceleration => 'Acceleration',
    AthleticQuality.deceleration => 'Deceleration',
    AthleticQuality.changeOfDirection => 'Change of direction',
    AthleticQuality.capacity => 'Athletic capacity',
  };
}

class AthleticDrill {
  const AthleticDrill({
    required this.name,
    required this.prescription,
    required this.purpose,
    required this.cues,
    required this.equipment,
    required this.regression,
    required this.progression,
  });

  final String name;
  final String prescription;
  final String purpose;
  final List<String> cues;
  final String equipment;
  final String regression;
  final String progression;
}

class AthleticSession {
  const AthleticSession({
    required this.id,
    required this.day,
    required this.name,
    required this.summary,
    required this.durationMinutes,
    required this.qualities,
    required this.drills,
  });

  final String id;
  final String day;
  final String name;
  final String summary;
  final int durationMinutes;
  final List<AthleticQuality> qualities;
  final List<AthleticDrill> drills;
}

class AthleticWeek {
  const AthleticWeek({
    required this.number,
    required this.cycleNumber,
    required this.cycleName,
    required this.weekInCycle,
    required this.stage,
    required this.goal,
    required this.sessions,
  });

  final int number;
  final int cycleNumber;
  final String cycleName;
  final int weekInCycle;
  final String stage;
  final String goal;
  final List<AthleticSession> sessions;
}

class AthleticCycle {
  const AthleticCycle({
    required this.number,
    required this.name,
    required this.weeks,
    required this.description,
    required this.aims,
  });

  final int number;
  final String name;
  final String weeks;
  final String description;
  final List<String> aims;
}

class _DrillTemplate {
  const _DrillTemplate({
    required this.name,
    required this.prescriptions,
    required this.purpose,
    required this.cues,
    required this.equipment,
    required this.regression,
    required this.progression,
  });

  final String name;
  final List<String> prescriptions;
  final String purpose;
  final List<String> cues;
  final String equipment;
  final String regression;
  final String progression;

  AthleticDrill forWeek(int weekInCycle) => AthleticDrill(
    name: name,
    prescription: prescriptions[(weekInCycle - 1).clamp(0, 3).toInt()],
    purpose: purpose,
    cues: cues,
    equipment: equipment,
    regression: regression,
    progression: progression,
  );
}

class _SessionTemplate {
  const _SessionTemplate({
    required this.id,
    required this.day,
    required this.name,
    required this.summary,
    required this.durationMinutes,
    required this.qualities,
    required this.drills,
  });

  final String id;
  final String day;
  final String name;
  final String summary;
  final int durationMinutes;
  final List<AthleticQuality> qualities;
  final List<_DrillTemplate> drills;

  AthleticSession forWeek(int weekInCycle) => AthleticSession(
    id: id,
    day: day,
    name: name,
    summary: summary,
    durationMinutes: durationMinutes,
    qualities: qualities,
    drills: [for (final drill in drills) drill.forWeek(weekInCycle)],
  );
}

abstract final class AthleticProgram {
  static const int totalWeeks = 12;
  static const int weeksPerCycle = 4;
  static const int sessionsPerWeek = 4;

  static const cycles = <AthleticCycle>[
    AthleticCycle(
      number: 1,
      name: 'Foundation & Control',
      weeks: 'Weeks 1–4',
      description:
          'Build dependable foot-to-hip alignment, cross-body timing, trunk control, unilateral strength, and landing positions before speed is added.',
      aims: [
        'Organize the foot, ankle, pelvis, and rib cage under low fatigue.',
        'Build left-right balance and split-stance strength.',
        'Coordinate opposite arm and leg actions used in walking and running.',
        'Learn to absorb force without the knee, hip, or trunk collapsing.',
      ],
    ),
    AthleticCycle(
      number: 2,
      name: 'Elastic Strength & Rotation',
      weeks: 'Weeks 5–8',
      description:
          'Add spring, multiplanar loading, diagonal force transfer, rotational strength, and stronger braking while retaining clean positions.',
      aims: [
        'Increase ankle and lower-limb stiffness for efficient elastic contacts.',
        'Produce and resist rotation through the hips and trunk.',
        'Transfer force between the upper and lower body in diagonal patterns.',
        'Improve lateral force absorption and re-acceleration.',
      ],
    ),
    AthleticCycle(
      number: 3,
      name: 'Speed & Integration',
      weeks: 'Weeks 9–12',
      description:
          'Express the prior work through acceleration, faster directional changes, linked rotation, reactive movement, and repeat-effort conditioning.',
      aims: [
        'Accelerate with a stable trunk and effective ground projection.',
        'Brake and redirect without losing posture or foot control.',
        'Link rotational power to sprinting and change-of-direction tasks.',
        'Maintain movement quality across repeated high-intent efforts.',
      ],
    ),
  ];

  static AthleticCycle cycleForWeek(int number) {
    _validateWeek(number);
    return cycles[(number - 1) ~/ 4];
  }

  static AthleticWeek week(int number) {
    _validateWeek(number);
    final cycleIndex = (number - 1) ~/ 4;
    final weekInCycle = ((number - 1) % 4) + 1;
    final cycle = cycles[cycleIndex];
    final stage = switch (weekInCycle) {
      1 => 'Learn & benchmark',
      2 => 'Build volume',
      3 => 'Raise intent',
      _ => 'Consolidate & reassess',
    };
    final goal = switch ((cycleIndex, weekInCycle)) {
      (0, 1) =>
        'Move slowly enough to own every position and establish clean baselines.',
      (0, 2) =>
        'Add one controlled exposure while keeping left and right sides even.',
      (0, 3) =>
        'Use more intent without sacrificing foot pressure, trunk control, or landing quality.',
      (0, 4) =>
        'Reduce fatigue, sharpen technique, and repeat the field measures.',
      (1, 1) =>
        'Introduce elastic and rotational actions at a submaximal speed.',
      (1, 2) =>
        'Add contacts and loaded diagonal work while keeping the same mechanics.',
      (1, 3) =>
        'Increase velocity and range only when the landings and trunk remain quiet.',
      (1, 4) => 'Cut volume, retain speed, and compare control against week 4.',
      (2, 1) =>
        'Express acceleration and redirection with planned, predictable tasks.',
      (2, 2) =>
        'Add repeat efforts and slightly more reactive decision-making.',
      (2, 3) =>
        'Use the highest safe intent of the program with complete recovery between quality efforts.',
      _ =>
        'Taper, reassess, and finish with movement quality—not exhaustion—as the standard.',
    };
    final templates = switch (cycleIndex) {
      0 => _foundationSessions,
      1 => _elasticSessions,
      _ => _integrationSessions,
    };
    return AthleticWeek(
      number: number,
      cycleNumber: cycle.number,
      cycleName: cycle.name,
      weekInCycle: weekInCycle,
      stage: stage,
      goal: goal,
      sessions: [
        for (final template in templates) template.forWeek(weekInCycle),
      ],
    );
  }

  static void _validateWeek(int number) {
    if (number < 1 || number > totalWeeks) {
      throw RangeError.range(number, 1, totalWeeks, 'number');
    }
  }

  static const _foundationSessions = <_SessionTemplate>[
    _SessionTemplate(
      id: 'foundation-locomotion',
      day: 'MONDAY',
      name: 'Locomotion & Unilateral Base',
      summary:
          'Foot control, gait timing, split-stance strength, and single-leg balance.',
      durationMinutes: 48,
      qualities: [
        AthleticQuality.gait,
        AthleticQuality.mobility,
        AthleticQuality.unilateralStrength,
        AthleticQuality.trunkControl,
      ],
      drills: [
        _DrillTemplate(
          name: 'Tripod Foot + Short-Foot Hold',
          prescriptions: [
            '2 × 20 sec each foot',
            '3 × 20 sec each foot',
            '3 × 25 sec each foot',
            '2 × 20 sec each foot',
          ],
          purpose:
              'Create even pressure under the heel, base of the big toe, and base of the little toe before loading the leg.',
          cues: [
            'Keep all three pressure points in contact.',
            'Shorten the foot without curling the toes.',
            'Keep the knee stacked over the middle toes.',
          ],
          equipment: 'Barefoot space or flat shoes',
          regression: 'Perform seated with light pressure through the foot.',
          progression: 'Perform standing on one leg without gripping the toes.',
        ),
        _DrillTemplate(
          name: 'Wall March Iso to Alternating March',
          prescriptions: [
            '3 × 15 sec each side + 6 switches',
            '3 × 20 sec each side + 8 switches',
            '4 × 6 crisp switches',
            '2 × 15 sec each side + 6 switches',
          ],
          purpose:
              'Teach the forward body angle, stacked stance leg, and opposite arm-leg timing used in acceleration.',
          cues: [
            'Push the wall away and keep a straight line from head to heel.',
            'Drive the knee without arching the lower back.',
            'Switch feet under the hips, not out in front.',
          ],
          equipment: 'Wall',
          regression: 'Hold one marching position without switching.',
          progression: 'Use faster switches while the torso stays still.',
        ),
        _DrillTemplate(
          name: 'Contralateral Split Squat',
          prescriptions: [
            '3 × 6 each side at 3-sec lowering',
            '3 × 8 each side at controlled tempo',
            '4 × 6 each side with a modest load',
            '2 × 6 each side, easy and precise',
          ],
          purpose:
              'Build unilateral hip and leg strength while the opposite-side load challenges pelvic and trunk control.',
          cues: [
            'Keep the whole front foot connected to the floor.',
            'Lower the rear knee while the front knee tracks forward.',
            'Keep the belt line and ribs facing ahead.',
          ],
          equipment: 'Dumbbell, kettlebell, or body weight',
          regression: 'Use body weight and hold a support.',
          progression: 'Add load or elevate the front foot slightly.',
        ),
        _DrillTemplate(
          name: 'Single-Leg RDL Reach',
          prescriptions: [
            '3 × 6 each side with 2-sec pause',
            '3 × 8 each side',
            '4 × 6 each side with light contralateral load',
            '2 × 6 each side with pause',
          ],
          purpose:
              'Train hip hinging, balance, posterior-chain strength, and control of the pelvis over one leg.',
          cues: [
            'Reach the free heel long behind you.',
            'Keep both hip points facing the floor.',
            'Finish tall by pushing the floor away.',
          ],
          equipment: 'Optional dumbbell or kettlebell',
          regression: 'Use a kickstand stance or fingertip support.',
          progression: 'Add a contralateral load or longer reach.',
        ),
        _DrillTemplate(
          name: 'Suitcase Carry March',
          prescriptions: [
            '3 × 20 m each side',
            '3 × 30 m each side',
            '4 × 20 m each side, heavier',
            '2 × 20 m each side',
          ],
          purpose:
              'Resist side-bending while coordinating controlled steps and stable single-leg support.',
          cues: [
            'Stay tall without leaning away from the load.',
            'Move quietly and place each foot under the hip.',
            'Let the free arm swing naturally.',
          ],
          equipment: 'Dumbbell or kettlebell',
          regression: 'Use a lighter load or march in place.',
          progression: 'Increase load while keeping the same posture.',
        ),
        _DrillTemplate(
          name: '90/90 Hip-Lift Breathing',
          prescriptions: [
            '3 rounds of 4 slow breaths',
            '3 rounds of 5 slow breaths',
            '4 rounds of 4 slow breaths',
            '2 rounds of 4 slow breaths',
          ],
          purpose:
              'Finish with controlled exhalation, posterior pelvic position, and lower-rib movement.',
          cues: [
            'Exhale fully without forcing the neck.',
            'Feel the back of the ribs expand on the inhale.',
            'Keep gentle hamstring pressure into the floor or wall.',
          ],
          equipment: 'Floor and optional wall',
          regression: 'Lie on the back with feet on the floor.',
          progression: 'Add a light reach without losing the exhale.',
        ),
      ],
    ),
    _SessionTemplate(
      id: 'foundation-rotation',
      day: 'WEDNESDAY',
      name: 'Rotation & Integrated Strength',
      summary:
          'Thoracic motion, diagonal force transfer, pushing, pulling, and anti-rotation.',
      durationMinutes: 50,
      qualities: [
        AthleticQuality.mobility,
        AthleticQuality.rotation,
        AthleticQuality.trunkControl,
        AthleticQuality.unilateralStrength,
      ],
      drills: [
        _DrillTemplate(
          name: 'Half-Kneeling Thoracic Rotation Reach',
          prescriptions: [
            '2 × 6 each side',
            '2 × 8 each side',
            '3 × 6 each side',
            '2 × 5 each side',
          ],
          purpose:
              'Separate upper-back rotation from uncontrolled movement at the pelvis or lower back.',
          cues: [
            'Squeeze the down-leg glute lightly.',
            'Rotate through the upper back while the pelvis stays forward.',
            'Reach long instead of forcing range.',
          ],
          equipment: 'Floor pad',
          regression: 'Use a tall-kneeling or side-lying open-book position.',
          progression: 'Add a light band pulling across the body.',
        ),
        _DrillTemplate(
          name: 'Half-Kneeling Band Lift',
          prescriptions: [
            '3 × 8 each side',
            '3 × 10 each side',
            '4 × 8 each side with more tension',
            '2 × 8 each side',
          ],
          purpose:
              'Coordinate hip stability, trunk rotation control, and diagonal arm action from low to high.',
          cues: [
            'Keep pressure through the front foot and down knee.',
            'Move the hands while the ribs stay stacked over the pelvis.',
            'Finish with the shoulder blade rotating naturally.',
          ],
          equipment: 'Resistance band or cable',
          regression: 'Use less tension and a shorter range.',
          progression: 'Perform from a split stance.',
        ),
        _DrillTemplate(
          name: 'Split-Stance One-Arm Row',
          prescriptions: [
            '3 × 8 each side',
            '3 × 10 each side',
            '4 × 8 each side, heavier',
            '2 × 8 each side',
          ],
          purpose:
              'Link pulling strength to contralateral leg support and controlled trunk rotation.',
          cues: [
            'Keep the front heel heavy and back heel lifted.',
            'Let the shoulder blade reach, then pull without shrugging.',
            'Do not twist the pelvis toward the cable.',
          ],
          equipment: 'Cable or resistance band',
          regression: 'Use a square stance.',
          progression: 'Use a longer split stance or heavier load.',
        ),
        _DrillTemplate(
          name: 'Half-Kneeling Landmine Press with Reach',
          prescriptions: [
            '3 × 6 each side',
            '3 × 8 each side',
            '4 × 6 each side with modest load',
            '2 × 6 each side',
          ],
          purpose:
              'Train upward pressing with rib control, shoulder-blade motion, and opposite-hip stability.',
          cues: [
            'Press up and forward, not straight overhead.',
            'Keep the lower ribs from flaring.',
            'Finish by reaching through the shoulder blade.',
          ],
          equipment: 'Landmine or anchored resistance band',
          regression: 'Use a light band press.',
          progression: 'Move to a split-stance landmine press.',
        ),
        _DrillTemplate(
          name: 'Dead Bug Cross-Press',
          prescriptions: [
            '3 × 5 slow reps each side',
            '3 × 6 each side',
            '4 × 5 each side with stronger press',
            '2 × 5 each side',
          ],
          purpose:
              'Build anterior trunk control while coordinating opposite arm and leg tension.',
          cues: [
            'Exhale and keep the lower ribs heavy.',
            'Move only as far as the back remains quiet.',
            'Press hand and knee together without holding the breath.',
          ],
          equipment: 'Floor',
          regression: 'Move one limb at a time.',
          progression: 'Add a light band to the moving arm.',
        ),
        _DrillTemplate(
          name: 'Cross-Crawl Carry',
          prescriptions: [
            '3 × 20 m',
            '3 × 30 m',
            '4 × 20 m with moderate load',
            '2 × 20 m',
          ],
          purpose:
              'Integrate walking rhythm, trunk stiffness, arm swing, and loaded gait.',
          cues: [
            'Keep the steps smooth and narrow.',
            'Let the unloaded arm swing opposite the lead leg.',
            'Avoid rushing or swaying side to side.',
          ],
          equipment: 'One dumbbell or kettlebell',
          regression: 'March in place with a light load.',
          progression: 'Use a front-rack carry or heavier suitcase load.',
        ),
      ],
    ),
    _SessionTemplate(
      id: 'foundation-deceleration',
      day: 'FRIDAY',
      name: 'Landing & Deceleration',
      summary:
          'Ankle stiffness, quiet landings, frontal-plane control, and planned braking.',
      durationMinutes: 44,
      qualities: [
        AthleticQuality.elasticStrength,
        AthleticQuality.deceleration,
        AthleticQuality.unilateralStrength,
        AthleticQuality.trunkControl,
      ],
      drills: [
        _DrillTemplate(
          name: 'Ankle Pogo Preparation',
          prescriptions: [
            '3 × 15 low contacts',
            '3 × 20 low contacts',
            '4 × 15 crisp contacts',
            '2 × 15 easy contacts',
          ],
          purpose:
              'Introduce short, elastic ground contacts while keeping the ankle and trunk organized.',
          cues: [
            'Bounce from the ankles with tall posture.',
            'Keep contacts quiet and under the hips.',
            'Stop if the knees or heels collapse inward.',
          ],
          equipment: 'Flat floor',
          regression: 'Fast calf raises without leaving the floor.',
          progression: 'Increase rhythm slightly, not jump height.',
        ),
        _DrillTemplate(
          name: 'Snap-Down to Athletic Stance',
          prescriptions: [
            '3 × 5 with 2-sec stick',
            '4 × 5 with 2-sec stick',
            '4 × 4 faster snap-downs',
            '2 × 5 with perfect stick',
          ],
          purpose:
              'Teach rapid force absorption into a stable hip, knee, ankle, and trunk position.',
          cues: [
            'Land with the whole foot, not only the toes or heels.',
            'Push the hips back while the knees track over the toes.',
            'Freeze without extra steps or trunk sway.',
          ],
          equipment: 'Open floor',
          regression: 'Use a slow squat-to-stick.',
          progression: 'Add a small vertical jump before the snap-down.',
        ),
        _DrillTemplate(
          name: 'Lateral Step-to-Stick',
          prescriptions: [
            '3 × 5 each side',
            '3 × 6 each side',
            '4 × 5 each side with faster entry',
            '2 × 5 each side',
          ],
          purpose:
              'Build side-to-side force absorption and control of the knee and pelvis over one foot.',
          cues: [
            'Step far enough to load the hip, not so far that the foot rolls.',
            'Keep the chest and pelvis level.',
            'Hold the landing before returning.',
          ],
          equipment: 'Open floor',
          regression: 'Use a shorter lateral step.',
          progression: 'Use a low lateral hop-to-stick.',
        ),
        _DrillTemplate(
          name: 'Low Step-Off Landing',
          prescriptions: [
            '3 × 4 from 10–15 cm',
            '4 × 4 from 10–20 cm',
            '4 × 3 with quicker stabilization',
            '2 × 4 from the lowest height',
          ],
          purpose:
              'Practice receiving vertical force without excessive noise, collapse, or extra movement.',
          cues: [
            'Step off; do not jump up from the box.',
            'Meet the floor with hips, knees, and ankles together.',
            'Hold the finish for two seconds.',
          ],
          equipment: 'Low step or plate',
          regression: 'Use a calf-rise drop from the floor.',
          progression: 'Increase height only after every landing is stable.',
        ),
        _DrillTemplate(
          name: 'Reverse Lunge to Knee Drive',
          prescriptions: [
            '3 × 6 each side',
            '3 × 8 each side',
            '4 × 6 each side with light load',
            '2 × 6 each side',
          ],
          purpose:
              'Link controlled braking in the lunge to a stable single-leg drive position.',
          cues: [
            'Reach the rear foot back while the front foot stays planted.',
            'Drive through the floor and finish tall.',
            'Pause with the opposite knee lifted.',
          ],
          equipment: 'Optional dumbbells',
          regression: 'Remove the knee drive or hold a support.',
          progression: 'Add load or a faster upward drive.',
        ),
        _DrillTemplate(
          name: 'Tempo Shuttle with Controlled Stops',
          prescriptions: [
            '6 × 10 m at 60%, walk-back recovery',
            '8 × 10 m at 65%, walk-back recovery',
            '8 × 10 m at 70%, full control',
            '5 × 10 m at 60%',
          ],
          purpose:
              'Practice planned acceleration and braking at a speed that allows technical control.',
          cues: [
            'Build speed gradually, then lower the center of mass before the line.',
            'Use several small braking steps instead of one hard reach.',
            'Finish balanced and facing forward.',
          ],
          equipment: 'Two markers and 10 m of space',
          regression: 'Use a brisk walk or shorter distance.',
          progression: 'Raise speed only if every stop is balanced.',
        ),
      ],
    ),
    _SessionTemplate(
      id: 'foundation-acceleration',
      day: 'SATURDAY',
      name: 'Acceleration Fundamentals & Capacity',
      summary:
          'Marching mechanics, short starts, lateral braking, crawling, and low-impact intervals.',
      durationMinutes: 46,
      qualities: [
        AthleticQuality.gait,
        AthleticQuality.acceleration,
        AthleticQuality.changeOfDirection,
        AthleticQuality.capacity,
      ],
      drills: [
        _DrillTemplate(
          name: 'Wall Switch Series',
          prescriptions: [
            '3 rounds: 5 singles each side',
            '3 rounds: 5 double switches',
            '4 rounds: 4 double switches',
            '2 rounds: 5 singles each side',
          ],
          purpose:
              'Reinforce front-side mechanics and force direction before open-space acceleration.',
          cues: [
            'Push through the stance foot.',
            'Switch the legs without the hips dropping.',
            'Keep the neck and face relaxed.',
          ],
          equipment: 'Wall',
          regression: 'Use static wall-march holds.',
          progression: 'Use triple switches with the same posture.',
        ),
        _DrillTemplate(
          name: 'A-March to Low A-Skip',
          prescriptions: [
            '3 × 15 m march',
            '2 × 15 m march + 2 × 15 m low skip',
            '4 × 15 m low skip',
            '2 × 15 m march + 1 × 15 m skip',
          ],
          purpose:
              'Coordinate arm swing, front-side knee action, and foot strike beneath the body.',
          cues: [
            'Stay tall and move rhythmically.',
            'Strike down under the hips.',
            'Keep the toes pulled up without stiffening the whole leg.',
          ],
          equipment: '15 m of open space',
          regression: 'March in place.',
          progression: 'Increase rhythm while preserving timing.',
        ),
        _DrillTemplate(
          name: 'Falling Start Acceleration',
          prescriptions: [
            '6 × 8 m at 65–70%',
            '8 × 8 m at 70–75%',
            '6 × 10 m at 75–80%',
            '4 × 8 m at 65–70%',
          ],
          purpose:
              'Teach forward projection and early acceleration without a complicated starting position.',
          cues: [
            'Fall as one line, then catch the fall with a forceful first step.',
            'Push back into the ground instead of reaching forward.',
            'Take full recovery so each repetition is crisp.',
          ],
          equipment: '10 m of open space',
          regression: 'Use a two-step lean-and-go drill.',
          progression: 'Increase distance to 12–15 m.',
        ),
        _DrillTemplate(
          name: 'Lateral Shuffle to Two-Step Brake',
          prescriptions: [
            '3 × 3 each direction over 4 m',
            '4 × 3 each direction over 4 m',
            '4 × 3 each direction over 5 m',
            '2 × 3 each direction over 4 m',
          ],
          purpose:
              'Introduce lateral movement and braking without a reactive decision demand.',
          cues: [
            'Keep the feet apart and avoid crossing over.',
            'Lower the hips before the stop.',
            'Finish with the outside hip loaded and trunk controlled.',
          ],
          equipment: 'Two markers',
          regression: 'Use a slower side step.',
          progression: 'Add a short forward exit after the brake.',
        ),
        _DrillTemplate(
          name: 'Bear Crawl with Opposite-Limb Timing',
          prescriptions: [
            '3 × 10 m',
            '3 × 15 m',
            '4 × 10 m with slower control',
            '2 × 10 m',
          ],
          purpose:
              'Train cross-body coordination, shoulder stability, and trunk control in a locomotor pattern.',
          cues: [
            'Move the opposite hand and foot together.',
            'Keep the hips level and knees close to the floor.',
            'Use small, quiet steps.',
          ],
          equipment: 'Open floor',
          regression: 'Use a quadruped hover or stationary shoulder taps.',
          progression: 'Crawl backward or add controlled direction changes.',
        ),
        _DrillTemplate(
          name: 'Easy Cyclic Intervals',
          prescriptions: [
            '6 rounds: 30 sec work / 60 sec easy',
            '8 rounds: 30 sec work / 45 sec easy',
            '8 rounds: 40 sec work / 40 sec easy',
            '5 rounds: 30 sec work / 60 sec easy',
          ],
          purpose:
              'Build general conditioning without adding high-impact fatigue to the movement work.',
          cues: [
            'Use a pace that allows nasal breathing for most of the session.',
            'Keep the movement smooth instead of chasing a score.',
            'Finish with energy left in reserve.',
          ],
          equipment: 'Bike, rower, incline walk, or low-impact alternative',
          regression: 'Use continuous easy walking.',
          progression: 'Add one interval before raising intensity.',
        ),
      ],
    ),
  ];

  static const _elasticSessions = <_SessionTemplate>[
    _SessionTemplate(
      id: 'elastic-locomotion',
      day: 'MONDAY',
      name: 'Loaded Gait & Unilateral Strength',
      summary:
          'Stronger single-leg support, loaded marching, step-up drive, and diagonal trunk control.',
      durationMinutes: 52,
      qualities: [
        AthleticQuality.gait,
        AthleticQuality.unilateralStrength,
        AthleticQuality.trunkControl,
        AthleticQuality.mobility,
      ],
      drills: [
        _DrillTemplate(
          name: 'Foot Rocker to Calf-Isometric',
          prescriptions: [
            '2 × 8 rocks + 20-sec hold each side',
            '3 × 8 rocks + 20-sec hold each side',
            '3 × 10 rocks + 25-sec hold each side',
            '2 × 8 rocks + 15-sec hold each side',
          ],
          purpose:
              'Connect ankle motion to a strong forefoot position before faster elastic work.',
          cues: [
            'Move over the big toe without letting the arch collapse.',
            'Keep the heel centered rather than rolling outward.',
            'Finish tall with pressure through the first two toes.',
          ],
          equipment: 'Wall or support',
          regression: 'Use two-leg calf holds.',
          progression: 'Use a single-leg hold without hand support.',
        ),
        _DrillTemplate(
          name: 'Front-Rack March',
          prescriptions: [
            '3 × 20 m each side',
            '3 × 30 m each side',
            '4 × 20 m, heavier',
            '2 × 20 m each side',
          ],
          purpose:
              'Load gait while resisting rotation and maintaining clean single-leg stance.',
          cues: [
            'Keep the weight close and the wrist neutral.',
            'Pause briefly over each stance leg.',
            'Do not let the loaded side pull the ribs down or forward.',
          ],
          equipment: 'Kettlebell or dumbbell',
          regression: 'Use a suitcase carry march.',
          progression: 'Use an offset double-rack carry.',
        ),
        _DrillTemplate(
          name: 'Contralateral Step-Up to Knee Drive',
          prescriptions: [
            '3 × 6 each side',
            '3 × 8 each side',
            '4 × 6 each side, heavier',
            '2 × 6 each side',
          ],
          purpose:
              'Develop vertical force through one leg and finish in a stable gait-like position.',
          cues: [
            'Drive through the full foot on the box.',
            'Avoid pushing off aggressively with the trailing foot.',
            'Finish tall with the opposite knee and arm forward.',
          ],
          equipment: 'Low box and optional dumbbell',
          regression: 'Use a lower step or body weight.',
          progression: 'Increase load before box height.',
        ),
        _DrillTemplate(
          name: 'Rear-Foot-Elevated Split Squat',
          prescriptions: [
            '3 × 6 each side at controlled tempo',
            '3 × 8 each side',
            '4 × 6 each side with load',
            '2 × 6 each side',
          ],
          purpose:
              'Increase unilateral leg strength and hip range while the pelvis remains controlled.',
          cues: [
            'Use a stance long enough to keep the front heel down.',
            'Descend vertically and let the front knee travel naturally.',
            'Keep the torso long rather than collapsing forward.',
          ],
          equipment: 'Bench and optional dumbbells',
          regression: 'Use a standard split squat.',
          progression:
              'Add contralateral load or a small front-foot elevation.',
        ),
        _DrillTemplate(
          name: 'Single-Leg RDL to Row',
          prescriptions: [
            '3 × 6 each side',
            '3 × 8 each side',
            '4 × 6 each side with moderate load',
            '2 × 6 each side',
          ],
          purpose:
              'Combine hip control, balance, and pulling strength across the diagonal chain.',
          cues: [
            'Own the hinge before pulling.',
            'Row without opening the pelvis.',
            'Return to standing through the stance hip.',
          ],
          equipment: 'Cable, band, or dumbbell',
          regression: 'Use a kickstand RDL and row.',
          progression: 'Use less hand support or more load.',
        ),
        _DrillTemplate(
          name: 'Tall-Kneeling Pallof Arc',
          prescriptions: [
            '3 × 6 arcs each direction',
            '3 × 8 arcs each direction',
            '4 × 6 arcs with more tension',
            '2 × 6 arcs each direction',
          ],
          purpose:
              'Resist unwanted rotation while the arms travel through a larger arc.',
          cues: [
            'Keep the glutes lightly engaged and ribs stacked.',
            'Move the arms without letting the cable turn the torso.',
            'Breathe continuously.',
          ],
          equipment: 'Cable or resistance band',
          regression: 'Use a standard Pallof press.',
          progression: 'Perform from a split stance.',
        ),
      ],
    ),
    _SessionTemplate(
      id: 'elastic-rotation',
      day: 'WEDNESDAY',
      name: 'Rotational Force Transfer',
      summary:
          'Hip-to-trunk rotation, medicine-ball intent, diagonal pulling, and pressing.',
      durationMinutes: 50,
      qualities: [
        AthleticQuality.rotation,
        AthleticQuality.trunkControl,
        AthleticQuality.unilateralStrength,
        AthleticQuality.elasticStrength,
      ],
      drills: [
        _DrillTemplate(
          name: 'Hip Airplane with Support',
          prescriptions: [
            '2 × 5 each side',
            '3 × 5 each side',
            '3 × 6 each side with less support',
            '2 × 4 each side',
          ],
          purpose:
              'Control pelvic rotation over a stable stance leg through a usable hip range.',
          cues: [
            'Keep the stance foot rooted.',
            'Rotate the pelvis around the hip instead of twisting the knee.',
            'Use only the range you can reverse smoothly.',
          ],
          equipment: 'Wall or rack for support',
          regression: 'Use a kickstand stance.',
          progression: 'Reduce hand support.',
        ),
        _DrillTemplate(
          name: 'Rotational Medicine-Ball Scoop Toss',
          prescriptions: [
            '4 × 4 each side at 70%',
            '5 × 4 each side at 75%',
            '5 × 3 each side at high safe intent',
            '3 × 4 each side at 70%',
          ],
          purpose:
              'Produce rotational force from the floor through the hips and trunk into the arms.',
          cues: [
            'Load the back hip before turning.',
            'Drive the floor away and let the hips lead.',
            'Finish balanced instead of falling toward the wall.',
          ],
          equipment: 'Light medicine ball and solid wall',
          regression: 'Use a banded rotational punch without release.',
          progression: 'Use a small approach step before the toss.',
        ),
        _DrillTemplate(
          name: 'Split-Stance Cable Chop',
          prescriptions: [
            '3 × 8 each side',
            '3 × 10 each side',
            '4 × 8 each side with more load',
            '2 × 8 each side',
          ],
          purpose:
              'Control high-to-low diagonal force while the legs maintain a split stance.',
          cues: [
            'Rotate through the trunk without collapsing the front knee inward.',
            'Keep both feet connected to the floor.',
            'Finish with the hands outside the lead hip.',
          ],
          equipment: 'Cable or resistance band',
          regression: 'Use a half-kneeling chop.',
          progression: 'Add a small pivot through the back foot.',
        ),
        _DrillTemplate(
          name: 'Landmine Rotation',
          prescriptions: [
            '3 × 6 each side',
            '3 × 8 each side',
            '4 × 6 each side with moderate load',
            '2 × 6 each side',
          ],
          purpose:
              'Integrate the hips, trunk, and shoulders through a controlled rotational arc.',
          cues: [
            'Turn the hips and feet together.',
            'Keep the bar close enough to control.',
            'Do not force the range with the lower back.',
          ],
          equipment: 'Landmine or securely anchored barbell',
          regression: 'Use a banded rotational press.',
          progression: 'Increase speed before adding substantial load.',
        ),
        _DrillTemplate(
          name: 'One-Arm Cable Press with Step',
          prescriptions: [
            '3 × 6 each side',
            '3 × 8 each side',
            '4 × 6 each side with faster intent',
            '2 × 6 each side',
          ],
          purpose:
              'Link a contralateral step to horizontal pressing and controlled trunk rotation.',
          cues: [
            'Step and press as one coordinated action.',
            'Keep the shoulder away from the ear.',
            'Return under control instead of letting the cable pull you back.',
          ],
          equipment: 'Cable or resistance band',
          regression: 'Use a static split-stance press.',
          progression: 'Use a more dynamic step-in.',
        ),
        _DrillTemplate(
          name: 'Offset Farmer Carry',
          prescriptions: [
            '3 × 25 m each arrangement',
            '3 × 35 m each arrangement',
            '4 × 25 m, heavier',
            '2 × 25 m each arrangement',
          ],
          purpose:
              'Challenge the trunk to manage asymmetrical loading during gait.',
          cues: [
            'Keep the ribs over the pelvis.',
            'Walk naturally without shortening one side.',
            'Use quiet, controlled steps.',
          ],
          equipment: 'Two unequal dumbbells or kettlebells',
          regression: 'Use a single suitcase carry.',
          progression: 'Increase the load difference.',
        ),
      ],
    ),
    _SessionTemplate(
      id: 'elastic-deceleration',
      day: 'FRIDAY',
      name: 'Elastic Contacts & Braking',
      summary:
          'Pogos, bounds, lateral landing, drop-to-sprint, and stronger deceleration.',
      durationMinutes: 47,
      qualities: [
        AthleticQuality.elasticStrength,
        AthleticQuality.deceleration,
        AthleticQuality.changeOfDirection,
        AthleticQuality.acceleration,
      ],
      drills: [
        _DrillTemplate(
          name: 'Pogo Series: In-Place to Forward',
          prescriptions: [
            '3 × 20 in-place + 2 × 10 m forward',
            '4 × 20 in-place + 3 × 10 m forward',
            '4 × 15 fast + 3 × 12 m forward',
            '2 × 20 in-place + 2 × 10 m forward',
          ],
          purpose:
              'Build rhythmic ankle stiffness and short ground contacts in place and through space.',
          cues: [
            'Stay tall and let the ankles do most of the work.',
            'Keep contacts under the center of mass.',
            'Stop the set when rhythm or posture changes.',
          ],
          equipment: 'Open floor',
          regression: 'Use low two-leg hops in place.',
          progression: 'Add a low single-leg pogo series.',
        ),
        _DrillTemplate(
          name: 'Skater Bound to Stick',
          prescriptions: [
            '3 × 4 each side',
            '4 × 4 each side',
            '4 × 5 each side with greater distance',
            '2 × 4 each side',
          ],
          purpose:
              'Produce lateral force and absorb it on one leg with pelvis and trunk control.',
          cues: [
            'Push the floor away laterally.',
            'Land over the whole foot with the hip loaded.',
            'Hold before the next repetition.',
          ],
          equipment: 'Open floor',
          regression: 'Use a lateral step-to-stick.',
          progression: 'Link two bounds before the stick.',
        ),
        _DrillTemplate(
          name: 'Low Drop Landing to 5 m Acceleration',
          prescriptions: [
            '4 × 3',
            '5 × 3',
            '6 × 2 at high safe intent',
            '3 × 3',
          ],
          purpose:
              'Transition from vertical force absorption into a quick, organized acceleration.',
          cues: [
            'Land quietly and stabilize before leaving.',
            'Project forward with the first two steps.',
            'Take full recovery between repetitions.',
          ],
          equipment: 'Low step and 5–8 m of space',
          regression: 'Use a snap-down before accelerating.',
          progression: 'Reduce the pause between landing and exit.',
        ),
        _DrillTemplate(
          name: 'Three-Step Deceleration',
          prescriptions: [
            '5 × 10 m at 70%',
            '6 × 12 m at 75%',
            '6 × 12 m at 80%',
            '4 × 10 m at 70%',
          ],
          purpose:
              'Teach gradual, powerful braking over several steps instead of a single reaching stop.',
          cues: [
            'Lower the hips before the final stop.',
            'Keep the feet under the body as cadence increases.',
            'Finish with the chest and pelvis controlled.',
          ],
          equipment: '12–15 m lane and markers',
          regression: 'Use a slower approach or longer braking zone.',
          progression: 'Shorten the braking zone slightly.',
        ),
        _DrillTemplate(
          name: 'Lateral Shuffle to Crossover Exit',
          prescriptions: [
            '3 × 3 each direction',
            '4 × 3 each direction',
            '4 × 4 each direction at faster intent',
            '2 × 3 each direction',
          ],
          purpose:
              'Link lateral braking to an efficient crossover step and forward re-acceleration.',
          cues: [
            'Load the outside hip before crossing over.',
            'Push rather than reach with the exit leg.',
            'Keep the first exit steps low and directed.',
          ],
          equipment: 'Markers and 6–8 m of space',
          regression: 'Use a planned lateral shuffle and stop.',
          progression: 'Add a coach or partner direction cue.',
        ),
        _DrillTemplate(
          name: 'Backward Sled Drag or Incline March',
          prescriptions: [
            '5 × 20 m, moderate effort',
            '6 × 20 m',
            '6 × 25 m, strong but smooth',
            '4 × 20 m, easy',
          ],
          purpose:
              'Build leg capacity with low eccentric stress after the higher-skill elastic work.',
          cues: [
            'Use short, continuous steps.',
            'Keep the torso tall and knees tracking over the toes.',
            'Choose a load that does not stop the rhythm.',
          ],
          equipment: 'Sled or incline treadmill',
          regression: 'Use backward walking on flat ground.',
          progression: 'Add distance before load.',
        ),
      ],
    ),
    _SessionTemplate(
      id: 'elastic-speed',
      day: 'SATURDAY',
      name: 'Acceleration & Multidirectional Capacity',
      summary:
          'Short sprints, curved running, planned cuts, crawling, and repeat-effort work.',
      durationMinutes: 50,
      qualities: [
        AthleticQuality.acceleration,
        AthleticQuality.changeOfDirection,
        AthleticQuality.gait,
        AthleticQuality.capacity,
      ],
      drills: [
        _DrillTemplate(
          name: 'A-Skip + Straight-Leg Run',
          prescriptions: [
            '2 × 15 m each drill',
            '3 × 15 m each drill',
            '3 × 20 m each drill',
            '2 × 15 m each drill',
          ],
          purpose:
              'Prepare sprint rhythm, front-side mechanics, and active ground contact.',
          cues: [
            'Stay tall with relaxed shoulders.',
            'Strike down beneath the hips.',
            'Keep the rhythm light and elastic.',
          ],
          equipment: '20 m lane',
          regression: 'Use A-march and ankle dribbles.',
          progression: 'Increase rhythm without overstriding.',
        ),
        _DrillTemplate(
          name: 'Two-Point Start',
          prescriptions: [
            '6 × 10 m at 75%',
            '8 × 10 m at 80%',
            '6 × 15 m at 85%',
            '4 × 10 m at 75%',
          ],
          purpose:
              'Develop a repeatable acceleration start with strong projection and gradual rise.',
          cues: [
            'Load the front leg and keep the shin angled forward.',
            'Push through the ground for the first steps.',
            'Rise gradually instead of standing up immediately.',
          ],
          equipment: '15 m lane',
          regression: 'Use a falling start.',
          progression: 'Use varied lead legs or a light visual cue.',
        ),
        _DrillTemplate(
          name: 'Curve Run at Controlled Speed',
          prescriptions: [
            '4 × 15 m each direction at 65%',
            '5 × 15 m each direction at 70%',
            '5 × 20 m each direction at 75%',
            '3 × 15 m each direction at 65%',
          ],
          purpose:
              'Expose the body to curved locomotion and inside-outside leg demands without maximal speed.',
          cues: [
            'Lean the whole body slightly into the curve.',
            'Keep the feet cycling under the hips.',
            'Use a smooth radius rather than a sharp cut.',
          ],
          equipment: 'Markers forming a wide arc',
          regression: 'Walk or jog a larger curve.',
          progression: 'Use a slightly tighter curve.',
        ),
        _DrillTemplate(
          name: 'Planned 45-Degree Cut',
          prescriptions: [
            '4 × 3 each side at 65%',
            '5 × 3 each side at 70%',
            '5 × 3 each side at 75–80%',
            '3 × 3 each side at 65%',
          ],
          purpose:
              'Learn to lower, plant, and redirect at a manageable angle before reactive cutting.',
          cues: [
            'Decelerate before the plant step.',
            'Place the foot close enough to the body to push away.',
            'Direct the first exit step along the new line.',
          ],
          equipment: 'Three markers',
          regression: 'Use a walking or jogging approach.',
          progression: 'Increase approach speed slightly.',
        ),
        _DrillTemplate(
          name: 'Lateral Bear Crawl',
          prescriptions: [
            '3 × 8 m each direction',
            '3 × 10 m each direction',
            '4 × 8 m each direction',
            '2 × 8 m each direction',
          ],
          purpose:
              'Build lateral cross-body coordination and shoulder-hip control under low impact.',
          cues: [
            'Move the hands and feet in small steps.',
            'Keep the hips level and knees close to the floor.',
            'Do not let the feet cross.',
          ],
          equipment: 'Open floor',
          regression: 'Use a quadruped lateral step without hovering.',
          progression: 'Add a direction change on a cue.',
        ),
        _DrillTemplate(
          name: 'Repeat-Effort Shuttle',
          prescriptions: [
            '2 sets of 4 × 15 sec, 45 sec easy',
            '2 sets of 5 × 15 sec, 40 sec easy',
            '3 sets of 4 × 15 sec, 35 sec easy',
            '2 sets of 3 × 15 sec, 50 sec easy',
          ],
          purpose:
              'Build the ability to repeat moderate athletic efforts while preserving movement quality.',
          cues: [
            'Stay below all-out speed.',
            'Use controlled turns and smooth acceleration.',
            'Stop the set if mechanics deteriorate.',
          ],
          equipment: '10–15 m lane or low-impact machine',
          regression: 'Use bike or incline-walk intervals.',
          progression: 'Add one repetition before increasing speed.',
        ),
      ],
    ),
  ];

  static const _integrationSessions = <_SessionTemplate>[
    _SessionTemplate(
      id: 'integration-acceleration',
      day: 'MONDAY',
      name: 'Acceleration & Unilateral Power',
      summary:
          'High-quality starts, resisted projection, unilateral force, and gait-linked trunk control.',
      durationMinutes: 52,
      qualities: [
        AthleticQuality.acceleration,
        AthleticQuality.unilateralStrength,
        AthleticQuality.gait,
        AthleticQuality.trunkControl,
      ],
      drills: [
        _DrillTemplate(
          name: 'Dribble Run Progression',
          prescriptions: [
            '2 × 15 m ankle + 2 × 15 m knee-height dribbles',
            '3 × 15 m each height',
            '3 × 20 m blended dribbles',
            '2 × 15 m each height',
          ],
          purpose:
              'Refine foot strike beneath the body and smoothly progress sprint limb speed.',
          cues: [
            'Keep the pelvis tall and shoulders relaxed.',
            'Cycle the feet down and back under the hips.',
            'Increase height only while the rhythm stays clean.',
          ],
          equipment: '20 m lane',
          regression: 'Use A-march and low dribbles.',
          progression: 'Blend directly into a short acceleration.',
        ),
        _DrillTemplate(
          name: 'Resisted March to Sprint',
          prescriptions: [
            '4 rounds: 8 resisted steps + 8 m sprint',
            '5 rounds: 8 resisted steps + 10 m sprint',
            '6 rounds: 6 resisted steps + 12 m sprint',
            '3 rounds: 8 resisted steps + 8 m sprint',
          ],
          purpose:
              'Reinforce force projection before an unresisted acceleration.',
          cues: [
            'Keep a straight body line and push backward through the ground.',
            'Do not let the resistance shorten posture.',
            'Release into fast, low first steps.',
          ],
          equipment: 'Light sled, band partner, or hill',
          regression: 'Use wall marches followed by a falling start.',
          progression: 'Reduce resistance and increase sprint intent.',
        ),
        _DrillTemplate(
          name: 'Three-Point Start',
          prescriptions: [
            '6 × 10 m at 80%',
            '8 × 10 m at 85%',
            '6 × 15 m at 90% with full recovery',
            '4 × 10 m at 75–80%',
          ],
          purpose:
              'Express horizontal force from a stable start while preserving the acceleration posture developed earlier.',
          cues: [
            'Set the hips above the shoulders without crowding the line.',
            'Push through both legs, then strike back under the body.',
            'Rest long enough for every repetition to remain fast.',
          ],
          equipment: '15 m lane',
          regression: 'Use a two-point or falling start.',
          progression: 'Use a light external start cue.',
        ),
        _DrillTemplate(
          name: 'Explosive Step-Up',
          prescriptions: [
            '4 × 4 each side, body weight or light load',
            '4 × 5 each side',
            '5 × 3 each side at high intent',
            '3 × 4 each side',
          ],
          purpose:
              'Develop rapid unilateral force into a stable knee-drive finish.',
          cues: [
            'Push through the whole working foot.',
            'Drive up fast and own the top position.',
            'Step down under control.',
          ],
          equipment: 'Low box and optional light dumbbells',
          regression: 'Use a controlled step-up.',
          progression: 'Add a small hop only if landing control is excellent.',
        ),
        _DrillTemplate(
          name: 'Kickstand RDL to Contralateral Press',
          prescriptions: [
            '3 × 6 each side',
            '3 × 8 each side',
            '4 × 6 each side with moderate load',
            '2 × 6 each side',
          ],
          purpose:
              'Link hip extension to opposite-arm force while the trunk resists unwanted rotation.',
          cues: [
            'Load the front hip during the hinge.',
            'Stand and press as one connected action.',
            'Keep the pelvis and lower ribs controlled.',
          ],
          equipment: 'Cable, band, or dumbbell',
          regression: 'Separate the hinge and press.',
          progression: 'Use a true single-leg stance.',
        ),
        _DrillTemplate(
          name: 'Heavy Suitcase Carry',
          prescriptions: [
            '4 × 20 m each side',
            '4 × 25 m each side',
            '5 × 20 m each side, heavy but controlled',
            '3 × 20 m each side',
          ],
          purpose:
              'Build high-tension trunk control that carries into unilateral force production.',
          cues: [
            'Stand tall without leaning or shrugging.',
            'Keep normal step width and arm swing.',
            'End the set before grip changes posture.',
          ],
          equipment: 'Heavy dumbbell or kettlebell',
          regression: 'Use a moderate load.',
          progression: 'Increase load while keeping the same walk speed.',
        ),
      ],
    ),
    _SessionTemplate(
      id: 'integration-rotation',
      day: 'WEDNESDAY',
      name: 'Integrated Rotation & Power',
      summary:
          'Step-behind throws, dynamic chops, pressing, pulling, and diagonal force transfer.',
      durationMinutes: 50,
      qualities: [
        AthleticQuality.rotation,
        AthleticQuality.elasticStrength,
        AthleticQuality.trunkControl,
        AthleticQuality.unilateralStrength,
      ],
      drills: [
        _DrillTemplate(
          name: 'Lunge with Thoracic Rotation',
          prescriptions: [
            '2 × 5 each side',
            '2 × 6 each side',
            '3 × 5 each side with light reach load',
            '2 × 4 each side',
          ],
          purpose:
              'Prepare hip motion and upper-back rotation in a split-stance pattern.',
          cues: [
            'Keep the front foot fully connected.',
            'Rotate through the upper back, not the front knee.',
            'Return to center before stepping out.',
          ],
          equipment: 'Optional light medicine ball',
          regression: 'Use a static split stance.',
          progression: 'Use a walking lunge with controlled rotation.',
        ),
        _DrillTemplate(
          name: 'Step-Behind Rotational Medicine-Ball Throw',
          prescriptions: [
            '4 × 3 each side at 75%',
            '5 × 3 each side at 80%',
            '6 × 2 each side at high safe intent',
            '3 × 3 each side at 70%',
          ],
          purpose:
              'Integrate an approach step, hip turn, and explosive rotational release.',
          cues: [
            'Use the step to load the rear hip.',
            'Sequence the floor, hips, trunk, then arms.',
            'Finish balanced and let the rear foot pivot.',
          ],
          equipment: 'Light medicine ball and solid wall',
          regression: 'Use a stationary scoop toss.',
          progression: 'Increase approach rhythm, not ball weight.',
        ),
        _DrillTemplate(
          name: 'Dynamic Cable Lift with Pivot',
          prescriptions: [
            '3 × 6 each side',
            '3 × 8 each side',
            '4 × 6 each side at faster intent',
            '2 × 6 each side',
          ],
          purpose:
              'Train low-to-high diagonal force with coordinated foot and hip rotation.',
          cues: [
            'Pivot through the foot instead of twisting the knee.',
            'Keep the arms connected to the trunk.',
            'Finish tall without overextending the back.',
          ],
          equipment: 'Cable or resistance band',
          regression: 'Use a half-kneeling lift.',
          progression: 'Use a small step into the lift.',
        ),
        _DrillTemplate(
          name: 'Landmine Push-Press in Split Stance',
          prescriptions: [
            '4 × 4 each side',
            '4 × 5 each side',
            '5 × 3 each side at high intent',
            '3 × 4 each side',
          ],
          purpose:
              'Transfer force from the legs through the trunk into an angled press.',
          cues: [
            'Dip vertically with pressure through both feet.',
            'Drive the bar forward and up as the legs extend.',
            'Finish with the ribs controlled and shoulder blade reaching.',
          ],
          equipment: 'Landmine or heavy resistance band',
          regression: 'Use a strict split-stance landmine press.',
          progression: 'Increase intent before adding load.',
        ),
        _DrillTemplate(
          name: 'One-Arm Row with Contralateral Step-Back',
          prescriptions: [
            '3 × 6 each side',
            '3 × 8 each side',
            '4 × 6 each side with more load',
            '2 × 6 each side',
          ],
          purpose:
              'Coordinate a step, hip load, and opposite-arm pull across the posterior diagonal chain.',
          cues: [
            'Step back as the arm reaches.',
            'Pull while driving through the front foot.',
            'Keep the pelvis level during the return.',
          ],
          equipment: 'Cable or resistance band',
          regression: 'Use a static split-stance row.',
          progression: 'Use a faster but controlled step rhythm.',
        ),
        _DrillTemplate(
          name: 'Dead Bug Pullover with Cross-Body Tension',
          prescriptions: [
            '3 × 5 each side',
            '3 × 6 each side',
            '4 × 5 each side with light load',
            '2 × 5 each side',
          ],
          purpose:
              'Maintain trunk position while the arms move overhead and the opposite hip remains active.',
          cues: [
            'Exhale before the arms travel overhead.',
            'Keep the ribs heavy and move only through the available range.',
            'Maintain gentle pressure between the opposite hand and knee.',
          ],
          equipment: 'Light dumbbell or band',
          regression: 'Use an unloaded dead bug.',
          progression: 'Increase lever length or light resistance.',
        ),
      ],
    ),
    _SessionTemplate(
      id: 'integration-change-direction',
      day: 'FRIDAY',
      name: 'Reactive Braking & Change of Direction',
      summary:
          'Landing stiffness, approach braking, 45- and 90-degree cuts, and simple reaction cues.',
      durationMinutes: 48,
      qualities: [
        AthleticQuality.elasticStrength,
        AthleticQuality.deceleration,
        AthleticQuality.changeOfDirection,
        AthleticQuality.trunkControl,
      ],
      drills: [
        _DrillTemplate(
          name: 'Single-Leg Pogo to Stick',
          prescriptions: [
            '3 × 8 contacts + stick each side',
            '4 × 8 contacts + stick each side',
            '4 × 10 fast contacts + stick each side',
            '2 × 8 contacts + stick each side',
          ],
          purpose:
              'Develop single-leg elastic rhythm and the ability to stop that rhythm in a stable position.',
          cues: [
            'Keep the contacts small and under the hip.',
            'Maintain a tall trunk and stable foot.',
            'Finish by absorbing quietly and holding balance.',
          ],
          equipment: 'Open floor',
          regression: 'Use two-leg pogos or assisted single-leg contacts.',
          progression: 'Travel slightly forward before the stick.',
        ),
        _DrillTemplate(
          name: 'Lateral Bound to Crossover Sprint',
          prescriptions: [
            '4 × 3 each side',
            '5 × 3 each side',
            '6 × 2 each side at high safe intent',
            '3 × 3 each side',
          ],
          purpose:
              'Link lateral force production and absorption to a rapid forward exit.',
          cues: [
            'Land on the outside leg with the hip loaded.',
            'Push through the planted foot into the crossover step.',
            'Direct the first sprint steps forward, not upward.',
          ],
          equipment: '8–10 m lane',
          regression: 'Use a lateral step-to-stick before the exit.',
          progression: 'Reduce the stabilization pause.',
        ),
        _DrillTemplate(
          name: 'Approach Deceleration into 45-Degree Cut',
          prescriptions: [
            '4 × 3 each side at 70%',
            '5 × 3 each side at 75–80%',
            '5 × 3 each side at 85%',
            '3 × 3 each side at 70%',
          ],
          purpose:
              'Manage approach speed, lower the center of mass, and redirect efficiently.',
          cues: [
            'Use several braking steps before the plant.',
            'Keep the plant foot close enough to push from.',
            'Point the chest and first exit step along the new direction.',
          ],
          equipment: 'Markers and 12–15 m of space',
          regression: 'Use a slower approach or wider angle.',
          progression: 'Increase approach speed gradually.',
        ),
        _DrillTemplate(
          name: 'Planned 90-Degree Cut',
          prescriptions: [
            '4 × 2 each side at 65%',
            '5 × 2 each side at 70%',
            '5 × 3 each side at 75–80%',
            '3 × 2 each side at 65%',
          ],
          purpose:
              'Develop stronger braking and reorientation for a sharper direction change.',
          cues: [
            'Brake before the corner instead of reaching at it.',
            'Load the outside hip and keep the trunk inside the base of support.',
            'Push through the new line with short first steps.',
          ],
          equipment: 'Three markers',
          regression: 'Use a rounded turn or walking approach.',
          progression: 'Use a slightly faster approach.',
        ),
        _DrillTemplate(
          name: 'Color or Point Reaction Shuffle',
          prescriptions: [
            '5 × 12-sec bouts, 60-sec rest',
            '6 × 12-sec bouts, 55-sec rest',
            '6 × 15-sec bouts, 60-sec rest',
            '4 × 10-sec bouts, 60-sec rest',
          ],
          purpose:
              'Add a simple perceptual cue while preserving the braking mechanics learned in planned drills.',
          cues: [
            'React after the cue; do not guess.',
            'Use short steps to organize before changing direction.',
            'Keep the bout brief enough for quality movement.',
          ],
          equipment: 'Partner, phone cue, or colored markers',
          regression: 'Use a known sequence.',
          progression: 'Add one extra cue location.',
        ),
        _DrillTemplate(
          name: 'Sled Push with Controlled Stop',
          prescriptions: [
            '5 × 15 m, moderate load',
            '6 × 15 m',
            '6 × 20 m, strong intent',
            '4 × 15 m, easy',
          ],
          purpose:
              'Build horizontal leg drive and conditioning without high running speed.',
          cues: [
            'Keep a long line from head through the stance leg.',
            'Use strong, continuous steps.',
            'Decelerate the sled under control at the finish.',
          ],
          equipment: 'Sled or steep incline walk',
          regression: 'Use a light sled or incline march.',
          progression: 'Add distance before load.',
        ),
      ],
    ),
    _SessionTemplate(
      id: 'integration-capacity',
      day: 'SATURDAY',
      name: 'Speed Integration & Repeat Effort',
      summary:
          'Short acceleration, controlled top-speed exposure, curved running, and repeat-sprint quality.',
      durationMinutes: 52,
      qualities: [
        AthleticQuality.acceleration,
        AthleticQuality.gait,
        AthleticQuality.changeOfDirection,
        AthleticQuality.capacity,
      ],
      drills: [
        _DrillTemplate(
          name: 'Sprint Drill Blend',
          prescriptions: [
            '2 rounds: A-skip, dribble, 10 m build-up',
            '3 rounds: A-skip, dribble, 15 m build-up',
            '3 rounds: dribble directly into 15 m build-up',
            '2 rounds: A-skip, dribble, 10 m build-up',
          ],
          purpose:
              'Link technical drills into relaxed running without a sudden jump in intensity.',
          cues: [
            'Keep the shoulders, jaw, and hands relaxed.',
            'Let stride length grow naturally as speed rises.',
            'Stop increasing speed if the foot lands far ahead.',
          ],
          equipment: '20–25 m lane',
          regression: 'Use marches and low skips only.',
          progression: 'Lengthen the build-up slightly.',
        ),
        _DrillTemplate(
          name: '10 m Acceleration + 10 m Build',
          prescriptions: [
            '5 reps at 75–80%, 90-sec rest',
            '6 reps at 80–85%, 90-sec rest',
            '6 reps at 85–90%, 2-min rest',
            '4 reps at 70–75%, full recovery',
          ],
          purpose:
              'Transition from acceleration into upright running while retaining posture and rhythm.',
          cues: [
            'Push during the first 10 m, then rise gradually.',
            'Run tall and relaxed through the build zone.',
            'Use complete recovery; this is speed practice, not conditioning.',
          ],
          equipment: '25 m lane',
          regression: 'Use 10 m accelerations only.',
          progression: 'Extend the build zone to 15 m.',
        ),
        _DrillTemplate(
          name: 'Curve-to-Straight Run',
          prescriptions: [
            '4 × 20 m each direction at 70%',
            '5 × 20 m each direction at 75%',
            '5 × 25 m each direction at 80%',
            '3 × 20 m each direction at 65–70%',
          ],
          purpose:
              'Integrate curved locomotion with a smooth transition into straight-line running.',
          cues: [
            'Lean the body into the curve as one unit.',
            'Exit the curve gradually rather than snapping upright.',
            'Keep the feet cycling under the hips.',
          ],
          equipment: 'Markers forming a curve and straight exit',
          regression: 'Jog a wider curve.',
          progression: 'Use a slightly tighter curve or faster exit.',
        ),
        _DrillTemplate(
          name: '5-0-5 Technique Rehearsal',
          prescriptions: [
            '4 × 2 each side at 70%',
            '5 × 2 each side at 75%',
            '5 × 2 each side at 80–85%',
            '3 × 2 each side at 65–70%',
          ],
          purpose:
              'Practice the approach, braking, plant, and re-acceleration pattern used in the 5-0-5 field measure.',
          cues: [
            'Prepare the turn before the line.',
            'Use the plant to push away, not to reach and collapse.',
            'Accelerate through the finish instead of standing up.',
          ],
          equipment: 'Markers and measured 10 m lane',
          regression: 'Use a shorter approach and submaximal speed.',
          progression:
              'Increase approach speed while retaining the same turn mechanics.',
        ),
        _DrillTemplate(
          name: 'Repeat Sprint Cluster',
          prescriptions: [
            '2 clusters of 4 × 10 m, 25 sec between reps, 3 min between clusters',
            '2 clusters of 5 × 10 m, 25 sec between reps',
            '3 clusters of 4 × 10 m, 20 sec between reps, full cluster recovery',
            '2 clusters of 3 × 10 m, 30 sec between reps',
          ],
          purpose:
              'Train repeated acceleration while monitoring whether speed and mechanics remain stable.',
          cues: [
            'Use about 85% effort, not an all-out first repetition.',
            'Stop the cluster if times or mechanics fall sharply.',
            'Walk and breathe between repetitions.',
          ],
          equipment: '10–15 m lane and optional stopwatch',
          regression: 'Use bike sprints or longer recovery.',
          progression:
              'Add one repetition only when quality remains consistent.',
        ),
        _DrillTemplate(
          name: 'Downshift Walk + Breathing Reset',
          prescriptions: [
            '6–8 min easy walk + 3 slow breaths per side',
            '8 min easy walk + 4 slow breaths per side',
            '8–10 min easy walk + 4 slow breaths per side',
            '6 min easy walk + 3 slow breaths per side',
          ],
          purpose:
              'Return breathing and gait rhythm toward baseline after the highest-intent session.',
          cues: [
            'Let the arms swing and steps become quiet.',
            'Extend the exhale without forcing it.',
            'Finish feeling recovered rather than depleted.',
          ],
          equipment: 'Open walking space',
          regression: 'Use seated breathing after a shorter walk.',
          progression: 'No progression needed; recovery quality is the goal.',
        ),
      ],
    ),
  ];
}
