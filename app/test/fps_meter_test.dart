import 'package:ergocam/services/fps_meter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Duration ms(int v) => Duration(milliseconds: v);

  test('is 0 with fewer than two ticks', () {
    final m = FpsMeter();
    expect(m.fps, 0);
    m.tick(ms(0));
    expect(m.fps, 0);
  });

  test('measures a steady 20 fps', () {
    final m = FpsMeter();
    for (var t = 0; t <= 1000; t += 50) {
      m.tick(ms(t));
    }
    expect(m.fps, closeTo(20, 0.01));
  });

  test('forgets ticks older than the window', () {
    final m = FpsMeter();
    for (var t = 0; t <= 1000; t += 10) {
      m.tick(ms(t)); // 100 fps burst
    }
    for (var t = 1100; t <= 3000; t += 100) {
      m.tick(ms(t)); // then 10 fps
    }
    expect(m.fps, closeTo(10, 0.01));
  });

  test('reset clears history', () {
    final m = FpsMeter()
      ..tick(ms(0))
      ..tick(ms(100))
      ..reset();
    expect(m.fps, 0);
  });
}
