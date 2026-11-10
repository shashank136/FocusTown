# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project summary

Focus Town is a mobile app where a block-style isometric town is built by small workers during focus sessions. Leaving the app mid-session kills the assigned workers and leaves a ruin. Completed buildings grow a persistent town with a daily streak, town levels, and a new plot per focus day. The app is fully offline.

## Where things are

- Requirements: `docs/spec.md`
- Build steps and prompts: `docs/prompt_plan.md`
- Task queue and handoff notes (the active work list): `docs/tasks.md`
- Progress checklist: `docs/todo.md`
- Manual device tests: `docs/device_tests.md`
- Visual target: `docs/images/` and `docs/reference/focus-town-voxel.html`

## Repo status

The Flutter project exists and is built task by task. Phase A (steps 1-6: clock, tiers, session engine, town rules, progression) is done as pure, tested Dart in `lib/domain`, driven by a debug screen in `lib/ui` that now runs on the real `FocusController` (`lib/app`) and the drift database. `lib/data` (drift database, mappers, `TownRepository`) is done and read by the debug screen; `lib/platform` and `lib/game` are still empty. The Handoff notes at the top of `docs/tasks.md` name the current task; check them and `git log` rather than relying on this paragraph for progress.

## Commands

Valid once the project exists (T-01.1):

- `flutter pub get`
- `dart run build_runner build --delete-conflicting-outputs` (after changing drift tables)
- `flutter analyze`
- `flutter test` (all), `flutter test test/domain/some_test.dart` (one file), `flutter test --plain-name "case name"` (one case)
- `flutter test integration_test` (needs a device or simulator)
- `flutter run` (device or simulator)

## Running the app on the iOS simulator

Xcode 27.2 on the dev machine has no `Simulator.app`, so `open -a Simulator` fails. Use Device Hub instead.

1. List devices with `xcrun simctl list devices available` and pick an id (device ids are machine-specific).
2. Boot it with `xcrun simctl boot <id>`, then run `flutter run -d <id>`.
3. Open the window with `open "/Applications/Xcode.app/Contents/Applications/DeviceHub.app"`, then select the device.
4. To reset the app's state without `flutter run`, run `xcrun simctl terminate <id> com.example.focusTown`, then `xcrun simctl launch <id> com.example.focusTown`. The bundle id is a placeholder until the user decides.

Driving the UI from the shell (XcodeBuildMCP 2.7.0, registered as the MCP server `xcodebuild`; its tap and swipe tools are not exposed to the model, so use its CLI):

- Command form: `npx -y xcodebuildmcp@2.7.0 ui-automation <cmd> --simulator-id <id>`.
- `snapshot-ui` lists the buttons with refs such as `e31`, and the text on screen with `--output json`.
- `tap` reports success but Flutter ignores it. Use `touch --element-ref eNN --down --up`.
- Each action uses up the snapshot, so run `snapshot-ui` before every `touch`.
- The slider has no element ref, so it cannot be driven this way.
- `xcrun simctl io <id> screenshot <file>` saves a screenshot.

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

## Session protocol

The queue of coding work is `docs/tasks.md`. This protocol replaces the "one `prompt_plan` step at a time" and `step NN: description` commit rules above: work in tasks and use each task's own `Commit:` line.

- Every session starts by reading CLAUDE.md, then the Handoff notes and the first `[~]` or `[ ]` task in `docs/tasks.md`.
- If a task is `[~]`, run `git status` and `git diff` first and continue from where it stopped.
- Work on ONE task per session unless the user says otherwise.
- Write failing tests first, then implement until green.
- Before finishing: `flutter analyze` clean, `flutter test` green, tick the task `[x]`, tick matching boxes in `docs/todo.md`, update Handoff notes, then ask the user before committing with the task's commit message.
- For `[device]` tasks: give the user exact steps to perform on their iPhone or Android phone, wait for their results, record them in `docs/device_tests.md`, then tick the task.
- If stuck or a test cannot pass legitimately, mark the task `[!]` with the reason, update Handoff notes, and stop. Never weaken or delete a test to make it pass.
