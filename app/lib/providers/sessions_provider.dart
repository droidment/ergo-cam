import 'package:ergo_core/ergo_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/session_store.dart';

final sessionStoreProvider = FutureProvider<SessionStore>(
  (ref) => SessionStore.open(),
);

/// Saved sessions, newest first. Invalidate after saving or deleting.
final sessionsProvider = FutureProvider.autoDispose<List<SessionMeta>>((
  ref,
) async {
  final store = await ref.watch(sessionStoreProvider.future);
  return store.list();
});

/// One session's frame log.
final sessionFramesProvider = FutureProvider.autoDispose
    .family<List<FrameScore>, String>((ref, id) async {
      final store = await ref.watch(sessionStoreProvider.future);
      return store.frames(id);
    });
