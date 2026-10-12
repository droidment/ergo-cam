# Architecture

```
Camera (image stream, YUV) ──► PoseService (ML Kit, isolate-safe, drops busy frames)
        │                              │ 33 landmarks + visibility
        │                              ▼
        │                    ergo_core.Smoother (One Euro, per landmark)
        │                              ▼
  Accelerometer ──gravity──► ergo_core.AngleCalculator ──► JointAngles
                                       ▼
                 SessionInputs ──► ergo_core.Reba / ergo_core.Owas ──► FrameScore
                                       ▼
                ┌──────────────────────┼─────────────────────────┐
                ▼                      ▼                         ▼
       SkeletonPainter + HUD     SessionRecorder (log + video)   StreamClient (WS → dashboard)
                                       ▼
                               SessionSummary (stats) ──► Report / CSV / JSON
```

## Packages
| Concern | Package |
|---|---|
| Camera | `camera` |
| Pose | `google_mlkit_pose_detection` |
| Sensors | `sensors_plus` |
| State | `flutter_riverpod` |
| Charts | `fl_chart` |
| Storage | `sqflite` (or `isar`) + `path_provider` |
| Export | `share_plus`, `csv` |
| Streaming | `web_socket_channel` |

## App folders (`app/lib`)
```
main.dart
features/live/        live_screen.dart, skeleton_painter.dart, hud.dart, risk_colors.dart
features/session/     setup_sheet.dart, recorder.dart, summary_screen.dart, review_screen.dart
features/stream/      stream_client.dart, connect_screen.dart
services/             pose_service.dart, gravity_service.dart, frame_geometry.dart,
                      framing.dart, fps_meter.dart, camera_permission_service.dart
providers/            live_session_provider.dart (camera + pose + FrameScorer),
                      session_setup_provider.dart, camera_permission_provider.dart
```

## ergo_core (`packages/ergo_core/lib`)
```
(all under lib/src/, exported from lib/ergo_core.dart)
math/       vec2.dart
models/     landmark.dart, joint_angles.dart, session_inputs.dart, frame_score.dart
filters/    one_euro.dart
angles/     angle_calculator.dart
scoring/    frame_scorer.dart (live pipeline), reba.dart, reba_tables.dart, angle_bands.dart,
            owas.dart, owas_tables.dart, body_regions.dart
stats/      summary.dart          (max, p90, mean, % over threshold)
```

## Wire format (frame log + stream)
```json
{
  "t": 1234,
  "lm": [[x, y, z, vis], ...33],
  "angles": {"trunkFlex": 42.1, "neckFlex": 18.0, "upperArmL": 65.0, "...": 0},
  "reba": {"score": 9, "risk": "high", "a": 7, "b": 5, "regions": {"trunk": 3, "neck": 1}},
  "owas": {"code": "2141", "category": 3},
  "scored": true,
  "confidence": 0.86
}
```
