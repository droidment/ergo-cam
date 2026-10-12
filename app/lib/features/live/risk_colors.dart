import 'package:ergo_core/ergo_core.dart';
import 'package:flutter/material.dart';

/// The one place the green → red risk palette is defined.
abstract final class RiskColors {
  static const green = Color(0xFF43A047);
  static const yellow = Color(0xFFFDD835);
  static const orange = Color(0xFFFB8C00);
  static const red = Color(0xFFE53935);

  /// Skeleton colour when a part isn't scored (unscored frame, unseen arm).
  static const neutral = Color(0xFFB0BEC5);

  static Color region(RegionLevel level) => switch (level) {
    RegionLevel.low => green,
    RegionLevel.moderate => yellow,
    RegionLevel.elevated => orange,
    RegionLevel.high => red,
  };

  static Color reba(RebaRisk risk) => switch (risk) {
    RebaRisk.negligible => green,
    RebaRisk.low => green,
    RebaRisk.medium => yellow,
    RebaRisk.high => orange,
    RebaRisk.veryHigh => red,
  };

  static Color owas(int category) => switch (category) {
    1 => green,
    2 => yellow,
    3 => orange,
    _ => red,
  };

  /// Text colour that stays readable on [background].
  static Color onColor(Color background) =>
      background.computeLuminance() > 0.4 ? Colors.black : Colors.white;
}

/// OWAS action category wording.
String owasActionLabel(int category) => switch (category) {
  1 => 'No action',
  2 => 'Correct soon',
  3 => 'Correct ASAP',
  _ => 'Correct now',
};
