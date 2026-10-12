import 'package:ergo_core/ergo_core.dart';
import 'package:ergocam/features/live/risk_colors.dart';
import 'package:ergocam/features/live/skeleton_painter.dart';
import 'package:flutter_test/flutter_test.dart';

Bone boneOf(BodyLandmark a, BodyLandmark b) =>
    skeletonBones.firstWhere((x) => x.a == a && x.b == b);

void main() {
  // Stoop with the far arm raised: trunk 4 (high), neck 2 (elevated),
  // legs 1 (low), near arm 1/1 (low/low), far arm 4/2 (high/elevated).
  final regions = RegionLevels.of(
    scoreReba(
      const JointAngles(
        trunkFlexion: 75,
        neckFlexion: 25,
        kneeFlexion: 0,
        nearArm: ArmAngles(upperArmFlexion: 0, elbowFlexion: 80),
        farArm: ArmAngles(upperArmFlexion: 100, elbowFlexion: 10),
      ),
      const SessionInputs(),
    ),
  );

  test('unscored frames draw every bone neutral', () {
    for (final b in skeletonBones) {
      expect(boneColor(b, null), RiskColors.neutral);
    }
  });

  test('trunk, neck and legs use their region levels', () {
    expect(
      boneColor(
        boneOf(BodyLandmark.leftShoulder, BodyLandmark.leftHip),
        regions,
      ),
      RiskColors.red,
    );
    expect(
      boneColor(
        boneOf(BodyLandmark.leftShoulder, BodyLandmark.leftEar),
        regions,
      ),
      RiskColors.orange,
    );
    expect(
      boneColor(
        boneOf(BodyLandmark.rightKnee, BodyLandmark.rightAnkle),
        regions,
      ),
      RiskColors.green,
    );
  });

  test('each arm is coloured by its own score', () {
    expect(
      boneColor(
        boneOf(BodyLandmark.leftShoulder, BodyLandmark.leftElbow),
        regions,
      ),
      RiskColors.green,
    );
    expect(
      boneColor(
        boneOf(BodyLandmark.rightShoulder, BodyLandmark.rightElbow),
        regions,
      ),
      RiskColors.red,
    );
    expect(
      boneColor(
        boneOf(BodyLandmark.rightElbow, BodyLandmark.rightWrist),
        regions,
      ),
      RiskColors.orange,
    );
  });

  test('an arm that was not measured stays neutral', () {
    final nearOnly = RegionLevels.of(
      scoreReba(
        const JointAngles(
          trunkFlexion: 0,
          neckFlexion: 0,
          kneeFlexion: 0,
          nearArm: ArmAngles(upperArmFlexion: 0, elbowFlexion: 80),
        ),
        const SessionInputs(),
      ),
    );
    expect(
      boneColor(
        boneOf(BodyLandmark.rightShoulder, BodyLandmark.rightElbow),
        nearOnly,
      ),
      RiskColors.neutral,
    );
  });

  test('every bone belongs to exactly one region, arms have a side', () {
    for (final b in skeletonBones) {
      final isArm =
          b.region == BodyRegion.upperArm || b.region == BodyRegion.lowerArm;
      expect(b.side != null, isArm, reason: '${b.a.name}-${b.b.name}');
    }
  });
}
