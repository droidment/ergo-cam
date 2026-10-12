/// Which side of the body faces the camera (and is measured).
enum BodySide { left, right }

/// Upper-arm and elbow angles for one arm, in degrees.
class ArmAngles {
  const ArmAngles({required this.upperArmFlexion, required this.elbowFlexion});

  /// Shoulder → elbow vs. the trunk pointing down. Forward = +, back = −.
  final double upperArmFlexion;

  /// 180° − interior angle at the elbow. 0 = straight arm.
  final double elbowFlexion;

  @override
  String toString() => 'Arm(ua: $upperArmFlexion, elbow: $elbowFlexion)';
}

/// Joint angles for one frame, per docs/SCORING.md. Degrees throughout.
class JointAngles {
  const JointAngles({
    required this.trunkFlexion,
    required this.neckFlexion,
    required this.kneeFlexion,
    required this.nearArm,
    this.farArm,
    this.side = BodySide.left,
    this.confidence = 1,
  });

  /// Hip-mid → shoulder-mid vs. vertical. Forward = +, extension = −.
  final double trunkFlexion;

  /// Shoulder-mid → ear-mid vs. the trunk. Forward = +, extension = −.
  final double neckFlexion;

  /// The more flexed of the visible knees. 0 = straight leg.
  final double kneeFlexion;

  /// Arm on the side facing the camera (always measured).
  final ArmAngles nearArm;

  /// Arm on the far side, when its landmarks are confidently visible.
  final ArmAngles? farArm;

  final BodySide side;

  /// Mean visibility of the landmarks the angles were built from, 0–1.
  final double confidence;

  @override
  String toString() =>
      'JointAngles(trunk: $trunkFlexion, neck: $neckFlexion, '
      'knee: $kneeFlexion, near: $nearArm, far: $farArm, side: ${side.name})';
}
