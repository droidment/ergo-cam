import 'package:ergo_core/ergo_core.dart';
import 'package:ergocam/services/pose_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

void main() {
  test('every ergo_core landmark maps to the same ML Kit landmark', () {
    expect(BodyLandmark.values, hasLength(PoseLandmarkType.values.length));
    for (final b in BodyLandmark.values) {
      final t = mlKitLandmarkType(b);
      expect(t.name, b.name);
      expect(t.index, b.index, reason: 'BlazePose index order must match');
    }
  });
}
