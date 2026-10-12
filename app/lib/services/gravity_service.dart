import 'dart:math' as math;

import 'package:ergo_core/ergo_core.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// Gravity in device axes (m/s²): x to the right edge and y to the top edge
/// in natural portrait, z out of the screen. At rest the accelerometer reads
/// +g pointing up, so this vector points to true up.
class DeviceGravity {
  const DeviceGravity(this.x, this.y, this.z);

  final double x;
  final double y;
  final double z;
}

/// Exponential low-pass that keeps gravity and drops hand shake.
class GravityLowPass {
  GravityLowPass({this.alpha = 0.1});

  /// Weight of each new sample; 0.1 at ~50 Hz ≈ 0.2 s time constant.
  final double alpha;
  DeviceGravity? _g;

  DeviceGravity update(double x, double y, double z) {
    final g = _g;
    return _g = g == null
        ? DeviceGravity(x, y, z)
        : DeviceGravity(
            g.x + alpha * (x - g.x),
            g.y + alpha * (y - g.y),
            g.z + alpha * (z - g.z),
          );
  }
}

/// Below this in-plane gravity (m/s²) the phone is too close to flat for the
/// image to have a meaningful vertical (camera looking at floor or ceiling).
const minInPlaneGravity = 2.0;

/// True up in upright image coordinates (x right, y down), for an image
/// shown upright in [orientation]. Null when the phone is nearly flat.
Vec2? imageUpFromGravity(DeviceGravity g, DeviceOrientation orientation) {
  if (math.sqrt(g.x * g.x + g.y * g.y) < minInPlaneGravity) return null;
  final up = switch (orientation) {
    DeviceOrientation.portraitUp => Vec2(g.x, -g.y),
    DeviceOrientation.portraitDown => Vec2(-g.x, g.y),
    // Top edge to the left: device +y is the viewer's left, +x is up.
    DeviceOrientation.landscapeLeft => Vec2(-g.y, -g.x),
    // Top edge to the right: device +y is the viewer's right, +x is down.
    DeviceOrientation.landscapeRight => Vec2(g.y, g.x),
  };
  return up.normalized;
}

/// Smoothed device gravity from the accelerometer, ~50 Hz.
final deviceGravityProvider = StreamProvider.autoDispose<DeviceGravity>((ref) {
  final lowPass = GravityLowPass();
  return accelerometerEventStream(samplingPeriod: SensorInterval.gameInterval)
      .map((e) => lowPass.update(e.x, e.y, e.z));
});
