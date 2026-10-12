import 'package:ergo_core/ergo_core.dart';
import 'package:ergocam/features/session/setup_sheet.dart';
import 'package:ergocam/providers/live_session_provider.dart';
import 'package:ergocam/providers/session_setup_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeLive extends LiveSessionController {
  @override
  LiveState build() => const LiveState();
}

void main() {
  late ProviderContainer container;

  Future<void> pumpSheet(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    container = ProviderContainer(
      overrides: [liveSessionProvider.overrideWith(_FakeLive.new)],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: SetupSheet())),
      ),
    );
  }

  SessionSetup setup() => container.read(sessionSetupProvider);

  testWidgets('task and load flow into the session inputs', (tester) async {
    await pumpSheet(tester);
    await tester.enterText(find.byKey(const Key('task-name')), 'Unload van');
    await tester.enterText(find.byKey(const Key('load-kg')), '12.5');
    expect(setup().taskName, 'Unload van');
    expect(setup().inputs.loadKg, 12.5);

    await tester.enterText(find.byKey(const Key('load-kg')), '');
    expect(setup().inputs.loadKg, 0);
  });

  testWidgets('coupling, stance and toggles update inputs', (tester) async {
    await pumpSheet(tester);
    await tester.tap(find.text('Fair'));
    await tester.tap(find.byKey(const Key('stance-oneLeg')));
    await tester.tap(find.byKey(const Key('wrist-flexed')));
    await tester.tap(find.byKey(const Key('static')));
    await tester.pump();

    final i = setup().inputs;
    expect(i.coupling, Coupling.fair);
    expect(i.unilateralStance, isTrue);
    expect(i.wristFlexedOver15, isTrue);
    expect(i.activityScore, 1);

    await tester.tap(find.byKey(const Key('stance-sitting')));
    await tester.pump();
    expect(setup().inputs.sitting, isTrue);
    expect(setup().inputs.unilateralStance, isFalse);
  });

  testWidgets('reset asks first, then clears everything', (tester) async {
    await pumpSheet(tester);
    await tester.tap(find.byKey(const Key('shock')));
    await tester.tap(find.byKey(const Key('setup-reset')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Reset'));
    await tester.pumpAndSettle();
    expect(setup().inputs.shockOrRapidForce, isFalse);
  });

  group('Stance', () {
    test('round-trips through SessionInputs', () {
      for (final s in Stance.values) {
        expect(Stance.of(s.applyTo(const SessionInputs())), s);
      }
    });

    test('assumptions list manual toggles only', () {
      const s = SessionSetup(
        inputs: SessionInputs(loadKg: 20, wristDeviatedOrTwisted: true),
      );
      expect(s.assumptions, ['wrist deviated']);
    });
  });
}
