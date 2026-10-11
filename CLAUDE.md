# ErgoCam — Live Ergonomic Assessment (Flutter)

Internal demo. A phone camera watches a worker (side view), runs on-device pose
estimation, and scores posture live with REBA and OWAS. Sessions can be recorded,
summarized (max / P90 / mean / % high-risk frames) and exported. Optional: stream
the live wireframe + scores to a laptop dashboard for demos.

Primary target: **Android (Pixel)**. iOS should compile but is secondary.

## Read before working
- `docs/PLAN.md` — phases, scope, acceptance criteria. Work one phase at a time.
- `docs/ARCHITECTURE.md` — modules, data flow, package choices.
- `docs/SCORING.md` — REBA/OWAS rules, angle definitions, golden tests.

## Repo layout
```
app/                    Flutter app (UI, camera, pose, sessions)
packages/ergo_core/     Pure Dart: angles, smoothing, REBA, OWAS, stats. NO Flutter imports.
dashboard/              (Phase 5) Small web viewer for live stream
docs/
```

## Commands
- `cd packages/ergo_core && dart test` — scoring unit tests (run after ANY scoring change)
- `cd app && flutter pub get && flutter run` — needs a physical device (camera)
- `cd app && flutter test` — widget/unit tests
- `cd app && flutter analyze` — must be clean before a phase is "done"

## Rules
1. **Scoring lives only in `packages/ergo_core`.** UI never computes scores.
2. **Never invent lookup-table values.** REBA tables are in `docs/SCORING.md`.
   The OWAS action-category table must be transcribed from a cited source and
   committed with a test per row block. If unsure of a value, stop and ask.
3. Every scoring rule change ships with a unit test. Golden posture tests in
   `docs/SCORING.md` must always pass (neutral standing must NOT score high).
4. Pose landmarks below the visibility threshold are ignored, not guessed.
   Frames without enough confident landmarks are marked `unscored`, not scored.
5. Privacy: don't persist raw camera frames unless the user starts a recording.
   No cloud upload of video in this demo.
6. Keep the camera/image-stream pipeline off the UI thread; measure FPS and show it.
7. Small, reviewable commits per task. Update `docs/PLAN.md` checkboxes as you go.

## Style
- Dart 3, null-safe, `flutter_lints`. Riverpod for state.
- Immutable models (`freezed` OK). Prefer pure functions in ergo_core.
