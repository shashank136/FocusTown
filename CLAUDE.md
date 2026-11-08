# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Status

Pre-code. The repo currently holds only planning documents; no Flutter project exists yet (no `pubspec.yaml`, `lib/`, or `test/`). `files.zip` is just a bundle of the same docs and images. The first build step creates the app `focus_town`, so build/lint/test commands below are the ones the plan prescribes, not ones that run today.

- `spec.md` — MVP specification and source of truth (requirement IDs FR-1..12, NFR-1..8).
- `prompt_plan.md` — 22 ordered, test-driven prompts; "Prompt 0" is the shared context to prepend to each step.
- `todo.md` — per-step checklist. A step is done only when `flutter analyze` is clean, `flutter test` is green, and the app launches on a device.

When asked to implement a step, read its section in `prompt_plan.md` and `todo.md` first, and keep the spec's requirement IDs in tests.

## Product

Focus Town: iOS 17+/Android 10+ (minSdk 29) Flutter app. A block-style isometric town is built while the user stays off the phone. Leaving the app (without a lock or a call) for >10s (+60s with the single free pass) kills the assigned workers and leaves a permanent ruin. Fully offline, no accounts, no analytics, no network calls.

## Commands (once the project exists)

```
flutter analyze
flutter test
flutter test test/domain/session_engine_test.dart   # single file
flutter test --plain-name "substring of test name"  # single test
flutter test integration_test                       # on device
```

Commit format agreed in `todo.md`: `step NN: short description`.

## Architecture

Four layers in one Flutter app (`lib/domain`, `lib/data`, `lib/platform`, `lib/game`, `lib/ui`, `lib/app`; tests mirror these under `test/`). Riverpod for state, Drift/SQLite for storage, Flame for the town, `flutter_local_notifications` for warnings.

- **`lib/domain` is pure Dart**: no Flutter imports, no I/O, time only via the injected `Clock` (`SystemClock` / `FakeClock` with `advance`, `setWall`, `simulateReboot`). Key modules: `session_engine` (state machine), `town_rules` (tiers, workers, plots, queue, recovery mode, streak, XP), `building_defs` (block lists per tier/construction stage).
- **Outcomes are resolved from stored timestamps, never from timers alone.** The OS suspends or kills the app in the background, so the result must be identical whether the app stayed alive, was suspended, or was killed. On launch, any active/away session is resolved before the town is shown.
- **Time**: store both wall clock and monotonic uptime. Use uptime unless the device rebooted (uptime lower than stored), then fall back to wall clock and count the gap as away. If clock and uptime disagree, trust uptime; a session can never complete faster than real time.
- **Native bridge** (platform channel `focus/lifecycle`, Swift + Kotlin) emits `locked`, `unlocked`, `backgrounded`, `foregrounded`, `callStarted`, `callEnded` with monotonic timestamps. Distinguishing lock vs. app switch is the riskiest piece; it can only be verified on real devices (simulators can't). If the bridge is unavailable, fall back to `AppLifecycleState` treating every background as a lock (lenient).
- **Error philosophy**: when the app can't tell what happened, resolve in the user's favor; never destroy progress because of an app/OS fault. Every DB write is one transaction (no workers assigned without a session, no building without a plot).
- **Rendering**: 2D isometric blocks (three flat faces per block, back-to-front), cached static layer redrawn only on pan/zoom, frame-capped at 15–20 fps (10 in Low Power/Battery Saver), fully paused when hidden or locked. Fixed plot grid on fixed roads, no free placement or pathfinding; buildings defined in code as block lists.
- **Rules worth remembering**: tiers by session length (hut 10–20 / house 21–40 / workshop 41–60 / tower 61–90 / castle 91–120 min; durations in 5-min steps); only huts/houses add workers; start with 3 workers, 1 house, 6 plots, +1 plot per day with a completed session; full town queues finished buildings; 0 workers triggers Last Builder recovery mode (huts only) until 3 workers; failed sessions don't break the streak but earn no XP.
- Art: original blocky style, no Minecraft textures/characters/logos. Visual references are `block-town-*.png`.
