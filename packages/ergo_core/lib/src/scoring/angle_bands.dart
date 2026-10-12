/// Splits an angle range into scored bands at fixed cut points.
///
/// Band `i` lies between `cuts[i - 1]` and `cuts[i]`. A value exactly on a
/// cut belongs to the lower band when `lowerInclusive[i]` is true, otherwise
/// to the upper one — so each REBA boundary can follow the published sheet.
class AngleBands {
  /// [lowerInclusive] has one entry per cut; [scores] one per band
  /// (`cuts.length + 1`). Checked by tests, as const constructors can't.
  const AngleBands({
    required this.cuts,
    required this.lowerInclusive,
    required this.scores,
  });

  final List<double> cuts;
  final List<bool> lowerInclusive;
  final List<int> scores;

  int get bandCount => scores.length;

  int bandOf(double v) {
    for (var i = 0; i < cuts.length; i++) {
      if (v < cuts[i] || (v == cuts[i] && lowerInclusive[i])) return i;
    }
    return cuts.length;
  }

  int scoreOf(double v) => scores[bandOf(v)];
}

/// Holds a band steady until the angle moves clearly past its edges, so a
/// score doesn't flicker when an angle hovers on a threshold.
class BandTracker {
  BandTracker(this.bands, {this.margin = 3});

  final AngleBands bands;

  /// Degrees the angle must pass beyond a band edge before the band changes.
  final double margin;

  int? _band;

  int update(double v) {
    final prev = _band;
    if (prev != null) {
      final lower = prev == 0 ? double.negativeInfinity : bands.cuts[prev - 1];
      final upper = prev == bands.cuts.length
          ? double.infinity
          : bands.cuts[prev];
      if (v >= lower - margin && v <= upper + margin) return prev;
    }
    return _band = bands.bandOf(v);
  }

  void reset() => _band = null;
}
