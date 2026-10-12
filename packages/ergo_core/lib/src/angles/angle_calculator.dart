import 'dart:math' as math;

import '../math/vec2.dart';
import '../models/joint_angles.dart';
import '../models/landmark.dart';

/// Joint angles for a frame, or why the frame can't be scored.
class AngleResult {
  const AngleResult.scored(JointAngles this.angles)
    : unscoredReason = null,
      confidence = 0;

  const AngleResult.unscored(String this.unscoredReason, {this.confidence = 0})
    : angles = null;

  final JointAngles? angles;
  final String? unscoredReason;
  final double confidence;

  bool get isScored => angles != null;
  double get frameConfidence => angles?.confidence ?? confidence;
}

/// Turns 2D landmarks into the joint angles defined in docs/SCORING.md.
///
/// Works on the body side facing the camera. Every landmark it needs must
/// pass the visibility threshold; otherwise the frame is unscored — angles are
/// never estimated from low-confidence points.
class AngleCalculator {
  const AngleCalculator();

  /// Near-side landmarks a frame needs to be scored.
  static const _requiredParts = [
    _Part.shoulder,
    _Part.elbow,
    _Part.wrist,
    _Part.hip,
    _Part.knee,
    _Part.ankle,
    _Part.ear,
  ];

  /// [up] is true vertical in image coordinates (x right, y down), e.g. from
  /// the accelerometer. Defaults to the image's own up.
  AngleResult compute(PoseFrame frame, {Vec2 up = const Vec2(0, -1)}) {
    if (up.length == 0) {
      return const AngleResult.unscored('No vertical reference');
    }
    final u = up.normalized;

    final side = _nearSide(frame);
    final near = _Side(frame, side);
    final far = _Side(
      frame,
      side == BodySide.left ? BodySide.right : BodySide.left,
    );

    final required = [for (final p in _requiredParts) near[p]];
    final confidence =
        required.map((l) => l.visibility).reduce((a, b) => a + b) /
        required.length;
    final missing = [
      for (final p in _requiredParts)
        if (!near[p].isVisible) p.name,
    ];
    if (missing.isNotEmpty) {
      return AngleResult.unscored(
        'Low-confidence ${side.name} ${missing.join(', ')}',
        confidence: confidence,
      );
    }

    // Rotation sense in which "forward" is positive (up turning toward the
    // direction the person faces). Image handedness cancels out through it.
    final forward = _forward(frame, near, u);
    if (forward == null) {
      return AngleResult.unscored(
        'Facing direction unknown',
        confidence: confidence,
      );
    }
    final s = u.cross(forward) >= 0 ? 1.0 : -1.0;

    final shoulderMid = _mid(near[_Part.shoulder], far[_Part.shoulder]);
    final hipMid = _mid(near[_Part.hip], far[_Part.hip]);
    final earMid = _mid(near[_Part.ear], far[_Part.ear]);

    final trunk = shoulderMid - hipMid;
    final neck = earMid - shoulderMid;

    final knees = [
      _flexion(near[_Part.hip], near[_Part.knee], near[_Part.ankle]),
      if (far.allVisible([_Part.hip, _Part.knee, _Part.ankle]))
        _flexion(far[_Part.hip], far[_Part.knee], far[_Part.ankle]),
    ];

    return AngleResult.scored(
      JointAngles(
        trunkFlexion: s * rotationDeg(u, trunk),
        neckFlexion: s * rotationDeg(trunk, neck),
        kneeFlexion: knees.reduce(math.max),
        nearArm: _arm(near, trunk, s),
        farArm: far.allVisible([_Part.shoulder, _Part.elbow, _Part.wrist])
            ? _arm(far, trunk, s)
            : null,
        side: side,
        confidence: confidence,
      ),
    );
  }

  static BodySide _nearSide(PoseFrame f) {
    double sum(BodySide s) {
      final side = _Side(f, s);
      return _requiredParts.fold(0.0, (acc, p) => acc + side[p].visibility);
    }

    return sum(BodySide.left) >= sum(BodySide.right)
        ? BodySide.left
        : BodySide.right;
  }

  /// Direction the person faces, perpendicular to [up]: from the near foot
  /// (heel → toe) if visible, else from the nose relative to the near ear.
  static Vec2? _forward(PoseFrame f, _Side near, Vec2 up) {
    final heel = near[_Part.heel], toe = near[_Part.footIndex];
    final nose = f[BodyLandmark.nose], ear = near[_Part.ear];
    final hints = [
      if (heel.isVisible && toe.isVisible) _vec(toe) - _vec(heel),
      if (nose.isVisible) _vec(nose) - _vec(ear),
    ];
    for (final h in hints) {
      final perp = h - up * h.dot(up);
      // Ignore hints that are nearly vertical (no horizontal information).
      if (perp.length > 0.25 * h.length && perp.length > 0) return perp;
    }
    return null;
  }

  static ArmAngles _arm(_Side side, Vec2 trunk, double s) {
    final shoulder = _vec(side[_Part.shoulder]);
    final elbow = _vec(side[_Part.elbow]);
    // Swinging the arm forward from hanging turns "down" the opposite way to
    // tipping "up" forward, hence −s.
    return ArmAngles(
      upperArmFlexion: -s * rotationDeg(-trunk, elbow - shoulder),
      elbowFlexion: _flexion(
        side[_Part.shoulder],
        side[_Part.elbow],
        side[_Part.wrist],
      ),
    );
  }

  /// 180° − interior angle at [joint]: 0 when the limb is straight.
  static double _flexion(Landmark a, Landmark joint, Landmark b) =>
      180 - interiorAngleDeg(_vec(a), _vec(joint), _vec(b));

  /// Midpoint of both sides when the far one is visible, else the near one.
  static Vec2 _mid(Landmark near, Landmark far) =>
      far.isVisible ? Vec2.midpoint(_vec(near), _vec(far)) : _vec(near);

  static Vec2 _vec(Landmark l) => Vec2(l.x, l.y);
}

enum _Part { shoulder, elbow, wrist, hip, knee, ankle, ear, heel, footIndex }

class _Side {
  _Side(this.frame, this.side);

  final PoseFrame frame;
  final BodySide side;

  Landmark operator [](_Part p) {
    final left = side == BodySide.left;
    return frame[switch (p) {
      _Part.shoulder =>
        left ? BodyLandmark.leftShoulder : BodyLandmark.rightShoulder,
      _Part.elbow => left ? BodyLandmark.leftElbow : BodyLandmark.rightElbow,
      _Part.wrist => left ? BodyLandmark.leftWrist : BodyLandmark.rightWrist,
      _Part.hip => left ? BodyLandmark.leftHip : BodyLandmark.rightHip,
      _Part.knee => left ? BodyLandmark.leftKnee : BodyLandmark.rightKnee,
      _Part.ankle => left ? BodyLandmark.leftAnkle : BodyLandmark.rightAnkle,
      _Part.ear => left ? BodyLandmark.leftEar : BodyLandmark.rightEar,
      _Part.heel => left ? BodyLandmark.leftHeel : BodyLandmark.rightHeel,
      _Part.footIndex =>
        left ? BodyLandmark.leftFootIndex : BodyLandmark.rightFootIndex,
    }];
  }

  bool allVisible(List<_Part> parts) => parts.every((p) => this[p].isVisible);
}
