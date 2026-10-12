import 'package:ergo_core/ergo_core.dart';
import 'package:test/test.dart';

void main() {
  test('every band set is well formed', () {
    const all = {
      'trunk': rebaTrunkBands,
      'neck': rebaNeckBands,
      'upperArm': rebaUpperArmBands,
      'lowerArm': rebaLowerArmBands,
      'knee': rebaKneeBands,
      'owasBack': owasBackBentBands,
      'owasArm': owasArmRaisedBands,
      'owasKnee': owasKneeBentBands,
    };
    all.forEach((name, b) {
      expect(b.lowerInclusive, hasLength(b.cuts.length), reason: name);
      expect(b.scores, hasLength(b.cuts.length + 1), reason: name);
      for (var i = 1; i < b.cuts.length; i++) {
        expect(b.cuts[i], greaterThan(b.cuts[i - 1]), reason: name);
      }
    });
  });

  group('AngleBands', () {
    const b = AngleBands(
      cuts: [10, 20],
      lowerInclusive: [true, false],
      scores: [1, 2, 3],
    );

    test('places values between cuts', () {
      expect(b.bandOf(-100), 0);
      expect(b.bandOf(15), 1);
      expect(b.bandOf(100), 2);
    });

    test('values on a cut follow lowerInclusive', () {
      expect(b.bandOf(10), 0); // inclusive: stays low
      expect(b.bandOf(20), 2); // exclusive: goes up
    });

    test('scoreOf maps through scores', () {
      expect(b.scoreOf(15), 2);
    });
  });

  group('BandTracker hysteresis', () {
    test('holds a band within the margin past its edge', () {
      final t = BandTracker(rebaTrunkBands); // cut at 20°
      expect(rebaTrunkBands.scores[t.update(18)], 2);
      expect(rebaTrunkBands.scores[t.update(22)], 2); // 22 < 20 + 3
      expect(rebaTrunkBands.scores[t.update(19)], 2);
      expect(rebaTrunkBands.scores[t.update(23.5)], 3); // clearly past
      expect(rebaTrunkBands.scores[t.update(18)], 3); // 18 > 20 − 3
      expect(rebaTrunkBands.scores[t.update(16.5)], 2);
    });

    test('a big jump moves straight to the right band', () {
      final t = BandTracker(rebaTrunkBands);
      t.update(0);
      expect(rebaTrunkBands.scores[t.update(75)], 4);
    });

    test('reset drops the held band', () {
      final t = BandTracker(rebaTrunkBands)..update(22);
      t.reset();
      expect(rebaTrunkBands.scores[t.update(18)], 2);
    });
  });
}
