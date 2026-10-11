import 'package:flutter/services.dart';

const _deviceOrientationDegrees = {
  DeviceOrientation.portraitUp: 0,
  DeviceOrientation.landscapeLeft: 90,
  DeviceOrientation.portraitDown: 180,
  DeviceOrientation.landscapeRight: 270,
};

/// Clockwise rotation (0/90/180/270) that makes a raw camera frame upright for
/// the current device orientation. Follows the ML Kit Flutter sample.
///
/// On iOS the plugin's frames only need the sensor orientation.
int frameRotationDegrees({
  required int sensorOrientation,
  required DeviceOrientation deviceOrientation,
  required bool frontFacing,
  required bool isAndroid,
}) {
  if (!isAndroid) return sensorOrientation;
  final device = _deviceOrientationDegrees[deviceOrientation]!;
  return frontFacing
      ? (sensorOrientation + device) % 360
      : (sensorOrientation - device + 360) % 360;
}

/// Size of the frame after rotation, which is the space ML Kit reports
/// landmark coordinates in. Android swaps width/height for 90°/270°.
Size uprightFrameSize(
  Size raw,
  int rotationDegrees, {
  required bool isAndroid,
}) {
  final quarterTurn = rotationDegrees == 90 || rotationDegrees == 270;
  return isAndroid && quarterTurn ? Size(raw.height, raw.width) : raw;
}

/// Maps a point in upright frame coordinates onto a preview box of [canvas]
/// size that shows the same field of view. Mirrors horizontally for
/// front-facing cameras, whose preview is shown mirrored.
Offset frameToPreview(
  double x,
  double y, {
  required Size frame,
  required Size canvas,
  required bool mirror,
}) {
  final px = x * canvas.width / frame.width;
  final py = y * canvas.height / frame.height;
  return Offset(mirror ? canvas.width - px : px, py);
}
