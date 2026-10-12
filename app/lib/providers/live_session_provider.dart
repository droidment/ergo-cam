import 'package:camera/camera.dart';
import 'package:ergo_core/ergo_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../services/fps_meter.dart';
import '../services/gravity_service.dart';
import '../services/pose_service.dart';
import 'session_setup_provider.dart';

enum CameraStatus { idle, starting, running, error }

@immutable
class LiveState {
  const LiveState({
    this.status = CameraStatus.idle,
    this.controller,
    this.score,
    this.poseFps = 0,
    this.cameraFps = 0,
    this.droppedFrames = 0,
    this.model = PoseDetectionModel.base,
    this.error,
  });

  final CameraStatus status;
  final CameraController? controller;

  /// Latest scored (or unscored) frame, including the smoothed pose to draw.
  /// Null until the first detection completes.
  final FrameScore? score;

  /// Completed detections per second — the number that matters for Phase 1.
  final double poseFps;

  /// Frames delivered by the camera per second (including dropped ones).
  final double cameraFps;

  /// Frames skipped because a detection was still in flight.
  final int droppedFrames;
  final PoseDetectionModel model;
  final String? error;

  bool get mirror =>
      controller?.description.lensDirection == CameraLensDirection.front;

  LiveState copyWith({
    CameraStatus? status,
    CameraController? controller,
    FrameScore? score,
    double? poseFps,
    double? cameraFps,
    int? droppedFrames,
    PoseDetectionModel? model,
    String? error,
  }) {
    return LiveState(
      status: status ?? this.status,
      controller: controller ?? this.controller,
      score: score ?? this.score,
      poseFps: poseFps ?? this.poseFps,
      cameraFps: cameraFps ?? this.cameraFps,
      droppedFrames: droppedFrames ?? this.droppedFrames,
      model: model ?? this.model,
      error: error ?? this.error,
    );
  }
}

/// Owns the camera controller and pose pipeline for the live screen.
///
/// start/stop are serialized so app lifecycle flapping (permission dialogs,
/// quick background/foreground) can't interleave camera setup and teardown.
class LiveSessionController extends Notifier<LiveState> {
  CameraController? _camera;
  PoseService? _pose;
  final _clock = Stopwatch();
  final _cameraMeter = FpsMeter();
  final _poseMeter = FpsMeter();
  int _dropped = 0;
  Future<void> _ops = Future.value();
  final _scorer = FrameScorer();
  DeviceGravity? _gravity;

  @override
  LiveState build() {
    ref.onDispose(() => _serial(_teardown));
    // Keep the latest gravity reading; frames read it when they're scored.
    ref.listen(deviceGravityProvider, (_, next) => _gravity = next.value);
    return const LiveState();
  }

  Future<void> start() => _serial(_startNow);

  Future<void> stop() => _serial(() async {
    // Drop the controller from state first so no preview is built on a
    // controller that is being disposed.
    if (ref.mounted) state = LiveState(model: state.model);
    await _teardown();
  });

  Future<void> setModel(PoseDetectionModel model) async {
    state = state.copyWith(model: model);
    await _pose?.setModel(model);
  }

  Future<void> _serial(Future<void> Function() op) =>
      _ops = _ops.then((_) => op()).catchError((Object e, StackTrace s) {
        debugPrint('LiveSessionController: $e\n$s');
      });

  Future<void> _startNow() async {
    if (_camera != null || !ref.mounted) return;
    state = state.copyWith(status: CameraStatus.starting);
    try {
      final cameras = await availableCameras();
      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => throw CameraException('noBackCamera', 'No back camera'),
      );
      final camera = CameraController(
        back,
        ResolutionPreset.high, // 720p
        enableAudio: false,
        imageFormatGroup: poseImageFormatGroup,
      );
      _camera = camera;
      _pose = PoseService(model: state.model);
      await camera.initialize();
      _dropped = 0;
      _scorer.reset();
      _cameraMeter.reset();
      _poseMeter.reset();
      _clock
        ..reset()
        ..start();
      await camera.startImageStream(_onFrame);
      if (!ref.mounted) return;
      state = state.copyWith(status: CameraStatus.running, controller: camera);
      await WakelockPlus.enable().catchError((Object e) {
        debugPrint('Wakelock unavailable: $e');
      });
    } catch (e) {
      await _teardown();
      if (!ref.mounted) return;
      state = LiveState(
        status: CameraStatus.error,
        model: state.model,
        error: e is CameraException ? (e.description ?? e.code) : '$e',
      );
    }
  }

  void _onFrame(CameraImage image) {
    final now = _clock.elapsed;
    _cameraMeter.tick(now);
    final camera = _camera;
    final pose = _pose;
    if (camera == null || pose == null) return;
    if (pose.isBusy) {
      _dropped++;
      return;
    }
    final orientation = camera.value.deviceOrientation;
    pose
        .detect(
          image,
          camera: camera.description,
          deviceOrientation: orientation,
          timestamp: now,
        )
        .then((frame) {
          if (!ref.mounted || !identical(_camera, camera)) return;
          _poseMeter.tick(_clock.elapsed);
          final gravity = _gravity;
          final score = _scorer.score(
            frame,
            up: gravity == null
                ? null
                : imageUpFromGravity(gravity, orientation),
            inputs: ref.read(sessionSetupProvider).inputs,
            timestamp: now,
          );
          state = state.copyWith(
            score: score,
            poseFps: _poseMeter.fps,
            cameraFps: _cameraMeter.fps,
            droppedFrames: _dropped,
          );
        })
        .catchError((Object e) {
          debugPrint('Pose detection failed: $e');
        });
  }

  Future<void> _teardown() async {
    final camera = _camera;
    final pose = _pose;
    _camera = null;
    _pose = null;
    _clock.stop();
    await WakelockPlus.disable().catchError((Object e) {
      debugPrint('Wakelock unavailable: $e');
    });
    if (camera != null) {
      if (camera.value.isStreamingImages) {
        await camera.stopImageStream().catchError((_) {});
      }
      await camera.dispose();
    }
    await pose?.close();
  }
}

final liveSessionProvider =
    NotifierProvider.autoDispose<LiveSessionController, LiveState>(
      LiveSessionController.new,
    );
