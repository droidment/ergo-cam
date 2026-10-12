import '../scoring/body_regions.dart';
import '../scoring/owas.dart';
import '../scoring/reba.dart';
import 'joint_angles.dart';
import 'landmark.dart';

/// Everything known about one camera frame: the smoothed pose to draw, and
/// either a full score or the reason it couldn't be scored.
class FrameScore {
  const FrameScore.scored({
    required this.timestamp,
    required this.pose,
    required JointAngles this.angles,
    required RebaResult this.reba,
    required OwasResult this.owas,
    required RegionLevels this.regions,
  }) : unscoredReason = null,
       confidence = null;

  const FrameScore.unscored({
    required this.timestamp,
    required String this.unscoredReason,
    this.pose,
    this.confidence,
  }) : angles = null,
       reba = null,
       owas = null,
       regions = null;

  final Duration timestamp;

  /// Smoothed landmarks, or null when no person was detected.
  final PoseFrame? pose;

  final JointAngles? angles;
  final RebaResult? reba;
  final OwasResult? owas;
  final RegionLevels? regions;
  final String? unscoredReason;
  final double? confidence;

  bool get isScored => reba != null;

  /// Mean visibility of the landmarks the score relies on, 0–1 (0 when
  /// nothing was measured).
  double get frameConfidence => angles?.confidence ?? confidence ?? 0;
}
