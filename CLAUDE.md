# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project summary

Focus Town is a mobile app where a block-style isometric town is built by small workers during focus sessions. Leaving the app mid-session kills the assigned workers and leaves a ruin. Completed buildings grow a persistent town with a daily streak, town levels, and a new plot per focus day. The app is fully offline.

## Where things are

- Requirements: `docs/spec.md`
- Build steps and prompts: `docs/prompt_plan.md`
- Progress checklist: `docs/todo.md`
- Manual device tests: `docs/device_tests.md`
- Visual target: `docs/images/` and `docs/reference/focus-town-voxel.html`

## Workflow rules

- Work on exactly one `prompt_plan` step at a time, always applying "Prompt 0" shared context.
- Write failing tests first, then implement until green.
- Run `flutter analyze` and `flutter test` before finishing a step and report the results.
- Tick the matching boxes in `docs/todo.md` when a step's work is done.
- Never start the next step without the user's go-ahead.
- Commit each step as `step NN: description`.

## Architecture rules

- `lib/domain` is pure Dart: no Flutter imports, no I/O, time only via the injected `Clock`.
- Layers: `lib/domain`, `lib/data`, `lib/platform`, `lib/game`, `lib/ui`, `lib/app`; tests mirror them under `test/`.
- Every new class must be wired into the app (app, provider, or debug screen) by the end of its step. No orphaned code.
- Session outcomes are always computed from stored timestamps (wall clock + monotonic uptime), never from in-memory timers alone.

## Tech stack and tools

- Platforms: one Flutter codebase for iOS 17+ and Android 10+ (minSdk 29). iOS beta first (TestFlight), then Android.
- Flutter stable channel, Dart 3 with null safety.
- Rendering: Flame (block-style isometric town, 2D, not real 3D).
- State management: `flutter_riverpod`.
- Local database: `drift` + `drift_flutter` (SQLite), with `drift_dev` + `build_runner` for code generation.
- Notifications: `flutter_local_notifications`.
- Native code: Swift (iOS) and Kotlin (Android) via platform channels, only for lifecycle/lock/call detection, uptime, and low-power mode.
- Testing: `flutter_test` (unit, widget, golden), `mocktail`, `integration_test`; use `FakeClock`, `FakeLifecycleSource`, and `FakeNotifier` for time, platform, and notifications.
- Lints: `very_good_analysis` (or `flutter_lints` with strict rules if it conflicts).
- Editor: VS Code with the Flutter and Dart extensions.
- Xcode: only for signing, iOS capabilities, Swift debugging (step 10), and archiving for TestFlight.
- Android Studio: not needed until step 11; only for the Android SDK and emulator.
- CocoaPods for iOS dependencies.

## Dependency rules

- Do not add any package not listed above without asking the user first and explaining why.
- Before adding a listed package, check its current stable version on pub.dev and pin it in `pubspec.yaml`.
- Never upgrade Flutter or packages mid-step; propose upgrades separately.
- Forbidden: Firebase; any analytics, crash-reporting, or ads SDK; `http`, `dio`, or any networking package; accounts or auth packages; other game engines; other state managers (Bloc, Provider, GetX); other databases (Hive, Isar, sqflite directly).

## Art rules

- Original block-style art only, matching `docs/images/` and the voxel prototype.
- No Minecraft textures, characters, or logos.
