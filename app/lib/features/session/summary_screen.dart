import 'package:ergo_core/ergo_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../providers/session_setup_provider.dart';
import '../../providers/sessions_provider.dart';
import '../../services/session_store.dart';
import '../live/risk_colors.dart';
import 'reba_timeline.dart';
import 'review_screen.dart';
import 'session_format.dart';

/// Results of one recorded session: stats, timeline, review and export.
class SummaryScreen extends ConsumerWidget {
  const SummaryScreen({super.key, required this.meta});

  final SessionMeta meta;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = meta.summary;
    final frames = ref.watch(sessionFramesProvider(meta.id));
    final text = Theme.of(context).textTheme;
    final assumptions = SessionSetup(inputs: meta.inputs).assumptions;
    final i = meta.inputs;

    void openReview([Duration? at]) => Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ReviewScreen(meta: meta, startAt: at),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(meta.title),
        actions: [
          IconButton(
            key: const Key('delete-session'),
            tooltip: 'Delete',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _delete(context, ref),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '${formatDateTime(meta.startedAt)} · ${formatClock(s.duration)} · '
            '${formatPercent(s.scoredShare)} of frames scored',
            style: text.bodyMedium,
          ),
          const SizedBox(height: 16),
          if (!s.hasScores)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'No frame in this recording could be scored. Check the '
                  'camera placement: side view, whole body in frame.',
                ),
              ),
            )
          else ...[
            _StatGrid(
              stats: [
                _Stat(
                  'REBA max',
                  '${s.rebaMax}',
                  RiskColors.reba(RebaRisk.forScore(s.rebaMax!)),
                  key: const Key('stat-reba-max'),
                ),
                _Stat(
                  'REBA P90',
                  '${s.rebaP90}',
                  RiskColors.reba(RebaRisk.forScore(s.rebaP90!)),
                ),
                _Stat('REBA mean', s.rebaMean!.toStringAsFixed(1), null),
                _Stat(
                  'REBA ≥ $rebaHighThreshold',
                  formatPercent(s.rebaHighShare),
                  null,
                ),
                _Stat('OWAS max', '${s.owasMax}', RiskColors.owas(s.owasMax!)),
                _Stat('OWAS mean', s.owasMean!.toStringAsFixed(1), null),
                _Stat(
                  'OWAS ≥ $owasHighThreshold',
                  formatPercent(s.owasHighShare),
                  null,
                ),
                _Stat('Peak at', formatClock(s.peakAt!), null),
              ],
            ),
            const SizedBox(height: 16),
            Text('REBA over time — tap to review', style: text.titleSmall),
            const SizedBox(height: 8),
            frames.when(
              data: (f) => RebaTimeline(frames: f, onSeek: openReview),
              loading: () => const SizedBox(
                height: 160,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Text('Could not load frames: $e'),
            ),
          ],
          const SizedBox(height: 16),
          Text('Setup', style: text.titleSmall),
          const SizedBox(height: 4),
          Text(
            '${_kg(i.loadKg)} kg · ${i.coupling.name} grip'
            '${i.shockOrRapidForce ? ' · shock' : ''}'
            '${i.activityScore > 0 ? ' · activity +${i.activityScore}' : ''}',
          ),
          if (assumptions.isNotEmpty)
            Text(
              'Assumed: ${assumptions.join(', ')}',
              style: TextStyle(color: Theme.of(context).colorScheme.tertiary),
            ),
          if (meta.inputsChanged)
            const Text('Setup was changed during the recording.'),
          Text(
            'Scored with ergo_core ${meta.engineVersion}',
            style: text.bodySmall,
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton.icon(
                key: const Key('review'),
                onPressed: meta.hasVideo ? openReview : null,
                icon: const Icon(Icons.play_arrow),
                label: Text(meta.hasVideo ? 'Review video' : 'No video'),
              ),
              OutlinedButton.icon(
                key: const Key('share-data'),
                onPressed: () => _shareData(context, ref),
                icon: const Icon(Icons.table_chart_outlined),
                label: const Text('Share data (CSV + JSON)'),
              ),
              if (meta.hasVideo)
                OutlinedButton.icon(
                  onPressed: () => _shareVideo(context, ref),
                  icon: const Icon(Icons.movie_outlined),
                  label: const Text('Share video'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  static String _kg(double kg) =>
      kg == kg.roundToDouble() ? kg.toStringAsFixed(0) : kg.toStringAsFixed(1);

  String _summaryText() {
    final s = meta.summary;
    if (!s.hasScores) return 'ErgoCam: ${meta.title} — no scored frames.';
    return 'ErgoCam: ${meta.title} (${formatDateTime(meta.startedAt)}, '
        '${formatClock(s.duration)}). REBA max ${s.rebaMax}, P90 ${s.rebaP90}, '
        'mean ${s.rebaMean!.toStringAsFixed(1)}, '
        '${formatPercent(s.rebaHighShare)} of frames ≥ $rebaHighThreshold. '
        'OWAS max ${s.owasMax}, ${formatPercent(s.owasHighShare)} ≥ '
        '$owasHighThreshold.';
  }

  Future<void> _shareData(BuildContext context, WidgetRef ref) async {
    final store = await ref.read(sessionStoreProvider.future);
    final files = await store.dataFiles(meta.id);
    await SharePlus.instance.share(
      ShareParams(
        files: [for (final f in files) XFile(f.path)],
        subject: 'ErgoCam — ${meta.title}',
        text: _summaryText(),
      ),
    );
  }

  Future<void> _shareVideo(BuildContext context, WidgetRef ref) async {
    final store = await ref.read(sessionStoreProvider.future);
    final video = store.videoOf(meta);
    if (video == null) return;
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(video.path, mimeType: 'video/mp4')],
        subject: 'ErgoCam video — ${meta.title}',
      ),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete this session?'),
        content: const Text(
          'The video, frame log and summary are removed from this phone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final store = await ref.read(sessionStoreProvider.future);
    await store.delete(meta.id);
    ref.invalidate(sessionsProvider);
    if (context.mounted) Navigator.of(context).pop();
  }
}

class _Stat {
  const _Stat(this.label, this.value, this.color, {this.key});
  final String label;
  final String value;
  final Color? color;
  final Key? key;
}

class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.stats});
  final List<_Stat> stats;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return LayoutBuilder(
      builder: (context, c) {
        final columns = c.maxWidth > 600 ? 4 : 2;
        final w = (c.maxWidth - 8 * (columns - 1)) / columns;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final s in stats)
              SizedBox(
                width: w,
                child: Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.label, style: text.labelMedium),
                        const SizedBox(height: 4),
                        Text(
                          s.value,
                          key: s.key,
                          style: text.headlineSmall!.copyWith(
                            color: s.color,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
