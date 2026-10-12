import 'dart:math' as math;

import 'package:ergo_core/ergo_core.dart';
import 'package:test/test.dart';

import 'support/skeleton.dart';

Duration frameAt(int i, {int fps = 30}) =>
    Duration(microseconds: i * Duration.microsecondsPerSecond ~/ fps);

void main() {
  group('OneEuroFilter', () {
    test('first sample passes through', () {
      expect(OneEuroFilter().filter(42, Duration.zero), 42);
    });

    test('constant signal stays constant', () {
      final f = OneEuroFilter();
      for (var i = 0; i < 30; i++) {
        expect(f.filter(10, frameAt(i)), closeTo(10, 1e-9));
      }
    });

    test('reduces jitter on a still point', () {
      final f = OneEuroFilter();
      final rnd = math.Random(1);
      double variance(List<double> v) {
        final mean = v.reduce((a, b) => a + b) / v.length;
        return v.map((x) => (x - mean) * (x - mean)).reduce((a, b) => a + b) /
            v.length;
      }

      final raw = [
        for (var i = 0; i < 300; i++) 100 + rnd.nextDouble() * 6 - 3,
      ];
      final out = [
        for (var i = 0; i < raw.length; i++) f.filter(raw[i], frameAt(i)),
      ];
      expect(variance(out.sublist(30)), lessThan(variance(raw) * 0.2));
    });

    test('follows a fast move with modest lag', () {
      final f = OneEuroFilter();
      var out = 0.0;
      for (var i = 0; i <= 15; i++) {
        out = f.filter(i * 20.0, frameAt(i)); // 600 px/s sweep
      }
      // Within 15% of the true position after half a second.
      expect(out, closeTo(300, 45));
    });

    test('settles on a new position after a step', () {
      final f = OneEuroFilter()..filter(0, Duration.zero);
      var out = 0.0;
      for (var i = 1; i <= 60; i++) {
        out = f.filter(100, frameAt(i));
      }
      expect(out, closeTo(100, 1));
    });

    test('non-increasing timestamp restarts the filter', () {
      final f = OneEuroFilter()
        ..filter(0, frameAt(1))
        ..filter(0, frameAt(2));
      expect(f.filter(50, frameAt(2)), 50);
    });

    test('reset forgets history', () {
      final f = OneEuroFilter()
        ..filter(0, frameAt(0))
        ..reset();
      expect(f.filter(80, frameAt(1)), 80);
    });
  });

  group('LandmarkSmoother', () {
    PoseFrame shifted(PoseFrame f, double dx, Duration t, {Set<int>? hide}) =>
        PoseFrame(
          timestamp: t,
          width: f.width,
          height: f.height,
          landmarks: [
            for (var i = 0; i < f.landmarks.length; i++)
              Landmark(
                f.landmarks[i].x + dx,
                f.landmarks[i].y,
                0,
                hide?.contains(i) ?? false ? 0.1 : f.landmarks[i].visibility,
              ),
          ],
        );

    final base = Skeleton().build();
    final shoulder = BodyLandmark.leftShoulder;

    test('smooths visible landmarks toward the new position', () {
      final s = LandmarkSmoother();
      s.smooth(shifted(base, 0, frameAt(0)));
      final out = s.smooth(shifted(base, 10, frameAt(1)));
      final raw = base[shoulder].x;
      expect(out[shoulder].x, greaterThan(raw));
      expect(out[shoulder].x, lessThan(raw + 10));
    });

    test('keeps visibility and passes hidden landmarks through untouched', () {
      final s = LandmarkSmoother();
      s.smooth(shifted(base, 0, frameAt(0)));
      final out = s.smooth(
        shifted(base, 10, frameAt(1), hide: {shoulder.index}),
      );
      expect(out[shoulder].x, base[shoulder].x + 10);
      expect(out[shoulder].visibility, 0.1);
      expect(out[BodyLandmark.leftHip].visibility, 0.95);
    });

    test('a long gap resets so the pose jumps instead of gliding', () {
      final s = LandmarkSmoother();
      s.smooth(shifted(base, 0, frameAt(0)));
      final out = s.smooth(shifted(base, 50, const Duration(seconds: 2)));
      expect(out[shoulder].x, base[shoulder].x + 50);
    });
  });
}
