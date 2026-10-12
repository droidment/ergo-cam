import 'dart:async';

import 'package:camera/camera.dart';
import 'package:ergo_core/ergo_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../services/fps_meter.dart';
import '../services/gravity_service.dart';
import '../services/pose_service.dart';
import '../services/session_store.dart';
import 'session_setup_provider.dart';
import 'sessions_provider.dart';

enum CameraStatus { idle, starting, running, error }

/// A recording in progress.
@immutable
class RecordingInfo {
  const RecordingInfo({required this.startedAt});

  /// Wall-clock start, for the elapsed-time display and the session id.
  final DateTime startedAt;
}

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
    this.recording,
    this.saving = false,
    this.lastSaved,
    this.notice,
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

  /// Non-null while recording.
  final RecordingInfo? recording;

  /// True while a finished recording is being written to storage.
  final bool saving;

  /// The most recently saved recording (the UI opens its summary).
  final SessionMeta? lastSaved;

  /// A one-off message for the user (shown once per new instance).
  final LiveNotice? notice;

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
    RecordingInfo? recording,
    bool clearRecording = false,
    bool? saving,
    SessionMeta? lastSaved,
    LiveNotice? notice,
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
      recording: clearRecording ? null : (recording ?? this.recording),
      saving: saving ?? this.saving,
      lastSaved: lastSaved ?? this.lastSaved,
      notice: notice ?? this.notice,
    );
  }
}

/// A message to show once; compared by identity so repeats still show.
class LiveNotice {
  LiveNotice(this.message);
  final String message;
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

  /// Recordings stop on their own after this long.
  static const maxRecording = Duration(minutes: 5);

  // Recording in progress (all null/empty when not recording).
  Duration? _recordStart; // on [_clock]
  DateTime? _recordWall;
  SessionSetup? _recordSetup;
  bool _setupChanged = false;
  List<FrameScore> _log = [];
  Timer? _capTimer;

  @override
  LiveState build() {
    ref.onDispose(() {
      _capTimer?.cancel();
      _serial(_teardown);
    });
    // Keep the latest gravity reading; frames read it when they're scored.
    ref.listen(deviceGravityProvider, (_, next) => _gravity = next.value);
    ref.listen(sessionSetupProvider, (_, _) {
      if (_recordStart != null) _setupChanged = true;
    });
    return const LiveState();
  }

  Future<void> start() => _serial(_startNow);

  Future<void> stop() => _serial(() async {
    // Save a recording in progress rather than losing it.
    await _finishRecording(resumeStream: false);
    // Drop the controller from state first so no preview is built on a
    // controller that is being disposed.
    if (ref.mounted) {
      state = LiveState(model: state.model, lastSaved: state.lastSaved);
    }
    await _teardown();
  });

  /// Starts recording video plus the per-frame log. Pose scoring continues
  /// on the same camera stream while recording.
  Future<void> startRecording() => _serial(() async {
    final camera = _camera;
    if (camera == null || _recordStart != null || !ref.mounted) return;
    try {
      // Recording takes over the frame stream; hand it the same callback.
      if (camera.value.isStreamingImages) await camera.stopImageStream();
      await camera.startVideoRecording(onAvailable: _onFrame);
    } on Object catch (e) {
      debugPrint('Recording failed to start: $e');
      await _resumeStream(camera);
      _notify('Recording could not start on this device ($e)');
      return;
    }
    _recordStart = _clock.elapsed;
    _recordWall = DateTime.now();
    _recordSetup = ref.read(sessionSetupProvider);
    _setupChanged = false;
    _log = [];
    _capTimer = Timer(maxRecording, () {
      _notify(
        'Recording stopped at the ${maxRecording.inMinutes}-minute limit',
      );
      stopRecording();
    });
    state = state.copyWith(recording: RecordingInfo(startedAt: _recordWall!));
  });

  /// Stops recording, resumes live scoring and saves the session.
  Future<void> stopRecording() =>
      _serial(() => _finishRecording(resumeStream: true));

  Future<void> _finishRecording({required bool resumeStream}) async {
    final start = _recordStart;
    if (start == null) return;
    _capTimer?.cancel();
    final log = _log, setup = _recordSetup!, wall = _recordWall!;
    final changed = _setupChanged;
    _recordStart = null;
    _log = [];
    if (ref.mounted) {
      state = state.copyWith(clearRecording: true, saving: true);
    }

    final camera = _camera;
    String? videoPath;
    if (camera != null && camera.value.isRecordingVideo) {
      try {
        videoPath = (await camera.stopVideoRecording()).path;
      } on Object catch (e) {
        debugPrint('Stopping video failed: $e');
        _notify('Video could not be saved; the score log was kept');
      }
      if (resumeStream) await _resumeStream(camera);
    }

    if (!ref.mounted) return;
    try {
      final store = await ref.read(sessionStoreProvider.future);
      final meta = await store.save(
        taskName: setup.taskName,
        startedAt: wall,
        inputs: setup.inputs,
        inputsChanged: changed,
        frames: log,
        videoPath: videoPath,
      );
      ref.invalidate(sessionsProvider);
      if (ref.mounted) state = state.copyWith(saving: false, lastSaved: meta);
    } on Object catch (e) {
      debugPrint('Saving session failed: $e');
      if (ref.mounted) state = state.copyWith(saving: false);
      _notify('Could not save the recording: $e');
    }
  }

  Future<void> _resumeStream(CameraController camera) async {
    try {
      if (!camera.value.isStreamingImages && !camera.value.isRecordingVideo) {
        await camera.startImageStream(_onFrame);
      }
    } on Object catch (e) {
      debugPrint('Resuming image stream failed: $e');
    }
  }

  void _notify(String message) {
    if (ref.mounted) state = state.copyWith(notice: LiveNotice(message));
  }

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
          final recordStart = _recordStart;
          if (recordStart != null && now >= recordStart) {
            _log.add(score.at(now - recordStart));
          }
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
