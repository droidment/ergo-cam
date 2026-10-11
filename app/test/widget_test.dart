import 'package:ergocam/main.dart';
import 'package:ergocam/providers/live_session_provider.dart';
import 'package:ergocam/services/camera_permission_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Stands in for the real camera pipeline, which needs a device.
class FakeLiveSession extends LiveSessionController {
  int starts = 0;

  @override
  LiveState build() => const LiveState();

  @override
  Future<void> start() async => starts++;

  @override
  Future<void> stop() async {}
}

class FakeCameraPermission implements CameraPermissionService {
  FakeCameraPermission({required this.current, required this.onRequest});

  CameraAccess current;
  final CameraAccess onRequest;
  int requests = 0;
  int settingsOpened = 0;

  @override
  Future<CameraAccess> status() async => current;

  @override
  Future<CameraAccess> request() async {
    requests++;
    return current = onRequest;
  }

  @override
  Future<bool> openSettings() async {
    settingsOpened++;
    return true;
  }
}

late FakeLiveSession session;

Future<void> pumpApp(WidgetTester tester, FakeCameraPermission fake) async {
  session = FakeLiveSession();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        cameraPermissionServiceProvider.overrideWithValue(fake),
        liveSessionProvider.overrideWith(() => session),
      ],
      child: const ErgoCamApp(),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('starts the camera when already granted', (tester) async {
    final fake = FakeCameraPermission(
      current: CameraAccess.granted,
      onRequest: CameraAccess.granted,
    );
    await pumpApp(tester, fake);

    expect(find.byKey(const Key('camera-starting')), findsOneWidget);
    expect(session.starts, 1);
    expect(fake.requests, 0);
  });

  testWidgets('asks once on first launch, starts camera on grant', (
    tester,
  ) async {
    final fake = FakeCameraPermission(
      current: CameraAccess.denied,
      onRequest: CameraAccess.granted,
    );
    await pumpApp(tester, fake);

    expect(fake.requests, 1);
    expect(session.starts, 1);
  });

  testWidgets('denied shows a grant button that re-requests', (tester) async {
    final fake = FakeCameraPermission(
      current: CameraAccess.denied,
      onRequest: CameraAccess.denied,
    );
    await pumpApp(tester, fake);
    expect(fake.requests, 1);
    expect(session.starts, 0);

    await tester.tap(find.text('Grant camera access'));
    await tester.pumpAndSettle();
    expect(fake.requests, 2);
  });

  testWidgets('permanently denied offers system settings, never prompts', (
    tester,
  ) async {
    final fake = FakeCameraPermission(
      current: CameraAccess.permanentlyDenied,
      onRequest: CameraAccess.permanentlyDenied,
    );
    await pumpApp(tester, fake);

    expect(fake.requests, 0);
    await tester.tap(find.text('Open settings'));
    await tester.pumpAndSettle();
    expect(fake.settingsOpened, 1);
  });
}
