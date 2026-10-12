import 'package:ergo_core/ergo_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../providers/sessions_provider.dart';
import '../../services/session_store.dart';
import '../live/risk_colors.dart';
import '../live/skeleton_painter.dart';
import 'reba_timeline.dart';
import 'session_format.dart';

/// Plays a recording with the risk-coloured skeleton redrawn from the log.
class ReviewScreen extends ConsumerStatefulWidget {
  const ReviewScreen({super.key, required this.meta, this.startAt});

  final SessionMeta meta;
  final Duration? startAt;

  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen> {
  VideoPlayerController? _video;
  String? _error;

  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    final store = await ref.read(sessionStoreProvider.future);
    final file = store.videoOf(widget.meta);
    if (file == null || !file.existsSync()) {
      setState(() => _error = 'No video for this session.');
      return;
    }
    final c = VideoPlayerController.file(file);
    try {
      await c.initialize();
      if (widget.startAt != null) await c.seekTo(widget.startAt!);
    } on Object catch (e) {
      await c.dispose();
      if (mounted) setState(() => _error = 'Could not play the video: $e');
      return;
    }
    if (!mounted) {
      await c.dispose();
      return;
    }
    setState(() => _video = c);
  }

  @override
  void dispose() {
    _video?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final frames =
        ref.watch(sessionFramesProvider(widget.meta.id)).value ?? const [];
    final video = _video;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: Text(widget.meta.title)),
      body: SafeArea(
        child: _error != null
            ? Center(
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.white70),
                ),
              )
            : video == null
            ? const Center(child: CircularProgressIndicator())
            : ValueListenableBuilder<VideoPlayerValue>(
                valueListenable: video,
                builder: (context, v, _) {
                  final frame = frameAt(frames, v.position);
                  return Column(
                    children: [
                      Expanded(
                        child: Center(
                          child: AspectRatio(
                            aspectRatio: v.aspectRatio,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                VideoPlayer(video),
                                CustomPaint(
                                  painter: SkeletonPainter(
                                    score: frame,
                                    mirror: false,
                                  ),
                                ),
                                Align(
                                  alignment: Alignment.topLeft,
                                  child: _FrameBadge(frame: frame),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      _Controls(video: video, value: v),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 0, 16, 12),
                        child: Theme(
                          data: ThemeData(brightness: Brightness.dark),
                          child: RebaTimeline(
                            frames: frames,
                            position: v.position,
                            height: 120,
                            onSeek: video.seekTo,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
      ),
    );
  }
}

class _FrameBadge extends StatelessWidget {
  const _FrameBadge({required this.frame});
  final FrameScore? frame;

  @override
  Widget build(BuildContext context) {
    final r = frame?.reba;
    final o = frame?.owas;
    final label = r == null
        ? 'Unscored'
        : 'REBA ${r.score} · ${r.risk.label}'
              '${o == null ? '' : ' · OWAS ${o.code.code} (${o.actionCategory})'}';
    final color = r == null ? Colors.black54 : RiskColors.reba(r.risk);
    return Padding(
      padding: const EdgeInsets.all(8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Text(
            label,
            key: const Key('review-frame'),
            style: TextStyle(
              color: r == null ? Colors.white : RiskColors.onColor(color),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({required this.video, required this.value});
  final VideoPlayerController video;
  final VideoPlayerValue value;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      IconButton(
        color: Colors.white,
        icon: Icon(value.isPlaying ? Icons.pause : Icons.play_arrow),
        onPressed: () async {
          if (value.isPlaying) {
            await video.pause();
          } else {
            if (value.position >= value.duration) {
              await video.seekTo(Duration.zero);
            }
            await video.play();
          }
        },
      ),
      Text(
        '${formatClock(value.position)} / ${formatClock(value.duration)}',
        style: const TextStyle(
          color: Colors.white70,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
      ),
    ],
  );
}
