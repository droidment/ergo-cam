import '../angles/angle_calculator.dart';
import '../filters/one_euro.dart';
import '../math/vec2.dart';
import '../models/frame_score.dart';
import '../models/landmark.dart';
import '../models/session_inputs.dart';
import 'body_regions.dart';
import 'owas.dart';
import 'reba.dart';

/// The live scoring pipeline: smooth → angles → REBA (with hysteresis) →
/// OWAS → region levels. One instance per live session; feed it every
/// detection result in order.
class FrameScorer {
  FrameScorer({
    this.calculator = const AngleCalculator(),
    LandmarkSmoother? smoother,
    StableRebaScorer? reba,
    this.holdHysteresisFor = const Duration(milliseconds: 500),
  }) : _smoother = smoother ?? LandmarkSmoother(),
       _reba = reba ?? StableRebaScorer();

  final AngleCalculator calculator;
  final LandmarkSmoother _smoother;
  final StableRebaScorer _reba;

  /// Brief dropouts keep the REBA hysteresis state; longer ones reset it.
  final Duration holdHysteresisFor;

  Duration? _lastScoredAt;

  /// Scores [frame] (null = no person detected at [timestamp]).
  ///
  /// [up] is true vertical in image coordinates from the accelerometer; null
  /// when unknown (sensor not ready, or phone lying flat), which leaves the
  /// frame unscored rather than assuming the image's own vertical.
  FrameScore score(
    PoseFrame? frame, {
    required Vec2? up,
    required SessionInputs inputs,
    required Duration timestamp,
  }) {
    if (frame == null) {
      _smoother.reset();
      return _unscored(timestamp, 'No person detected');
    }
    final pose = _smoother.smooth(frame);
    if (up == null) {
      return _unscored(
        timestamp,
        'Hold the phone upright (no vertical reference)',
        pose: pose,
      );
    }

    final result = calculator.compute(pose, up: up);
    final angles = result.angles;
    if (angles == null) {
      return _unscored(
        timestamp,
        result.unscoredReason!,
        pose: pose,
        confidence: result.frameConfidence,
      );
    }

    _expireHysteresis(timestamp);
    _lastScoredAt = timestamp;
    final reba = _reba.score(angles, inputs);
    return FrameScore.scored(
      timestamp: timestamp,
      pose: pose,
      angles: angles,
      reba: reba,
      owas: scoreOwas(angles, inputs),
      regions: RegionLevels.of(reba),
    );
  }

  FrameScore _unscored(
    Duration t,
    String reason, {
    PoseFrame? pose,
    double? confidence,
  }) {
    _expireHysteresis(t);
    return FrameScore.unscored(
      timestamp: t,
      unscoredReason: reason,
      pose: pose,
      confidence: confidence,
    );
  }

  void _expireHysteresis(Duration now) {
    final last = _lastScoredAt;
    if (last != null && now - last > holdHysteresisFor) {
      _reba.reset();
      _lastScoredAt = null;
    }
  }

  /// Forget everything (new session, camera restarted).
  void reset() {
    _smoother.reset();
    _reba.reset();
    _lastScoredAt = null;
  }
}
