import 'package:ergo_core/ergo_core.dart';
import 'package:test/test.dart';

JointAngles angles({
  double trunk = 0,
  double neck = 5,
  double knee = 0,
  double ua = 0,
  double elbow = 80,
  ArmAngles? far,
}) => JointAngles(
  trunkFlexion: trunk,
  neckFlexion: neck,
  kneeFlexion: knee,
  nearArm: ArmAngles(upperArmFlexion: ua, elbowFlexion: elbow),
  farArm: far,
);

RebaResult reba(JointAngles a, [SessionInputs i = const SessionInputs()]) =>
    scoreReba(a, i);

void main() {
  group('trunk', () {
    final cases = {
      -25.0: 3,
      -20.0: 2,
      -10.0: 2,
      -5.0: 1,
      0.0: 1,
      5.0: 1,
      5.1: 2,
      20.0: 2,
      20.1: 3,
      60.0: 3,
      60.1: 4,
      120.0: 4,
    };
    cases.forEach((deg, score) {
      test(
        '$deg° → $score',
        () => expect(reba(angles(trunk: deg)).trunk, score),
      );
    });

    test('+1 for twist or side bend', () {
      expect(
        reba(
          angles(trunk: 30),
          const SessionInputs(trunkTwistOrSideBend: true),
        ).trunk,
        4,
      );
    });
  });

  group('neck', () {
    final cases = {-10.0: 2, -5.0: 1, 0.0: 1, 20.0: 1, 20.1: 2, 45.0: 2};
    cases.forEach((deg, score) {
      test('$deg° → $score', () => expect(reba(angles(neck: deg)).neck, score));
    });

    test('+1 for twist or side bend', () {
      expect(
        reba(
          angles(neck: 30),
          const SessionInputs(neckTwistOrSideBend: true),
        ).neck,
        3,
      );
    });
  });

  group('legs', () {
    final cases = {0.0: 1, 29.9: 1, 30.0: 2, 60.0: 2, 60.1: 3, 110.0: 3};
    cases.forEach((knee, score) {
      test(
        'bilateral, knee $knee° → $score',
        () => expect(reba(angles(knee: knee)).legs, score),
      );
    });

    test('unilateral stance adds 1', () {
      expect(
        reba(
          angles(knee: 45),
          const SessionInputs(unilateralStance: true),
        ).legs,
        3,
      );
    });

    test('sitting drops the >60° adjustment', () {
      expect(
        reba(angles(knee: 90), const SessionInputs(sitting: true)).legs,
        1,
      );
      expect(
        reba(angles(knee: 45), const SessionInputs(sitting: true)).legs,
        2,
      );
    });
  });

  group('load', () {
    final cases = {0.0: 0, 4.9: 0, 5.0: 1, 10.0: 1, 10.1: 2, 25.0: 2};
    cases.forEach((kg, score) {
      test(
        '$kg kg → $score',
        () => expect(rebaLoadScore(kg, shock: false), score),
      );
    });

    test('+1 for shock or rapid force', () {
      expect(rebaLoadScore(12, shock: true), 3);
    });

    test('adds to Table A for score A', () {
      final r = reba(angles(), const SessionInputs(loadKg: 12));
      expect(r.scoreA, r.tableA + 2);
    });
  });

  group('upper arm', () {
    final cases = {
      -30.0: 2,
      -20.0: 1,
      0.0: 1,
      20.0: 1,
      20.1: 2,
      45.0: 2,
      45.1: 3,
      90.0: 3,
      90.1: 4,
      150.0: 4,
    };
    cases.forEach((deg, score) {
      test(
        '$deg° → $score',
        () => expect(reba(angles(ua: deg)).upperArm, score),
      );
    });

    test('abducted and raised add 1 each', () {
      expect(
        reba(
          angles(ua: 100),
          const SessionInputs(armAbductedOrRotated: true, shoulderRaised: true),
        ).upperArm,
        6,
      );
    });

    test('supported subtracts 1 but never below 1', () {
      expect(
        reba(angles(ua: 60), const SessionInputs(armSupported: true)).upperArm,
        2,
      );
      expect(
        reba(angles(ua: 0), const SessionInputs(armSupported: true)).upperArm,
        1,
      );
    });
  });

  group('lower arm', () {
    final cases = {0.0: 2, 59.9: 2, 60.0: 1, 80.0: 1, 100.0: 1, 100.1: 2};
    cases.forEach((deg, score) {
      test(
        '$deg° → $score',
        () => expect(reba(angles(elbow: deg)).lowerArm, score),
      );
    });
  });

  group('wrist', () {
    test('defaults to 1 (not measurable from pose)', () {
      expect(reba(angles()).wrist, 1);
    });
    test('flexed >15° and deviated from setup', () {
      expect(
        reba(
          angles(),
          const SessionInputs(
            wristFlexedOver15: true,
            wristDeviatedOrTwisted: true,
          ),
        ).wrist,
        3,
      );
    });
  });

  group('group B uses the worse arm', () {
    test('far arm wins when it scores higher', () {
      final r = reba(
        angles(
          ua: 0,
          far: const ArmAngles(upperArmFlexion: 100, elbowFlexion: 80),
        ),
      );
      expect(r.upperArm, 4);
      expect(r.scoredArm, BodySide.right);
    });

    test('near arm kept on a tie', () {
      final r = reba(
        angles(far: const ArmAngles(upperArmFlexion: 0, elbowFlexion: 80)),
      );
      expect(r.scoredArm, BodySide.left);
    });
  });

  group('coupling, activity, cap and risk', () {
    test('coupling adds to Table B', () {
      for (final c in Coupling.values) {
        final r = reba(angles(), SessionInputs(coupling: c));
        expect(r.scoreB, r.tableB + c.score);
      }
    });

    test('each activity flag adds 1', () {
      final r = reba(
        angles(),
        const SessionInputs(
          staticPosture: true,
          repeatedSmallRange: true,
          rapidLargeChanges: true,
        ),
      );
      expect(r.activity, 3);
      expect(r.score, r.tableC + 3);
    });

    test('final score caps at 15', () {
      final r = reba(
        angles(trunk: 90, neck: 40, knee: 90, ua: 120, elbow: 0),
        const SessionInputs(
          loadKg: 30,
          shockOrRapidForce: true,
          coupling: Coupling.unacceptable,
          staticPosture: true,
          repeatedSmallRange: true,
          rapidLargeChanges: true,
          trunkTwistOrSideBend: true,
          neckTwistOrSideBend: true,
          wristFlexedOver15: true,
          wristDeviatedOrTwisted: true,
          armAbductedOrRotated: true,
          shoulderRaised: true,
          unilateralStance: true,
        ),
      );
      expect(r.scoreA, 12);
      expect(r.scoreB, 12);
      expect(r.tableC, 12);
      expect(r.score, 15);
      expect(r.risk, RebaRisk.veryHigh);
    });

    test('risk bands', () {
      final expected = {
        1: RebaRisk.negligible,
        2: RebaRisk.low,
        3: RebaRisk.low,
        4: RebaRisk.medium,
        7: RebaRisk.medium,
        8: RebaRisk.high,
        10: RebaRisk.high,
        11: RebaRisk.veryHigh,
        15: RebaRisk.veryHigh,
      };
      expected.forEach((s, r) => expect(RebaRisk.forScore(s), r, reason: '$s'));
    });
  });

  group('StableRebaScorer', () {
    test('holds trunk score while hovering on 20°', () {
      final s = StableRebaScorer();
      const i = SessionInputs();
      expect(s.score(angles(trunk: 18), i).trunk, 2);
      expect(s.score(angles(trunk: 21), i).trunk, 2);
      expect(s.score(angles(trunk: 19), i).trunk, 2);
      expect(s.score(angles(trunk: 22.9), i).trunk, 2);
      expect(s.score(angles(trunk: 23.1), i).trunk, 3);
      expect(s.score(angles(trunk: 18), i).trunk, 3);
    });

    test('matches the pure scorer on the first frame', () {
      final a = angles(trunk: 40, knee: 100, ua: 30, elbow: 20);
      expect(
        StableRebaScorer().score(a, const SessionInputs()).score,
        scoreReba(a, const SessionInputs()).score,
      );
    });

    test('reset after losing the person', () {
      final s = StableRebaScorer();
      const i = SessionInputs();
      s.score(angles(trunk: 22), i);
      s.reset();
      expect(s.score(angles(trunk: 19), i).trunk, 2);
    });
  });
}
