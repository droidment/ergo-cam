import '../models/frame_score.dart';

/// Column order of [framesToCsv].
const frameCsvHeader = [
  't_s',
  'scored',
  'reason',
  'confidence',
  'reba',
  'risk',
  'score_a',
  'score_b',
  'table_c',
  'trunk',
  'neck',
  'legs',
  'load',
  'upper_arm',
  'lower_arm',
  'wrist',
  'coupling',
  'activity',
  'owas_code',
  'owas_category',
  'side',
  'trunk_flex',
  'neck_flex',
  'knee_flex',
  'upper_arm_near',
  'elbow_near',
  'upper_arm_far',
  'elbow_far',
];

/// One row per frame (RFC 4180: comma-separated, CRLF line ends, quoted
/// where needed). Unscored frames leave the score columns empty.
String framesToCsv(List<FrameScore> frames) {
  final rows = <List<Object?>>[frameCsvHeader];
  String n(double? v) => v == null ? '' : v.toStringAsFixed(1);
  for (final f in frames) {
    final r = f.reba, a = f.angles, o = f.owas;
    rows.add([
      (f.timestamp.inMilliseconds / 1000).toStringAsFixed(3),
      f.isScored ? 1 : 0,
      f.unscoredReason,
      f.frameConfidence.toStringAsFixed(3),
      r?.score,
      r?.risk.name,
      r?.scoreA,
      r?.scoreB,
      r?.tableC,
      r?.trunk,
      r?.neck,
      r?.legs,
      r?.load,
      r?.upperArm,
      r?.lowerArm,
      r?.wrist,
      r?.coupling,
      r?.activity,
      o?.code.code,
      o?.actionCategory,
      a?.side.name,
      n(a?.trunkFlexion),
      n(a?.neckFlexion),
      n(a?.kneeFlexion),
      n(a?.nearArm.upperArmFlexion),
      n(a?.nearArm.elbowFlexion),
      n(a?.farArm?.upperArmFlexion),
      n(a?.farArm?.elbowFlexion),
    ]);
  }
  final body = rows.map((r) => r.map(_cell).join(',')).join('\r\n');
  return '$body\r\n';
}

String _cell(Object? v) {
  final s = v?.toString() ?? '';
  if (s.contains(RegExp('[",\r\n]'))) return '"${s.replaceAll('"', '""')}"';
  return s;
}
