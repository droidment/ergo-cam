// JSON for the frame log and live stream (docs/ARCHITECTURE.md, "Wire
// format"). One object per frame; numbers rounded to keep logs small.

import '../models/frame_score.dart';
import '../models/joint_angles.dart';
import '../models/landmark.dart';
import '../models/session_inputs.dart';
import '../scoring/body_regions.dart';
import '../scoring/owas.dart';
import '../scoring/reba.dart';

double _r(double v, [int places = 2]) {
  final f = places == 2 ? 100 : (places == 1 ? 10 : 1000);
  return (v * f).roundToDouble() / f;
}

Map<String, Object?> frameScoreToJson(FrameScore f) {
  final pose = f.pose, a = f.angles, r = f.reba, o = f.owas;
  return {
    't': f.timestamp.inMilliseconds,
    'scored': f.isScored,
    if (f.unscoredReason != null) 'reason': f.unscoredReason,
    'confidence': _r(f.frameConfidence, 3),
    if (pose != null) ...{
      'w': pose.width,
      'h': pose.height,
      'lm': [
        for (final l in pose.landmarks)
          [_r(l.x, 1), _r(l.y, 1), _r(l.z, 1), _r(l.visibility, 3)],
      ],
    },
    if (a != null)
      'angles': {
        'side': a.side.name,
        'trunkFlex': _r(a.trunkFlexion),
        'neckFlex': _r(a.neckFlexion),
        'kneeFlex': _r(a.kneeFlexion),
        'upperArmNear': _r(a.nearArm.upperArmFlexion),
        'elbowNear': _r(a.nearArm.elbowFlexion),
        if (a.farArm != null) ...{
          'upperArmFar': _r(a.farArm!.upperArmFlexion),
          'elbowFar': _r(a.farArm!.elbowFlexion),
        },
      },
    if (r != null)
      'reba': {
        'score': r.score,
        'risk': r.risk.name,
        'a': r.scoreA,
        'b': r.scoreB,
        'c': r.tableC,
        'trunk': r.trunk,
        'neck': r.neck,
        'legs': r.legs,
        'tableA': r.tableA,
        'load': r.load,
        'upperArm': r.upperArm,
        'lowerArm': r.lowerArm,
        'wrist': r.wrist,
        'tableB': r.tableB,
        'coupling': r.coupling,
        'activity': r.activity,
        'arms': [
          for (final arm in [r.nearArm, ?r.farArm])
            {
              'side': arm.side.name,
              'ua': arm.upperArm,
              'la': arm.lowerArm,
              'tableB': arm.tableB,
            },
        ],
      },
    if (o != null) 'owas': {'code': o.code.code, 'category': o.actionCategory},
  };
}

FrameScore frameScoreFromJson(Map<String, Object?> j) {
  final t = Duration(milliseconds: (j['t']! as num).toInt());
  final lm = j['lm'] as List<Object?>?;
  final pose = lm == null
      ? null
      : PoseFrame(
          timestamp: t,
          width: (j['w']! as num).toDouble(),
          height: (j['h']! as num).toDouble(),
          landmarks: [
            for (final p in lm.cast<List<Object?>>())
              Landmark(
                (p[0]! as num).toDouble(),
                (p[1]! as num).toDouble(),
                (p[2]! as num).toDouble(),
                (p[3]! as num).toDouble(),
              ),
          ],
        );
  final confidence = (j['confidence']! as num).toDouble();

  if (j['scored'] != true) {
    return FrameScore.unscored(
      timestamp: t,
      unscoredReason: (j['reason'] as String?) ?? 'Unscored',
      pose: pose,
      confidence: confidence,
    );
  }

  double d(Map<String, Object?> m, String k) => (m[k]! as num).toDouble();
  int i(Map<String, Object?> m, String k) => (m[k]! as num).toInt();

  final aj = (j['angles']! as Map).cast<String, Object?>();
  final angles = JointAngles(
    side: BodySide.values.byName(aj['side']! as String),
    trunkFlexion: d(aj, 'trunkFlex'),
    neckFlexion: d(aj, 'neckFlex'),
    kneeFlexion: d(aj, 'kneeFlex'),
    nearArm: ArmAngles(
      upperArmFlexion: d(aj, 'upperArmNear'),
      elbowFlexion: d(aj, 'elbowNear'),
    ),
    farArm: aj.containsKey('upperArmFar')
        ? ArmAngles(
            upperArmFlexion: d(aj, 'upperArmFar'),
            elbowFlexion: d(aj, 'elbowFar'),
          )
        : null,
    confidence: confidence,
  );

  final rj = (j['reba']! as Map).cast<String, Object?>();
  final arms = [
    for (final m in (rj['arms']! as List).cast<Map<Object?, Object?>>())
      RebaArmScore(
        side: BodySide.values.byName(m['side']! as String),
        upperArm: (m['ua']! as num).toInt(),
        lowerArm: (m['la']! as num).toInt(),
        tableB: (m['tableB']! as num).toInt(),
      ),
  ];
  final reba = RebaResult(
    trunk: i(rj, 'trunk'),
    neck: i(rj, 'neck'),
    legs: i(rj, 'legs'),
    tableA: i(rj, 'tableA'),
    load: i(rj, 'load'),
    scoreA: i(rj, 'a'),
    upperArm: i(rj, 'upperArm'),
    lowerArm: i(rj, 'lowerArm'),
    wrist: i(rj, 'wrist'),
    tableB: i(rj, 'tableB'),
    coupling: i(rj, 'coupling'),
    scoreB: i(rj, 'b'),
    tableC: i(rj, 'c'),
    activity: i(rj, 'activity'),
    score: i(rj, 'score'),
    nearArm: arms.first,
    farArm: arms.length > 1 ? arms[1] : null,
  );

  final oj = (j['owas']! as Map).cast<String, Object?>();
  final code = oj['code']! as String;
  int digit(int k) => int.parse(code[k]);
  final owas = OwasResult(
    OwasCode(back: digit(0), arms: digit(1), legs: digit(2), load: digit(3)),
    i(oj, 'category'),
  );

  return FrameScore.scored(
    timestamp: t,
    pose: pose,
    angles: angles,
    reba: reba,
    owas: owas,
    regions: RegionLevels.of(reba),
  );
}

Map<String, Object?> sessionInputsToJson(SessionInputs i) => {
  'loadKg': i.loadKg,
  'shockOrRapidForce': i.shockOrRapidForce,
  'coupling': i.coupling.name,
  'staticPosture': i.staticPosture,
  'repeatedSmallRange': i.repeatedSmallRange,
  'rapidLargeChanges': i.rapidLargeChanges,
  'trunkTwistOrSideBend': i.trunkTwistOrSideBend,
  'neckTwistOrSideBend': i.neckTwistOrSideBend,
  'wristFlexedOver15': i.wristFlexedOver15,
  'wristDeviatedOrTwisted': i.wristDeviatedOrTwisted,
  'armAbductedOrRotated': i.armAbductedOrRotated,
  'shoulderRaised': i.shoulderRaised,
  'armSupported': i.armSupported,
  'unilateralStance': i.unilateralStance,
  'sitting': i.sitting,
  'walking': i.walking,
  'kneeling': i.kneeling,
};

/// Missing keys fall back to the neutral defaults, so older files still load.
SessionInputs sessionInputsFromJson(Map<String, Object?> j) {
  bool b(String k) => j[k] == true;
  return SessionInputs(
    loadKg: (j['loadKg'] as num?)?.toDouble() ?? 0,
    shockOrRapidForce: b('shockOrRapidForce'),
    coupling: Coupling.values.asNameMap()[j['coupling']] ?? Coupling.good,
    staticPosture: b('staticPosture'),
    repeatedSmallRange: b('repeatedSmallRange'),
    rapidLargeChanges: b('rapidLargeChanges'),
    trunkTwistOrSideBend: b('trunkTwistOrSideBend'),
    neckTwistOrSideBend: b('neckTwistOrSideBend'),
    wristFlexedOver15: b('wristFlexedOver15'),
    wristDeviatedOrTwisted: b('wristDeviatedOrTwisted'),
    armAbductedOrRotated: b('armAbductedOrRotated'),
    shoulderRaised: b('shoulderRaised'),
    armSupported: b('armSupported'),
    unilateralStance: b('unilateralStance'),
    sitting: b('sitting'),
    walking: b('walking'),
    kneeling: b('kneeling'),
  );
}
