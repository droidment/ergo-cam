import 'package:ergo_core/ergo_core.dart';
import 'package:ergocam/services/framing.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/poses.dart';

void main() {
  test('good side view needs no hint', () {
    expect(framingHint(poseWith(sideViewPoints())), isNull);
  });

  test('nobody in view shows the placement guide', () {
    expect(framingHint(null), contains(placementGuide));
  });

  test('feet missing', () {
    final m = sideViewPoints()
      ..remove(BodyLandmark.leftAnkle)
      ..remove(BodyLandmark.rightAnkle)
      ..remove(BodyLandmark.leftHeel)
      ..remove(BodyLandmark.rightHeel);
    expect(framingHint(poseWith(m)), startsWith('Feet not in frame'));
  });

  test('feet at the bottom edge', () {
    expect(
      framingHint(poseWith(sideViewPoints(dy: 170))),
      startsWith('Feet not in frame'),
    );
  });

  test('head at the top edge', () {
    expect(
      framingHint(poseWith(sideViewPoints(dy: -190))),
      startsWith('Head not in frame'),
    );
  });

  test('person too small', () {
    expect(
      framingHint(poseWith(sideViewPoints(scale: 0.3))),
      startsWith('Person looks small'),
    );
  });

  test('stooping is not mistaken for "too small" or "not side-on"', () {
    // Trunk horizontal: shoulders forward at hip height.
    final m = sideViewPoints()
      ..[BodyLandmark.leftShoulder] = (620, 690)
      ..[BodyLandmark.rightShoulder] = (620, 690)
      ..[BodyLandmark.leftEar] = (720 - 10, 700)
      ..[BodyLandmark.rightEar] = (720 - 10, 700);
    expect(framingHint(poseWith(m)), isNull);
  });

  test('facing the camera asks to turn side-on', () {
    final m = sideViewPoints()
      ..[BodyLandmark.leftShoulder] = (480, 330)
      ..[BodyLandmark.rightShoulder] = (240, 330);
    expect(framingHint(poseWith(m)), 'Turn side-on to the camera');
  });
}
