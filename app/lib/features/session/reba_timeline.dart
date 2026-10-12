import 'dart:math' as math;

import 'package:ergo_core/ergo_core.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../live/risk_colors.dart';
import 'session_format.dart';

/// REBA over time on the risk bands. Unscored stretches are gaps.
/// Tap or drag to seek when [onSeek] is set.
class RebaTimeline extends StatelessWidget {
  const RebaTimeline({
    super.key,
    required this.frames,
    this.position,
    this.onSeek,
    this.height = 160,
  });

  final List<FrameScore> frames;

  /// Draws a playhead at this time.
  final Duration? position;
  final ValueChanged<Duration>? onSeek;
  final double height;

  static double _s(Duration d) => d.inMilliseconds / 1000;

  @override
  Widget build(BuildContext context) {
    final spots = [
      for (final f in frames)
        f.isScored
            ? FlSpot(_s(f.timestamp), f.reba!.score.toDouble())
            : FlSpot.nullSpot,
    ];
    final maxX = math.max(
      frames.isEmpty ? 1.0 : _s(frames.last.timestamp),
      1.0,
    );
    final labelStyle = Theme.of(context).textTheme.labelSmall;

    HorizontalRangeAnnotation band(double y1, double y2, Color c) =>
        HorizontalRangeAnnotation(
          y1: y1,
          y2: y2,
          color: c.withValues(alpha: 0.18),
        );

    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: maxX,
          minY: 0,
          maxY: 15,
          clipData: const FlClipData.all(),
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          rangeAnnotations: RangeAnnotations(
            horizontalRangeAnnotations: [
              band(0, 3.5, RiskColors.green),
              band(3.5, 7.5, RiskColors.yellow),
              band(7.5, 10.5, RiskColors.orange),
              band(10.5, 15, RiskColors.red),
            ],
          ),
          extraLinesData: position == null
              ? null
              : ExtraLinesData(
                  verticalLines: [
                    VerticalLine(
                      x: _s(position!).clamp(0, maxX),
                      color: Theme.of(context).colorScheme.primary,
                      strokeWidth: 2,
                    ),
                  ],
                ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 4,
                reservedSize: 24,
                getTitlesWidget: (v, _) =>
                    Text(v.toInt().toString(), style: labelStyle),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 20,
                interval: math.max(1, (maxX / 5).ceilToDouble()),
                getTitlesWidget: (v, meta) {
                  // fl_chart always labels the axis end; skip it unless it
                  // falls on the interval, so it can't collide with the last
                  // regular label.
                  final interval = meta.appliedInterval;
                  if (v == meta.max && (v / interval) % 1 != 0) {
                    return const SizedBox.shrink();
                  }
                  return Text(
                    formatClock(Duration(milliseconds: (v * 1000).round())),
                    style: labelStyle,
                  );
                },
              ),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              color: Theme.of(context).colorScheme.onSurface,
              barWidth: 2,
              dotData: const FlDotData(show: false),
            ),
          ],
          lineTouchData: LineTouchData(
            enabled: onSeek != null,
            handleBuiltInTouches: false,
            touchSpotThreshold: 24,
            touchCallback: (event, response) {
              final seek = onSeek;
              final spot = response?.lineBarSpots?.firstOrNull;
              if (seek == null || spot == null) return;
              if (event is FlTapUpEvent ||
                  event is FlPanUpdateEvent ||
                  event is FlLongPressMoveUpdate) {
                seek(Duration(milliseconds: (spot.x * 1000).round()));
              }
            },
          ),
        ),
        duration: Duration.zero,
      ),
    );
  }
}
