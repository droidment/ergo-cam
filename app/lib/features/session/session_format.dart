import 'package:ergo_core/ergo_core.dart';

/// `m:ss`, or `h:mm:ss` from an hour.
String formatClock(Duration d) {
  String two(int v) => v.toString().padLeft(2, '0');
  final h = d.inHours, m = d.inMinutes % 60, s = d.inSeconds % 60;
  return h > 0 ? '$h:${two(m)}:${two(s)}' : '$m:${two(s)}';
}

String formatPercent(double? share) =>
    share == null ? '–' : '${(share * 100).round()}%';

String formatDateTime(DateTime t) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${t.year}-${two(t.month)}-${two(t.day)} '
      '${two(t.hour)}:${two(t.minute)}';
}

/// The frame showing at [t]: the last one at or before it, unless the log
/// has a gap longer than [maxGap] there (then nothing is drawn).
FrameScore? frameAt(
  List<FrameScore> log,
  Duration t, {
  Duration maxGap = const Duration(milliseconds: 250),
}) {
  var lo = 0, hi = log.length - 1, found = -1;
  while (lo <= hi) {
    final mid = (lo + hi) >> 1;
    if (log[mid].timestamp <= t) {
      found = mid;
      lo = mid + 1;
    } else {
      hi = mid - 1;
    }
  }
  if (found < 0) return null;
  final f = log[found];
  return t - f.timestamp > maxGap ? null : f;
}
