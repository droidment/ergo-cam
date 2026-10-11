import 'package:ergo_core/ergo_core.dart';
import 'package:flutter/material.dart';

import '../../services/frame_geometry.dart';

typedef Bone = (BodyLandmark, BodyLandmark);

const _l = BodyLandmark.values;

/// Body skeleton. Face points are drawn as joints only.
const List<Bone> skeletonBones = [
  // Torso
  (BodyLandmark.leftShoulder, BodyLandmark.rightShoulder),
  (BodyLandmark.leftHip, BodyLandmark.rightHip),
  (BodyLandmark.leftShoulder, BodyLandmark.leftHip),
  (BodyLandmark.rightShoulder, BodyLandmark.rightHip),
  // Arms
  (BodyLandmark.leftShoulder, BodyLandmark.leftElbow),
  (BodyLandmark.leftElbow, BodyLandmark.leftWrist),
  (BodyLandmark.leftWrist, BodyLandmark.leftIndex),
  (BodyLandmark.rightShoulder, BodyLandmark.rightElbow),
  (BodyLandmark.rightElbow, BodyLandmark.rightWrist),
  (BodyLandmark.rightWrist, BodyLandmark.rightIndex),
  // Legs
  (BodyLandmark.leftHip, BodyLandmark.leftKnee),
  (BodyLandmark.leftKnee, BodyLandmark.leftAnkle),
  (BodyLandmark.leftAnkle, BodyLandmark.leftHeel),
  (BodyLandmark.leftHeel, BodyLandmark.leftFootIndex),
  (BodyLandmark.leftAnkle, BodyLandmark.leftFootIndex),
  (BodyLandmark.rightHip, BodyLandmark.rightKnee),
  (BodyLandmark.rightKnee, BodyLandmark.rightAnkle),
  (BodyLandmark.rightAnkle, BodyLandmark.rightHeel),
  (BodyLandmark.rightHeel, BodyLandmark.rightFootIndex),
  (BodyLandmark.rightAnkle, BodyLandmark.rightFootIndex),
];

/// Joints drawn as dots: everything on the body plus nose and ears.
final List<BodyLandmark> skeletonJoints = [
  BodyLandmark.nose,
  BodyLandmark.leftEar,
  BodyLandmark.rightEar,
  ..._l.where((b) => b.index >= BodyLandmark.leftShoulder.index),
];

bool _isLeft(BodyLandmark b) => b.name.startsWith('left');
bool _isRight(BodyLandmark b) => b.name.startsWith('right');

/// Draws the detected skeleton over the camera preview.
///
/// Left side is cyan, right side orange, so a mirrored or rotated mapping is
/// obvious at a glance. Landmarks below the visibility threshold are skipped.
class SkeletonPainter extends CustomPainter {
  SkeletonPainter({required this.pose, required this.mirror});

  final PoseFrame? pose;
  final bool mirror;

  static const leftColor = Color(0xFF26C6DA);
  static const rightColor = Color(0xFFFFA726);
  static const centerColor = Color(0xFFEEEEEE);

  Color _colorFor(BodyLandmark a, [BodyLandmark? b]) {
    final ends = [a, ?b];
    if (ends.every(_isLeft)) return leftColor;
    if (ends.every(_isRight)) return rightColor;
    return centerColor;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final p = pose;
    if (p == null) return;
    final frame = Size(p.width, p.height);
    Offset at(Landmark l) =>
        frameToPreview(l.x, l.y, frame: frame, canvas: size, mirror: mirror);

    final bone = Paint()
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    for (final (a, b) in skeletonBones) {
      final la = p[a], lb = p[b];
      if (!la.isVisible || !lb.isVisible) continue;
      canvas.drawLine(at(la), at(lb), bone..color = _colorFor(a, b));
    }

    final joint = Paint();
    for (final j in skeletonJoints) {
      final l = p[j];
      if (!l.isVisible) continue;
      canvas.drawCircle(at(l), 5, joint..color = _colorFor(j));
    }
  }

  @override
  bool shouldRepaint(SkeletonPainter old) =>
      !identical(old.pose, pose) || old.mirror != mirror;
}
