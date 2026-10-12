import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../../providers/live_session_provider.dart';

/// Performance readout and model toggle shown over the live preview.
class LiveHud extends StatelessWidget {
  const LiveHud({super.key, required this.state, required this.onModel});

  final LiveState state;
  final ValueChanged<PoseDetectionModel> onModel;

  /// Phase 1 target: the skeleton must update at least this often.
  static const targetPoseFps = 15.0;

  @override
  Widget build(BuildContext context) {
    final pose = state.pose;
    final mono = Theme.of(context).textTheme.bodySmall!.copyWith(
      color: Colors.white,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final fpsColor = state.poseFps >= targetPoseFps
        ? Colors.greenAccent
        : Colors.orangeAccent;

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pose ${state.poseFps.toStringAsFixed(1)} fps',
                    key: const Key('pose-fps'),
                    style: mono.copyWith(
                      color: fpsColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Cam ${state.cameraFps.toStringAsFixed(0)} fps · '
                    'dropped ${state.droppedFrames}',
                    style: mono,
                  ),
                  Text(
                    pose == null
                        ? 'No person detected'
                        : 'Frame ${pose.width.toInt()}×${pose.height.toInt()}',
                    style: mono.copyWith(color: Colors.white70),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          SegmentedButton<PoseDetectionModel>(
            showSelectedIcon: false,
            style: SegmentedButton.styleFrom(
              backgroundColor: Colors.black54,
              visualDensity: VisualDensity.compact,
            ),
            segments: const [
              ButtonSegment(
                value: PoseDetectionModel.base,
                label: Text('Base'),
              ),
              ButtonSegment(
                value: PoseDetectionModel.accurate,
                label: Text('Accurate'),
              ),
            ],
            selected: {state.model},
            onSelectionChanged: (s) => onModel(s.first),
          ),
        ],
      ),
    );
  }
}
