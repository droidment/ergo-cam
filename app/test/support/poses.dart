import 'package:ergo_core/ergo_core.dart';

/// A [PoseFrame] with only the given landmarks visible (vis 0.95).
PoseFrame poseWith(
  Map<BodyLandmark, (double, double)> points, {
  double width = 720,
  double height = 1280,
}) => PoseFrame(
  timestamp: Duration.zero,
  width: width,
  height: height,
  landmarks: [
    for (final b in BodyLandmark.values)
      switch (points[b]) {
        (final x, final y) => Landmark(x, y, 0, 0.95),
        null => Landmark.missing,
      },
  ],
);

/// Upright side view facing right, filling about 80% of a 720×1280 frame.
/// Both sides share coordinates, as they nearly do from the side.
Map<BodyLandmark, (double, double)> sideViewPoints({
  double scale = 1,
  double dy = 0,
}) {
  (double, double) p(double x, double y) =>
      (360 + (x - 360) * scale, 640 + (y - 640) * scale + dy);
  final m = <BodyLandmark, (double, double)>{BodyLandmark.nose: p(380, 200)};
  void both(BodyLandmark l, BodyLandmark r, (double, double) v) {
    m[l] = v;
    m[r] = v;
  }

  both(BodyLandmark.leftEar, BodyLandmark.rightEar, p(360, 210));
  both(BodyLandmark.leftShoulder, BodyLandmark.rightShoulder, p(360, 330));
  both(BodyLandmark.leftElbow, BodyLandmark.rightElbow, p(360, 520));
  both(BodyLandmark.leftWrist, BodyLandmark.rightWrist, p(365, 690));
  both(BodyLandmark.leftHip, BodyLandmark.rightHip, p(360, 700));
  both(BodyLandmark.leftKnee, BodyLandmark.rightKnee, p(360, 900));
  both(BodyLandmark.leftAnkle, BodyLandmark.rightAnkle, p(360, 1100));
  both(BodyLandmark.leftHeel, BodyLandmark.rightHeel, p(350, 1115));
  both(BodyLandmark.leftFootIndex, BodyLandmark.rightFootIndex, p(400, 1120));
  return m;
}
