import 'package:ergo_core/ergo_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/sessions_provider.dart';
import '../live/risk_colors.dart';
import 'session_format.dart';
import 'summary_screen.dart';

/// Saved recordings, newest first.
class SessionsScreen extends ConsumerWidget {
  const SessionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(sessionsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Recorded sessions')),
      body: sessions.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not read sessions: $e')),
        data: (list) => list.isEmpty
            ? const Center(
                key: Key('no-sessions'),
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'No recordings yet.\nPress ● on the live screen to record.',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            : ListView.separated(
                itemCount: list.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final m = list[i];
                  final s = m.summary;
                  return ListTile(
                    title: Text(m.title),
                    subtitle: Text(
                      '${formatDateTime(m.startedAt)} · '
                      '${formatClock(s.duration)}'
                      '${s.hasScores ? ' · P90 ${s.rebaP90}' : ' · unscored'}'
                      '${m.hasVideo ? '' : ' · no video'}',
                    ),
                    trailing: s.hasScores
                        ? _MaxBadge(score: s.rebaMax!)
                        : const Icon(Icons.help_outline),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => SummaryScreen(meta: m),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class _MaxBadge extends StatelessWidget {
  const _MaxBadge({required this.score});
  final int score;

  @override
  Widget build(BuildContext context) {
    final c = RiskColors.reba(RebaRisk.forScore(score));
    return CircleAvatar(
      backgroundColor: c,
      child: Text(
        '$score',
        style: TextStyle(
          color: RiskColors.onColor(c),
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
