import 'package:ergo_core/ergo_core.dart';
import 'package:test/test.dart';

import 'support/skeleton.dart';

void main() {
  const calc = AngleCalculator();
  const eps = 1e-6;

  JointAngles anglesOf(Skeleton s) {
    final r = calc.compute(s.build(), up: s.up);
    expect(r.isScored, isTrue, reason: r.unscoredReason);
    return r.angles!;
  }

  void expectAngles(
    JointAngles a, {
    required double trunk,
    required double neck,
    required double upperArm,
    required double elbow,
    required double knee,
  }) {
    expect(a.trunkFlexion, closeTo(trunk, eps), reason: 'trunk');
    expect(a.neckFlexion, closeTo(neck, eps), reason: 'neck');
    expect(a.nearArm.upperArmFlexion, closeTo(upperArm, eps), reason: 'ua');
    expect(a.nearArm.elbowFlexion, closeTo(elbow, eps), reason: 'elbow');
    expect(a.kneeFlexion, closeTo(knee, eps), reason: 'knee');
  }

  group('recovers known angles', () {
    for (final facingRight in [true, false]) {
      for (final near in BodySide.values) {
        final label =
            'facing ${facingRight ? 'right' : 'left'}, near ${near.name}';

        test('neutral standing ($label)', () {
          final a = anglesOf(
            Skeleton(facingRight: facingRight, nearSide: near),
          );
          expectAngles(a, trunk: 0, neck: 0, upperArm: 0, elbow: 0, knee: 0);
          expect(a.side, near);
        });

        test('flexed lift posture ($label)', () {
          final a = anglesOf(
            Skeleton(
              trunk: 45,
              neck: 15,
              upperArm: 60,
              elbow: 90,
              knee: 40,
              facingRight: facingRight,
              nearSide: near,
            ),
          );
          expectAngles(
            a,
            trunk: 45,
            neck: 15,
            upperArm: 60,
            elbow: 90,
            knee: 40,
          );
        });

        test('extension is negative ($label)', () {
          final a = anglesOf(
            Skeleton(
              trunk: -15,
              neck: -10,
              upperArm: -30,
              facingRight: facingRight,
              nearSide: near,
            ),
          );
          expect(a.trunkFlexion, closeTo(-15, eps));
          expect(a.neckFlexion, closeTo(-10, eps));
          expect(a.nearArm.upperArmFlexion, closeTo(-30, eps));
        });
      }
    }

    test('shin lean does not change knee flexion', () {
      final a = anglesOf(Skeleton(trunk: 40, knee: 100, shinLean: 35));
      expect(a.kneeFlexion, closeTo(100, eps));
      expect(a.trunkFlexion, closeTo(40, eps));
    });

    test('overhead reach beyond 90°', () {
      final a = anglesOf(Skeleton(upperArm: 120, elbow: 30));
      expect(a.nearArm.upperArmFlexion, closeTo(120, eps));
      expect(a.nearArm.elbowFlexion, closeTo(30, eps));
    });
  });

  group('gravity reference', () {
    test('tilted phone with gravity vector gives true angles', () {
      final a = anglesOf(Skeleton(trunk: 30, neck: 10, cameraTiltDeg: 12));
      expect(a.trunkFlexion, closeTo(30, eps));
      expect(a.neckFlexion, closeTo(10, eps)); // relative angles unaffected
    });

    test('tilted phone without gravity fakes trunk flexion', () {
      final s = Skeleton(trunk: 0, cameraTiltDeg: 12);
      final r = calc.compute(s.build()); // image up, not true up
      expect(r.angles!.trunkFlexion.abs(), closeTo(12, eps));
    });
  });

  group('confidence gating', () {
    for (final part in [
      BodyLandmark.leftShoulder,
      BodyLandmark.leftElbow,
      BodyLandmark.leftWrist,
      BodyLandmark.leftHip,
      BodyLandmark.leftKnee,
      BodyLandmark.leftAnkle,
      BodyLandmark.leftEar,
    ]) {
      test('unscored when near-side ${part.name} is low confidence', () {
        final s = Skeleton(hidden: {part});
        final r = calc.compute(s.build(), up: s.up);
        expect(r.isScored, isFalse);
        expect(
          r.unscoredReason,
          contains(part.name.replaceFirst('left', '').toLowerCase()),
        );
        expect(r.frameConfidence, lessThan(1));
      });
    }

    test('unscored when facing direction is unknown', () {
      final s = Skeleton(withFeet: false, withNose: false);
      final r = calc.compute(s.build(), up: s.up);
      expect(r.isScored, isFalse);
      expect(r.unscoredReason, contains('Facing'));
    });

    test('nose alone is enough to tell facing', () {
      final a = anglesOf(Skeleton(trunk: 30, withFeet: false));
      expect(a.trunkFlexion, closeTo(30, eps));
    });

    test('feet alone are enough to tell facing', () {
      final a = anglesOf(Skeleton(trunk: 30, withNose: false));
      expect(a.trunkFlexion, closeTo(30, eps));
    });

    test('zero vertical is rejected', () {
      final r = calc.compute(Skeleton().build(), up: const Vec2(0, 0));
      expect(r.isScored, isFalse);
    });

    test('confidence is the mean visibility of required landmarks', () {
      expect(anglesOf(Skeleton()).confidence, closeTo(0.95, eps));
    });
  });

  group('far side', () {
    test('far arm is measured only when visible', () {
      expect(anglesOf(Skeleton(upperArm: 50)).farArm, isNull);
      final far = anglesOf(Skeleton(upperArm: 50, farVisible: true)).farArm;
      expect(far, isNotNull);
      expect(far!.upperArmFlexion, closeTo(50, eps));
    });

    test('near side is the more visible one', () {
      expect(anglesOf(Skeleton(nearSide: BodySide.right)).side, BodySide.right);
    });
  });
}
