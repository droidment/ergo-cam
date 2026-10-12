import 'dart:convert';

import 'package:ergo_core/ergo_core.dart';
import 'package:test/test.dart';

import 'support/skeleton.dart';

Duration ms(int v) => Duration(milliseconds: v);

FrameScore scoredFrame(
  Duration t, {
  double trunk = 0,
  double knee = 0,
  double upperArm = 0,
  bool farArm = false,
  SessionInputs inputs = const SessionInputs(),
}) {
  final s = Skeleton(
    trunk: trunk,
    knee: knee,
    upperArm: upperArm,
    elbow: 80,
    farVisible: farArm,
  );
  final f = s.build();
  final r = FrameScorer().score(
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
  expect(r.isScored, isTrue, reason: r.unscoredReason);
  return r;
}

FrameScore unscored(Duration t) => FrameScore.unscored(
  timestamp: t,
  unscoredReason: 'Low-confidence left wrist, "quoted"',
  confidence: 0.42,
);

void main() {
  group('frame JSON', () {
    test('scored frame round-trips through JSON text', () {
      final f = scoredFrame(
        ms(1234),
        trunk: 40,
        knee: 100,
        upperArm: 95,
        farArm: true,
        inputs: const SessionInputs(loadKg: 15, coupling: Coupling.fair),
      );
      final json =
          jsonDecode(jsonEncode(frameScoreToJson(f))) as Map<String, Object?>;
      final back = frameScoreFromJson(json);

      expect(back.timestamp, ms(1234));
      expect(back.isScored, isTrue);
      expect(back.reba!.toString(), f.reba!.toString());
      expect(back.reba!.farArm!.upperArm, f.reba!.farArm!.upperArm);
      expect(back.owas!.code, f.owas!.code);
      expect(back.owas!.actionCategory, f.owas!.actionCategory);
      expect(back.angles!.trunkFlexion, closeTo(f.angles!.trunkFlexion, 0.01));
      expect(back.angles!.farArm, isNotNull);
      expect(back.regions!.legs, f.regions!.legs);
      expect(back.pose!.landmarks, hasLength(33));
      expect(
        back.pose![BodyLandmark.leftHip].x,
        closeTo(f.pose![BodyLandmark.leftHip].x, 0.05),
      );
      expect(back.frameConfidence, closeTo(f.frameConfidence, 0.001));
    });

    test('uses the documented wire-format keys', () {
      final j = frameScoreToJson(scoredFrame(ms(0)));
      expect(
        j.keys,
        containsAll([
          't',
          'lm',
          'angles',
          'reba',
          'owas',
          'scored',
          'confidence',
        ]),
      );
      expect((j['reba']! as Map)['score'], 1);
      expect((j['owas']! as Map)['code'], '1121');
      expect((j['lm']! as List).first, hasLength(4));
    });

    test('unscored frame keeps its reason and has no scores', () {
      final back = frameScoreFromJson(
        jsonDecode(jsonEncode(frameScoreToJson(unscored(ms(5)))))
            as Map<String, Object?>,
      );
      expect(back.isScored, isFalse);
      expect(back.unscoredReason, contains('wrist'));
      expect(back.frameConfidence, 0.42);
      expect(back.pose, isNull);
    });

    test('at() moves a frame in time and keeps everything else', () {
      final f = scoredFrame(ms(900));
      final g = f.at(ms(100));
      expect(g.timestamp, ms(100));
      expect(g.reba, same(f.reba));
      expect(g.pose, same(f.pose));
    });
  });

  group('session inputs JSON', () {
    test('round-trips every field', () {
      const i = SessionInputs(
        loadKg: 12.5,
        shockOrRapidForce: true,
        coupling: Coupling.poor,
        staticPosture: true,
        rapidLargeChanges: true,
        trunkTwistOrSideBend: true,
        wristDeviatedOrTwisted: true,
        armSupported: true,
        kneeling: true,
      );
      final back = sessionInputsFromJson(
        jsonDecode(jsonEncode(sessionInputsToJson(i))) as Map<String, Object?>,
      );
      expect(sessionInputsToJson(back), sessionInputsToJson(i));
    });

    test('missing keys load as neutral defaults', () {
      final i = sessionInputsFromJson({});
      expect(i.loadKg, 0);
      expect(i.coupling, Coupling.good);
    });
  });

  group('SessionSummary', () {
    test('nearest-rank P90', () {
      expect(nearestRankPercentile([1, 2, 3, 4, 5, 6, 7, 8, 9, 10], 0.9), 9);
      expect(nearestRankPercentile([5], 0.9), 5);
      expect(nearestRankPercentile([3, 1, 2], 0.9), 3);
      expect(nearestRankPercentile([1, 1, 1, 1, 1, 1, 1, 1, 1, 12], 0.9), 1);
    });

    test('stats over scored frames, unscored share reported', () {
      // REBA 1 standing ×6, 8 loaded squat ×2, 2 unscored.
      const loaded = SessionInputs(loadKg: 15, coupling: Coupling.fair);
      final log = [
        for (var i = 0; i < 6; i++) scoredFrame(ms(i * 100)),
        unscored(ms(600)),
        scoredFrame(
          ms(700),
          trunk: 40,
          knee: 100,
          upperArm: 30,
          inputs: loaded,
        ),
        scoredFrame(
          ms(800),
          trunk: 40,
          knee: 100,
          upperArm: 30,
          inputs: loaded,
        ),
        unscored(ms(900)),
      ];
      expect(
        log[7].reba!.score,
        7,
      ); // neck 1 here: A = 5 + load 2 = 7; B = 1 + fair 1 = 2; C(7,2) = 7

      final s = SessionSummary.of(log);
      expect(s.frames, 10);
      expect(s.scoredFrames, 8);
      expect(s.scoredShare, 0.8);
      expect(s.duration, ms(900));
      expect(s.rebaMax, 7);
      expect(s.rebaP90, 7);
      expect(s.rebaMean, closeTo((6 * 1 + 2 * 7) / 8, 1e-9));
      expect(s.rebaHighShare, 0); // nothing ≥ 8
      expect(s.owasMax, 3);
      expect(s.owasHighShare, closeTo(2 / 8, 1e-9));
      expect(s.peakAt, ms(700));
    });

    test('no scored frames gives null stats, not zeros', () {
      final s = SessionSummary.of([unscored(ms(0)), unscored(ms(500))]);
      expect(s.hasScores, isFalse);
      expect(s.rebaMax, isNull);
      expect(s.rebaMean, isNull);
      expect(s.duration, ms(500));
    });

    test('round-trips through JSON', () {
      final s = SessionSummary.of([scoredFrame(ms(0)), scoredFrame(ms(40))]);
      final back = SessionSummary.fromJson(
        jsonDecode(jsonEncode(s.toJson())) as Map<String, Object?>,
      );
      expect(back.toJson(), s.toJson());
    });
  });

  group('CSV', () {
    test('header plus one row per frame, CRLF, quoted reason', () {
      final csv = framesToCsv([scoredFrame(ms(1500)), unscored(ms(1600))]);
      final lines = csv.split('\r\n');
      expect(lines.last, isEmpty); // trailing CRLF
      expect(lines, hasLength(4));
      expect(lines[0], frameCsvHeader.join(','));
      final row = lines[1].split(',');
      expect(row, hasLength(frameCsvHeader.length));
      expect(row[0], '1.500');
      expect(row[frameCsvHeader.indexOf('reba')], '1');
      expect(row[frameCsvHeader.indexOf('owas_code')], '1121');
      expect(lines[2], contains('"Low-confidence left wrist, ""quoted"""'));
      expect(lines[2], startsWith('1.600,0,'));
    });
  });
}
