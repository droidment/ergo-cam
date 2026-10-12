// Golden postures from docs/SCORING.md. Every expected value is derived by
// hand from the REBA rules and tables in that doc; keep the two in sync.
import 'package:ergo_core/ergo_core.dart';
import 'package:test/test.dart';

import 'support/skeleton.dart';

class Golden {
  const Golden(
    this.id,
    this.name, {
    required this.trunk,
    required this.neck,
    required this.knee,
    required this.upperArm,
    required this.elbow,
    this.inputs = const SessionInputs(),
    required this.sub,
    required this.score,
  });

  final String id, name;
  final double trunk, neck, knee, upperArm, elbow;
  final SessionInputs inputs;

  /// Expected [trunk, neck, legs, tableA, scoreA, upperArm, lowerArm, wrist,
  /// tableB, scoreB, tableC].
  final List<int> sub;
  final int score;

  JointAngles get angles => JointAngles(
    trunkFlexion: trunk,
    neckFlexion: neck,
    kneeFlexion: knee,
    nearArm: ArmAngles(upperArmFlexion: upperArm, elbowFlexion: elbow),
  );
}

const goldens = [
  Golden(
    'G1',
    'Neutral standing, arms by sides',
    trunk: 0,
    neck: 5,
    knee: 0,
    upperArm: 0,
    elbow: 5,
    sub: [1, 1, 1, 1, 1, 1, 2, 1, 1, 1, 1],
    score: 1,
  ),
  Golden(
    'G2',
    'Light forward reach at bench',
    trunk: 15,
    neck: 15,
    knee: 0,
    upperArm: 50,
    elbow: 80,
    sub: [2, 1, 1, 2, 2, 3, 1, 1, 3, 3, 2],
    score: 2,
  ),
  Golden(
    'G3',
    'Stoop to floor, legs straight',
    trunk: 75,
    neck: 25,
    knee: 10,
    upperArm: 80,
    elbow: 10,
    sub: [4, 2, 1, 5, 5, 3, 2, 1, 4, 4, 5],
    score: 5,
  ),
  Golden(
    'G4',
    'Deep squat lift',
    trunk: 40,
    neck: 10,
    knee: 100,
    upperArm: 30,
    elbow: 20,
    sub: [3, 1, 3, 5, 5, 2, 2, 1, 2, 2, 4],
    score: 4,
  ),
  Golden(
    'G4b',
    'Deep squat lift, 15 kg, fair grip, looking at load',
    trunk: 40,
    neck: 25,
    knee: 100,
    upperArm: 30,
    elbow: 20,
    inputs: SessionInputs(loadKg: 15, coupling: Coupling.fair),
    sub: [3, 2, 3, 6, 8, 2, 2, 1, 2, 3, 8],
    score: 8,
  ),
  Golden(
    'G5',
    'Overhead reach',
    trunk: 0,
    neck: -25,
    knee: 0,
    upperArm: 120,
    elbow: 30,
    sub: [1, 2, 1, 1, 1, 4, 2, 1, 5, 5, 3],
    score: 3,
  ),
];

List<int> subScores(RebaResult r) => [
  r.trunk,
  r.neck,
  r.legs,
  r.tableA,
  r.scoreA,
  r.upperArm,
  r.lowerArm,
  r.wrist,
  r.tableB,
  r.scoreB,
  r.tableC,
];

void main() {
  group('golden postures (from angles)', () {
    for (final g in goldens) {
      test('${g.id} ${g.name} → REBA ${g.score}', () {
        final r = scoreReba(g.angles, g.inputs);
        expect(subScores(r), g.sub, reason: r.toString());
        expect(r.score, g.score);
      });
    }
  });

  test('neutral standing must not score high (REBA ≤ 3)', () {
    expect(
      scoreReba(goldens.first.angles, const SessionInputs()).score,
      lessThanOrEqualTo(3),
    );
  });

  test('G4b, a loaded squat lift, lands in the high band', () {
    final g = goldens.firstWhere((g) => g.id == 'G4b');
    expect(scoreReba(g.angles, g.inputs).risk, RebaRisk.high);
  });

  // The same postures end to end: synthetic landmarks → angles → REBA, on a
  // tilted phone, so the angle pipeline is covered by the goldens too.
  group('golden postures (from landmarks, phone tilted 8°)', () {
    const calc = AngleCalculator();
    for (final g in goldens) {
      test('${g.id} end to end → REBA ${g.score}', () {
        final s = Skeleton(
          trunk: g.trunk,
          neck: g.neck,
          knee: g.knee,
          upperArm: g.upperArm,
          elbow: g.elbow,
          cameraTiltDeg: 8,
        );
        final a = calc.compute(s.build(), up: s.up);
        expect(a.isScored, isTrue, reason: a.unscoredReason);
        expect(scoreReba(a.angles!, g.inputs).score, g.score);
      });
    }
  });
}
