import '../models/joint_angles.dart';
import 'reba.dart';

/// Severity of one body region, for colouring the skeleton.
///
/// A display convention, not part of REBA: each region's sub-score is placed
/// within that region's own range (docs/SCORING.md, "Region colours").
enum RegionLevel { low, moderate, elevated, high }

/// Body regions REBA scores separately.
enum BodyRegion { trunk, neck, legs, upperArm, lowerArm }

/// Level for a REBA sub-score of [region].
///
/// trunk 1/2/3/4+ · legs 1/2/3/4 · upper arm 1/2/3/4+ → low…high;
/// neck 1 low, 2 elevated, 3 high; lower arm 1 low, 2 elevated.
RegionLevel regionLevel(BodyRegion region, int score) {
  RegionLevel byIndex(int i) => RegionLevel.values[i.clamp(0, 3)];
  return switch (region) {
    BodyRegion.trunk ||
    BodyRegion.legs ||
    BodyRegion.upperArm => byIndex(score - 1),
    BodyRegion.neck => switch (score) {
      <= 1 => RegionLevel.low,
      2 => RegionLevel.elevated,
      _ => RegionLevel.high,
    },
    BodyRegion.lowerArm => score <= 1 ? RegionLevel.low : RegionLevel.elevated,
  };
}

/// Levels for one arm.
class ArmLevels {
  const ArmLevels({
    required this.side,
    required this.upperArm,
    required this.lowerArm,
  });

  factory ArmLevels.of(RebaArmScore a) => ArmLevels(
    side: a.side,
    upperArm: regionLevel(BodyRegion.upperArm, a.upperArm),
    lowerArm: regionLevel(BodyRegion.lowerArm, a.lowerArm),
  );

  final BodySide side;
  final RegionLevel upperArm;
  final RegionLevel lowerArm;
}

/// Region levels for a scored frame.
class RegionLevels {
  const RegionLevels({
    required this.trunk,
    required this.neck,
    required this.legs,
    required this.nearArm,
    this.farArm,
  });

  factory RegionLevels.of(RebaResult r) => RegionLevels(
    trunk: regionLevel(BodyRegion.trunk, r.trunk),
    neck: regionLevel(BodyRegion.neck, r.neck),
    legs: regionLevel(BodyRegion.legs, r.legs),
    nearArm: ArmLevels.of(r.nearArm),
    farArm: r.farArm == null ? null : ArmLevels.of(r.farArm!),
  );

  final RegionLevel trunk;
  final RegionLevel neck;
  final RegionLevel legs;
  final ArmLevels nearArm;

  /// Null when the far arm wasn't measured; draw it neutral.
  final ArmLevels? farArm;

  ArmLevels? arm(BodySide side) =>
      nearArm.side == side ? nearArm : (farArm?.side == side ? farArm : null);
}
