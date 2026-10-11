/// Minimum landmark visibility for a point to be used (docs/SCORING.md).
/// Points below this are ignored, never guessed.
const double minLandmarkVisibility = 0.5;

/// The 33 BlazePose body landmarks, in model index order.
enum BodyLandmark {
  nose,
  leftEyeInner,
  leftEye,
  leftEyeOuter,
  rightEyeInner,
  rightEye,
  rightEyeOuter,
  leftEar,
  rightEar,
  leftMouth,
  rightMouth,
  leftShoulder,
  rightShoulder,
  leftElbow,
  rightElbow,
  leftWrist,
  rightWrist,
  leftPinky,
  rightPinky,
  leftIndex,
  rightIndex,
  leftThumb,
  rightThumb,
  leftHip,
  rightHip,
  leftKnee,
  rightKnee,
  leftAnkle,
  rightAnkle,
  leftHeel,
  rightHeel,
  leftFootIndex,
  rightFootIndex,
}

/// One landmark in upright image pixel coordinates (origin top-left, y down).
class Landmark {
  const Landmark(this.x, this.y, this.z, this.visibility);

  /// A landmark the detector did not report.
  static const missing = Landmark(0, 0, 0, 0);

  final double x;
  final double y;

  /// Depth relative to the hips; same scale as [x]. Unreliable in 2D.
  final double z;

  /// Detector confidence that the point is in frame and unoccluded, 0–1.
  final double visibility;

  bool get isVisible => visibility >= minLandmarkVisibility;

  @override
  bool operator ==(Object other) =>
      other is Landmark &&
      other.x == x &&
      other.y == y &&
      other.z == z &&
      other.visibility == visibility;

  @override
  int get hashCode => Object.hash(x, y, z, visibility);

  @override
  String toString() => 'Landmark($x, $y, $z, vis: $visibility)';
}

/// All 33 landmarks of one detected person in one camera frame.
class PoseFrame {
  PoseFrame({
    required this.timestamp,
    required this.width,
    required this.height,
    required List<Landmark> landmarks,
  }) : landmarks = List.unmodifiable(landmarks) {
    if (landmarks.length != BodyLandmark.values.length) {
      throw ArgumentError.value(
        landmarks.length,
        'landmarks',
        'expected ${BodyLandmark.values.length}',
      );
    }
  }

  /// Time since the session (camera stream) started.
  final Duration timestamp;

  /// Upright image size the landmark coordinates refer to.
  final double width;
  final double height;

  /// Indexed by [BodyLandmark.index].
  final List<Landmark> landmarks;

  Landmark operator [](BodyLandmark b) => landmarks[b.index];
}
