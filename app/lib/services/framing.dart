import 'package:ergo_core/ergo_core.dart';

/// Default placement advice, shown until the camera sees a usable side view.
const placementGuide = 'Side view · whole body in frame · 2–4 m away';

/// One actionable hint about camera placement for [pose], or null when the
/// framing looks fine. Checked in order of what to fix first.
String? framingHint(PoseFrame? pose) {
  if (pose == null) return 'No one in view — $placementGuide';

  bool seen(BodyLandmark b) => pose[b].isVisible;
  bool anySeen(List<BodyLandmark> bs) => bs.any(seen);

  const head = [BodyLandmark.nose, BodyLandmark.leftEar, BodyLandmark.rightEar];
  const feet = [
    BodyLandmark.leftAnkle,
    BodyLandmark.rightAnkle,
    BodyLandmark.leftHeel,
    BodyLandmark.rightHeel,
  ];

  final edge = pose.height * 0.02;
  final headPoints = head.where(seen).map((b) => pose[b]);
  final footPoints = feet.where(seen).map((b) => pose[b]);

  if (!anySeen(feet) || footPoints.any((l) => l.y > pose.height - edge)) {
    return 'Feet not in frame — step back or tilt the phone down';
  }
  if (!anySeen(head) || headPoints.any((l) => l.y < edge)) {
    return 'Head not in frame — step back or tilt the phone up';
  }

  // Size and orientation use body segment lengths, which don't shrink when
  // the person bends (unlike head-to-feet height).
  final body = _segmentLength(pose);
  if (body != null && body < pose.height * 0.3) {
    return 'Person looks small — move the phone closer (2–4 m)';
  }

  // Side-on: the shoulders nearly overlap. Facing the camera, they're far
  // apart compared with the torso length.
  final ls = pose[BodyLandmark.leftShoulder];
  final rs = pose[BodyLandmark.rightShoulder];
  final torso =
      _dist(pose, BodyLandmark.leftShoulder, BodyLandmark.leftHip) ??
      _dist(pose, BodyLandmark.rightShoulder, BodyLandmark.rightHip);
  if (ls.isVisible && rs.isVisible && torso != null && torso > 0) {
    if ((ls.x - rs.x).abs() > 0.6 * torso) return 'Turn side-on to the camera';
  }
  return null;
}

double? _dist(PoseFrame p, BodyLandmark a, BodyLandmark b) {
  final la = p[a], lb = p[b];
  if (!la.isVisible || !lb.isVisible) return null;
  return Vec2(la.x - lb.x, la.y - lb.y).length;
}

/// Shoulder–hip + hip–knee + knee–ankle on whichever side is fully visible.
double? _segmentLength(PoseFrame p) {
  for (final side in [
    [
      BodyLandmark.leftShoulder,
      BodyLandmark.leftHip,
      BodyLandmark.leftKnee,
      BodyLandmark.leftAnkle,
    ],
    [
      BodyLandmark.rightShoulder,
      BodyLandmark.rightHip,
      BodyLandmark.rightKnee,
      BodyLandmark.rightAnkle,
    ],
  ]) {
    final parts = [for (var i = 0; i < 3; i++) _dist(p, side[i], side[i + 1])];
    if (parts.every((d) => d != null)) {
      return parts.fold<double>(0, (a, d) => a + d!);
    }
  }
  return null;
}
