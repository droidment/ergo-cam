import 'package:ergo_core/ergo_core.dart';
import 'package:test/test.dart';

JointAngles angles({
  double trunk = 0,
  double knee = 0,
  double ua = 0,
  double? farUa,
}) => JointAngles(
  trunkFlexion: trunk,
  neckFlexion: 0,
  kneeFlexion: knee,
  nearArm: ArmAngles(upperArmFlexion: ua, elbowFlexion: 10),
  farArm: farUa == null
      ? null
      : ArmAngles(upperArmFlexion: farUa, elbowFlexion: 10),
);

String code(JointAngles a, [SessionInputs i = const SessionInputs()]) =>
    owasCode(a, i).code;

void main() {
  group('back', () {
    test('straight up to 20°, bent above', () {
      expect(owasCode(angles(trunk: 20), const SessionInputs()).back, 1);
      expect(owasCode(angles(trunk: 20.1), const SessionInputs()).back, 2);
    });
    test('twist toggle gives 3, or 4 when also bent', () {
      const tw = SessionInputs(trunkTwistOrSideBend: true);
      expect(owasCode(angles(), tw).back, 3);
      expect(owasCode(angles(trunk: 45), tw).back, 4);
    });
  });

  group('arms', () {
    test('below shoulder under 90°', () {
      expect(
        owasCode(angles(ua: 89.9, farUa: 10), const SessionInputs()).arms,
        1,
      );
    });
    test('one arm at/above shoulder from 90°', () {
      expect(
        owasCode(angles(ua: 90, farUa: 10), const SessionInputs()).arms,
        2,
      );
    });
    test('both arms raised', () {
      expect(
        owasCode(angles(ua: 120, farUa: 110), const SessionInputs()).arms,
        3,
      );
    });
    test('unseen far arm is not guessed raised', () {
      expect(owasCode(angles(ua: 120), const SessionInputs()).arms, 2);
    });
  });

  group('legs', () {
    test('standing straight 2, knees bent 4 (above 30°)', () {
      expect(owasCode(angles(knee: 30), const SessionInputs()).legs, 2);
      expect(owasCode(angles(knee: 30.1), const SessionInputs()).legs, 4);
    });
    test('one leg: straight 3, bent 5', () {
      const one = SessionInputs(unilateralStance: true);
      expect(owasCode(angles(knee: 5), one).legs, 3);
      expect(owasCode(angles(knee: 50), one).legs, 5);
    });
    test('sitting 1, kneeling 6, walking 7 from setup', () {
      expect(
        owasCode(angles(knee: 90), const SessionInputs(sitting: true)).legs,
        1,
      );
      expect(
        owasCode(angles(knee: 90), const SessionInputs(kneeling: true)).legs,
        6,
      );
      expect(owasCode(angles(), const SessionInputs(walking: true)).legs, 7);
    });
  });

  group('load', () {
    final cases = {0.0: 1, 9.9: 1, 10.0: 2, 20.0: 2, 20.1: 3};
    cases.forEach((kg, load) {
      test('$kg kg → $load', () {
        expect(owasCode(angles(), SessionInputs(loadKg: kg)).load, load);
      });
    });
  });

  group('golden postures', () {
    test('G1 neutral standing → 1121', () => expect(code(angles()), '1121'));
    test('G3 stoop → 2121', () {
      expect(code(angles(trunk: 75, knee: 10, ua: 80)), '2121');
    });
    test('G4 squat lift → 2141', () {
      expect(code(angles(trunk: 40, knee: 100, ua: 30)), '2141');
    });
    test('G5 overhead, one arm seen → 1221', () {
      expect(code(angles(ua: 120)), '1221');
    });
  });

  group('action category for golden postures', () {
    const none = SessionInputs();
    test('G1 neutral standing 1121 → 1', () {
      expect(scoreOwas(angles(), none).actionCategory, 1);
    });
    test('G3 stoop 2121 → 2', () {
      expect(
        scoreOwas(angles(trunk: 75, knee: 10, ua: 80), none).actionCategory,
        2,
      );
    });
    test('G4 squat lift 2141 → 3', () {
      expect(
        scoreOwas(angles(trunk: 40, knee: 100, ua: 30), none).actionCategory,
        3,
      );
    });
    test('G5 overhead 1221 → 1', () {
      expect(scoreOwas(angles(ua: 120), none).actionCategory, 1);
    });
    test('squat lift with 25 kg (2143) → 3', () {
      expect(
        scoreOwas(
          angles(trunk: 40, knee: 100, ua: 30),
          const SessionInputs(loadKg: 25),
        ).actionCategory,
        3,
      );
    });
    test('squat, one arm raised, 15 kg (2242) → 4', () {
      final r = scoreOwas(
        angles(trunk: 40, knee: 100, ua: 95),
        const SessionInputs(loadKg: 15),
      );
      expect(r.code.code, '2242');
      expect(r.actionCategory, 4);
    });
  });
}
