import 'dart:io';

import 'package:ergo_core/ergo_core.dart';
import 'package:ergocam/features/session/sessions_screen.dart';
import 'package:ergocam/features/session/summary_screen.dart';
import 'package:ergocam/providers/sessions_provider.dart';
import 'package:ergocam/services/session_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

FrameScore frame(int ms, {required double knee, required double kg}) {
  final angles = JointAngles(
    trunkFlexion: 40,
    neckFlexion: 25,
    kneeFlexion: knee,
    nearArm: const ArmAngles(upperArmFlexion: 30, elbowFlexion: 20),
  );
  final inputs = SessionInputs(loadKg: kg, coupling: Coupling.fair);
  final reba = scoreReba(angles, inputs);
  return FrameScore.scored(
    timestamp: Duration(milliseconds: ms),
    pose: null,
    angles: angles,
    reba: reba,
    owas: scoreOwas(angles, inputs),
    regions: RegionLevels.of(reba),
  );
}

void main() {
  late Directory tmp;
  late SessionStore store;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('ergocam_summary_');
    store = SessionStore(Directory('${tmp.path}/sessions'));
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  /// Screens get their data through provider overrides; real file I/O
  /// doesn't complete under the widget-test clock (the store has its own
  /// tests in session_store_test.dart).
  Future<void> pump(
    WidgetTester tester,
    Widget home, {
    List<SessionMeta> sessions = const [],
    Map<String, List<FrameScore>> frames = const {},
  }) async {
    tester.view.physicalSize = const Size(1080, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        key: UniqueKey(),
        overrides: [
          sessionStoreProvider.overrideWith((_) async => store),
          sessionsProvider.overrideWith((_) async => sessions),
          sessionFramesProvider.overrideWith(
            (_, id) async => frames[id] ?? const [],
          ),
        ],
        child: MaterialApp(home: home),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('summary shows the stats from the saved session', (tester) async {
    final log = [
      for (var i = 0; i < 9; i++) frame(i * 100, knee: 0, kg: 0),
      frame(900, knee: 100, kg: 15), // G4b-like: REBA 8
    ];
    late SessionMeta meta;
    await tester.runAsync(() async {
      meta = await store.save(
        taskName: 'Lift box',
        startedAt: DateTime(2026, 10, 12, 9, 0),
        inputs: const SessionInputs(loadKg: 15, coupling: Coupling.fair),
        frames: log,
      );
    });
    expect(meta.summary.rebaMax, 8);

    await pump(tester, SummaryScreen(meta: meta), frames: {meta.id: log});
    expect(find.text('Lift box'), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('stat-reba-max'))).data,
      '8',
    );
    expect(find.text('REBA ≥ 8'), findsOneWidget);
    // 1 of 10 frames is REBA ≥ 8, and the same frame is the only OWAS ≥ 3
    // (2142 → 3; the unloaded 2121 frames → 2).
    expect(find.text('10%'), findsNWidgets(2));
    expect(find.text('No video'), findsOneWidget); // saved without video
    expect(find.byKey(const Key('share-data')), findsOneWidget);
  });

  testWidgets('session list shows saved sessions, or an empty state', (
    tester,
  ) async {
    await pump(tester, const SessionsScreen());
    expect(find.byKey(const Key('no-sessions')), findsOneWidget);

    late SessionMeta meta;
    await tester.runAsync(() async {
      meta = await store.save(
        taskName: 'Unload van',
        startedAt: DateTime(2026, 10, 12, 10, 0),
        inputs: const SessionInputs(),
        frames: [frame(0, knee: 0, kg: 0)],
      );
    });
    await pump(tester, const SessionsScreen(), sessions: [meta]);
    expect(find.text('Unload van'), findsOneWidget);
    // REBA max badge: unloaded frame, fair grip → A 4, B 2 + 1 = 3, C(4,3) = 4.
    expect(find.text('4'), findsOneWidget);
  });
}
