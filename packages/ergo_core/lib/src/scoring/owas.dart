import '../models/joint_angles.dart';
import '../models/session_inputs.dart';
import 'angle_bands.dart';
import 'owas_tables.dart';

/// Back is "bent" above 20° of trunk flexion (docs/SCORING.md).
const owasBackBentBands = AngleBands(
  cuts: [20],
  lowerInclusive: [true],
  scores: [0, 1],
);

/// An arm is "at or above shoulder" from 90° of upper-arm flexion.
const owasArmRaisedBands = AngleBands(
  cuts: [90],
  lowerInclusive: [false],
  scores: [0, 1],
);

/// A knee is "bent" above 30° of flexion.
const owasKneeBentBands = AngleBands(
  cuts: [30],
  lowerInclusive: [true],
  scores: [0, 1],
);

/// OWAS posture code: back, arms, legs, load.
class OwasCode {
  const OwasCode({
    required this.back,
    required this.arms,
    required this.legs,
    required this.load,
  }) : assert(back >= 1 && back <= 4),
       assert(arms >= 1 && arms <= 3),
       assert(legs >= 1 && legs <= 7),
       assert(load >= 1 && load <= 3);

  /// 1 straight · 2 bent · 3 twisted · 4 bent and twisted.
  final int back;

  /// 1 both below shoulder · 2 one at/above · 3 both at/above.
  final int arms;

  /// 1 sitting · 2 standing, legs straight · 3 one straight leg ·
  /// 4 both knees bent · 5 one knee bent · 6 kneeling · 7 walking.
  final int legs;

  /// 1 <10 kg · 2 10–20 kg · 3 >20 kg.
  final int load;

  String get code => '$back$arms$legs$load';

  @override
  bool operator ==(Object other) => other is OwasCode && other.code == code;

  @override
  int get hashCode => code.hashCode;

  @override
  String toString() => 'OWAS $code';
}

/// OWAS result for one frame.
class OwasResult {
  const OwasResult(this.code, this.actionCategory);

  final OwasCode code;

  /// 1 no action · 2 correct in the near future · 3 as soon as possible ·
  /// 4 immediately.
  final int actionCategory;
}

/// OWAS posture code from raw angles.
///
/// 2D limits: an arm whose landmarks aren't visible counts as below shoulder
/// (it isn't guessed), so "both arms raised" needs both arms in view.
/// Sitting, kneeling, walking and standing on one leg come from [inputs].
OwasCode owasCode(JointAngles a, SessionInputs inputs) {
  final bent = owasBackBentBands.scoreOf(a.trunkFlexion) == 1;
  final twisted = inputs.trunkTwistOrSideBend;
  final back = switch ((bent, twisted)) {
    (false, false) => 1,
    (true, false) => 2,
    (false, true) => 3,
    (true, true) => 4,
  };

  final raised = [
    a.nearArm,
    ?a.farArm,
  ].where((arm) => owasArmRaisedBands.scoreOf(arm.upperArmFlexion) == 1).length;
  final arms = 1 + raised;

  final kneeBent = owasKneeBentBands.scoreOf(a.kneeFlexion) == 1;
  final legs = switch (inputs) {
    SessionInputs(sitting: true) => 1,
    SessionInputs(kneeling: true) => 6,
    SessionInputs(walking: true) => 7,
    SessionInputs(unilateralStance: true) => kneeBent ? 5 : 3,
    _ => kneeBent ? 4 : 2,
  };

  final kg = inputs.loadKg;
  final load = kg < 10 ? 1 : (kg <= 20 ? 2 : 3);

  return OwasCode(back: back, arms: arms, legs: legs, load: load);
}

/// OWAS for one frame.
OwasResult scoreOwas(JointAngles a, SessionInputs inputs) {
  final c = owasCode(a, inputs);
  return OwasResult(
    c,
    owasActionCategoryFor(
      back: c.back,
      arms: c.arms,
      legs: c.legs,
      load: c.load,
    ),
  );
}
