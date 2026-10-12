import 'dart:math' as math;

import '../models/landmark.dart';

/// One Euro filter (Casiez, Roussel & Vogel, CHI 2012): a low-pass filter
/// whose cutoff rises with signal speed — smooth when still, responsive when
/// moving.
class OneEuroFilter {
  OneEuroFilter({this.minCutoff = 1.0, this.beta = 0.01, this.dCutoff = 1.0});

  /// Cutoff (Hz) when the signal is still. Lower = smoother, more lag.
  final double minCutoff;

  /// How fast the cutoff rises with speed. Higher = less lag when moving.
  final double beta;

  /// Cutoff (Hz) for the derivative estimate.
  final double dCutoff;

  double? _x;
  double _dx = 0;
  Duration? _t;

  static double _alpha(double cutoff, double dtSeconds) {
    final tau = 1 / (2 * math.pi * cutoff);
    return 1 / (1 + tau / dtSeconds);
  }

  double filter(double x, Duration t) {
    final prevX = _x, prevT = _t;
    if (prevX == null || prevT == null || t <= prevT) {
      // First sample, or a timestamp that doesn't move forward: start over.
      _x = x;
      _dx = 0;
      _t = t;
      return x;
    }
    final dt = (t - prevT).inMicroseconds / Duration.microsecondsPerSecond;
    final dx = (x - prevX) / dt;
    final aD = _alpha(dCutoff, dt);
    _dx = aD * dx + (1 - aD) * _dx;
    final cutoff = minCutoff + beta * _dx.abs();
    final a = _alpha(cutoff, dt);
    final filtered = a * x + (1 - a) * prevX;
    _x = filtered;
    _t = t;
    return filtered;
  }

  void reset() {
    _x = null;
    _dx = 0;
    _t = null;
  }
}

/// Smooths every landmark of a [PoseFrame] with its own One Euro filters.
///
/// Landmarks below the visibility threshold pass through untouched and reset
/// their filters, so a point that reappears isn't dragged from a stale spot.
class LandmarkSmoother {
  LandmarkSmoother({
    this.minCutoff = 1.0,
    this.beta = 0.01,
    this.maxGap = const Duration(milliseconds: 500),
  });

  final double minCutoff;
  final double beta;

  /// Frames further apart than this reset all filters (e.g. person left).
  final Duration maxGap;

  late final List<List<OneEuroFilter>> _filters = [
    for (var i = 0; i < BodyLandmark.values.length; i++)
      [
        for (var axis = 0; axis < 3; axis++)
          OneEuroFilter(minCutoff: minCutoff, beta: beta),
      ],
  ];
  Duration? _lastT;

  PoseFrame smooth(PoseFrame frame) {
    final t = frame.timestamp;
    final last = _lastT;
    if (last != null && (t - last > maxGap || t <= last)) reset();
    _lastT = t;

    return PoseFrame(
      timestamp: t,
      width: frame.width,
      height: frame.height,
      landmarks: [
        for (var i = 0; i < frame.landmarks.length; i++)
          _smoothOne(i, frame.landmarks[i], t),
      ],
    );
  }

  Landmark _smoothOne(int i, Landmark l, Duration t) {
    final f = _filters[i];
    if (!l.isVisible) {
      for (final axis in f) {
        axis.reset();
      }
      return l;
    }
    return Landmark(
      f[0].filter(l.x, t),
      f[1].filter(l.y, t),
      f[2].filter(l.z, t),
      l.visibility,
    );
  }

  void reset() {
    for (final f in _filters) {
      for (final axis in f) {
        axis.reset();
      }
    }
    _lastT = null;
  }
}
