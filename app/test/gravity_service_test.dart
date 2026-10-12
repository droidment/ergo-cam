import 'dart:math' as math;

import 'package:ergo_core/ergo_core.dart';
import 'package:ergocam/services/gravity_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const g = 9.81;

void expectVec(Vec2? v, double x, double y) {
  expect(v, isNotNull);
  expect(v!.x, closeTo(x, 1e-9), reason: 'x of $v');
  expect(v.y, closeTo(y, 1e-9), reason: 'y of $v');
}

void main() {
  group('imageUpFromGravity, phone held upright', () {
    test('portrait up', () {
      expectVec(
        imageUpFromGravity(
          const DeviceGravity(0, g, 0),
          DeviceOrientation.portraitUp,
        ),
        0,
        -1,
      );
    });

    test('landscape left (top edge pointing left)', () {
      // Up is along the device's +x (former right edge).
      expectVec(
        imageUpFromGravity(
          const DeviceGravity(g, 0, 0),
          DeviceOrientation.landscapeLeft,
        ),
        0,
        -1,
      );
    });

    test('landscape right (top edge pointing right)', () {
      expectVec(
        imageUpFromGravity(
          const DeviceGravity(-g, 0, 0),
          DeviceOrientation.landscapeRight,
        ),
        0,
        -1,
      );
    });

    test('portrait down', () {
      expectVec(
        imageUpFromGravity(
          const DeviceGravity(0, -g, 0),
          DeviceOrientation.portraitDown,
        ),
        0,
        -1,
      );
    });
  });

  test('portrait rolled 10° clockwise: true up leans left in the image', () {
    final r = 10 * math.pi / 180;
    final up = imageUpFromGravity(
      DeviceGravity(-g * math.sin(r), g * math.cos(r), 0),
      DeviceOrientation.portraitUp,
    );
    expectVec(up, -math.sin(r), -math.cos(r));
  });

  test('pitch toward the floor does not change the image vertical', () {
    final up = imageUpFromGravity(
      const DeviceGravity(0, g * 0.6, g * 0.8),
      DeviceOrientation.portraitUp,
    );
    expectVec(up, 0, -1);
  });

  test('flat phone has no image vertical', () {
    expect(
      imageUpFromGravity(
        const DeviceGravity(0.5, 0.5, g),
        DeviceOrientation.portraitUp,
      ),
      isNull,
    );
  });

  group('GravityLowPass', () {
    test('first sample passes through', () {
      final g0 = GravityLowPass().update(1, 2, 3);
      expect([g0.x, g0.y, g0.z], [1, 2, 3]);
    });

    test('shake is damped and the reading settles on gravity', () {
      final lp = GravityLowPass()..update(0, g, 0);
      final shaken = lp.update(5, g, 0); // one 5 m/s² jolt
      expect(shaken.x, closeTo(0.5, 1e-9));
      late DeviceGravity settled;
      for (var i = 0; i < 100; i++) {
        settled = lp.update(0, g, 0);
      }
      expect(settled.x, closeTo(0, 1e-3));
    });
  });
}
