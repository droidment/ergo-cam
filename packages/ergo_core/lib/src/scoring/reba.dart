import 'dart:math' as math;

import '../models/joint_angles.dart';
import '../models/session_inputs.dart';
import 'angle_bands.dart';
import 'reba_tables.dart';

// Angle bands per docs/SCORING.md. "Upright"/"neutral" is ±5° so camera noise
// doesn't add points; exact boundary values follow the REBA sheet.

/// Trunk: ext >20 → 3 · ext 5–20 → 2 · ±5 → 1 · flex 5–20 → 2 · 20–60 → 3 · >60 → 4.
const rebaTrunkBands = AngleBands(
  cuts: [-20, -5, 5, 20, 60],
  lowerInclusive: [false, false, true, true, true],
  scores: [3, 2, 1, 2, 3, 4],
);

/// Neck: ext >5 → 2 · −5 to 20 flex → 1 · >20 flex → 2.
const rebaNeckBands = AngleBands(
  cuts: [-5, 20],
  lowerInclusive: [false, true],
  scores: [2, 1, 2],
);

/// Upper arm: ext >20 → 2 · ±20 → 1 · 20–45 → 2 · 45–90 → 3 · >90 → 4.
const rebaUpperArmBands = AngleBands(
  cuts: [-20, 20, 45, 90],
  lowerInclusive: [false, true, true, true],
  scores: [2, 1, 2, 3, 4],
);

/// Lower arm (elbow flexion): 60–100 → 1, otherwise 2.
const rebaLowerArmBands = AngleBands(
  cuts: [60, 100],
  lowerInclusive: [false, true],
  scores: [2, 1, 2],
);

/// Knee adjustment to the legs score: <30 → 0 · 30–60 → +1 · >60 → +2.
const rebaKneeBands = AngleBands(
  cuts: [30, 60],
  lowerInclusive: [false, true],
  scores: [0, 1, 2],
);

enum RebaRisk {
  negligible('Negligible'),
  low('Low'),
  medium('Medium'),
  high('High'),
  veryHigh('Very high');

  const RebaRisk(this.label);
  final String label;

  static RebaRisk forScore(int score) => switch (score) {
    <= 1 => negligible,
    <= 3 => low,
    <= 7 => medium,
    <= 10 => high,
    _ => veryHigh,
  };
}

/// Band indices for each angle that REBA scores. The stateful scorer feeds
/// these through hysteresis; the pure path uses raw bands.
class RebaBands {
  const RebaBands({
    required this.trunk,
    required this.neck,
    required this.knee,
    required this.nearUpperArm,
    required this.nearLowerArm,
    this.farUpperArm,
    this.farLowerArm,
  });

  factory RebaBands.raw(JointAngles a) => RebaBands(
    trunk: rebaTrunkBands.bandOf(a.trunkFlexion),
    neck: rebaNeckBands.bandOf(a.neckFlexion),
    knee: rebaKneeBands.bandOf(a.kneeFlexion),
    nearUpperArm: rebaUpperArmBands.bandOf(a.nearArm.upperArmFlexion),
    nearLowerArm: rebaLowerArmBands.bandOf(a.nearArm.elbowFlexion),
    farUpperArm: a.farArm == null
        ? null
        : rebaUpperArmBands.bandOf(a.farArm!.upperArmFlexion),
    farLowerArm: a.farArm == null
        ? null
        : rebaLowerArmBands.bandOf(a.farArm!.elbowFlexion),
  );

  final int trunk;
  final int neck;
  final int knee;
  final int nearUpperArm;
  final int nearLowerArm;
  final int? farUpperArm;
  final int? farLowerArm;
}

/// A full REBA assessment with every intermediate score, so the UI and the
/// report can show where the number came from.
class RebaResult {
  const RebaResult({
    required this.trunk,
    required this.neck,
    required this.legs,
    required this.tableA,
    required this.load,
    required this.scoreA,
    required this.upperArm,
    required this.lowerArm,
    required this.wrist,
    required this.tableB,
    required this.coupling,
    required this.scoreB,
    required this.tableC,
    required this.activity,
    required this.score,
    required this.scoredArm,
  });

  final int trunk;
  final int neck;
  final int legs;
  final int tableA;
  final int load;
  final int scoreA;
  final int upperArm;
  final int lowerArm;
  final int wrist;
  final int tableB;
  final int coupling;
  final int scoreB;
  final int tableC;
  final int activity;

  /// Final REBA score, 1–15.
  final int score;

  /// The arm that produced Group B (the worse one).
  final BodySide scoredArm;

  RebaRisk get risk => RebaRisk.forScore(score);

  @override
  String toString() =>
      'REBA $score (${risk.label}) — A $scoreA [trunk $trunk, neck $neck, '
      'legs $legs, tableA $tableA, load $load] · B $scoreB [ua $upperArm, '
      'la $lowerArm, wrist $wrist, tableB $tableB, coupling $coupling] · '
      'C $tableC + activity $activity';
}

/// REBA for one frame from raw angles (no hysteresis).
RebaResult scoreReba(JointAngles angles, SessionInputs inputs) =>
    scoreRebaBands(RebaBands.raw(angles), inputs, near: angles.side);

/// REBA from already-banded angles. [near] is the camera-facing side.
RebaResult scoreRebaBands(
  RebaBands b,
  SessionInputs inputs, {
  BodySide near = BodySide.left,
}) {
  // Group A
  final trunk =
      rebaTrunkBands.scores[b.trunk] + (inputs.trunkTwistOrSideBend ? 1 : 0);
  final neck =
      rebaNeckBands.scores[b.neck] + (inputs.neckTwistOrSideBend ? 1 : 0);
  final legs = rebaLegsScore(
    kneeAdjustment: rebaKneeBands.scores[b.knee],
    unilateral: inputs.unilateralStance,
    sitting: inputs.sitting,
  );
  final tableA = rebaTableALookup(neck: neck, trunk: trunk, legs: legs);
  final load = rebaLoadScore(inputs.loadKg, shock: inputs.shockOrRapidForce);
  final scoreA = tableA + load;

  // Group B — score both arms when the far one is visible; keep the worse.
  final wrist =
      (inputs.wristFlexedOver15 ? 2 : 1) +
      (inputs.wristDeviatedOrTwisted ? 1 : 0);
  _Arm arm(int uaBand, int laBand, BodySide side) {
    final ua = rebaUpperArmScore(rebaUpperArmBands.scores[uaBand], inputs);
    final la = rebaLowerArmBands.scores[laBand];
    return _Arm(
      side,
      ua,
      la,
      rebaTableBLookup(lowerArm: la, upperArm: ua, wrist: wrist),
    );
  }

  final farSide = near == BodySide.left ? BodySide.right : BodySide.left;
  var worse = arm(b.nearUpperArm, b.nearLowerArm, near);
  if (b.farUpperArm != null && b.farLowerArm != null) {
    final other = arm(b.farUpperArm!, b.farLowerArm!, farSide);
    if (other.tableB > worse.tableB) worse = other;
  }
  final coupling = inputs.coupling.score;
  final scoreB = worse.tableB + coupling;

  // Table C + activity
  final tableC = rebaTableCLookup(scoreA: scoreA, scoreB: scoreB);
  final activity = inputs.activityScore;

  return RebaResult(
    trunk: trunk,
    neck: neck,
    legs: legs,
    tableA: tableA,
    load: load,
    scoreA: scoreA,
    upperArm: worse.upperArm,
    lowerArm: worse.lowerArm,
    wrist: wrist,
    tableB: worse.tableB,
    coupling: coupling,
    scoreB: scoreB,
    tableC: tableC,
    activity: activity,
    score: math.min(tableC + activity, 15),
    scoredArm: worse.side,
  );
}

/// Legs: bilateral / walking / sitting 1, unilateral or unstable 2, plus the
/// knee adjustment. Sitting drops the >60° (+2) adjustment, per the sheet.
int rebaLegsScore({
  required int kneeAdjustment,
  required bool unilateral,
  required bool sitting,
}) {
  final base = unilateral ? 2 : 1;
  final knee = sitting && kneeAdjustment == 2 ? 0 : kneeAdjustment;
  return base + knee;
}

/// Load/force: <5 kg 0 · 5–10 kg 1 · >10 kg 2 · +1 shock or rapid force.
int rebaLoadScore(double kg, {required bool shock}) {
  final base = kg < 5 ? 0 : (kg <= 10 ? 1 : 2);
  return base + (shock ? 1 : 0);
}

/// Upper arm with adjustments: +1 abducted/rotated, +1 shoulder raised,
/// −1 supported/leaning; never below 1.
int rebaUpperArmScore(int base, SessionInputs inputs) {
  final s =
      base +
      (inputs.armAbductedOrRotated ? 1 : 0) +
      (inputs.shoulderRaised ? 1 : 0) -
      (inputs.armSupported ? 1 : 0);
  return s.clamp(1, 6);
}

class _Arm {
  const _Arm(this.side, this.upperArm, this.lowerArm, this.tableB);
  final BodySide side;
  final int upperArm;
  final int lowerArm;
  final int tableB;
}

/// REBA over a stream of frames, with ±[margin]° hysteresis on every angle
/// band so the score doesn't flicker at thresholds.
class StableRebaScorer {
  StableRebaScorer({double margin = 3})
    : _trunk = BandTracker(rebaTrunkBands, margin: margin),
      _neck = BandTracker(rebaNeckBands, margin: margin),
      _knee = BandTracker(rebaKneeBands, margin: margin),
      _nearUa = BandTracker(rebaUpperArmBands, margin: margin),
      _nearLa = BandTracker(rebaLowerArmBands, margin: margin),
      _farUa = BandTracker(rebaUpperArmBands, margin: margin),
      _farLa = BandTracker(rebaLowerArmBands, margin: margin);

  final BandTracker _trunk, _neck, _knee, _nearUa, _nearLa, _farUa, _farLa;
  BodySide? _side;

  RebaResult score(JointAngles a, SessionInputs inputs) {
    // The arms swap meaning if the person turns around.
    if (_side != null && _side != a.side) reset();
    _side = a.side;

    final far = a.farArm;
    if (far == null) {
      _farUa.reset();
      _farLa.reset();
    }
    final bands = RebaBands(
      trunk: _trunk.update(a.trunkFlexion),
      neck: _neck.update(a.neckFlexion),
      knee: _knee.update(a.kneeFlexion),
      nearUpperArm: _nearUa.update(a.nearArm.upperArmFlexion),
      nearLowerArm: _nearLa.update(a.nearArm.elbowFlexion),
      farUpperArm: far == null ? null : _farUa.update(far.upperArmFlexion),
      farLowerArm: far == null ? null : _farLa.update(far.elbowFlexion),
    );
    return scoreRebaBands(bands, inputs, near: a.side);
  }

  /// Call when tracking is lost (unscored frame, person left the view).
  void reset() {
    for (final t in [_trunk, _neck, _knee, _nearUa, _nearLa, _farUa, _farLa]) {
      t.reset();
    }
    _side = null;
  }
}
