/// REBA hand coupling quality.
enum Coupling {
  good(0),
  fair(1),
  poor(2),
  unacceptable(3);

  const Coupling(this.score);
  final int score;
}

/// Everything about a session that the camera can't measure reliably.
/// Set in the session setup sheet; defaults are the neutral case (load 0,
/// good coupling, no flags) so nothing inflates the score by default.
class SessionInputs {
  const SessionInputs({
    this.loadKg = 0,
    this.shockOrRapidForce = false,
    this.coupling = Coupling.good,
    this.staticPosture = false,
    this.repeatedSmallRange = false,
    this.rapidLargeChanges = false,
    this.trunkTwistOrSideBend = false,
    this.neckTwistOrSideBend = false,
    this.wristFlexedOver15 = false,
    this.wristDeviatedOrTwisted = false,
    this.armAbductedOrRotated = false,
    this.shoulderRaised = false,
    this.armSupported = false,
    this.unilateralStance = false,
    this.sitting = false,
    this.walking = false,
    this.kneeling = false,
  });

  /// Load or force handled, kg.
  final double loadKg;
  final bool shockOrRapidForce;
  final Coupling coupling;

  // REBA activity score (+1 each).
  /// A body part held static for more than a minute.
  final bool staticPosture;

  /// Small-range actions repeated more than 4× per minute.
  final bool repeatedSmallRange;

  /// Rapid large posture changes or an unstable base.
  final bool rapidLargeChanges;

  // Manual toggles for what 2D side-view pose can't see.
  final bool trunkTwistOrSideBend;
  final bool neckTwistOrSideBend;
  final bool wristFlexedOver15;
  final bool wristDeviatedOrTwisted;
  final bool armAbductedOrRotated;
  final bool shoulderRaised;
  final bool armSupported;

  /// Weight on one leg, or an unstable stance (REBA legs 2).
  final bool unilateralStance;
  final bool sitting;
  final bool walking;
  final bool kneeling;

  int get activityScore =>
      (staticPosture ? 1 : 0) +
      (repeatedSmallRange ? 1 : 0) +
      (rapidLargeChanges ? 1 : 0);
}
