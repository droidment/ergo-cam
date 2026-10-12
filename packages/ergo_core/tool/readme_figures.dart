// Generates the README figures from the real scoring engine:
//
//   cd packages/ergo_core && dart run tool/readme_figures.dart ../../docs/images
//
// Poses are synthetic (test/support/skeleton.dart) but every score, colour
// and statistic is computed by ergo_core, exactly as the app would.
import 'dart:io';

import 'package:ergo_core/ergo_core.dart';

import '../test/support/skeleton.dart';

const _bg = '#102027';
const _panel = '#1b2b33';
const _text = '#eceff1';
const _muted = '#90a4ae';

String _levelColor(RegionLevel l) => switch (l) {
  RegionLevel.low => '#43A047',
  RegionLevel.moderate => '#FDD835',
  RegionLevel.elevated => '#FB8C00',
  RegionLevel.high => '#E53935',
};

String _rebaColor(RebaRisk r) => switch (r) {
  RebaRisk.negligible || RebaRisk.low => '#43A047',
  RebaRisk.medium => '#FDD835',
  RebaRisk.high => '#FB8C00',
  RebaRisk.veryHigh => '#E53935',
};

String _onColor(String hex) =>
    const {'#FDD835', '#43A047'}.contains(hex) ? '#000000' : '#ffffff';

String _esc(String s) =>
    s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');

FrameScore _score(
  Skeleton s,
  SessionInputs inputs, {
  FrameScorer? scorer,
  Duration t = Duration.zero,
}) {
  final f = s.build();
  return (scorer ?? FrameScorer()).score(
    PoseFrame(
      timestamp: t,
      width: f.width,
      height: f.height,
      landmarks: f.landmarks,
    ),
    up: s.up,
    inputs: inputs,
    timestamp: t,
  );
}

/// Near-side bones drawn per region (side view, facing right).
const _bones = [
  (BodyLandmark.leftHip, BodyLandmark.leftKnee, BodyRegion.legs),
  (BodyLandmark.leftKnee, BodyLandmark.leftAnkle, BodyRegion.legs),
  (BodyLandmark.leftAnkle, BodyLandmark.leftFootIndex, BodyRegion.legs),
  (BodyLandmark.leftHeel, BodyLandmark.leftFootIndex, BodyRegion.legs),
  (BodyLandmark.leftShoulder, BodyLandmark.leftHip, BodyRegion.trunk),
  (BodyLandmark.leftShoulder, BodyLandmark.leftEar, BodyRegion.neck),
  (BodyLandmark.leftShoulder, BodyLandmark.leftElbow, BodyRegion.upperArm),
  (BodyLandmark.leftElbow, BodyLandmark.leftWrist, BodyRegion.lowerArm),
];

const _limbRegions = {
  BodyRegion.legs,
  BodyRegion.upperArm,
  BodyRegion.lowerArm,
};

const _panelW = 380.0, _panelH = 440.0, _figTop = 140.0, _ground = 410.0;

/// Bounding box of the drawn landmarks (plus head radius), in pose units.
(double, double, double, double) _bounds(PoseFrame p) {
  final pts = [
    for (final (a, b, _) in _bones) ...[p[a], p[b]],
  ];
  final xs = pts.map((l) => l.x), ys = pts.map((l) => l.y);
  return (
    xs.reduce((a, b) => a < b ? a : b) - 8,
    ys.reduce((a, b) => a < b ? a : b) - 8,
    xs.reduce((a, b) => a > b ? a : b) + 8,
    ys.reduce((a, b) => a > b ? a : b),
  );
}

/// One posture panel: skeleton in region colours plus a HUD-style badge.
/// Far-side limbs are drawn faded and offset to show depth.
String _posturePanel({
  required double x,
  required double scale,
  required String title,
  required String subtitle,
  required FrameScore score,
  bool box = false,
}) {
  final p = score.pose!, r = score.regions!, reba = score.reba!;
  final owas = score.owas!;
  final (minX, _, maxX, maxY) = _bounds(p);
  final cx = x + _panelW / 2 - (minX + maxX) / 2 * scale;
  final cy = _ground - maxY * scale;
  (double, double) pt(BodyLandmark b, {double dx = 0, double dy = 0}) =>
      (cx + p[b].x * scale + dx, cy + p[b].y * scale + dy);

  RegionLevel level(BodyRegion region) => switch (region) {
    BodyRegion.trunk => r.trunk,
    BodyRegion.neck => r.neck,
    BodyRegion.legs => r.legs,
    BodyRegion.upperArm => r.nearArm.upperArm,
    BodyRegion.lowerArm => r.nearArm.lowerArm,
  };

  String line(
    BodyLandmark a,
    BodyLandmark b,
    String color, {
    double dx = 0,
    double dy = 0,
    double opacity = 1,
    double width = 9,
  }) {
    final (x1, y1) = pt(a, dx: dx, dy: dy);
    final (x2, y2) = pt(b, dx: dx, dy: dy);
    return '<line x1="${x1.toStringAsFixed(1)}" y1="${y1.toStringAsFixed(1)}" '
        'x2="${x2.toStringAsFixed(1)}" y2="${y2.toStringAsFixed(1)}" '
        'stroke="$color" stroke-opacity="$opacity" stroke-width="$width" '
        'stroke-linecap="round"/>';
  }

  final far = [
    for (final (a, b, region) in _bones)
      if (_limbRegions.contains(region))
        line(
          a,
          b,
          _levelColor(level(region)),
          dx: 10,
          dy: -6,
          opacity: .35,
          width: 7,
        ),
  ];
  final near = [
    for (final (a, b, region) in _bones) line(a, b, _levelColor(level(region))),
  ];
  final joints = [
    for (final b in [
      BodyLandmark.leftShoulder,
      BodyLandmark.leftElbow,
      BodyLandmark.leftWrist,
      BodyLandmark.leftHip,
      BodyLandmark.leftKnee,
      BodyLandmark.leftAnkle,
    ])
      () {
        final (jx, jy) = pt(b);
        return '<circle cx="${jx.toStringAsFixed(1)}" cy="${jy.toStringAsFixed(1)}" '
            'r="5.5" fill="#fff" stroke="#000" stroke-opacity=".5"/>';
      }(),
  ];
  final (ex, ey) = pt(BodyLandmark.leftEar);
  final (wx, wy) = pt(BodyLandmark.leftWrist);
  final boxSvg = box
      ? '<rect x="${(wx - 30).toStringAsFixed(1)}" y="${(wy - 6).toStringAsFixed(1)}" '
            'width="60" height="46" rx="5" fill="#ffffff22" stroke="#fff" '
            'stroke-width="4"/>'
      : '';
  final badge = _rebaColor(reba.risk);
  return '''
  <g>
    <rect x="$x" y="0" width="$_panelW" height="$_panelH" rx="18" fill="$_panel"/>
    <text x="${x + 20}" y="34" fill="$_text" font-size="20" font-weight="700">${_esc(title)}</text>
    <text x="${x + 20}" y="58" fill="$_muted" font-size="14">${_esc(subtitle)}</text>
    <rect x="${x + 20}" y="74" width="64" height="48" rx="10" fill="$badge"/>
    <text x="${x + 52}" y="108" fill="${_onColor(badge)}" font-size="28" font-weight="800" text-anchor="middle">${reba.score}</text>
    <text x="${x + 96}" y="94" fill="$_muted" font-size="13">REBA</text>
    <text x="${x + 96}" y="115" fill="$_text" font-size="17" font-weight="700">${reba.risk.label}</text>
    <text x="${x + 200}" y="94" fill="$_muted" font-size="13">OWAS ${owas.code.code}</text>
    <text x="${x + 200}" y="115" fill="$_text" font-size="17" font-weight="700">Action category ${owas.actionCategory}</text>
    <line x1="${x + 30}" y1="${_ground + 6}" x2="${x + _panelW - 30}" y2="${_ground + 6}" stroke="$_muted" stroke-opacity=".4" stroke-width="2"/>
    ${far.join('\n    ')}
    $boxSvg
    ${near.join('\n    ')}
    <circle cx="${ex.toStringAsFixed(1)}" cy="${ey.toStringAsFixed(1)}" r="13" fill="#fff"/>
    ${joints.join('\n    ')}
  </g>''';
}

String postureFigure() {
  final standing = _score(
    Skeleton(neck: 5, upperArm: 10, elbow: 20),
    const SessionInputs(),
  );
  final squat = _score(
    Skeleton(
      trunk: 40,
      neck: 25,
      knee: 100,
      shinLean: 35,
      upperArm: 30,
      elbow: 20,
    ),
    const SessionInputs(loadKg: 15, coupling: Coupling.fair),
  );
  // Each figure fills its panel (a squat is naturally much more compact).
  double fit(PoseFrame p) {
    final (x0, y0, x1, y1) = _bounds(p);
    final sx = (_panelW - 120) / (x1 - x0);
    final sy = (_ground - _figTop - 20) / (y1 - y0);
    return sx < sy ? sx : sy;
  }

  return '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 800 460" font-family="Roboto, Segoe UI, Arial, sans-serif">
  <rect width="800" height="460" fill="$_bg"/>
  <g transform="translate(10,10)">
${_posturePanel(x: 0, scale: fit(standing.pose!), title: 'Standing upright', subtitle: 'No load · good grip', score: standing)}
${_posturePanel(x: 400, scale: fit(squat.pose!), title: 'Squat lift', subtitle: '15 kg · fair grip · looking at the load', score: squat, box: true)}
  </g>
</svg>
''';
}

/// A simulated 30 s session: stand, squat-lift a 15 kg box, stand, stoop,
/// a brief occlusion (unscored), stand. Scored by FrameScorer at 10 Hz.
List<FrameScore> simulatedSession() {
  const inputs = SessionInputs(loadKg: 15, coupling: Coupling.fair);
  final scorer = FrameScorer();
  final log = <FrameScore>[];
  double lerp(double a, double b, double t) => a + (b - a) * t.clamp(0, 1);
  for (var i = 0; i <= 300; i++) {
    final s = i / 10;
    final t = Duration(milliseconds: i * 100);
    // Occluded: the person walks behind a rack.
    if (s >= 21 && s < 22.5) {
      log.add(scorer.score(null, up: null, inputs: inputs, timestamp: t));
      continue;
    }
    double trunk = 0, knee = 0, neck = 5, ua = 5, elbow = 10;
    if (s >= 6 && s < 9) {
      final k = (s - 6) / 3; // going down into the squat
      trunk = lerp(0, 40, k);
      knee = lerp(0, 100, k);
      neck = lerp(5, 25, k);
      ua = lerp(5, 30, k);
    } else if (s >= 9 && s < 12) {
      trunk = 40;
      knee = 100;
      neck = 25;
      ua = 30;
      elbow = 20;
    } else if (s >= 12 && s < 15) {
      final k = (s - 12) / 3; // standing up with the box
      trunk = lerp(40, 5, k);
      knee = lerp(100, 5, k);
      neck = lerp(25, 10, k);
      ua = lerp(30, 20, k);
      elbow = lerp(20, 80, k);
    } else if (s >= 15 && s < 18) {
      ua = 20;
      elbow = 85; // carrying at waist height
    } else if (s >= 18 && s < 21) {
      final k = s < 19 ? s - 18 : 1.0; // stooping to put it down
      trunk = lerp(0, 75, k);
      neck = lerp(5, 25, k);
      knee = 10;
      ua = lerp(20, 80, k);
    }
    log.add(
      _score(
        Skeleton(
          trunk: trunk,
          neck: neck,
          knee: knee,
          upperArm: ua,
          elbow: elbow,
        ),
        inputs,
        scorer: scorer,
        t: t,
      ),
    );
  }
  return log;
}

String timelineFigure(List<FrameScore> log, SessionSummary s) {
  const w = 800.0, h = 300.0, left = 46.0, right = 16.0, top = 40.0;
  const bottom = 46.0;
  final plotW = w - left - right, plotH = h - top - bottom;
  final maxT = log.last.timestamp.inMilliseconds / 1000;
  double x(double sec) => left + sec / maxT * plotW;
  double y(num v) => top + plotH - v / 15 * plotH;

  String band(double y1, double y2, String c) =>
      '<rect x="$left" y="${y(y2)}" width="$plotW" height="${y(y1) - y(y2)}" '
      'fill="$c" fill-opacity=".16"/>';

  // Polyline segments, broken at unscored frames.
  final segments = <List<String>>[[]];
  for (final f in log) {
    if (!f.isScored) {
      if (segments.last.isNotEmpty) segments.add([]);
      continue;
    }
    final sec = f.timestamp.inMilliseconds / 1000;
    segments.last.add(
      '${x(sec).toStringAsFixed(1)},${y(f.reba!.score).toStringAsFixed(1)}',
    );
  }
  final lines = [
    for (final seg in segments)
      if (seg.isNotEmpty)
        '<polyline points="${seg.join(' ')}" fill="none" stroke="$_text" '
            'stroke-width="2.5" stroke-linejoin="round"/>',
  ];

  String note(double sec, String label, double atY) =>
      '<text x="${x(sec)}" y="$atY" fill="$_muted" font-size="12" '
      'text-anchor="middle">${_esc(label)}</text>';

  final xTicks = [
    for (var sec = 0; sec <= maxT; sec += 5)
      '<text x="${x(sec.toDouble())}" y="${h - bottom + 18}" fill="$_muted" '
          'font-size="12" text-anchor="middle">0:${sec.toString().padLeft(2, '0')}</text>',
  ];
  final yTicks = [
    for (final v in [0, 4, 8, 12, 15])
      '<text x="${left - 8}" y="${y(v) + 4}" fill="$_muted" font-size="12" '
          'text-anchor="end">$v</text>',
  ];
  final gapStart = x(21), gapEnd = x(22.5);

  return '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 $w $h" font-family="Roboto, Segoe UI, Arial, sans-serif">
  <rect width="$w" height="$h" fill="$_bg"/>
  <text x="$left" y="24" fill="$_text" font-size="16" font-weight="700">REBA over a simulated 30 s session (15 kg box, fair grip)</text>
  ${band(0, 3.5, '#43A047')}
  ${band(3.5, 7.5, '#FDD835')}
  ${band(7.5, 10.5, '#FB8C00')}
  ${band(10.5, 15, '#E53935')}
  <rect x="$gapStart" y="$top" width="${gapEnd - gapStart}" height="$plotH" fill="#000" fill-opacity=".35"/>
  ${lines.join('\n  ')}
  ${yTicks.join('\n  ')}
  ${xTicks.join('\n  ')}
  ${note(3, 'standing', y(1) - 10)}
  ${note(10.5, 'squat lift', y(8) - 10)}
  ${note(16.5, 'carrying', y(4) - 26)}
  ${note(19.8, 'stoop', y(9) - 30)}
  ${note(21.75, 'unscored', top + 16)}
  ${note(26.5, 'standing', y(4) - 26)}
  <text x="${w - right}" y="${h - 8}" fill="$_muted" font-size="11" text-anchor="end">Bands: green low · yellow medium · orange high · red very high. Generated by ergo_core (tool/readme_figures.dart).</text>
</svg>
''';
}

String goldensFigure() {
  final rows = <(String, String, SessionInputs, Skeleton)>[
    (
      'G1',
      'Neutral standing',
      const SessionInputs(),
      Skeleton(neck: 5, elbow: 5),
    ),
    (
      'G2',
      'Bench reach',
      const SessionInputs(),
      Skeleton(trunk: 15, neck: 15, upperArm: 50, elbow: 80),
    ),
    (
      'G3',
      'Stoop to floor',
      const SessionInputs(),
      Skeleton(trunk: 75, neck: 25, knee: 10, upperArm: 80, elbow: 10),
    ),
    (
      'G4',
      'Squat lift',
      const SessionInputs(),
      Skeleton(trunk: 40, neck: 10, knee: 100, upperArm: 30, elbow: 20),
    ),
    (
      'G4b',
      'Squat lift, 15 kg',
      const SessionInputs(loadKg: 15, coupling: Coupling.fair),
      Skeleton(trunk: 40, neck: 25, knee: 100, upperArm: 30, elbow: 20),
    ),
    (
      'G5',
      'Overhead reach',
      const SessionInputs(),
      Skeleton(neck: -25, upperArm: 120, elbow: 30),
    ),
  ];
  const w = 800.0, rowH = 40.0, left = 210.0, top = 46.0;
  final h = top + rows.length * rowH + 30;
  const barMax = 800.0 - left - 70;
  final bars = <String>[];
  for (var i = 0; i < rows.length; i++) {
    final (id, name, inputs, sk) = rows[i];
    final r = _score(sk, inputs);
    final reba = r.reba!;
    final yy = top + i * rowH;
    final bw = reba.score / 15 * barMax;
    final c = _rebaColor(reba.risk);
    bars.add(
      '''
  <text x="16" y="${yy + 24}" fill="$_text" font-size="15" font-weight="700">$id</text>
  <text x="56" y="${yy + 24}" fill="$_muted" font-size="14">${_esc(name)}</text>
  <rect x="$left" y="${yy + 8}" width="${bw.toStringAsFixed(1)}" height="24" rx="5" fill="$c"/>
  <text x="${left + bw + 8}" y="${yy + 25}" fill="$_text" font-size="14" font-weight="700">${reba.score} · ${reba.risk.label} · OWAS ${r.owas!.actionCategory}</text>''',
    );
  }
  return '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 $w $h" font-family="Roboto, Segoe UI, Arial, sans-serif">
  <rect width="$w" height="$h" fill="$_bg"/>
  <text x="16" y="28" fill="$_text" font-size="16" font-weight="700">Golden postures: REBA (bar, out of 15) and OWAS action category</text>
${bars.join()}
  <text x="16" y="${h - 10}" fill="$_muted" font-size="11">Load 0 and good grip unless stated. Values are asserted in packages/ergo_core/test/golden_postures_test.dart.</text>
</svg>
''';
}

void main(List<String> args) {
  final out = Directory(args.isEmpty ? '../../docs/images' : args.first)
    ..createSync(recursive: true);
  File('${out.path}/postures.svg').writeAsStringSync(postureFigure());
  final log = simulatedSession();
  final s = SessionSummary.of(log);
  File('${out.path}/timeline.svg').writeAsStringSync(timelineFigure(log, s));
  File('${out.path}/goldens.svg').writeAsStringSync(goldensFigure());
  stdout.writeln(
    'Simulated session: ${s.frames} frames, ${(s.scoredShare * 100).round()}% scored, '
    'REBA max ${s.rebaMax} (at ${s.peakAt!.inMilliseconds / 1000}s), '
    'P90 ${s.rebaP90}, mean ${s.rebaMean!.toStringAsFixed(1)}, '
    '>=8 ${(s.rebaHighShare! * 100).round()}%, OWAS max ${s.owasMax}, '
    'mean ${s.owasMean!.toStringAsFixed(1)}, >=3 ${(s.owasHighShare! * 100).round()}%',
  );
}
