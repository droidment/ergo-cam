/// Posture math for ErgoCam: angles, smoothing, REBA, OWAS and session stats.
///
/// Pure Dart — this library must never depend on Flutter.
library;

export 'src/angles/angle_calculator.dart';
export 'src/filters/one_euro.dart';
export 'src/io/csv.dart';
export 'src/io/frame_json.dart';
export 'src/math/vec2.dart';
export 'src/models/frame_score.dart';
export 'src/models/joint_angles.dart';
export 'src/models/landmark.dart';
export 'src/models/session_inputs.dart';
export 'src/scoring/angle_bands.dart';
export 'src/scoring/body_regions.dart';
export 'src/scoring/frame_scorer.dart';
export 'src/scoring/owas.dart';
export 'src/scoring/owas_tables.dart';
export 'src/scoring/reba.dart';
export 'src/scoring/reba_tables.dart';
export 'src/stats/summary.dart';
export 'src/version.dart';
