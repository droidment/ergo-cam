# First prompt to paste into Claude Code

I'm building ErgoCam, an internal-demo Flutter app for live ergonomic posture
scoring from the phone camera. Read CLAUDE.md and everything in docs/ first.

Start with Phase 0 from docs/PLAN.md. Before writing code, show me:
1. The exact `flutter create` / `dart create` commands you'll run
2. The pubspec dependencies for app/ and packages/ergo_core with versions
3. Any Android manifest / gradle changes needed for camera + ML Kit

Then do Phase 0 and stop for review. After that, I'll run /next-phase each time.
Build `packages/ergo_core` scoring with tests (Phase 2) as early as you like —
it has no device dependency.
