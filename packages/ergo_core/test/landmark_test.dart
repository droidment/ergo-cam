import 'package:ergo_core/ergo_core.dart';
import 'package:test/test.dart';

void main() {
  group('Landmark visibility', () {
    test('threshold is 0.5 per SCORING.md', () {
      expect(minLandmarkVisibility, 0.5);
    });

    test('at threshold is visible, just below is not', () {
      expect(const Landmark(0, 0, 0, 0.5).isVisible, isTrue);
      expect(const Landmark(0, 0, 0, 0.4999).isVisible, isFalse);
    });

    test('missing landmark is never visible', () {
      expect(Landmark.missing.isVisible, isFalse);
    });
  });

  group('PoseFrame', () {
    List<Landmark> all() => [
      for (var i = 0; i < 33; i++) Landmark(i.toDouble(), 0, 0, 1),
    ];

    test('BlazePose has 33 landmarks in model order', () {
      expect(BodyLandmark.values, hasLength(33));
      expect(BodyLandmark.nose.index, 0);
      expect(BodyLandmark.leftShoulder.index, 11);
      expect(BodyLandmark.leftHip.index, 23);
      expect(BodyLandmark.rightFootIndex.index, 32);
    });

    test('looks up landmarks by body part', () {
      final f = PoseFrame(
        timestamp: Duration.zero,
        width: 720,
        height: 1280,
        landmarks: all(),
      );
      expect(f[BodyLandmark.leftHip].x, 23);
    });

    test('rejects a frame without exactly 33 landmarks', () {
      expect(
        () => PoseFrame(
          timestamp: Duration.zero,
          width: 1,
          height: 1,
          landmarks: all().sublist(1),
        ),
        throwsArgumentError,
      );
    });

    test('landmark list is immutable', () {
      final f = PoseFrame(
        timestamp: Duration.zero,
        width: 1,
        height: 1,
        landmarks: all(),
      );
      expect(() => f.landmarks[0] = Landmark.missing, throwsUnsupportedError);
    });
  });
}
