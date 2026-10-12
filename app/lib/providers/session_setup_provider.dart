import 'package:ergo_core/ergo_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// How the worker is supported. Mutually exclusive in the setup sheet; maps
/// onto the stance flags of [SessionInputs].
enum Stance {
  bothFeet('Both feet'),
  oneLeg('One leg'),
  sitting('Sitting'),
  kneeling('Kneeling'),
  walking('Walking');

  const Stance(this.label);
  final String label;

  static Stance of(SessionInputs i) => i.sitting
      ? sitting
      : i.kneeling
      ? kneeling
      : i.walking
      ? walking
      : i.unilateralStance
      ? oneLeg
      : bothFeet;

  SessionInputs applyTo(SessionInputs i) => i.copyWith(
    unilateralStance: this == oneLeg,
    sitting: this == sitting,
    kneeling: this == kneeling,
    walking: this == walking,
  );
}

/// What the assessor enters before (or during) a live session.
@immutable
class SessionSetup {
  const SessionSetup({this.taskName = '', this.inputs = const SessionInputs()});

  final String taskName;
  final SessionInputs inputs;

  SessionSetup copyWith({String? taskName, SessionInputs? inputs}) =>
      SessionSetup(
        taskName: taskName ?? this.taskName,
        inputs: inputs ?? this.inputs,
      );

  /// Manual posture toggles that are on. These are assumptions, not
  /// measurements, and are flagged as such in the HUD and reports.
  List<String> get assumptions {
    final i = inputs;
    return [
      if (i.trunkTwistOrSideBend) 'trunk twist/side bend',
      if (i.neckTwistOrSideBend) 'neck twist/side bend',
      if (i.wristFlexedOver15) 'wrist >15°',
      if (i.wristDeviatedOrTwisted) 'wrist deviated',
      if (i.armAbductedOrRotated) 'arm abducted',
      if (i.shoulderRaised) 'shoulder raised',
      if (i.armSupported) 'arm supported',
      if (Stance.of(i) != Stance.bothFeet) Stance.of(i).label.toLowerCase(),
    ];
  }
}

/// Session setup, in memory for now (saved with sessions in Phase 4).
class SessionSetupController extends Notifier<SessionSetup> {
  @override
  SessionSetup build() => const SessionSetup();

  void setTaskName(String name) => state = state.copyWith(taskName: name);

  void updateInputs(SessionInputs Function(SessionInputs) change) =>
      state = state.copyWith(inputs: change(state.inputs));

  void reset() => state = const SessionSetup();
}

final sessionSetupProvider =
    NotifierProvider<SessionSetupController, SessionSetup>(
      SessionSetupController.new,
    );
