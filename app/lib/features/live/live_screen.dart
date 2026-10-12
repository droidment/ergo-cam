import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/camera_permission_provider.dart';
import '../../providers/live_session_provider.dart';
import '../../services/camera_permission_service.dart';
import '../session/sessions_screen.dart';
import '../session/setup_sheet.dart';
import '../session/summary_screen.dart';
import 'hud.dart';
import 'skeleton_painter.dart';

/// Live assessment screen: permission gate, then camera + skeleton overlay.
class LiveScreen extends ConsumerStatefulWidget {
  const LiveScreen({super.key});

  @override
  ConsumerState<LiveScreen> createState() => _LiveScreenState();
}

class _LiveScreenState extends ConsumerState<LiveScreen> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // Pick up a permission granted from system Settings.
    _lifecycle = AppLifecycleListener(
      onResume: () => ref.read(cameraPermissionProvider.notifier).recheck(),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final access = ref.watch(cameraPermissionProvider);
    final notifier = ref.read(cameraPermissionProvider.notifier);
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: access.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _Message(
            icon: Icons.error_outline,
            text: 'Could not check camera permission.\n$e',
          ),
          data: (a) => switch (a) {
            CameraAccess.granted => const LiveCameraView(),
            CameraAccess.denied => _Message(
              icon: Icons.no_photography_outlined,
              text:
                  'ErgoCam needs the camera to assess posture.\n'
                  'Frames are processed on the phone and not uploaded.',
              actionLabel: 'Grant camera access',
              onAction: notifier.request,
            ),
            CameraAccess.permanentlyDenied => _Message(
              icon: Icons.no_photography_outlined,
              text:
                  'Camera access is turned off for ErgoCam.\n'
                  'Enable it in system Settings to continue.',
              actionLabel: 'Open settings',
              onAction: notifier.openSettings,
            ),
          },
        ),
      ),
    );
  }
}

/// Camera preview with skeleton overlay and HUD. Only built once camera
/// permission is granted; releases the camera whenever the app is hidden.
class LiveCameraView extends ConsumerStatefulWidget {
  const LiveCameraView({super.key});

  @override
  ConsumerState<LiveCameraView> createState() => _LiveCameraViewState();
}

class _LiveCameraViewState extends ConsumerState<LiveCameraView> {
  late final AppLifecycleListener _lifecycle;

  /// True while another page covers the live view; the camera stays off.
  bool _away = false;

  LiveSessionController get _session => ref.read(liveSessionProvider.notifier);

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onShow: () {
        if (!_away) _session.start();
      },
      onHide: () => _session.stop(),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _session.start();
    });
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  /// Opens [page] with the camera released, and restarts it on return.
  Future<void> _openPage(Widget page) async {
    if (_away) return;
    _away = true;
    await _session.stop();
    if (!mounted) return;
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => page));
    _away = false;
    if (mounted) await _session.start();
  }

  void _toggleRecording(LiveState state) {
    if (state.recording == null) {
      _session.startRecording();
    } else {
      _session.stopRecording();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(liveSessionProvider);
    final controller = state.controller;

    // A finished recording opens its summary.
    ref.listen(liveSessionProvider.select((s) => s.lastSaved), (prev, next) {
      if (next != null && !identical(prev, next)) {
        _openPage(SummaryScreen(meta: next));
      }
    });
    ref.listen(liveSessionProvider.select((s) => s.notice), (prev, next) {
      if (next != null && !identical(prev, next)) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(next.message)));
      }
    });

    return switch (state.status) {
      CameraStatus.error => _Message(
        icon: Icons.videocam_off_outlined,
        text: 'Camera failed to start.\n${state.error ?? ''}',
        actionLabel: 'Retry',
        onAction: _session.start,
      ),
      CameraStatus.running when controller != null => Stack(
        key: const Key('live-camera'),
        children: [
          Center(
            child: CameraPreview(
              controller,
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: SkeletonPainter(
                    score: state.score,
                    mirror: state.mirror,
                  ),
                ),
              ),
            ),
          ),
          LiveHud(
            state: state,
            onSetup: () => showSetupSheet(context),
            onRecord: () => _toggleRecording(state),
            onSessions: () => _openPage(const SessionsScreen()),
          ),
        ],
      ),
      _ => const Center(
        key: Key('camera-starting'),
        child: Text(
          'Starting camera…',
          style: TextStyle(color: Colors.white54),
        ),
      ),
    };
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.text,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: Colors.white70),
            const SizedBox(height: 16),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
            if (actionLabel != null) ...[
              const SizedBox(height: 24),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
