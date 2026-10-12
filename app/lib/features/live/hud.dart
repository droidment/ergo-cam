import 'dart:async';

import 'package:ergo_core/ergo_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/live_session_provider.dart';
import '../../providers/session_setup_provider.dart';
import '../../services/framing.dart';
import '../session/session_format.dart';
import 'risk_colors.dart';

/// Everything drawn over the live preview: score panel, setup button,
/// performance readout and placement hints.
class LiveHud extends ConsumerWidget {
  const LiveHud({
    super.key,
    required this.state,
    required this.onSetup,
    required this.onRecord,
    required this.onSessions,
  });

  final LiveState state;
  final VoidCallback onSetup;

  /// Starts or stops recording, depending on [LiveState.recording].
  final VoidCallback onRecord;
  final VoidCallback onSessions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final setup = ref.watch(sessionSetupProvider);
    final score = state.score;
    final hint = score == null
        ? placementGuide
        : framingHint(score.pose) ?? (score.isScored ? null : placementGuide);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Stack(
          children: [
            Align(
              alignment: Alignment.topLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 280),
                child: _ScorePanel(score: score, setup: setup),
              ),
            ),
            Align(
              alignment: Alignment.topRight,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton.filledTonal(
                    key: const Key('setup-button'),
                    tooltip: 'Session setup',
                    onPressed: onSetup,
                    icon: const Icon(Icons.tune),
                  ),
                  const SizedBox(height: 8),
                  IconButton.filledTonal(
                    key: const Key('sessions-button'),
                    tooltip: 'Recorded sessions',
                    onPressed: state.recording == null ? onSessions : null,
                    icon: const Icon(Icons.video_library_outlined),
                  ),
                ],
              ),
            ),
            if (state.recording case final rec?)
              Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: _RecordingClock(startedAt: rec.startedAt),
                ),
              ),
            Align(
              alignment: Alignment.centerRight,
              child: _RecordButton(
                recording: state.recording != null,
                saving: state.saving,
                onPressed: onRecord,
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (hint != null) _Banner(text: hint),
                  const SizedBox(height: 8),
                  _PerfLine(state: state),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Padding(padding: const EdgeInsets.all(12), child: child),
  );
}

class _ScorePanel extends StatelessWidget {
  const _ScorePanel({required this.score, required this.setup});

  final FrameScore? score;
  final SessionSetup setup;

  @override
  Widget build(BuildContext context) {
    final s = score;
    final text = Theme.of(context).textTheme;
    final reba = s?.reba;
    final owas = s?.owas;

    final headline = reba == null
        ? Text(
            s == null ? 'Starting…' : 'Unscored',
            key: const Key('unscored'),
            style: text.headlineMedium!.copyWith(color: RiskColors.neutral),
          )
        : Row(
            children: [
              _Badge(
                key: const Key('reba-score'),
                text: '${reba.score}',
                color: RiskColors.reba(reba.risk),
                big: true,
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'REBA',
                    style: text.labelMedium!.copyWith(color: Colors.white70),
                  ),
                  Text(
                    reba.risk.label,
                    style: text.titleMedium!.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          );

    final i = setup.inputs;
    final inputsLine = [
      if (setup.taskName.isNotEmpty) setup.taskName,
      '${_kg(i.loadKg)} kg',
      '${i.coupling.name} grip',
      if (i.activityScore > 0) 'activity +${i.activityScore}',
    ].join(' · ');

    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          headline,
          if (s != null && reba == null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                s.unscoredReason ?? '',
                key: const Key('unscored-reason'),
                style: text.bodySmall!.copyWith(color: Colors.white70),
              ),
            ),
          if (owas != null) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'OWAS ${owas.code.code}',
                  key: const Key('owas-code'),
                  style: text.bodyMedium!.copyWith(
                    color: Colors.white,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                _Badge(
                  text:
                      '${owas.actionCategory} · '
                      '${owasActionLabel(owas.actionCategory)}',
                  color: RiskColors.owas(owas.actionCategory),
                ),
              ],
            ),
          ],
          if (s != null) ...[
            const SizedBox(height: 10),
            _Confidence(value: s.frameConfidence),
          ],
          const SizedBox(height: 8),
          Text(
            inputsLine,
            style: text.bodySmall!.copyWith(color: Colors.white70),
          ),
          if (setup.assumptions.isNotEmpty)
            Text(
              'Assumed: ${setup.assumptions.join(', ')}',
              key: const Key('assumptions'),
              style: text.bodySmall!.copyWith(color: RiskColors.yellow),
            ),
        ],
      ),
    );
  }

  static String _kg(double kg) =>
      kg == kg.roundToDouble() ? kg.toStringAsFixed(0) : kg.toStringAsFixed(1);
}

class _Badge extends StatelessWidget {
  const _Badge({
    super.key,
    required this.text,
    required this.color,
    this.big = false,
  });

  final String text;
  final Color color;
  final bool big;

  @override
  Widget build(BuildContext context) {
    final style = big
        ? Theme.of(context).textTheme.headlineLarge
        : Theme.of(context).textTheme.labelMedium;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(big ? 10 : 6),
      ),
      child: Padding(
        padding: big
            ? const EdgeInsets.symmetric(horizontal: 14, vertical: 2)
            : const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Text(
          text,
          style: style!.copyWith(
            color: RiskColors.onColor(color),
            fontWeight: FontWeight.bold,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }
}

class _Confidence extends StatelessWidget {
  const _Confidence({required this.value});
  final double value;

  @override
  Widget build(BuildContext context) {
    final color = value >= 0.8
        ? RiskColors.green
        : value >= minLandmarkVisibility
        ? RiskColors.yellow
        : RiskColors.red;
    return Row(
      children: [
        Text(
          'Confidence ${(value * 100).round()}%',
          style: Theme.of(context).textTheme.bodySmall!
              .copyWith(color: Colors.white),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: value.clamp(0, 1),
              minHeight: 4,
              color: color,
              backgroundColor: Colors.white24,
            ),
          ),
        ),
      ],
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => _Panel(
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.videocam_outlined, color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            text,
            key: const Key('placement-hint'),
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ],
    ),
  );
}

class _PerfLine extends StatelessWidget {
  const _PerfLine({required this.state});
  final LiveState state;

  @override
  Widget build(BuildContext context) => Text(
    'Pose ${state.poseFps.toStringAsFixed(0)} fps · '
    'cam ${state.cameraFps.toStringAsFixed(0)} · '
    'dropped ${state.droppedFrames} · ${state.model.name}',
    key: const Key('pose-fps'),
    style: Theme.of(context).textTheme.labelSmall!.copyWith(
      color: Colors.white60,
      fontFeatures: const [FontFeature.tabularFigures()],
    ),
  );
}

class _RecordButton extends StatelessWidget {
  const _RecordButton({
    required this.recording,
    required this.saving,
    required this.onPressed,
  });

  final bool recording;
  final bool saving;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: recording ? 'Stop recording' : 'Start recording',
      child: GestureDetector(
        key: const Key('record-button'),
        onTap: saving ? null : onPressed,
        child: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 4),
            color: Colors.black26,
          ),
          alignment: Alignment.center,
          child: saving
              ? const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(color: Colors.white),
                )
              : AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: recording ? 26 : 52,
                  height: recording ? 26 : 52,
                  decoration: BoxDecoration(
                    color: RiskColors.red,
                    borderRadius: BorderRadius.circular(recording ? 4 : 26),
                  ),
                ),
        ),
      ),
    );
  }
}

/// "● REC m:ss", ticking once a second.
class _RecordingClock extends StatefulWidget {
  const _RecordingClock({required this.startedAt});
  final DateTime startedAt;

  @override
  State<_RecordingClock> createState() => _RecordingClockState();
}

class _RecordingClockState extends State<_RecordingClock> {
  late final Timer _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _tick.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: RiskColors.red,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Text(
        '● REC ${formatClock(DateTime.now().difference(widget.startedAt))}',
        key: const Key('recording-clock'),
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
      ),
    ),
  );
}
