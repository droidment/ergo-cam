import 'package:ergo_core/ergo_core.dart';
import 'package:ergocam/features/live/hud.dart';
import 'package:ergocam/providers/live_session_provider.dart';
import 'package:ergocam/providers/session_setup_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/poses.dart';

/// G4b: loaded squat lift — REBA 8 (high), OWAS 2142.
FrameScore loadedSquat(SessionInputs inputs) {
  const angles = JointAngles(
    trunkFlexion: 40,
    neckFlexion: 25,
    kneeFlexion: 100,
    nearArm: ArmAngles(upperArmFlexion: 30, elbowFlexion: 20),
    confidence: 0.92,
  );
  final reba = scoreReba(angles, inputs);
  return FrameScore.scored(
    timestamp: Duration.zero,
    pose: poseWith(sideViewPoints()),
    angles: angles,
    reba: reba,
    owas: scoreOwas(angles, inputs),
    regions: RegionLevels.of(reba),
  );
}

class _Setup extends SessionSetupController {
  _Setup(this.initial);
  final SessionSetup initial;
  @override
  SessionSetup build() => initial;
}

Future<void> pumpHud(
  WidgetTester tester,
  FrameScore? score, {
  SessionSetup setup = const SessionSetup(),
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [sessionSetupProvider.overrideWith(() => _Setup(setup))],
      child: MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.black,
          body: LiveHud(
            state: LiveState(status: CameraStatus.running, score: score),
            onSetup: () {},
          ),
        ),
      ),
    ),
  );
}

void main() {
  const loaded = SessionInputs(loadKg: 15, coupling: Coupling.fair);

  testWidgets('scored frame shows REBA, risk band, OWAS and confidence', (
    tester,
  ) async {
    await pumpHud(
      tester,
      loadedSquat(loaded),
      setup: const SessionSetup(taskName: 'Lift box', inputs: loaded),
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('reba-score')),
        matching: find.text('8'),
      ),
      findsOneWidget,
    );
    expect(find.text('High'), findsOneWidget);
    expect(find.text('OWAS 2142'), findsOneWidget);
    expect(find.text('3 · Correct ASAP'), findsOneWidget);
    expect(find.text('Confidence 92%'), findsOneWidget);
    expect(find.text('Lift box · 15 kg · fair grip'), findsOneWidget);
    expect(find.byKey(const Key('unscored')), findsNothing);
    expect(find.byKey(const Key('placement-hint')), findsNothing);
  });

  testWidgets('unscored frame shows the reason and never a number', (
    tester,
  ) async {
    await pumpHud(
      tester,
      FrameScore.unscored(
        timestamp: Duration.zero,
        unscoredReason: 'Low-confidence left wrist',
        pose: poseWith(sideViewPoints()),
        confidence: 0.6,
      ),
    );
    expect(find.text('Unscored'), findsOneWidget);
    expect(find.text('Low-confidence left wrist'), findsOneWidget);
    expect(find.byKey(const Key('reba-score')), findsNothing);
    expect(find.byKey(const Key('owas-code')), findsNothing);
    expect(find.byKey(const Key('placement-hint')), findsOneWidget);
  });

  testWidgets('nobody in view shows the placement guide', (tester) async {
    await pumpHud(
      tester,
      const FrameScore.unscored(
        timestamp: Duration.zero,
        unscoredReason: 'No person detected',
      ),
    );
    expect(
      find.textContaining('whole body in frame · 2–4 m away'),
      findsOneWidget,
    );
  });

  testWidgets('manual toggles are listed as assumptions', (tester) async {
    await pumpHud(
      tester,
      loadedSquat(const SessionInputs()),
      setup: const SessionSetup(
        inputs: SessionInputs(trunkTwistOrSideBend: true, sitting: true),
      ),
    );
    expect(
      find.text('Assumed: trunk twist/side bend, sitting'),
      findsOneWidget,
    );
  });
}
