# ErgoCam — Build Plan

Goal: a convincing internal demo where a phone films a lift side-on and shows a
live color-coded skeleton with REBA/OWAS scores, then produces a session report.

Core decision: **pose runs on the phone** (ML Kit Pose = BlazePose, same model
family as MediaPipe). No server needed for the core demo. Streaming to a laptop
is an add-on (Phase 5) that sends landmarks + scores, not video, so it stays fast.

---

## Phase 0 — Scaffold
- [x] Flutter app in `app/` (Android minSdk 36 — Pixel 10 and newer), Riverpod, flutter_lints
- [x] `packages/ergo_core` pure Dart package with `test` dependency, wired into app via path
- [x] Camera + microphone-free permissions setup (camera only)
- [x] CI-free is fine; `flutter analyze` + `dart test` clean
- [x] Verified launch on a Pixel (release arm64 APK sideloaded, placeholder shown)

**Done when:** app launches on a Pixel and shows a blank camera screen placeholder.

## Phase 1 — Live camera + pose overlay
- [x] `camera` preview, back camera, 720p, image stream (YUV420 → ML Kit InputImage)
      — CameraX delivers NV21 as one plane, passed straight to ML Kit
- [x] `google_mlkit_pose_detection` in stream mode (base model first, accurate as toggle)
- [x] Map landmarks from image coords to preview coords (rotation + mirroring handled)
- [x] `CustomPainter` skeleton overlay; FPS counter on screen
- [x] Drop frames while a detection is in flight (no queue build-up)
- [x] Verified on Pixel 11: ≥15 pose FPS, overlay aligned in portrait and landscape

**Done when:** skeleton tracks a person smoothly at ≥15 FPS on a Pixel, correct in
portrait and landscape.

## Phase 2 — Angles + scoring engine (ergo_core)
- [x] Landmark model, visibility gating, One Euro filter smoothing
- [x] Gravity vector from accelerometer (`sensors_plus`) so phone tilt doesn't fake trunk flexion
      — `app/lib/services/gravity_service.dart`; wired into the live screen in Phase 3
- [x] Joint angles per `docs/SCORING.md`
- [x] REBA: all sub-scores, Tables A/B/C, load/coupling/activity, risk level
- [x] OWAS: back/arms/legs/load codes + action category (table from cited source)
      — 3 sources agree 252/252; one disputed row noted in SCORING.md
- [x] Unit tests for every table and every golden posture

**Done when:** `dart test` passes, including "neutral standing ≤ 3 REBA".

## Phase 3 — Live scoring UI
- [ ] Session setup sheet: task name, load (kg), coupling, activity flags,
      manual overrides for twist / side-bend / wrist (2D can't see these well)
- [ ] Skeleton colored by body-region score (green → red)
- [ ] HUD: live REBA (with risk band), OWAS category, confidence indicator
- [ ] Camera placement guide: "side view, whole body in frame, 2–4 m away"
- [ ] Frames lacking confident landmarks show "unscored", not a number

**Done when:** a squat-lift scores high, standing upright scores low, live.

## Phase 4 — Record, summarize, export
- [ ] Record: video file + per-frame log (timestamp, landmarks, angles, scores)
      — try `startVideoRecording(onAvailable:)` to keep the pose stream alive while recording
- [ ] Summary: max / P90 / mean REBA, % frames REBA ≥ 8, max / mean OWAS, % frames OWAS ≥ 3
- [ ] Timeline chart of REBA over time (`fl_chart`), tap to seek
- [ ] Playback screen: recorded video with skeleton re-drawn from the frame log
- [ ] Export CSV + JSON via share sheet; session list stored locally (sqflite or Isar)

**Done when:** a 30-second recording produces a summary + playable annotated review.

## Phase 5 — Live stream to laptop (demo wow factor)
- [ ] Phone sends `{t, landmarks, angles, scores}` JSON over WebSocket (~15 Hz)
- [ ] `dashboard/`: single HTML page, draws wireframe + live gauges + rolling chart
- [ ] Phone discovers dashboard by IP entry or QR code
- [ ] Optional stretch: real video via `flutter_webrtc` (only if the demo needs it)

**Done when:** someone across the room sees the live wireframe and score on a laptop.

## Later (not in demo)
- Multi-person tracking, NIOSH lifting equation, RULA
- Server-side re-analysis with heavier 3D models
- Push findings to S/4HANA EHS (risk assessment) via OData; Fiori review app

---

## Known risks
| Risk | Mitigation |
|---|---|
| 2D pose distorts angles off side-view | Placement guide, accelerometer vertical, show confidence |
| Twist / side bend / wrist unreliable | Manual toggles in session setup; flag as assumed in report |
| Image stream + recording conflict on some devices | Test early on target Pixel; fallback: record landmarks only, then video separately |
| Thermal throttling on long sessions | Base model default, 720p, frame skipping |
| Score inflation (seen in reference demo) | Golden tests; load/coupling default 0, not hardcoded high |
