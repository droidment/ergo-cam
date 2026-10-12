import 'package:ergo_core/ergo_core.dart';
import 'package:test/test.dart';

const low = RegionLevel.low;
const moderate = RegionLevel.moderate;
const elevated = RegionLevel.elevated;
const high = RegionLevel.high;

void main() {
  group('regionLevel scales each region to its own range', () {
    final cases = <BodyRegion, Map<int, RegionLevel>>{
      BodyRegion.trunk: {1: low, 2: moderate, 3: elevated, 4: high, 5: high},
      BodyRegion.legs: {1: low, 2: moderate, 3: elevated, 4: high},
      BodyRegion.upperArm: {
        1: low,
        2: moderate,
        3: elevated,
        4: high,
        5: high,
        6: high,
      },
      BodyRegion.neck: {1: low, 2: elevated, 3: high},
      BodyRegion.lowerArm: {1: low, 2: elevated},
    };
    cases.forEach((region, expected) {
      expected.forEach((score, level) {
        test('${region.name} $score → ${level.name}', () {
          expect(regionLevel(region, score), level);
        });
      });
    });
  });

  test('RegionLevels.of maps every sub-score and both arms', () {
    final r = scoreReba(
      const JointAngles(
        trunkFlexion: 75, // trunk 4
        neckFlexion: 25, // neck 2
        kneeFlexion: 0, // legs 1
        nearArm: ArmAngles(upperArmFlexion: 0, elbowFlexion: 80), // 1, 1
        farArm: ArmAngles(upperArmFlexion: 100, elbowFlexion: 10), // 4, 2
      ),
      const SessionInputs(),
    );
    final l = RegionLevels.of(r);
    expect(l.trunk, high);
    expect(l.neck, elevated);
    expect(l.legs, low);
    expect(l.nearArm.upperArm, low);
    expect(l.nearArm.lowerArm, low);
    expect(l.farArm!.upperArm, high);
    expect(l.farArm!.lowerArm, elevated);
    expect(l.arm(BodySide.left), same(l.nearArm));
    expect(l.arm(BodySide.right), same(l.farArm));
  });

  test('no far arm → arm() is null for that side', () {
    final r = scoreReba(
      const JointAngles(
        trunkFlexion: 0,
        neckFlexion: 0,
        kneeFlexion: 0,
        nearArm: ArmAngles(upperArmFlexion: 0, elbowFlexion: 80),
      ),
      const SessionInputs(),
    );
    expect(RegionLevels.of(r).arm(BodySide.right), isNull);
  });
}
