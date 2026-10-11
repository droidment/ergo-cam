import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/camera_permission_service.dart';

/// Camera permission state. Asks once on first launch; afterwards only
/// re-checks (e.g. on app resume) so the system dialog never loops.
class CameraPermissionNotifier extends AsyncNotifier<CameraAccess> {
  bool _askedOnce = false;
  bool _requesting = false;

  CameraPermissionService get _service =>
      ref.read(cameraPermissionServiceProvider);

  @override
  Future<CameraAccess> build() async {
    final current = await _service.status();
    if (current == CameraAccess.denied && !_askedOnce) {
      _askedOnce = true;
      return _requestNow();
    }
    return current;
  }

  /// Explicit user action ("Grant camera access").
  Future<void> request() async {
    state = AsyncData(await _requestNow());
  }

  /// Re-read status without prompting, e.g. after returning from Settings.
  /// Skipped while a request is in flight: the system dialog itself
  /// pauses/resumes the activity on Android.
  Future<void> recheck() async {
    if (_requesting) return;
    state = AsyncData(await _service.status());
  }

  Future<bool> openSettings() => _service.openSettings();

  Future<CameraAccess> _requestNow() async {
    _requesting = true;
    try {
      return await _service.request();
    } finally {
      _requesting = false;
    }
  }
}

final cameraPermissionProvider =
    AsyncNotifierProvider<CameraPermissionNotifier, CameraAccess>(
      CameraPermissionNotifier.new,
    );
