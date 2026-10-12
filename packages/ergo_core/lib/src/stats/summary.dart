import '../models/frame_score.dart';

/// REBA at or above this counts as a high-risk frame.
const rebaHighThreshold = 8;

/// OWAS action category at or above this counts as a high-risk frame.
const owasHighThreshold = 3;

/// Value at [fraction] (0–1] of [values] by the nearest-rank method:
/// the smallest value with at least that fraction of values ≤ it.
num nearestRankPercentile(List<num> values, double fraction) {
  if (values.isEmpty) throw ArgumentError('no values');
  final sorted = [...values]..sort();
  final rank = (fraction * sorted.length).ceil().clamp(1, sorted.length);
  return sorted[rank - 1];
}

/// Statistics over a recorded session. Scores use scored frames only; the
/// share of unscored frames is reported alongside so gaps aren't hidden.
/// Percentages are by frame count (frames arrive at a roughly steady rate).
class SessionSummary {
  const SessionSummary({
    required this.duration,
    required this.frames,
    required this.scoredFrames,
    this.rebaMax,
    this.rebaP90,
    this.rebaMean,
    this.rebaHighShare,
    this.owasMax,
    this.owasMean,
    this.owasHighShare,
    this.peakAt,
  });

  factory SessionSummary.of(List<FrameScore> log) {
    final scored = log.where((f) => f.isScored).toList();
    final duration = log.isEmpty
        ? Duration.zero
        : log.last.timestamp - log.first.timestamp;
    if (scored.isEmpty) {
      return SessionSummary(
        duration: duration,
        frames: log.length,
        scoredFrames: 0,
      );
    }
    final reba = [for (final f in scored) f.reba!.score];
    final owas = [for (final f in scored) f.owas!.actionCategory];
    final rebaMax = reba.reduce((a, b) => a > b ? a : b);
    double mean(List<int> v) => v.reduce((a, b) => a + b) / v.length;
    double share(List<int> v, int threshold) =>
        v.where((x) => x >= threshold).length / v.length;

    return SessionSummary(
      duration: duration,
      frames: log.length,
      scoredFrames: scored.length,
      rebaMax: rebaMax,
      rebaP90: nearestRankPercentile(reba, 0.9).toInt(),
      rebaMean: mean(reba),
      rebaHighShare: share(reba, rebaHighThreshold),
      owasMax: owas.reduce((a, b) => a > b ? a : b),
      owasMean: mean(owas),
      owasHighShare: share(owas, owasHighThreshold),
      peakAt: scored.firstWhere((f) => f.reba!.score == rebaMax).timestamp,
    );
  }

  factory SessionSummary.fromJson(Map<String, Object?> j) {
    int? i(String k) => (j[k] as num?)?.toInt();
    double? d(String k) => (j[k] as num?)?.toDouble();
    return SessionSummary(
      duration: Duration(milliseconds: i('durationMs') ?? 0),
      frames: i('frames') ?? 0,
      scoredFrames: i('scoredFrames') ?? 0,
      rebaMax: i('rebaMax'),
      rebaP90: i('rebaP90'),
      rebaMean: d('rebaMean'),
      rebaHighShare: d('rebaHighShare'),
      owasMax: i('owasMax'),
      owasMean: d('owasMean'),
      owasHighShare: d('owasHighShare'),
      peakAt: i('peakAtMs') == null
          ? null
          : Duration(milliseconds: i('peakAtMs')!),
    );
  }

  final Duration duration;
  final int frames;
  final int scoredFrames;

  // Null when no frame was scored.
  final int? rebaMax;
  final int? rebaP90;
  final double? rebaMean;

  /// Share of scored frames with REBA ≥ [rebaHighThreshold], 0–1.
  final double? rebaHighShare;
  final int? owasMax;
  final double? owasMean;

  /// Share of scored frames with OWAS category ≥ [owasHighThreshold], 0–1.
  final double? owasHighShare;

  /// When the maximum REBA first occurred.
  final Duration? peakAt;

  bool get hasScores => scoredFrames > 0;

  /// Share of frames that could be scored, 0–1.
  double get scoredShare => frames == 0 ? 0 : scoredFrames / frames;

  Map<String, Object?> toJson() => {
    'durationMs': duration.inMilliseconds,
    'frames': frames,
    'scoredFrames': scoredFrames,
    'rebaMax': rebaMax,
    'rebaP90': rebaP90,
    'rebaMean': rebaMean,
    'rebaHighShare': rebaHighShare,
    'owasMax': owasMax,
    'owasMean': owasMean,
    'owasHighShare': owasHighShare,
    'peakAtMs': peakAt?.inMilliseconds,
  };
}
