import 'dart:collection';

/// Rate of events over a sliding time window.
class FpsMeter {
  FpsMeter({this.window = const Duration(seconds: 1)});

  final Duration window;
  final _ticks = Queue<Duration>();

  /// Records an event at [now] (monotonic time, e.g. a Stopwatch's elapsed).
  void tick(Duration now) {
    _ticks.addLast(now);
    while (now - _ticks.first > window) {
      _ticks.removeFirst();
    }
  }

  /// Events per second across the window; 0 until two events are seen.
  double get fps {
    if (_ticks.length < 2) return 0;
    final span = _ticks.last - _ticks.first;
    if (span <= Duration.zero) return 0;
    return (_ticks.length - 1) *
        Duration.microsecondsPerSecond /
        span.inMicroseconds;
  }

  void reset() => _ticks.clear();
}
