import 'package:ergocam/services/frame_geometry.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('frameRotationDegrees (Android back camera, sensor 90°)', () {
    int rot(DeviceOrientation o) => frameRotationDegrees(
      sensorOrientation: 90,
      deviceOrientation: o,
      frontFacing: false,
      isAndroid: true,
    );

    test('portrait up rotates 90°', () {
      expect(rot(DeviceOrientation.portraitUp), 90);
    });
    test('landscape left needs no rotation', () {
      expect(rot(DeviceOrientation.landscapeLeft), 0);
    });
    test('landscape right rotates 180°', () {
      expect(rot(DeviceOrientation.landscapeRight), 180);
    });
    test('portrait down rotates 270°', () {
      expect(rot(DeviceOrientation.portraitDown), 270);
    });
  });

  test('front camera adds device rotation instead of subtracting', () {
    expect(
      frameRotationDegrees(
        sensorOrientation: 270,
        deviceOrientation: DeviceOrientation.landscapeLeft,
        frontFacing: true,
        isAndroid: true,
      ),
      0,
    );
  });

  test('iOS uses sensor orientation as-is', () {
    expect(
      frameRotationDegrees(
        sensorOrientation: 90,
        deviceOrientation: DeviceOrientation.landscapeLeft,
        frontFacing: false,
        isAndroid: false,
      ),
      90,
    );
  });

  group('uprightFrameSize', () {
    const raw = Size(1280, 720);
    test('swaps for quarter turns on Android', () {
      expect(uprightFrameSize(raw, 90, isAndroid: true), const Size(720, 1280));
      expect(
        uprightFrameSize(raw, 270, isAndroid: true),
        const Size(720, 1280),
      );
    });
    test('keeps size for 0° and 180°', () {
      expect(uprightFrameSize(raw, 0, isAndroid: true), raw);
      expect(uprightFrameSize(raw, 180, isAndroid: true), raw);
    });
    test('never swaps on iOS', () {
      expect(uprightFrameSize(raw, 90, isAndroid: false), raw);
    });
  });

  group('frameToPreview', () {
    const frame = Size(720, 1280);
    const canvas = Size(360, 640);

    test('scales frame coordinates onto the preview', () {
      expect(
        frameToPreview(720, 1280, frame: frame, canvas: canvas, mirror: false),
        const Offset(360, 640),
      );
      expect(
        frameToPreview(180, 320, frame: frame, canvas: canvas, mirror: false),
        const Offset(90, 160),
      );
    });

    test('mirrors x only', () {
      expect(
        frameToPreview(180, 320, frame: frame, canvas: canvas, mirror: true),
        const Offset(270, 160),
      );
    });
  });
}
