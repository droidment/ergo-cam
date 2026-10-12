import 'package:ergo_core/ergo_core.dart';
import 'package:test/test.dart';

import 'support/skeleton.dart';

Duration ms(int v) => Duration(milliseconds: v);

PoseFrame at(Skeleton s, Duration t) {
  final f = s.build();
  return PoseFrame(
    timestamp: t,
    width: f.width,
    height: f.height,
    landmarks: f.landmarks,
  );
}

void main() {
  const none = SessionInputs();

  test('neutral standing scores low end to end', () {
    final s = Skeleton(neck: 5, elbow: 5, cameraTiltDeg: 5);
    final r = FrameScorer().score(
      at(s, ms(0)),
      up: s.up,
      inputs: none,
      timestamp: ms(0),
    );
    expect(r.isScored, isTrue, reason: r.unscoredReason);
    expect(r.reba!.score, 1);
    expect(r.owas!.code.code, '1121');
    expect(r.owas!.actionCategory, 1);
    expect(r.regions!.trunk, RegionLevel.low);
    expect(r.frameConfidence, closeTo(0.95, 1e-9));
    expect(r.pose, isNotNull);
  });

  test('loaded squat lift (G4b) scores high end to end', () {
    final s = Skeleton(trunk: 40, neck: 25, knee: 100, upperArm: 30, elbow: 20);
    final r = FrameScorer().score(
      at(s, ms(0)),
      up: s.up,
      inputs: const SessionInputs(loadKg: 15, coupling: Coupling.fair),
      timestamp: ms(0),
    );
    expect(r.reba!.score, 8);
    expect(r.reba!.risk, RebaRisk.high);
    expect(r.regions!.legs, RegionLevel.elevated);
  });

  group('unscored', () {
    test('no person', () {
      final r = FrameScorer().score(
        null,
        up: const Vec2(0, -1),
        inputs: none,
        timestamp: ms(0),
      );
      expect(r.isScored, isFalse);
      expect(r.unscoredReason, 'No person detected');
      expect(r.pose, isNull);
      expect(r.frameConfidence, 0);
    });

    test('no vertical reference keeps the pose for drawing', () {
      final s = Skeleton();
      final r = FrameScorer().score(
        at(s, ms(0)),
        up: null,
        inputs: none,
        timestamp: ms(0),
      );
      expect(r.isScored, isFalse);
      expect(r.unscoredReason, contains('upright'));
      expect(r.pose, isNotNull);
      expect(r.reba, isNull);
    });

    test('low-confidence landmark gives the reason and confidence', () {
      final s = Skeleton(hidden: {BodyLandmark.leftWrist});
      final r = FrameScorer().score(
        at(s, ms(0)),
        up: s.up,
        inputs: none,
        timestamp: ms(0),
      );
      expect(r.unscoredReason, contains('wrist'));
      expect(r.frameConfidence, greaterThan(0));
      expect(r.frameConfidence, lessThan(0.95));
    });
  });

  group('hysteresis across dropouts', () {
    final hover = Skeleton(trunk: 22); // inside the ±3° margin of 20°
    final lean = Skeleton(trunk: 18);

    // Each test drives one scorer: 18° (score 2), then 22° held at 2 by
    // hysteresis, then an unscored gap, then 22° again.
    int trunkAfterGap(Duration gap) {
      final scorer = FrameScorer(smoother: LandmarkSmoother(beta: 1e6));
      scorer.score(
        at(lean, ms(0)),
        up: lean.up,
        inputs: none,
        timestamp: ms(0),
      );
      final held = scorer.score(
        at(hover, ms(33)),
        up: hover.up,
        inputs: none,
        timestamp: ms(33),
      );
      expect(held.reba!.trunk, 2);
      scorer.score(null, up: hover.up, inputs: none, timestamp: ms(66));
      final t = ms(33) + gap;
      return scorer
          .score(at(hover, t), up: hover.up, inputs: none, timestamp: t)
          .reba!
          .trunk;
    }

    test('a brief dropout keeps the held band', () {
      expect(trunkAfterGap(ms(300)), 2);
    });

    test('a long dropout resets it', () {
      expect(trunkAfterGap(ms(900)), 3);
    });
  });

  test('landmarks are smoothed between frames', () {
    final scorer = FrameScorer();
    final s = Skeleton();
    final first = at(s, ms(0));
    scorer.score(first, up: s.up, inputs: none, timestamp: ms(0));
    final moved = PoseFrame(
      timestamp: ms(33),
      width: first.width,
      height: first.height,
      landmarks: [
        for (final l in first.landmarks)
          Landmark(l.x + 20, l.y, l.z, l.visibility),
      ],
    );
    final r = scorer.score(moved, up: s.up, inputs: none, timestamp: ms(33));
    final raw = moved[BodyLandmark.leftHip].x;
    expect(r.pose![BodyLandmark.leftHip].x, lessThan(raw));
  });
}
