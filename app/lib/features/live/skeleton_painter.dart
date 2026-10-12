import 'package:ergo_core/ergo_core.dart';
import 'package:flutter/material.dart';

import '../../services/frame_geometry.dart';
import 'risk_colors.dart';

/// A skeleton segment and the REBA region it belongs to.
class Bone {
  const Bone(this.a, this.b, this.region, [this.side]);

  final BodyLandmark a;
  final BodyLandmark b;
  final BodyRegion region;

  /// Which arm, for arm regions (each arm has its own score).
  final BodySide? side;
}

List<Bone> _sideBones(BodySide s) {
  final l = s == BodySide.left;
  BodyLandmark p(BodyLandmark left, BodyLandmark right) => l ? left : right;
  final shoulder = p(BodyLandmark.leftShoulder, BodyLandmark.rightShoulder);
  final elbow = p(BodyLandmark.leftElbow, BodyLandmark.rightElbow);
  final wrist = p(BodyLandmark.leftWrist, BodyLandmark.rightWrist);
  final index = p(BodyLandmark.leftIndex, BodyLandmark.rightIndex);
  final hip = p(BodyLandmark.leftHip, BodyLandmark.rightHip);
  final knee = p(BodyLandmark.leftKnee, BodyLandmark.rightKnee);
  final ankle = p(BodyLandmark.leftAnkle, BodyLandmark.rightAnkle);
  final heel = p(BodyLandmark.leftHeel, BodyLandmark.rightHeel);
  final toe = p(BodyLandmark.leftFootIndex, BodyLandmark.rightFootIndex);
  final ear = p(BodyLandmark.leftEar, BodyLandmark.rightEar);
  return [
    Bone(shoulder, hip, BodyRegion.trunk),
    Bone(shoulder, ear, BodyRegion.neck),
    Bone(shoulder, elbow, BodyRegion.upperArm, s),
    Bone(elbow, wrist, BodyRegion.lowerArm, s),
    Bone(wrist, index, BodyRegion.lowerArm, s),
    Bone(hip, knee, BodyRegion.legs),
    Bone(knee, ankle, BodyRegion.legs),
    Bone(ankle, heel, BodyRegion.legs),
    Bone(heel, toe, BodyRegion.legs),
    Bone(ankle, toe, BodyRegion.legs),
  ];
}

final List<Bone> skeletonBones = [
  const Bone(
    BodyLandmark.leftShoulder,
    BodyLandmark.rightShoulder,
    BodyRegion.trunk,
  ),
  const Bone(BodyLandmark.leftHip, BodyLandmark.rightHip, BodyRegion.trunk),
  ..._sideBones(BodySide.left),
  ..._sideBones(BodySide.right),
];

/// Joints drawn as dots: everything on the body plus nose and ears.
final List<BodyLandmark> skeletonJoints = [
  BodyLandmark.nose,
  BodyLandmark.leftEar,
  BodyLandmark.rightEar,
  ...BodyLandmark.values.where(
    (b) => b.index >= BodyLandmark.leftShoulder.index,
  ),
];

/// Colour for [bone]: its region's risk level, or neutral when the frame is
/// unscored or that arm wasn't measured.
Color boneColor(Bone bone, RegionLevels? regions) {
  if (regions == null) return RiskColors.neutral;
  final level = switch (bone.region) {
    BodyRegion.trunk => regions.trunk,
    BodyRegion.neck => regions.neck,
    BodyRegion.legs => regions.legs,
    BodyRegion.upperArm => regions.arm(bone.side!)?.upperArm,
    BodyRegion.lowerArm => regions.arm(bone.side!)?.lowerArm,
  };
  return level == null ? RiskColors.neutral : RiskColors.region(level);
}

/// Draws the smoothed skeleton over the camera preview, each body region in
/// its risk colour. Landmarks below the visibility threshold are skipped.
class SkeletonPainter extends CustomPainter {
  SkeletonPainter({required this.score, required this.mirror});

  final FrameScore? score;
  final bool mirror;

  @override
  void paint(Canvas canvas, Size size) {
    final p = score?.pose;
    if (p == null) return;
    final regions = score!.regions;
    final frame = Size(p.width, p.height);
    Offset at(Landmark l) =>
        frameToPreview(l.x, l.y, frame: frame, canvas: size, mirror: mirror);

    final bone = Paint()
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    for (final b in skeletonBones) {
      final la = p[b.a], lb = p[b.b];
      if (!la.isVisible || !lb.isVisible) continue;
      canvas.drawLine(at(la), at(lb), bone..color = boneColor(b, regions));
    }

    final joint = Paint()..color = Colors.white;
    final outline = Paint()
      ..color = Colors.black54
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (final j in skeletonJoints) {
      final l = p[j];
      if (!l.isVisible) continue;
      canvas
        ..drawCircle(at(l), 4, joint)
        ..drawCircle(at(l), 4, outline);
    }
  }

  @override
  bool shouldRepaint(SkeletonPainter old) =>
      !identical(old.score, score) || old.mirror != mirror;
}
