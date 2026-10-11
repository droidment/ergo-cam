import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/camera_permission_provider.dart';
import '../../services/camera_permission_service.dart';

/// Live assessment screen. Phase 0: permission gate + blank camera placeholder.
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
            CameraAccess.granted => const _CameraPlaceholder(),
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

class _CameraPlaceholder extends StatelessWidget {
  const _CameraPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Center(
      key: Key('camera-placeholder'),
      child: Text('Camera preview', style: TextStyle(color: Colors.white54)),
    );
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
