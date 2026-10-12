import 'dart:math' as math;

import 'package:ergo_core/ergo_core.dart';

/// Builds a side-view [PoseFrame] whose joint angles are known exactly.
///
/// Geometry is laid out in image coordinates (x right, y down) with the
/// person facing [facingRight] or left, then the whole frame (and the
/// returned [up] vector) is rotated by [cameraTiltDeg] to simulate a tilted
/// phone.
class Skeleton {
  Skeleton({
    this.trunk = 0,
    this.neck = 0,
    this.upperArm = 0,
    this.elbow = 0,
    this.knee = 0,
    this.facingRight = true,
    this.nearSide = BodySide.left,
    this.farVisible = false,
    this.cameraTiltDeg = 0,
    this.hidden = const {},
    this.withFeet = true,
    this.withNose = true,
  });

  final double trunk, neck, upperArm, elbow, knee;
  final bool facingRight;
  final BodySide nearSide;
  final bool farVisible;
  final double cameraTiltDeg;

  /// Landmarks forced below the visibility threshold.
  final Set<BodyLandmark> hidden;
  final bool withFeet;
  final bool withNose;

  static const _origin = Vec2(400, 500);

  /// True vertical in the (possibly tilted) image.
  Vec2 get up => _rotate(const Vec2(0, -1), cameraTiltDeg);

  PoseFrame build() {
    final f = facingRight ? 1.0 : -1.0;
    // Direction at [deg] measured from up toward the facing direction.
    Vec2 dir(double deg) {
      final r = deg * math.pi / 180;
      return Vec2(f * math.sin(r), -math.cos(r));
    }

    const hip = Vec2(0, 0);
    final knee_ = hip + dir(180 - knee) * 45; // thigh swings forward by knee
    final ankle = knee_ + dir(180) * 45; // shin vertical
    final shoulder = hip + dir(trunk) * 55;
    final ear = shoulder + dir(trunk + neck) * 20;
    final nose = ear + dir(trunk + neck + 90) * 8;
    final uaDeg = trunk + 180 - upperArm;
    final elbow_ = shoulder + dir(uaDeg) * 30;
    final wrist = elbow_ + dir(uaDeg - elbow) * 27;
    final heel = ankle + Vec2(-f * 5, 3);
    final toe = ankle + Vec2(f * 15, 3);

    final points = <BodyLandmark, Vec2>{};
    void side(BodySide s) {
      final l = s == BodySide.left;
      points[l ? BodyLandmark.leftShoulder : BodyLandmark.rightShoulder] =
          shoulder;
      points[l ? BodyLandmark.leftElbow : BodyLandmark.rightElbow] = elbow_;
      points[l ? BodyLandmark.leftWrist : BodyLandmark.rightWrist] = wrist;
      points[l ? BodyLandmark.leftHip : BodyLandmark.rightHip] = hip;
      points[l ? BodyLandmark.leftKnee : BodyLandmark.rightKnee] = knee_;
      points[l ? BodyLandmark.leftAnkle : BodyLandmark.rightAnkle] = ankle;
      points[l ? BodyLandmark.leftEar : BodyLandmark.rightEar] = ear;
      if (withFeet) {
        points[l ? BodyLandmark.leftHeel : BodyLandmark.rightHeel] = heel;
        points[l ? BodyLandmark.leftFootIndex : BodyLandmark.rightFootIndex] =
            toe;
      }
    }

    side(BodySide.left);
    side(BodySide.right);
    if (withNose) points[BodyLandmark.nose] = nose;

    final far = nearSide == BodySide.left ? 'right' : 'left';
    return PoseFrame(
      timestamp: Duration.zero,
      width: 800,
      height: 1000,
      landmarks: [
        for (final b in BodyLandmark.values)
          if (points[b] case final p?)
            _landmark(
              _rotate(p, cameraTiltDeg) + _origin,
              visibility: hidden.contains(b)
                  ? 0.2
                  : b.name.startsWith(far)
                  ? (farVisible ? 0.8 : 0.2)
                  : 0.95,
            )
          else
            Landmark.missing,
      ],
    );
  }

  static Landmark _landmark(Vec2 p, {required double visibility}) =>
      Landmark(p.x, p.y, 0, visibility);

  static Vec2 _rotate(Vec2 v, double deg) {
    final r = deg * math.pi / 180;
    final c = math.cos(r), s = math.sin(r);
    return Vec2(v.x * c - v.y * s, v.x * s + v.y * c);
  }
}
