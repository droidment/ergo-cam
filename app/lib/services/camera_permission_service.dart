import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

/// Camera access as the app cares about it. Microphone is never requested.
enum CameraAccess { granted, denied, permanentlyDenied }

/// Thin seam over the platform permission API so the UI can be tested.
abstract interface class CameraPermissionService {
  Future<CameraAccess> status();
  Future<CameraAccess> request();
  Future<bool> openSettings();
}

class PermissionHandlerCameraService implements CameraPermissionService {
  const PermissionHandlerCameraService();

  @override
  Future<CameraAccess> status() async => _map(await Permission.camera.status);

  @override
  Future<CameraAccess> request() async =>
      _map(await Permission.camera.request());

  @override
  Future<bool> openSettings() => openAppSettings();

  static CameraAccess _map(PermissionStatus s) => switch (s) {
    PermissionStatus.granted ||
    PermissionStatus.limited => CameraAccess.granted,
    // Restricted (parental controls / MDM) can't be changed by the user in-app.
    PermissionStatus.permanentlyDenied ||
    PermissionStatus.restricted => CameraAccess.permanentlyDenied,
    _ => CameraAccess.denied,
  };
}

final cameraPermissionServiceProvider = Provider<CameraPermissionService>(
  (ref) => const PermissionHandlerCameraService(),
);
