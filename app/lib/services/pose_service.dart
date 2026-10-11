import 'dart:io';

import 'package:camera/camera.dart';
import 'package:ergo_core/ergo_core.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import 'frame_geometry.dart';

/// Camera image format ML Kit can consume directly on each platform.
ImageFormatGroup get poseImageFormatGroup =>
    Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888;

/// Runs ML Kit pose detection on camera frames.
///
/// Inference runs on ML Kit's native background executor; the Dart side only
/// hands over the frame bytes. One frame at a time: callers check [isBusy]
/// and drop frames rather than queueing them.
class PoseService {
  PoseService({PoseDetectionModel model = PoseDetectionModel.base})
    : _model = model,
      _detector = _create(model);

  PoseDetectionModel _model;
  PoseDetector _detector;
  Future<void>? _inFlight;
  bool _closed = false;

  PoseDetectionModel get model => _model;
  bool get isBusy => _inFlight != null;

  static PoseDetector _create(PoseDetectionModel model) => PoseDetector(
    options: PoseDetectorOptions(model: model, mode: PoseDetectionMode.stream),
  );

  /// Detects the most prominent person in [image]. Returns null when nobody
  /// is found or the frame can't be converted. Throws [StateError] if called
  /// while busy.
  Future<PoseFrame?> detect(
    CameraImage image, {
    required CameraDescription camera,
    required DeviceOrientation deviceOrientation,
    required Duration timestamp,
  }) async {
    if (_closed) return null;
    if (isBusy) throw StateError('PoseService is busy; drop the frame');

    final isAndroid = Platform.isAndroid;
    final rotation = frameRotationDegrees(
      sensorOrientation: camera.sensorOrientation,
      deviceOrientation: deviceOrientation,
      frontFacing: camera.lensDirection == CameraLensDirection.front,
      isAndroid: isAndroid,
    );
    final input = _toInputImage(image, rotation);
    if (input == null) return null;

    final rawSize = Size(image.width.toDouble(), image.height.toDouble());
    final upright = uprightFrameSize(rawSize, rotation, isAndroid: isAndroid);

    final detection = _detector.processImage(input);
    _inFlight = detection;
    try {
      final poses = await detection;
      if (poses.isEmpty) return null;
      return _toFrame(poses.first, upright, timestamp);
    } finally {
      _inFlight = null;
    }
  }

  /// Switches model; the old detector is closed once its frame finishes.
  Future<void> setModel(PoseDetectionModel model) async {
    if (model == _model || _closed) return;
    final old = _detector;
    final pending = _inFlight;
    _model = model;
    _detector = _create(model);
    await _settle(pending);
    await old.close();
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _settle(_inFlight);
    await _detector.close();
  }

  static Future<void> _settle(Future<void>? f) async {
    try {
      await f;
    } catch (_) {
      // The caller of detect() already saw this error.
    }
  }

  static InputImage? _toInputImage(CameraImage image, int rotationDegrees) {
    final rotation = InputImageRotationValue.fromRawValue(rotationDegrees);
    final format = InputImageFormatValue.fromRawValue(image.format.raw as int);
    if (rotation == null || format == null) return null;

    // NV21 (Android) and BGRA8888 (iOS) both arrive as a single plane.
    final valid =
        (Platform.isAndroid && format == InputImageFormat.nv21) ||
        (Platform.isIOS && format == InputImageFormat.bgra8888);
    if (!valid || image.planes.length != 1) return null;

    final plane = image.planes.first;
    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  static PoseFrame _toFrame(Pose pose, Size upright, Duration timestamp) {
    return PoseFrame(
      timestamp: timestamp,
      width: upright.width,
      height: upright.height,
      landmarks: [
        for (final b in BodyLandmark.values)
          switch (pose.landmarks[mlKitLandmarkType(b)]) {
            final PoseLandmark p => Landmark(p.x, p.y, p.z, p.likelihood),
            null => Landmark.missing,
          },
      ],
    );
  }
}

/// ML Kit's landmark type for an ergo_core landmark (same BlazePose names).
PoseLandmarkType mlKitLandmarkType(BodyLandmark b) =>
    PoseLandmarkType.values.byName(b.name);
