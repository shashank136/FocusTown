# Focus Town — Task Queue

Single source of truth for coding work. Each task is one focused change (about 30–90 minutes, 1–5 files) that ends with the app compiling, `flutter analyze` clean, and `flutter test` green. Tasks come from `docs/prompt_plan.md` steps 1–22; requirements are in `docs/spec.md`.

## How to work on this file

1. Find the first task marked `[~]`, then (if none) the first marked `[ ]`. Work only on that task.
2. Read the Handoff notes below and CLAUDE.md "Session protocol" before starting.
3. A task lists everything needed (rules, values, names, tests). Do not read `prompt_plan.md` or `spec.md` unless the task is unclear.
4. Status markers: `[ ]` not started, `[~]` in progress, `[x]` done, `[!]` blocked (add a one-line reason after the title).

## Handoff notes

Each session updates this section before stopping.

- Current task: T-22.2 (user loop: build step 17 workers + step 18 live construction, milestone T-18.5; Android T-11.x deferred; [device] tasks T-09.6, T-10.5, T-12.4, T-15.5, T-16.4, T-17.7 parked for a physical iPhone)
- What's left on it: T-22.1 done: repository writes go through _write (one retry, then SaveFailedException 'Couldn't save your session. Try again.'); controller keeps the last good state when saving fails at finish, abandon, lifecycle events or launch (a later tick or event retries); setup sheet shows the message. Tests use a drift QueryInterceptor that fails N writes. Next: T-22.2 backup/restore/fresh-town fallback.
- Gotchas:
  - T-01.1 deviations: `cupertino_icons` removed (not on allowed list). Pinned: flutter_riverpod 3.5.0, very_good_analysis 11.0.0, mocktail 1.0.5. Bundle id is `com.example.focus_town` until the user decides (ask before step 22).
  - No Android SDK on this machine (`flutter build apk` fails with "No Android SDK found"); Android compile not verified. Needed by step 11.
  - iOS deployment target 17.0 is set in `ios/Runner.xcodeproj`; there is no `ios/Podfile` yet (no plugins). When the first plugin is added and `pod install` creates it, set `platform :ios, '17.0'`.
  - Lints: `factory ClassName.named` triggers `unnecessary_type_name_in_constructor`, but `factory .named` does not parse; use an `// ignore:` for named factories. `@immutable` needs `package:meta` (not approved), so value classes with `==` use `ignore_for_file: avoid_equals_and_hash_code_on_mutable_classes`. Ask the user if they want `meta` added.
  - Widget tests that show DebugScreen must override `databaseProvider` with an in-memory `AppDatabase` (see `_overrides` in `debug_screen_test.dart`); `Override` type needs `import 'package:flutter_riverpod/misc.dart' show Override;`.
  - drift: `database.dart` has `ignore_for_file: public_member_api_docs`; in tests import `package:drift/drift.dart hide isNull` (clashes with matcher). After table changes run `dart run build_runner build --delete-conflicting-outputs`. drift_flutter is added but unused until T-07.6.
  - `buildingsToRows` stamps every row with the same `now`, so queue order survives only if the repository (T-07.5) passes existing `completedAt` values through; ties fall back to id order.
  - Seeing the app: Xcode 27.2 has no Simulator.app. Boot a device (`xcrun simctl boot <id>`), `flutter run -d <id>`, then `open "/Applications/Xcode.app/Contents/Applications/DeviceHub.app"` (confirmed working).
  - `TownState.copyWith` cannot set `lastStreakDate`/`lastPlotGrantDate` back to null (not needed; no clear flags).
  - Private ctor with the 3.13 shorthand: `new _();` (not `new._()`).
  - Flutter on this machine: 3.47.9 stable, Dart 3.13.7.
  - Lint `unnecessary_type_name_in_constructor` (very_good_analysis 11) wants Dart 3.13 shorthand: write `new(...)` instead of `ClassName(...)` for constructors.
- Last updated: 2026-11-09 (T-22.1 done)

## Status of steps

Total: 124 tasks (T-01.1 to T-22.15). Tasks tagged `[device]` need the user's physical phone.

- T-01 (step 1): [x] done (T-01.1–T-01.3).

## Shared context (applies to every task)

Focus Town is an iOS 17+ / Android 10+ (minSdk 29) Flutter app. The user starts a focus session of 10–120 minutes in 5-minute steps. Blocky workers build a building in an isometric block-style town. If the user leaves the app (switches apps while the phone is unlocked) and does not return within 10 seconds (plus one free 60-second pass per session), the assigned workers die and the plot becomes a permanent ruin. Locking the screen and phone calls are allowed. Completed buildings grow a persistent town. Fully offline: no network, accounts, or analytics.

**Stack:** Flutter stable, Dart 3, `flutter_riverpod`, `flame`, `drift` + `drift_flutter` (+ `drift_dev`, `build_runner`), `flutter_local_notifications`, `mocktail`, `very_good_analysis`. Swift/Kotlin only for platform channels. No other packages without asking the user first. Forbidden: Firebase, analytics/crash/ads SDKs, `http`/`dio`/networking, auth packages, other engines/state managers/databases. Pin exact versions in `pubspec.yaml` after checking pub.dev. Never upgrade Flutter or packages mid-task.

**Layers:** `lib/domain` (pure Dart: no Flutter imports, no I/O, time only through the injected `Clock`), `lib/data`, `lib/platform`, `lib/game`, `lib/ui`, `lib/app`. Tests mirror them under `test/`. Session outcomes are always computed from stored timestamps (wall clock + monotonic uptime), never from in-memory timers alone.

**Rules for every task:**

- Write the failing tests first, run them red, then implement until green.
- Keep existing tests green. Document public APIs with one-line doc comments.
- Every new class is used by the app, a provider, or the debug screen by the end of its step (the last code task of each step wires it).
- Original block-style art only. No Minecraft textures, characters, or logos.
- "Done when" always includes: `flutter analyze` clean and `flutter test` green.

**Conventions decided for the whole queue (tasks rely on these):**

- `TimeStamp { DateTime wall; Duration uptime; }` is the time value passed to domain functions as `now`. `TimeStamp.now(Clock)` builds one.
- `SessionEngine`, `TownRules`, and `Progression` are classes with only static functions.
- `FocusController` methods that react to lifecycle events take an optional `TimeStamp? at` (defaults to now), so the router can pass the event's own timestamp.
- `TownState.queue` is `List<QueuedBuilding>` where `QueuedBuilding { String id; BuildingTier tier; }` (the id is the session id). This deviates from the prompt's `List<BuildingTier>` so queued buildings keep their identity in the database.
- Session ids are `'s${now.wall.microsecondsSinceEpoch}'`.
- Wall times are stored in SQLite as integer epoch milliseconds (UTC); uptimes as integer milliseconds.
- In recovery mode `workersAssigned` is always 0, so a failed recovery hut costs nothing and the wanderer never dies.
- Commit messages use the exact `Commit:` line of the task.
- The town map is 64x64 (not 32x32): 64 plots of 7x7 are needed for a long streak and cannot fit in 32x32. See T-14.1.
- iOS uptime must use `clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW)` (counts device sleep), not `ProcessInfo.systemUptime`. See T-10.2.
- The active construction site is part of the world and the cached picture re-records on stage change (no separate dynamic layer). See T-18.1.
- Packages not on the CLAUDE.md list (`path_provider`, `timezone`, any share/launcher-icon package) need the user's approval first. Tasks that might need them say so.

---

## Phase A: foundation and rules

### T-01.1 [x] Flutter project, dependencies, folders
- Step: 1 (docs/prompt_plan.md, Prompt 1)
- Depends on: none
- Goal: create the `focus_town` Flutter app in the repo root with dependencies, strict lints, and the layer folders, so later tasks have a compiling base.
- Files: `pubspec.yaml`, `analysis_options.yaml`, `lib/main.dart`, `test/widget_test.dart` (remove the counter test), `lib/{domain,data,platform,game,ui,app}/.gitkeep`, `test/{domain,data,platform,game,ui,app}/.gitkeep`, `.gitignore` (merge with the Flutter one, keep existing entries).
- Do:
  1. In the repo root run `flutter create --project-name focus_town --platforms ios,android --org com.example .` (keep `docs/`, `CLAUDE.md`, `README.md`, `.vscode/`). Bundle id stays `com.example.focus_town` until the user picks one.
  2. Set Android `minSdk` to 29 (`android/app/build.gradle*`) and iOS deployment target to 17.0 (`ios/Podfile` `platform :ios, '17.0'` and Xcode project setting).
  3. Check current stable versions on pub.dev and pin them exactly (no `^`): dependency `flutter_riverpod`; dev dependencies `very_good_analysis`, `mocktail`. Add nothing else.
  4. `analysis_options.yaml`: `include: package:very_good_analysis/analysis_options.yaml`. If a rule conflicts with generated code, exclude only that rule and note why in a comment.
  5. Replace the counter app in `lib/main.dart` with a minimal `runApp(const MaterialApp(home: Scaffold()))` placeholder (T-01.3 replaces it). Delete the generated counter widget test.
  6. Create the layer folders under `lib/` and `test/` with `.gitkeep` files.
- Tests first: none can be written before the project exists. After scaffolding, add `test/app/smoke_test.dart` with one widget test that pumps `MaterialApp(home: Scaffold())` and finds a `Scaffold`, to prove `flutter test` runs.
- Done when: flutter analyze clean; flutter test green; `flutter run` (or `flutter build apk --debug`) compiles; `git status` shows no build output committed.
- Commit: `T-01.1: flutter project skeleton and deps`

### T-01.2 [x] Clock, SystemClock, FakeClock
- Step: 1 (docs/prompt_plan.md, Prompt 1)
- Depends on: T-01.1
- Goal: the injectable clock every later task depends on: wall time plus monotonic uptime, with a controllable fake.
- Files: `lib/domain/clock.dart`, `lib/domain/testing/fake_clock.dart`, `test/domain/clock_test.dart`.
- Do:
  1. `lib/domain/clock.dart`: `abstract class Clock { DateTime nowWall(); Duration uptime(); }`.
  2. `SystemClock implements Clock` in the same file: `nowWall()` returns `DateTime.now()`; `uptime()` returns a `Stopwatch` started at construction (app launch). T-10.4 replaces this with native uptime on iOS/Android.
  3. `lib/domain/testing/fake_clock.dart`: `FakeClock implements Clock`, constructor `FakeClock({DateTime? start})` (default `DateTime(2026, 1, 1, 9)`), uptime starts at `Duration.zero`. Methods: `advance(Duration d)` (adds `d` to both wall and uptime), `setWall(DateTime t)` (changes wall only), `simulateReboot()` (sets uptime to zero; wall keeps going, unchanged).
  4. Pure Dart only: no Flutter imports in `lib/domain`.
- Tests first (`test/domain/clock_test.dart`):
  - `advance` moves wall and uptime by the same amount.
  - `setWall` changes wall only; uptime unchanged.
  - `simulateReboot` sets uptime to zero and leaves wall unchanged; a later `advance` moves both from there.
  - `SystemClock.uptime()` is non-negative and non-decreasing across two calls.
- Done when: flutter analyze clean; flutter test green.
- Commit: `T-01.2: clock, system clock and fake clock`

### T-01.3 [x] clockProvider, FocusTownApp and DebugScreen
- Step: 1 (docs/prompt_plan.md, Prompt 1)
- Depends on: T-01.2
- Goal: wire the clock into the running app with a debug screen showing live wall time and uptime. This ends step 1.
- Files: `lib/app/providers.dart`, `lib/app/app.dart`, `lib/main.dart`, `lib/ui/debug_screen.dart`, `test/ui/debug_screen_test.dart`.
- Do:
  1. `lib/app/providers.dart`: `final clockProvider = Provider<Clock>((ref) => SystemClock());`.
  2. `lib/app/app.dart`: `FocusTownApp` (`ConsumerWidget`/`StatelessWidget`) returning `MaterialApp(home: DebugScreen())`.
  3. `lib/main.dart`: `runApp(const ProviderScope(child: FocusTownApp()))`.
  4. `lib/ui/debug_screen.dart`: `DebugScreen` (`ConsumerStatefulWidget`) with title text `Focus Town debug`, and two lines `Wall: <time>` and `Uptime: <h:mm:ss>` read from `clockProvider`, refreshed by a 1-second `Timer.periodic` (cancel in `dispose`).
- Tests first (`test/ui/debug_screen_test.dart`): override `clockProvider` with a `FakeClock`; pump `DebugScreen`; expect the title `Focus Town debug` and text starting `Wall:` and `Uptime:`; call `clock.advance(const Duration(seconds: 5))`, pump 1 second, expect the uptime text changed.
- Done when: flutter analyze clean; flutter test green; app launches on the simulator showing the debug screen with ticking time.
- Commit: `T-01.3: app shell and debug screen`

### T-02.1 [x] BuildingTier enum and helpers
- Step: 2 (docs/prompt_plan.md, Prompt 2)
- Depends on: T-01.3
- Goal: one source of truth for the five building tiers and duration rules.
- Files: `lib/domain/building_tier.dart`, `test/domain/building_tier_test.dart`.
- Do:
  1. `enum BuildingTier { hut, house, workshop, tower, castle }` with fields `minMinutes`, `maxMinutes`, `workersAtRisk`, `workersAddedOnSuccess`:
     - hut: 10–20 min, risk 1, adds 1
     - house: 21–40 min, risk 2, adds 2
     - workshop: 41–60 min, risk 3, adds 0
     - tower: 61–90 min, risk 5, adds 0
     - castle: 91–120 min, risk 8, adds 0
  2. `static BuildingTier forMinutes(int minutes)`: throws `ArgumentError` if `minutes < 10`, `> 120`, or `minutes % 5 != 0`; otherwise returns the tier whose range contains it.
  3. `static List<int> validDurations()`: `[10, 15, ..., 120]` (23 values).
  4. `static BuildingTier? largestAffordable(int workers)`: the biggest tier whose `workersAtRisk <= workers`, else `null`.
- Tests first: `forMinutes` at 10, 20, 25, 40, 45, 60, 65, 90, 95, 120 returns hut, hut, house, house, workshop, workshop, tower, tower, castle, castle; throws for 5, 0, -5, 11, 22, 125, 130; `validDurations()` has length 23, first 10, last 120, all multiples of 5; `largestAffordable` for 0 → null, 1 → hut, 2 → house, 3 → workshop, 4 → workshop, 5 → tower, 8 → castle, 20 → castle.
- Done when: flutter analyze clean; flutter test green.
- Commit: `T-02.1: building tiers`

### T-02.2 [x] Debug duration slider
- Step: 2 (docs/prompt_plan.md, Prompt 2)
- Depends on: T-02.1
- Goal: wire `BuildingTier` into the app with a slider on the debug screen.
- Files: `lib/ui/debug_screen.dart`, `test/ui/debug_screen_test.dart`.
- Do:
  1. Add a `Slider` with `divisions` over `BuildingTier.validDurations()` (index 0–22). Default 25 minutes.
  2. Below it show `Minutes: <n>`, `Tier: <name>`, `Workers at risk: <n>`.
  3. For the tier use `BuildingTier.forMinutes(minutes)`.
- Tests first: default shows `Minutes: 25`, `Tier: house`, `Workers at risk: 2`; dragging the slider to its minimum shows `Minutes: 10`, `Tier: hut`, `Workers at risk: 1`; maximum shows `Minutes: 120`, `Tier: castle`, `Workers at risk: 8`.
- Done when: flutter analyze clean; flutter test green; slider works in the simulator.
- Commit: `T-02.2: debug duration slider`

### T-03.1 [x] TimeStamp and elapsedBetween
- Step: 3 (docs/prompt_plan.md, Prompt 3)
- Depends on: T-02.2
- Goal: the elapsed-time function that survives reboots and wall-clock changes.
- Files: `lib/domain/time_stamp.dart`, `lib/domain/elapsed.dart`, `test/domain/elapsed_test.dart`.
- Do:
  1. `TimeStamp` immutable value class `{ final DateTime wall; final Duration uptime; }` with `==`/`hashCode`, `const` constructor, and `factory TimeStamp.now(Clock clock)` = `TimeStamp(clock.nowWall(), clock.uptime())`.
  2. `Duration elapsedBetween(TimeStamp from, TimeStamp to)`:
     - Normal case (`to.uptime >= from.uptime`): return `to.uptime - from.uptime`. Uptime is trusted over wall time.
     - Reboot happened (`to.uptime < from.uptime`): return `to.wall - from.wall`, clamped to `>= Duration.zero`.
     - Never return a negative duration.
- Tests first (`FakeClock`): 30 minutes passes normally → 30 min; wall clock moved forward 2 hours mid-way (`setWall`) → elapsed still 30 min; wall clock moved backward → elapsed unaffected; reboot after 10 min then 5 more minutes of wall time → 15 min; reboot with wall clock moved backward → exactly `Duration.zero`, not negative; `TimeStamp.now` captures both values.
- Done when: flutter analyze clean; flutter test green.
- Commit: `T-03.1: time stamp and elapsed calculation`

### T-03.2 [x] Wall-clock tamper detection
- Step: 3 (docs/prompt_plan.md, Prompt 3)
- Depends on: T-03.1
- Goal: detect when the wall clock disagrees with uptime so it can be logged.
- Files: `lib/domain/elapsed.dart`, `test/domain/elapsed_test.dart`.
- Do: add `bool wallClockTampered(TimeStamp from, TimeStamp to)`: true when uptime did not reset (`to.uptime >= from.uptime`) and `|wallDelta - uptimeDelta| > Duration(minutes: 2)`, where `wallDelta = to.wall - from.wall` and `uptimeDelta = to.uptime - from.uptime`. After a reboot always false (cannot tell).
- Tests first: clean 30 minutes → false; wall +2 hours → true; wall -2 hours → true; difference exactly 2 minutes → false; 2 minutes 1 second → true; reboot with any wall change → false.
- Done when: flutter analyze clean; flutter test green.
- Commit: `T-03.2: wall clock tamper detection`

### T-03.3 [x] Debug "elapsed since app start"
- Step: 3 (docs/prompt_plan.md, Prompt 3)
- Depends on: T-03.2
- Goal: wire `elapsedBetween` and `wallClockTampered` into the app via the debug screen. Ends step 3.
- Files: `lib/ui/debug_screen.dart`, `test/ui/debug_screen_test.dart`.
- Do:
  1. In `DebugScreen` state, capture `TimeStamp.now(clock)` once when the screen is first built (`initState`).
  2. Each refresh show `Elapsed since start: <mm:ss>` from `elapsedBetween(start, TimeStamp.now(clock))` and `Clock tampered: yes/no` from `wallClockTampered`.
- Tests first: with `FakeClock`, after `advance(90s)` and a pump the text shows `01:30` and `Clock tampered: no`; after `setWall` +3 hours the text shows `Clock tampered: yes` and elapsed unchanged.
- Done when: flutter analyze clean; flutter test green.
- Commit: `T-03.3: debug elapsed time display`

### T-04.1 [x] Session model and enums (no logic)
- Step: 4 (docs/prompt_plan.md, Prompt 4)
- Depends on: T-03.3
- Goal: the immutable `Session` value type and its enums, with no behavior beyond copying.
- Files: `lib/domain/session.dart`, `test/domain/session_test.dart`.
- Do:
  1. `enum SessionState { running, away, completed, failed }` and `enum OutcomeReason { completed, leftTooLong, abandoned }`.
  2. Immutable `Session` with fields: `String id`, `int plannedMinutes`, `BuildingTier tier`, `int workersAssigned`, `SessionState state`, `TimeStamp startedAt`, `TimeStamp? leftAt`, `Duration awayTotal`, `bool passUsed`, `OutcomeReason? outcomeReason`.
  3. `const` constructor, `copyWith` (to set `leftAt` or `outcomeReason` back to null use a `clearLeftAt: true` flag; `outcomeReason` never needs clearing), `==`/`hashCode` over all fields, helper getters `bool get isActive` (running or away) and `bool get isFinished` (completed or failed), and `Duration get planned => Duration(minutes: plannedMinutes)`.
- Tests first: `copyWith` changes only the named field; `clearLeftAt` clears `leftAt`; equal sessions compare equal and differ when any field differs; `isActive`/`isFinished` for all four states; `planned` for 25 minutes is 25 min.
- Done when: flutter analyze clean; flutter test green.
- Commit: `T-04.1: session model and enums`

### T-04.2 [x] SessionEngine.start with validation
- Step: 4 (docs/prompt_plan.md, Prompt 4)
- Depends on: T-04.1
- Goal: create a running session, rejecting invalid durations and too few workers.
- Files: `lib/domain/session_engine.dart`, `test/domain/session_engine_test.dart`.
- Do:
  1. `class SessionEngine { SessionEngine._(); }` with only static functions. Constants at top of the file: `const kWarningWindow = Duration(seconds: 10);` and `const kPassWindow = Duration(seconds: 60);`.
  2. `static Session start({required String id, required int minutes, required int workersAvailable, required TimeStamp now})`:
     - `tier = BuildingTier.forMinutes(minutes)` (this throws `ArgumentError` for invalid minutes; let it propagate).
     - throw `StateError` if `workersAvailable < tier.workersAtRisk`.
     - return `Session(id, plannedMinutes: minutes, tier, workersAssigned: tier.workersAtRisk, state: running, startedAt: now, leftAt: null, awayTotal: Duration.zero, passUsed: false, outcomeReason: null)`.
- Tests first: valid 25 min with 5 workers → running house, `workersAssigned` 2, `startedAt` equals `now`, `passUsed` false, `awayTotal` zero; 10 min with 1 worker works; 120 min with 8 works; 120 min with 7 throws `StateError`; 7 min throws `ArgumentError`; 130 min throws `ArgumentError`; 25 min with 1 worker throws `StateError`.
- Done when: flutter analyze clean; flutter test green.
- Commit: `T-04.2: session engine start`

### T-04.3 [x] Away and foreground rules (10 s window, one 60 s pass)
- Step: 4 (docs/prompt_plan.md, Prompt 4)
- Depends on: T-04.2
- Goal: lock/call events are harmless; leaving the app starts the away timer; returning applies the 10-second window and the single free 60-second pass.
- Files: `lib/domain/session_engine.dart`, `test/domain/session_engine_test.dart`.
- Do: add static functions, each returning a new `Session`:
  1. `onLocked(session, now)` and `onCallStarted(session, now)`: return the session unchanged (allowed).
  2. `onBackgroundedUnlocked(session, now)`: only if `state == running` → `away` with `leftAt = now`. Any other state: unchanged.
  3. `onForegrounded(session, now)`: only if `state == away`, else unchanged. `away = elapsedBetween(session.leftAt!, now)`.
     - `away <= kWarningWindow` (10 s, inclusive) → `running`, `leftAt` cleared, `awayTotal += away`.
     - `away > kWarningWindow && away <= kWarningWindow + kPassWindow` (70 s, inclusive) and `!passUsed` → `running`, `passUsed = true`, `leftAt` cleared, `awayTotal += away`.
     - otherwise → `failed`, `outcomeReason = leftTooLong`, `awayTotal += away`, keep `leftAt`.
  4. `abandon(session, now)`: if active (running or away) → `failed` with `outcomeReason = abandoned`. Finished sessions unchanged.
  5. The pass is only spent on return (`onForegrounded`); `resolve` (T-04.4) never spends it.
- Tests first (FakeClock; start a 25-minute session each time): lock for 5 minutes → unchanged; call started → unchanged; away 5 s → running, `passUsed` false, `awayTotal` 5 s; away exactly 10 s → running, no pass; away 30 s → running, `passUsed` true; second away of 30 s in the same session → failed `leftTooLong`; away exactly 70 s with pass → running; away 71 s → failed; away 90 s → failed; away 11 s after the pass was already used → failed; `onBackgroundedUnlocked` on an away or finished session is a no-op; `onForegrounded` on a running session is a no-op; abandon from running and from away → failed `abandoned`; abandon of a completed session is a no-op.
- Done when: flutter analyze clean; flutter test green.
- Commit: `T-04.3: session away window and pass`

### T-04.4 [x] resolve(): away timeout and completion
- Step: 4 (docs/prompt_plan.md, Prompt 4)
- Depends on: T-04.3
- Goal: the single function called on every tick and app launch; it decides timeouts and completion from stored timestamps only.
- Files: `lib/domain/session_engine.dart`, `test/domain/session_engine_test.dart`.
- Do: add `static Session resolve(Session session, TimeStamp now)`:
  1. Finished sessions: return unchanged.
  2. Away session: `away = elapsedBetween(leftAt!, now)`; `limit = passUsed ? kWarningWindow : kWarningWindow + kPassWindow` (10 s if the pass is already spent, else 70 s).
     - `away > limit`: if `elapsedBetween(startedAt, leftAt) + limit >= planned` the planned time was reached while the user was still inside the allowed window → `completed`, `outcomeReason = completed`; otherwise `failed`, `outcomeReason = leftTooLong`. Either way `awayTotal += away`, keep `leftAt`.
     - `away <= limit`: if `elapsedBetween(startedAt, now) >= planned` → `completed` (`awayTotal += away`); else unchanged (still away; the app has not come back yet).
  3. Running session: if `elapsedBetween(startedAt, now) >= planned` → `completed`, `outcomeReason = completed`. Time away inside the allowed limits counts, because completion uses the whole span from `startedAt`.
  4. Add a doc comment on `resolve` describing these rules.
- Tests first (25-minute session): completion exactly at 25 min → completed; 24 min 59 s → still running; resolve while away 30 s → still away; resolve while away 71 s with pass unused → failed without any `onForegrounded` call; away 11 s with pass already used → failed; user left at minute 24, now is minute 60 (pass unused, limit ends at 25:10, planned time 25:00 falls inside it) → completed; user left at minute 10, now minute 60 → failed; running session with a 5-minute lock in the middle completes at 25 min total; resolve on a finished session returns the same object.
- Done when: flutter analyze clean; flutter test green.
- Commit: `T-04.4: session resolve and completion`

### T-04.5 [x] progress() and reboot during away
- Step: 4 (docs/prompt_plan.md, Prompt 4)
- Depends on: T-04.4
- Goal: add progress reporting and prove the reboot paths through the elapsed calculator.
- Files: `lib/domain/session_engine.dart`, `test/domain/session_engine_test.dart`.
- Do:
  1. `static double progress(Session session, TimeStamp now)`: `completed` → `1.0`; otherwise `elapsedBetween(startedAt, now) / planned` clamped to `0.0..1.0`.
  2. No new rules for reboots: `elapsedBetween` already falls back to wall time when uptime drops. Only tests are needed for that, plus fixes if any test fails.
- Tests first: progress at 0 → 0.0; at 12.5 of 25 min → 0.5; at 25 min → 1.0; at 40 min → 1.0 (clamped); completed session → 1.0; reboot during away (leave at uptime 10 min, `simulateReboot`, wall gap 90 s) → `onForegrounded` fails with `leftTooLong`; reboot during away with a 30 s wall gap and pass unused → returns to running with `passUsed`; reboot while running (planned 25 min, 10 min before, reboot, 15 min wall) → `resolve` completes; reboot with wall clock set backward → elapsed 0, session not completed early and no negative progress.
- Done when: flutter analyze clean; flutter test green.
- Commit: `T-04.5: session progress and reboot cases`

### T-04.6 [x] Session simulator panel on DebugScreen
- Step: 4 (docs/prompt_plan.md, Prompt 4)
- Depends on: T-04.5
- Goal: wire `SessionEngine` into the running app with a simulator driven by its own `FakeClock`. Ends step 4.
- Files: `lib/ui/session_simulator_panel.dart`, `lib/ui/debug_screen.dart`, `test/ui/session_simulator_panel_test.dart`.
- Do:
  1. `SessionSimulatorPanel` (StatefulWidget) takes `int minutes` (the debug slider value) and owns a local `FakeClock` plus a nullable `Session`.
  2. Buttons: `Start` (calls `SessionEngine.start` with id `'sim'`, the slider minutes, and `workersAvailable: 20` for now), `+1 min` (advance 1 min), `Leave` (`onBackgroundedUnlocked`), `Return after 5s`, `Return after 30s`, `Return after 90s` (each advances the fake clock by that time, then `onForegrounded`), `Lock` (advance 5 min, `onLocked`), `Abandon`.
  3. After every action call `SessionEngine.resolve(session, TimeStamp.now(clock))`.
  4. Show: state, progress as a percent, `passUsed`, outcome reason (or `-`).
  5. Place the panel in `DebugScreen` below the slider, passing the slider minutes.
- Tests first (widget, 10-minute duration): Start → state `running`; Leave then Return after 5s → `running`, pass `false`; Leave then Return after 30s → pass `true`; Leave then Return after 90s → `failed`, outcome `leftTooLong`; `+1 min` ten times → `completed`; Abandon → `failed`, `abandoned`.
- Done when: flutter analyze clean; flutter test green; simulator behaves per the rules in the app.
- Commit: `T-04.6: session simulator panel`

### T-05.1 [x] TownState, TownBuilding, QueuedBuilding, initial town
- Step: 5 (docs/prompt_plan.md, Prompt 5)
- Depends on: T-04.6
- Goal: the immutable town value types and the starting town.
- Files: `lib/domain/town.dart`, `test/domain/town_test.dart`.
- Do:
  1. `enum BuildingStatus { complete, ruin }`.
  2. `TownBuilding { String id; BuildingTier tier; BuildingStatus status; int plotIndex; }`.
  3. `QueuedBuilding { String id; BuildingTier tier; }` (a finished building waiting for a free plot; the id is the session id).
  4. `TownState { int workers; int plotsUnlocked; List<TownBuilding> buildings; List<QueuedBuilding> queue; bool inRecoveryMode; }` with `copyWith`, value equality (deep over lists), and unmodifiable lists.
  5. `TownState.initial()`: `workers = 3`, `plotsUnlocked = 6`, `buildings = [TownBuilding(id: 'starter', tier: house, status: complete, plotIndex: 0)]`, `queue = []`, `inRecoveryMode = false`.
- Tests first: `initial()` values exactly as above; `copyWith` changes only named fields; equality is deep (two equal states with separate lists are equal; differing queue makes them unequal); lists cannot be mutated from outside (throws `UnsupportedError`).
- Done when: flutter analyze clean; flutter test green.
- Commit: `T-05.1: town state types`

### T-05.2 [x] nextFreePlot and canStart
- Step: 5 (docs/prompt_plan.md, Prompt 5)
- Depends on: T-05.1
- Goal: plot lookup and the rule for whether a duration can be started.
- Files: `lib/domain/town_rules.dart`, `test/domain/town_rules_test.dart`.
- Do:
  1. `class TownRules { TownRules._(); }`, static functions only.
  2. `static int? nextFreePlot(TownState town)`: lowest index `i < plotsUnlocked` not used by any building in `town.buildings` (complete or ruin both occupy a plot); `null` if none.
  3. `static bool canStart(TownState town, int minutes)`: `false` if minutes is invalid (not 10–120 in steps of 5; do not throw). Otherwise `tier = BuildingTier.forMinutes(minutes)`; if `town.inRecoveryMode` → `tier == hut`; else `town.workers >= tier.workersAtRisk`.
- Tests first: initial town → `nextFreePlot` 1; buildings on plots 0, 1, 3 with 6 unlocked → 2; all 6 plots used → null; ruin on plot 0 still blocks it; `plotsUnlocked` 7 with 6 used → 6; `canStart` for every tier (10, 25, 45, 65, 95 minutes) at 0, 1, 2, 3, 4, 5, 8 workers per the table (risk 1/2/3/5/8); invalid minutes (7, 130) → false; recovery mode with 0 workers: 10 and 20 → true, 25 → false; recovery mode with 2 workers: 25 → false.
- Done when: flutter analyze clean; flutter test green.
- Commit: `T-05.2: town rules plot lookup and canStart`

### T-05.3 [x] applyCompleted and placeQueued
- Step: 5 (docs/prompt_plan.md, Prompt 5)
- Depends on: T-05.2
- Goal: success outcome: add workers, place or queue the building, and drain the queue.
- Files: `lib/domain/town_rules.dart`, `test/domain/town_rules_test.dart`.
- Do:
  1. `static TownState applyCompleted(TownState town, Session session)`: `workers += session.tier.workersAddedOnSuccess` (assigned workers come back alive, so no other change). Place `TownBuilding(id: session.id, tier: session.tier, status: complete, plotIndex: nextFreePlot)` if a plot is free; otherwise append `QueuedBuilding(session.id, session.tier)` to `queue`. Then run the recovery check (below).
  2. `static TownState placeQueued(TownState town)`: while `queue` is not empty and `nextFreePlot` exists, move the oldest (first) queued item to `buildings` as `complete` on that plot.
  3. Recovery check helper (private `_updateRecovery`, reused by T-05.4): if `workers >= 3` → `inRecoveryMode = false`; if `workers == 0` → `true`; otherwise unchanged.
- Tests first: hut success on initial town → workers 4, new building on plot 1; house success → workers 5; workshop/tower/castle success → workers unchanged; all 6 plots full then success → queue length 1, buildings unchanged; `placeQueued` with `plotsUnlocked` raised from 6 to 7 → queue empty, building on plot 6; two queued with one free plot → oldest placed, one left; `placeQueued` with no free plot or empty queue → unchanged; recovery town with 2 workers, hut success → workers 3, `inRecoveryMode` false; recovery town with 0 workers, hut success → workers 1, still recovery.
- Done when: flutter analyze clean; flutter test green.
- Commit: `T-05.3: town rules completed and queue`

### T-05.4 [x] applyFailed and recovery mode
- Step: 5 (docs/prompt_plan.md, Prompt 5)
- Depends on: T-05.3
- Goal: failure outcome: workers die, a ruin takes a plot, and recovery mode starts at 0 workers.
- Files: `lib/domain/town_rules.dart`, `test/domain/town_rules_test.dart`.
- Do: `static TownState applyFailed(TownState town, Session session)`:
  1. `workers = max(0, workers - session.workersAssigned)`. In recovery mode sessions have `workersAssigned == 0` (T-05.5), so a failed recovery hut costs nothing and the wanderer survives.
  2. If a plot is free, add `TownBuilding(id: session.id, tier: session.tier, status: ruin, plotIndex: nextFreePlot)`. If none is free, place nothing (no ruin and no queue entry).
  3. Run `_updateRecovery`: `workers == 0` → `inRecoveryMode = true`.
- Tests first: house failure on initial town (3 workers) → workers 1, ruin on plot 1; castle assigned 8 on a 10-worker town → 2 left; failure with no free plot → workers reduced, buildings unchanged, queue unchanged; failure that leaves 0 workers → `inRecoveryMode` true; recovery failure with `workersAssigned` 0 → workers unchanged, ruin placed, still recovery; 3 recovery huts completing from 0 workers → workers 3 and recovery false (exits exactly at 3, not before); workers never negative.
- Done when: flutter analyze clean; flutter test green.
- Commit: `T-05.4: town rules failure and recovery`

### T-05.5 [x] SessionEngine.start supports recovery
- Step: 5 (docs/prompt_plan.md, Prompt 5)
- Depends on: T-05.4
- Goal: let the engine start a worker-free hut session in recovery mode.
- Files: `lib/domain/session_engine.dart`, `test/domain/session_engine_test.dart`.
- Do: add `bool recovery = false` to `SessionEngine.start`. When `recovery` is true: the tier must be `hut` (else `StateError`), `workersAvailable` is ignored, and `workersAssigned = 0`. When false: behavior unchanged (`StateError` if `workersAvailable < tier.workersAtRisk`, `workersAssigned = tier.workersAtRisk`). Callers decide `recovery` from `TownState.inRecoveryMode` after checking `TownRules.canStart`.
- Tests first: recovery start 10 min with 0 workers → running, `workersAssigned` 0; recovery start 20 min works; recovery start 25 min → `StateError`; recovery start with 2 workers available still assigns 0; non-recovery start unchanged (existing tests stay green); after a recovery session fails, `TownRules.applyFailed` leaves workers unchanged (cross-check).
- Done when: flutter analyze clean; flutter test green.
- Commit: `T-05.5: session start in recovery mode`

### T-05.6 [x] Simulator owns a TownState
- Step: 5 (docs/prompt_plan.md, Prompt 5)
- Depends on: T-05.5
- Goal: wire `TownRules` into the app: simulated sessions now change a simulated town. Ends step 5.
- Files: `lib/ui/session_simulator_panel.dart`, `lib/ui/debug_screen.dart`, `test/ui/session_simulator_panel_test.dart`.
- Do:
  1. The panel owns a `TownState` (starts as `TownState.initial()`).
  2. `Start` is disabled unless `TownRules.canStart(town, minutes)`; when disabled show a reason line: `Needs N workers, you have M` (N = tier risk) or, in recovery, `Recovery mode: huts only`. (The slider itself stays as is; rejected values are blocked at Start.) Start calls `SessionEngine.start(workersAvailable: town.workers, recovery: town.inRecoveryMode, ...)` with a unique id (`'sim${counter}'`).
  3. When a session becomes `completed`, apply `TownRules.applyCompleted` once; when `failed`, apply `TownRules.applyFailed` once (guard against applying twice).
  4. Show: workers, plots `used/unlocked` (buildings count / plotsUnlocked), queue length, recovery flag, and a list of buildings (`tier status plot N`).
- Tests first (widget): initial display shows workers 3, plots 1/6, queue 0, recovery false; completing a 10-minute hut → workers 4 and 2 buildings; failing a 25-minute house session (Leave, Return after 90s) → workers 1 and a ruin listed; Start with a castle duration at 3 workers is disabled with the reason `Needs 8 workers, you have 3`; losing all workers shows recovery true and only 10–20 minute durations enable Start.
- Done when: flutter analyze clean; flutter test green; simulator updates the town in the app.
- Commit: `T-05.6: simulator town state`

### T-06.1 [x] LocalDate value class
- Step: 6 (docs/prompt_plan.md, Prompt 6)
- Depends on: T-05.6
- Goal: calendar-day arithmetic kept in one tiny tested class.
- Files: `lib/domain/local_date.dart`, `test/domain/local_date_test.dart`.
- Do: immutable `LocalDate(year, month, day)` with `const` constructor; `factory LocalDate.fromDateTime(DateTime dt)` uses `dt.year/month/day` as given (the caller passes local time); `int daysBetween(LocalDate other)` = days from `this` to `other` (positive if `other` is later), computed with `DateTime.utc(y, m, d)` differences so DST never matters; `==`, `hashCode`, `compareTo`; `String toIso()` → `yyyy-MM-dd` (zero padded) and `factory LocalDate.parse(String)` that reads it back (throws `FormatException` on bad input).
- Tests first: same day → 0; next day → 1; reverse → -1; Jan 31 → Feb 1 is 1; Feb 28 → Mar 1 is 1 in 2026 and 2 in 2028 (leap year Feb 29); Dec 31 → Jan 1 is 1; across a DST change in a local-time `DateTime` still 1; `toIso`/`parse` round trip for 2026-03-05; `parse('bad')` throws; equality and ordering.
- Done when: flutter analyze clean; flutter test green.
- Commit: `T-06.1: local date`

### T-06.2 [x] TownState progression fields and TownLevel
- Step: 6 (docs/prompt_plan.md, Prompt 6)
- Depends on: T-06.1
- Goal: add XP, streak, and plot-grant fields to the town and define town levels.
- Files: `lib/domain/town.dart`, `lib/domain/progression.dart`, `test/domain/town_test.dart`, `test/domain/progression_test.dart`.
- Do:
  1. `TownState` gets `int xp` (0), `int streakCount` (0), `LocalDate? lastStreakDate`, `LocalDate? lastPlotGrantDate`; defaults keep `initial()` and all earlier tests unchanged. Update `copyWith`, equality.
  2. In `progression.dart`: `enum TownLevel { camp(0), village(300), town(1500), city(6000), metropolis(15000) }` with `final int minXp`; `static TownLevel levelFor(int xp)` and `static double progressToNext(int xp)` as functions of a `Progression` class (static only): fraction `(xp - level.minXp) / (next.minXp - level.minXp)` clamped 0.0–1.0; `metropolis` returns `1.0`.
- Tests first: `initial()` has xp 0, streak 0, null dates; `levelFor` at 0, 299, 300, 1499, 1500, 5999, 6000, 14999, 15000, 100000 → camp, camp, village, village, town, town, city, city, metropolis, metropolis; `progressToNext` at 0 → 0.0, 150 → 0.5, 300 → 0.0 (village start), 900 → 0.5 (village 300→1500: (900-300)/1200), 15000 → 1.0; `copyWith` handles the new fields.
- Done when: flutter analyze clean; flutter test green.
- Commit: `T-06.2: town progression fields and levels`

### T-06.3 [x] onSessionCompleted: XP and streak
- Step: 6 (docs/prompt_plan.md, Prompt 6)
- Depends on: T-06.2
- Goal: XP and daily streak update on a completed session.
- Files: `lib/domain/progression.dart`, `test/domain/progression_test.dart`.
- Do: `static TownState onSessionCompleted(TownState town, Session session, DateTime completedAtLocal)`:
  1. `today = LocalDate.fromDateTime(completedAtLocal)`.
  2. `xp += session.plannedMinutes`.
  3. Streak: `lastStreakDate == null` → 1; same day as `lastStreakDate` → unchanged; exactly 1 day after → `+1`; anything else (gap, or a date in the past) → 1. Set `lastStreakDate = today` (only move forward: if `today` is before `lastStreakDate`, treat as a gap and set streak 1 with `lastStreakDate = today`).
  4. The daily plot grant is added in T-06.4. Failed sessions never call this function (nothing changes on failure); add a test that `TownRules.applyFailed` leaves xp/streak/dates untouched.
- Tests first: first ever completion → xp = minutes, streak 1, `lastStreakDate` today; two sessions the same day (25 and 10 min) → xp 35, streak 1; consecutive days → streak 2; a gap day → resets to 1; month boundary Jan 31 → Feb 1 → streak 2; year boundary Dec 31 → Jan 1 → streak 2; failed session leaves xp, streak, dates unchanged.
- Done when: flutter analyze clean; flutter test green.
- Commit: `T-06.3: progression xp and streak`

### T-06.4 [x] Daily plot grant, currentStreak, queue drain
- Step: 6 (docs/prompt_plan.md, Prompt 6)
- Depends on: T-06.3
- Goal: one new plot per focus day, queue drains when it arrives, and the displayed streak shows 0 after a missed day.
- Files: `lib/domain/progression.dart`, `test/domain/progression_test.dart`.
- Do:
  1. In `onSessionCompleted`, after the streak: if `lastPlotGrantDate != today` → `plotsUnlocked += 1` and `lastPlotGrantDate = today`; then call `TownRules.placeQueued` on the result (always, even without a grant).
  2. `static int currentStreak(TownState town, LocalDate today)`: `0` if `lastStreakDate == null` or `lastStreakDate.daysBetween(today) > 1` (streak broken but not yet reset); otherwise `streakCount`.
- Tests first: two sessions the same day → one plot granted (6 → 7); consecutive days → plots 8 and streak 2; gap day → streak 1, plot granted again; queue drains when a daily plot arrives (6 plots full, queued building, new day completion → queue empty and building placed on plot 6); `currentStreak` is the stored count on the same day and the next day, and `0` two days later, and `0` for a fresh town; month and year boundaries for `currentStreak` (Jan 31 → Feb 1 keeps it, Dec 31 → Jan 2 gives 0).
- Done when: flutter analyze clean; flutter test green.
- Commit: `T-06.4: daily plot grant and current streak`

### T-06.5 [x] Simulator: +1 day, streak, level
- Step: 6 (docs/prompt_plan.md, Prompt 6)
- Depends on: T-06.4
- Goal: wire progression into the app's simulator. Ends step 6 and phase A.
- Files: `lib/ui/session_simulator_panel.dart`, `test/ui/session_simulator_panel_test.dart`.
- Do:
  1. A `+1 day` button advances the panel's `FakeClock` by 24 hours.
  2. On completion apply `TownRules.applyCompleted` and then `Progression.onSessionCompleted(town, session, clock.nowWall())` (this exact order, once per session).
  3. Show: `Streak: N` (`Progression.currentStreak` with `LocalDate.fromDateTime(clock.nowWall())`), `Level: <name>`, level progress as a percent from `progressToNext`, XP, and plots `used/unlocked`.
- Tests first (widget): complete a 10-minute session → streak 1, xp 10, plots unlocked 7; `+1 day` then complete another → streak 2, plots 8; `+1 day` twice then check → streak 0 displayed; level name `camp` at start and progress updates after completions.
- Done when: flutter analyze clean; flutter test green; all core rules run in the app. Phase A done.
- Commit: `T-06.5: simulator progression display`

## Phase B: data and controller

### T-07.1 [x] Drift dependencies, tables, schema v1
- Step: 7 (docs/prompt_plan.md, Prompt 7)
- Depends on: T-06.5
- Goal: add Drift and define the three tables with `schemaVersion = 1`.
- Files: `pubspec.yaml`, `lib/data/database.dart` (+ generated `lib/data/database.g.dart`, committed), `test/data/database_test.dart`.
- Do:
  1. Check pub.dev for current stable versions and pin exactly: dependencies `drift`, `drift_flutter`; dev dependencies `drift_dev`, `build_runner`. If an in-memory test database needs `sqlite3` directly, use only what `drift` already depends on; ask the user before adding any other package.
  2. `lib/data/database.dart`: `@DriftDatabase(tables: [Towns, Buildings, Sessions]) class AppDatabase extends _$AppDatabase` with constructor `AppDatabase(QueryExecutor e)`, `schemaVersion => 1`. Production executor is created in T-07.6, not here.
  3. Tables (column names exact):
     - `Towns` (single row, id always 1): `id` int pk, `workerCount` int, `plotsUnlocked` int, `xp` int, `streakCount` int, `lastStreakDate` text nullable (`yyyy-mm-dd`), `lastPlotGrantDate` text nullable, `inRecoveryMode` bool, `onboardingDone` bool default false, `createdAt` int (epoch ms, UTC).
     - `Buildings`: `id` text pk, `tier` text (enum name), `status` text (`complete`/`ruin`/`queued`), `plotIndex` int nullable (null when queued), `sessionId` text nullable, `completedAt` int (epoch ms).
     - `Sessions`: `id` text pk, `plannedMinutes` int, `tier` text, `workersAssigned` int, `state` text, `startedAtWall` int (epoch ms), `startedAtUptimeMs` int, `leftAtWall` int nullable, `leftAtUptimeMs` int nullable, `awayTotalMs` int, `passUsed` bool, `outcomeReason` text nullable, `resolvedAt` int nullable.
  4. Run `dart run build_runner build --delete-conflicting-outputs`. Commit the generated file so fresh sessions compile without codegen.
  5. Save the schema for migration tests: configure `drift_dev` in `build.yaml` if needed and run `dart run drift_dev schema dump lib/data/database.dart drift_schemas/` so `drift_schemas/drift_schema_v1.json` is committed (T-19.1 and T-21.1 generate migration test helpers from these dumps).
- Tests first (`test/data/database_test.dart`, in-memory `NativeDatabase.memory()`): the database opens; `schemaVersion` is 1; inserting and reading one row in each table works; `onboardingDone` defaults to false. If the host cannot load SQLite, mark the task `[!]` and ask the user.
- Done when: flutter analyze clean; flutter test green; the table classes and `AppDatabase` are used by the test (the repository, T-07.3, and provider, T-07.6, use them in app code).
- Commit: `T-07.1: drift database and tables`

### T-07.2 [x] Row-to-domain mappers
- Step: 7 (docs/prompt_plan.md, Prompt 7)
- Depends on: T-07.1
- Goal: convert between Drift rows and domain types; domain stays Drift-free.
- Files: `lib/data/mappers.dart`, `test/data/mappers_test.dart`.
- Do:
  1. Town: `TownState townFromRows(TownRow town, List<BuildingRow> buildings)` and `TownsCompanion townToRow(TownState)` (without `id`, `onboardingDone`, `createdAt`, which the repository owns). `buildings` rows with status `complete`/`ruin` become `TownBuilding`s; rows with status `queued` become `QueuedBuilding`s in order of `completedAt` ascending, ties broken by `id` ascending. `lastStreakDate` / `lastPlotGrantDate` use `LocalDate.toIso()` / `LocalDate.parse`.
  2. Buildings: `List<BuildingsCompanion> buildingsToRows(TownState, {required DateTime now})`; queued items get `status = 'queued'`, `plotIndex = null`, `sessionId = id`; placed items keep `plotIndex`; `sessionId` = the building id unless the id is `'starter'` (then null). `completedAt` = `now.millisecondsSinceEpoch` for new rows (the repository passes existing values through where possible, see T-07.5).
  3. Session: `Session sessionFromRow(SessionRow)` and `SessionsCompanion sessionToRow(Session, {DateTime? resolvedAt})`. `TimeStamp.wall` is stored as UTC epoch ms and restored with `DateTime.fromMillisecondsSinceEpoch(ms)`; `TimeStamp.uptime` as ms (`Duration(milliseconds: ms)`); `awayTotal` as ms; enums by `.name`.
- Tests first: round trip of a `TownState` with workers, plots, xp, streak, both dates, recovery flag, 2 placed buildings (one ruin), 2 queued buildings (order preserved); round trip of a `Session` in each state with `leftAt` null and non-null, `passUsed` true, `outcomeReason` set; null date fields map to null.
- Done when: flutter analyze clean; flutter test green (mappers are used by the repository in T-07.3).
- Commit: `T-07.2: data mappers`

### T-07.3 [x] TownRepository: loadOrCreate and activeSession
- Step: 7 (docs/prompt_plan.md, Prompt 7)
- Depends on: T-07.2
- Goal: read side of the repository, including first-run seeding.
- Files: `lib/data/town_repository.dart`, `test/data/town_repository_test.dart`.
- Do:
  1. `class TownRepository { TownRepository(this._db, this._clock); }`.
  2. `Future<TownState> loadOrCreate()`: if there is no town row, create one from `TownState.initial()` (workers 3, plotsUnlocked 6, starter house on plot 0 with id `'starter'`, `completedAt` and `createdAt` = clock wall now) in one transaction, then return the state. Otherwise read it.
  3. `Future<Session?> activeSession()`: the session whose state is `running` or `away`, else null.
- Tests first (in-memory DB, `FakeClock`): first call seeds the initial town and a second call does not seed again (still one town row, one building); the returned state equals `TownState.initial()`; `activeSession()` is null with no sessions and returns an inserted `running` or `away` session; completed or failed sessions are not returned.
- Done when: flutter analyze clean; flutter test green.
- Commit: `T-07.3: town repository load and active session`

### T-07.4 [x] TownRepository: saveSessionStarted and saveSessionUpdated
- Step: 7 (docs/prompt_plan.md, Prompt 7)
- Depends on: T-07.3
- Goal: persist a new session and its in-flight updates.
- Files: `lib/data/town_repository.dart`, `test/data/town_repository_test.dart`.
- Do:
  1. `Future<void> saveSessionStarted(TownState town, Session session)`: one transaction that inserts the session row and writes the town row and buildings from `town` (same writer used by T-07.5; for now it is idempotent).
  2. `Future<void> saveSessionUpdated(Session session)`: updates the session row only (state, `leftAt`, `awayTotal`, `passUsed`, `outcomeReason`).
- Tests first: after `saveSessionStarted`, `activeSession()` returns an equal `Session`; after `saveSessionUpdated` with an away session (`leftAt` set), `activeSession()` returns state away with the same `leftAt`; updating to `completed` makes `activeSession()` null; starting a second session with the same id throws.
- Done when: flutter analyze clean; flutter test green.
- Commit: `T-07.4: repository session start and update`

### T-07.5 [x] TownRepository: atomic saveSessionResolved
- Step: 7 (docs/prompt_plan.md, Prompt 7)
- Depends on: T-07.4
- Goal: save the finished session and the whole new town in one transaction so a crash never leaves a half-written result.
- Files: `lib/data/town_repository.dart`, `test/data/town_repository_test.dart`.
- Do: `Future<void> saveSessionResolved(TownState town, Session session)`: in ONE `transaction`: write the session row with `resolvedAt` = clock wall now; update the town row (keep `createdAt` and `onboardingDone`; do not overwrite them); delete all rows in `Buildings` and re-insert from `town` (placed and queued, keeping the existing `completedAt` of rows that already existed by id, `now` for new ones). Any exception rolls the whole transaction back and propagates.
- Tests first: completed save → reload gives the new town (workers, plots, xp, streak, buildings, queue) and the session is no longer active; failed save with a ruin round trips; queued building round trips with order; atomicity: pass a `TownState` containing two buildings with the same id (primary-key violation inside the transaction) → the call throws and afterwards the town row, buildings, and session row are exactly as before; `createdAt` and `onboardingDone` survive a resolved save.
- Done when: flutter analyze clean; flutter test green.
- Commit: `T-07.5: repository atomic session resolve`

### T-07.6 [x] Providers and "Stored town" card
- Step: 7 (docs/prompt_plan.md, Prompt 7)
- Depends on: T-07.5
- Goal: wire the database and repository into the app and show stored data on the debug screen. Ends step 7 code.
- Files: `lib/app/providers.dart`, `lib/ui/debug_screen.dart`, `test/ui/debug_screen_test.dart`.
- Do:
  1. `databaseProvider = Provider<AppDatabase>((ref) { final db = AppDatabase(driftDatabase(name: 'focus_town')); ref.onDispose(db.close); return db; });` (`driftDatabase` from `drift_flutter`).
  2. `townRepositoryProvider = Provider((ref) => TownRepository(ref.watch(databaseProvider), ref.watch(clockProvider)))`.
  3. `storedTownProvider = FutureProvider<TownState>((ref) => ref.watch(townRepositoryProvider).loadOrCreate())` (replaced by controller state in T-08.6).
  4. Debug screen "Stored town" card: workers, plots unlocked, xp, streak, building count (placed + queued), loaded from `storedTownProvider`.
- Tests first (widget): override `databaseProvider` with an in-memory `AppDatabase` and `clockProvider` with `FakeClock`; the card shows workers 3, plots 6, xp 0, streak 0, buildings 1.
- Done when: flutter analyze clean; flutter test green; app launches with the card visible.
- Commit: `T-07.6: database providers and stored town card`

### T-07.7 [x] [device] Data persists across restarts
- Step: 7 (docs/prompt_plan.md, Prompt 7)
- Depends on: T-07.6
- Goal: confirm the on-disk database is created once and survives app restarts on the iPhone.
- Files: `docs/device_tests.md`.
- Do: give the user these steps for the iPhone, wait for results, then record them under a `## Step 7: persistence` heading in `docs/device_tests.md`:
  1. Run the app (`flutter run -d <iPhone>`). The "Stored town" card shows workers 3, plots 6, xp 0, streak 0, buildings 1.
  2. Force-quit the app (app switcher, swipe up) and reopen. The card shows the same values and no error.
  3. Delete the app, reinstall, run again: same initial values (fresh database).
- Tests first: none (manual).
- Done when: user-reported results recorded in docs/device_tests.md; flutter analyze clean; flutter test green.
- Commit: `T-07.7: record step 7 device check`

### T-08.1 [x] FocusState, SessionResult, controller build and clearResult
- Step: 8 (docs/prompt_plan.md, Prompt 8)
- Depends on: T-07.7
- Goal: the controller skeleton that loads the town and exposes state.
- Files: `lib/app/focus_state.dart`, `lib/app/focus_controller.dart`, `lib/app/providers.dart`, `test/app/focus_controller_test.dart`.
- Do:
  1. `enum SessionOutcome { completed, failed, queued }`; `SessionResult { SessionOutcome outcome; BuildingTier tier; int workersLost; int workersGained; int newStreak; bool plotGranted; }`.
  2. `FocusState { TownState town; Session? active; SessionResult? lastResult; }` with `copyWith` (`clearActive` and `clearLastResult` flags) and value equality.
  3. `class FocusController extends AsyncNotifier<FocusState>` and `focusControllerProvider = AsyncNotifierProvider<FocusController, FocusState>(FocusController.new)`. `build()` loads the town via `townRepositoryProvider.loadOrCreate()` and returns `FocusState(town, active: null, lastResult: null)` (T-08.5 extends `build()` to resume a running session).
  4. `void clearResult()` sets `lastResult` to null.
- Tests first (`ProviderContainer`, overrides: `clockProvider` = `FakeClock`, `databaseProvider` = in-memory): first read yields the initial town and no active session; `clearResult` with a set result clears it; the state `copyWith` flags work.
- Done when: flutter analyze clean; flutter test green; the provider is used by the test and wired into the UI in T-08.6.
- Commit: `T-08.1: focus controller skeleton`

### T-08.2 [x] Controller start()
- Step: 8 (docs/prompt_plan.md, Prompt 8)
- Depends on: T-08.1
- Goal: start a validated, persisted session.
- Files: `lib/app/focus_controller.dart`, `test/app/focus_controller_test.dart`.
- Do: `Future<void> start(int minutes)`:
  1. Throw `StateError` if a session is already active, or `!TownRules.canStart(town, minutes)`.
  2. `now = TimeStamp.now(clock)`; `session = SessionEngine.start(id: 's${now.wall.microsecondsSinceEpoch}', minutes, workersAvailable: town.workers, recovery: town.inRecoveryMode, now)`.
  3. `await repo.saveSessionStarted(town, session)` FIRST; only then set state `active = session`. If saving throws, state stays unchanged and the error propagates (a session that was not saved never starts).
- Tests first: start 10 min → state `active` is running with `workersAssigned` 1 and `repo.activeSession()` returns it; start with too few workers (castle at 3 workers) throws and persists nothing; start while active throws; recovery town (0 workers) can start 10 min with `workersAssigned` 0 and cannot start 25.
- Done when: flutter analyze clean; flutter test green.
- Commit: `T-08.2: controller start`

### T-08.3 [x] Finish pipeline, tick() and abandon()
- Step: 8 (docs/prompt_plan.md, Prompt 8)
- Depends on: T-08.2
- Goal: resolve a session to completed/failed, apply the town rules, build the result, and save atomically.
- Files: `lib/app/focus_controller.dart`, `test/app/focus_controller_test.dart`.
- Do:
  1. Private `Future<FocusState> _finish(FocusState base, Session finished, TimeStamp now)`: if `finished.state == completed` → `town = Progression.onSessionCompleted(TownRules.applyCompleted(base.town, finished), finished, now.wall)`; if `failed` → `town = TownRules.applyFailed(base.town, finished)`. `await repo.saveSessionResolved(town, finished)`; return `FocusState(town, active: null, lastResult: result)`.
  2. `SessionResult`: `outcome` = failed → `failed`; completed with `finished.id` found in `town.queue` → `queued`; otherwise `completed`. `workersLost` = failed ? `workersAssigned` : 0. `workersGained` = completed ? `tier.workersAddedOnSuccess` : 0. `newStreak` = `Progression.currentStreak(town, LocalDate.fromDateTime(now.wall))`. `plotGranted` = `town.plotsUnlocked > base.town.plotsUnlocked`. `tier` = session tier.
  3. `Future<void> tick()`: if no active session return; `resolved = SessionEngine.resolve(active, now)`; if `resolved` is finished → `_finish`; else nothing.
  4. `Future<void> abandon()`: `SessionEngine.abandon(active, now)` → `_finish`.
- Tests first (FakeClock + in-memory DB): start 10 min, `advance(10 min)`, `tick()` → town has workers 4 and a new building on plot 1, streak 1, `lastResult.outcome == completed`, `workersGained` 1, `plotGranted` true, session no longer active in the DB; abandon → workers 2, ruin, `lastResult.failed`, `workersLost` 1; all 6 plots full then a completed session on the same day → `lastResult.outcome == queued`, queue length 1; recovery end to end: town with 1 worker, failed 10-minute session → 0 workers and `inRecoveryMode`; recovery hut abandoned → workers still 0; 3 recovery huts completed (advance, tick, clearResult, repeat) → workers 3 and `inRecoveryMode` false; `tick()` with nothing active is a no-op.
- Done when: flutter analyze clean; flutter test green.
- Commit: `T-08.3: controller finish, tick and abandon`

### T-08.4 [x] Controller lifecycle forwards
- Step: 8 (docs/prompt_plan.md, Prompt 8)
- Depends on: T-08.3
- Goal: forward lifecycle events to the engine, persist updates, and finish the session when it ends.
- Files: `lib/app/focus_controller.dart`, `test/app/focus_controller_test.dart`.
- Do: add `Future<void> onLocked({TimeStamp? at})`, `onCallStarted({TimeStamp? at})`, `onBackgroundedUnlocked({TimeStamp? at})`, `onForegrounded({TimeStamp? at})`. Each: no-op if no active session; `t = at ?? TimeStamp.now(clock)`; `updated = SessionEngine.<fn>(active, t)`; for `onForegrounded` then also `SessionEngine.resolve(updated, TimeStamp.now(clock))` (planned time may have passed meanwhile). If `updated == active` do nothing. If finished → `_finish` (using `t`). Otherwise `repo.saveSessionUpdated(updated)` and set state `active`.
- Tests first: leave then return after 5 s → running, no pass, DB shows running; leave, return after 30 s → `passUsed` true and persisted; leave, return after 90 s → failed, `lastResult.failed`, workers reduced, ruin; second 30 s away in the same session → failed; `onLocked` and `onCallStarted` change nothing and write nothing; events with no active session are no-ops; `at` timestamp is used for `leftAt` (pass a `TimeStamp` 3 s in the past, return now → away measured from `at`); away saved to the DB survives (`activeSession()` returns away with `leftAt`).
- Done when: flutter analyze clean; flutter test green.
- Commit: `T-08.4: controller lifecycle events`

### T-08.5 [x] Resume and resolve on launch
- Step: 8 (docs/prompt_plan.md, Prompt 8)
- Depends on: T-08.4
- Goal: after the app was killed, `build()` resolves any stored active session from timestamps.
- Files: `lib/app/focus_controller.dart`, `test/app/focus_controller_test.dart`.
- Do: in `build()`, after loading the town, `active = await repo.activeSession()`. If present: `resolved = SessionEngine.resolve(active, now)`; if finished → `_finish` (sets `lastResult`); else keep it as `active` (if `resolved != active`, persist with `saveSessionUpdated`). Spec rule: result is computed before the town is shown.
- Tests first (new `ProviderContainer` over the SAME in-memory database to simulate a kill): running session, 4 minutes pass, new container → still active, no result; away session left 90 s ago → `lastResult.failed` and town updated; running session whose planned time passed while killed → `lastResult.completed`; away session left 30 s ago with pass unused → still away; reboot while away (`simulateReboot`, 100 s wall gap) → failed; wall clock set 2 hours forward while killed but uptime only 3 minutes → session not completed early.
- Done when: flutter analyze clean; flutter test green.
- Commit: `T-08.5: controller resume on launch`

### T-08.6 [x] Debug screen runs on FocusController
- Step: 8 (docs/prompt_plan.md, Prompt 8)
- Depends on: T-08.5
- Goal: replace the local FakeClock simulator with the real controller, database, and clock. Ends step 8 code.
- Files: `lib/ui/focus_debug_panel.dart` (replaces `lib/ui/session_simulator_panel.dart`), `lib/ui/debug_screen.dart`, `lib/app/providers.dart` (remove `storedTownProvider`), `test/ui/focus_debug_panel_test.dart` (replaces the old simulator panel test).
- Do:
  1. `FocusDebugPanel` (ConsumerStatefulWidget): reads `focusControllerProvider`; buttons `Start` (slider minutes, disabled unless `TownRules.canStart`, with the reason line from T-05.6), `Leave` (`onBackgroundedUnlocked`), `Return` (`onForegrounded`), `Lock` (`onLocked`), `Abandon`.
  2. A 1-second `Timer.periodic` calling `tick()` only while `active != null` (start/cancel as state changes; cancel in `dispose`).
  3. Show everything the old panel showed: state, progress (`SessionEngine.progress`), `passUsed`, outcome, workers, plots used/unlocked, queue length, recovery flag, buildings list, streak (`Progression.currentStreak`), level name and progress, xp. Keep the "Stored town" card, now driven by the controller state.
  4. When `lastResult != null` show an `AlertDialog` (outcome, tier, workers lost/gained, streak, plot granted); dismissing calls `clearResult()`.
  5. The "+1 min" and "+1 day" fake-clock buttons are gone (real clock). Port every assertion of the removed panel tests (T-04.6, T-05.6, T-06.5) into the new tests by overriding `clockProvider` with a `FakeClock`, `databaseProvider` with in-memory, calling `clock.advance(...)` and pumping 1 second. Do not drop coverage.
- Tests first (widget): the ported cases (complete a 10-minute hut, leave/return 5 s/30 s/90 s, abandon, lock, disabled start with reason, recovery limits, streak/plots after `advance(24h)` + completion) plus: result dialog appears on completion and dismissing clears `lastResult`; the tick timer stops when no session is active.
- Done when: flutter analyze clean; flutter test green; app starts a real 10-minute session from the debug screen.
- Commit: `T-08.6: debug screen uses focus controller`

### T-08.7 [x] [device] Force-quit and reopen resolves correctly
- Step: 8 (docs/prompt_plan.md, Prompt 8)
- Depends on: T-08.6
- Goal: verify real-clock resolution after a kill on the iPhone.
- Files: `docs/device_tests.md`.
- Do: give the user these steps, wait for results, record under `## Step 8: controller` in `docs/device_tests.md`:
  1. Pick 10 minutes, Start. State running.
  2. Force-quit after about 2 minutes, reopen after about 1 minute: session still running with progress about 30%.
  3. Force-quit again, wait until 10+ minutes have passed since the start, reopen: a dialog shows the completed result, workers 4, a new building listed.
  4. Start another 10-minute session, tap Leave, wait 90 seconds, tap Return: dialog shows failed, workers reduced, ruin listed.
  5. Start another, tap Leave, force-quit, wait 90+ seconds, reopen: dialog shows failed (resolved at launch).
- Tests first: none (manual).
- Done when: user-reported results recorded; flutter analyze clean; flutter test green.
- Commit: `T-08.7: record step 8 device check`

## Phase C: platform

### T-09.1 [x] LifecycleEvent, LifecycleSource, FakeLifecycleSource
- Step: 9 (docs/prompt_plan.md, Prompt 9)
- Depends on: T-08.7
- Goal: the platform abstraction every lifecycle source implements, plus a test double.
- Files: `lib/platform/lifecycle_events.dart`, `lib/platform/testing/fake_lifecycle_source.dart`, `test/platform/lifecycle_events_test.dart`.
- Do:
  1. `sealed class LifecycleEvent { const LifecycleEvent(this.timestamp); final TimeStamp timestamp; }` with final subclasses `LockedEvent`, `UnlockedEvent`, `BackgroundedEvent`, `ForegroundedEvent`, `CallStartedEvent`, `CallEndedEvent`. Add `String get name` (`locked`, `unlocked`, `backgrounded`, `foregrounded`, `callStarted`, `callEnded`) and value equality.
  2. `abstract class LifecycleSource { Stream<LifecycleEvent> get events; bool get isNative; Future<void> dispose(); }`.
  3. `FakeLifecycleSource implements LifecycleSource`: a broadcast `StreamController<LifecycleEvent>`; `void emit(LifecycleEvent e)`; `isNative` constructor argument (default false); `dispose` closes the controller.
- Tests first: each event type reports its `name` and keeps its timestamp; equal events compare equal; `FakeLifecycleSource.emit` delivers to a listener in order; `dispose` completes the stream.
- Done when: flutter analyze clean; flutter test green (these types are used by T-09.2 and T-09.3).
- Commit: `T-09.1: lifecycle event types and fake source`

### T-09.2 [x] FallbackLifecycleSource (Flutter-only)
- Step: 9 (docs/prompt_plan.md, Prompt 9)
- Depends on: T-09.1
- Goal: a lenient source that works before any native code exists.
- Files: `lib/platform/fallback_lifecycle_source.dart`, `test/platform/fallback_lifecycle_source_test.dart`.
- Do: `FallbackLifecycleSource(Clock clock)` implements `LifecycleSource` with `WidgetsBindingObserver` (register in the constructor, remove in `dispose`). Flutter alone cannot tell a lock from an app switch, so map leniently and never punish: `AppLifecycleState.paused` → `LockedEvent`; `AppLifecycleState.resumed` → `UnlockedEvent` then `ForegroundedEvent` (this order). `inactive`, `hidden`, `detached` emit nothing (Control Center and notification shade only make the app inactive). `isNative = false`. Timestamps come from `TimeStamp.now(clock)`.
- Tests first (`TestWidgetsFlutterBinding`, `FakeClock`): `handleAppLifecycleStateChanged(paused)` emits one `LockedEvent`; `resumed` emits `UnlockedEvent` then `ForegroundedEvent`; `inactive` emits nothing; `dispose` removes the observer (no events after); `isNative` is false.
- Done when: flutter analyze clean; flutter test green.
- Commit: `T-09.2: fallback lifecycle source`

### T-09.3 [x] LifecycleRouter: event mapping
- Step: 9 (docs/prompt_plan.md, Prompt 9)
- Depends on: T-09.2
- Goal: route lifecycle events to `FocusController`, passing each event's own timestamp.
- Files: `lib/platform/lifecycle_router.dart`, `test/platform/lifecycle_router_test.dart`.
- Do: `LifecycleRouter(LifecycleSource source, FocusController controller, Clock clock, {void Function(LifecycleEvent)? onEvent})` with `void start()` (subscribe) and `Future<void> dispose()` (cancel the subscription; the source is owned by its provider). Mapping:
  - `LockedEvent` → `controller.onLocked(at: e.timestamp)`
  - `CallStartedEvent` → remember `inCall = true`, `controller.onCallStarted(at: e.timestamp)`
  - `CallEndedEvent` → `inCall = false`
  - `BackgroundedEvent` → if `inCall` ignore, else `controller.onBackgroundedUnlocked(at: e.timestamp)` (the 500 ms pending window is added in T-09.4)
  - `ForegroundedEvent` → `controller.onForegrounded(at: e.timestamp)`
  - `UnlockedEvent` → no controller call
  - `onEvent` is called for every event first (used by the event log in T-09.5).
  Events are handled one at a time in arrival order (await each controller call before the next).
- Tests first (`ProviderContainer` with `FakeClock`, in-memory DB, `FakeLifecycleSource`; read the notifier from `focusControllerProvider`): locked → no state change on a running session; callStarted → no state change; backgrounded → session is `away` with `leftAt` equal to the event timestamp; foregrounded 5 s later → running; unlocked → nothing; backgrounded while `inCall` ignored; after callEnded backgrounded works again; events with no active session are no-ops and do not throw.
- Done when: flutter analyze clean; flutter test green.
- Commit: `T-09.3: lifecycle router mapping`

### T-09.4 [x] LifecycleRouter: 500 ms lock window
- Step: 9 (docs/prompt_plan.md, Prompt 9)
- Depends on: T-09.3
- Goal: tolerate `backgrounded` arriving a moment before `locked` without a penalty or a false warning notification. Testable because it uses event timestamps and the Clock, not `Future.delayed`.
- Files: `lib/platform/lifecycle_router.dart`, `test/platform/lifecycle_router_test.dart`.
- Do:
  1. A non-in-call `BackgroundedEvent` is held as `_pending` instead of being forwarded.
  2. Constant `kLockWindow = Duration(milliseconds: 500)`.
  3. Resolve the pending event when the next event arrives, comparing with `elapsedBetween(pending.timestamp, next.timestamp)`:
     - `LockedEvent` within the window (`<= 500 ms`) → drop pending, forward `onLocked`.
     - `LockedEvent` after the window → forward pending `onBackgroundedUnlocked(at: pending.timestamp)` first, then `onLocked`.
     - `ForegroundedEvent`: within the window → drop pending (no penalty), forward `onForegrounded`; after the window → forward pending, then `onForegrounded`.
     - `CallStartedEvent` → drop pending (calls are allowed), forward `onCallStarted`.
     - `UnlockedEvent`/`CallEndedEvent`: resolve as above by time, then continue.
  4. `Future<void> flushExpired()`: if pending exists and `elapsedBetween(pending.timestamp, TimeStamp.now(clock)) >= kLockWindow` → forward it. The app calls this from a 100 ms timer (T-09.5), so a real app switch is forwarded about 0.5 s after it happens (leftAt is still the event timestamp).
- Tests first: backgrounded then locked 200 ms later → session stays running, never `away`, no `onBackgroundedUnlocked` call; backgrounded then locked 600 ms later → away then locked (session away with leftAt = pending timestamp); backgrounded, `clock.advance(600 ms)`, `flushExpired()` → away; `flushExpired()` at 400 ms → still running; backgrounded then foregrounded within 300 ms → running, no pass; backgrounded then callStarted → running; backgrounded during a call ignored; two backgrounded events in a row keep the earlier timestamp; events with no active session still no-ops.
- Done when: flutter analyze clean; flutter test green.
- Commit: `T-09.4: lifecycle router lock window`

### T-09.5 [x] Providers, router start, event log panel
- Step: 9 (docs/prompt_plan.md, Prompt 9)
- Depends on: T-09.4
- Goal: wire the lifecycle source and router into the app and show the last 20 events. Ends step 9 code.
- Files: `lib/app/providers.dart`, `lib/app/app.dart`, `lib/ui/event_log_panel.dart`, `lib/ui/debug_screen.dart`, `test/ui/event_log_panel_test.dart`, `test/app/lifecycle_wiring_test.dart`.
- Do:
  1. `lifecycleSourceProvider = Provider<LifecycleSource>` returning `FallbackLifecycleSource(ref.watch(clockProvider))` for now, disposed with `ref.onDispose` (T-10.4 replaces the choice with a bootstrapped override).
  2. `eventLogProvider`: a `Notifier<List<LifecycleEvent>>` with `add(event)` that keeps only the last 20 (newest first).
  3. `lifecycleRouterProvider`: creates the router with `onEvent: ref.read(eventLogProvider.notifier).add`, calls `start()`, disposes on `ref.onDispose`.
  4. `FocusTownApp` becomes a `ConsumerStatefulWidget` that reads `lifecycleRouterProvider` once in `initState`/first build and runs a `Timer.periodic(100 ms)` calling `router.flushExpired()` (cancel in `dispose`).
  5. `EventLogPanel` on `DebugScreen`: header `Event log (native|fallback)` from `source.isNative`; each row shows `HH:mm:ss.mmm name`.
- Tests first: pushing 25 events through a `FakeLifecycleSource` keeps 20 with newest first; panel shows the `fallback` label for a non-native fake and `native` for a native one; wiring test: pumping `FocusTownApp` with overridden `lifecycleSourceProvider` (fake) and a started session, emitting backgrounded then advancing the clock 600 ms and pumping shows the session as away.
- Done when: flutter analyze clean; flutter test green; backgrounding the app on a device shows entries in the log.
- Commit: `T-09.5: lifecycle wiring and event log`

### T-09.6 [ ] [device] Event log shows lifecycle on the iPhone
- Step: 9 (docs/prompt_plan.md, Prompt 9)
- Depends on: T-09.5
- Goal: confirm the fallback source reports events on a real device.
- Files: `docs/device_tests.md`.
- Do: give the user these steps and record results under `## Step 9: lifecycle fallback`:
  1. Run on the iPhone; the event log header says `fallback`.
  2. Press the side button to lock, wait 5 s, unlock: log shows `locked`, then `unlocked` and `foregrounded` (fallback maps every background to a lock; it never punishes).
  3. Swipe to another app and back: same events. Pull down Control Center: no events.
  4. Start a 10-minute session, repeat step 3: session stays running (the fallback is lenient).
- Tests first: none (manual).
- Done when: results recorded; flutter analyze clean; flutter test green.
- Commit: `T-09.6: record step 9 device check`

### T-10.1 [x] NativeLifecycleSource (Dart side)
- Step: 10 (docs/prompt_plan.md, Prompt 10)
- Depends on: T-09.6
- Goal: a Dart `LifecycleSource` over the platform channels, tolerant of bad data. Same contract is used on Android in step 11.
- Files: `lib/platform/native_lifecycle_source.dart`, `test/platform/native_lifecycle_source_test.dart`.
- Do:
  1. Channel contract: `EventChannel('focus/lifecycle/events')` emits `Map` with `type` (`locked|unlocked|backgrounded|foregrounded|callStarted|callEnded`), `wallMs` (int, epoch ms), `uptimeMs` (int). `MethodChannel('focus/lifecycle')` method `uptimeMs` returns the monotonic uptime in ms.
  2. `NativeLifecycleSource({EventChannel? eventChannel, void Function(String message)? onMalformed})`: `isNative = true`; maps each valid map to the matching event with `TimeStamp(DateTime.fromMillisecondsSinceEpoch(wallMs), Duration(milliseconds: uptimeMs))`.
  3. Malformed events (not a map, missing/unknown `type`, missing or non-int times) are skipped and reported via `onMalformed` (default `debugPrint`; step 22 routes it to the local log). A stream error is reported the same way and does not close the stream.
- Tests first (`TestDefaultBinaryMessengerBinding` mock stream handler): each of the 6 valid types parses with correct timestamps; unknown type, null, a string, missing `uptimeMs`, `wallMs` as string are ignored and `onMalformed` is called once each; a valid event after a malformed one is still delivered; `dispose` cancels the subscription.
- Done when: flutter analyze clean; flutter test green (the class is wired in T-10.4).
- Commit: `T-10.1: native lifecycle source`

### T-10.2 [x] iOS plugin: lock, background, foreground, uptime
- Step: 10 (docs/prompt_plan.md, Prompt 10)
- Depends on: T-10.1
- Goal: Swift side of the bridge for lock/background/foreground events and uptime.
- Files: `ios/Runner/FocusLifecyclePlugin.swift`, `ios/Runner/AppDelegate.swift`, `docs/device_tests.md` (notes).
- Do:
  1. `FocusLifecyclePlugin` registers `FlutterEventChannel("focus/lifecycle/events")` and `FlutterMethodChannel("focus/lifecycle")` (use the registration pattern valid for the generated `AppDelegate` of this Flutter version) and implements `FlutterStreamHandler`.
  2. Each event is a map `{type, wallMs, uptimeMs}`. `wallMs = Int(Date().timeIntervalSince1970 * 1000)`.
  3. **Uptime must include device sleep** (the app is asleep while the phone is locked). Do NOT use `ProcessInfo.processInfo.systemUptime` (it excludes sleep, which would make locked sessions complete late). Use `clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW) / 1_000_000` (continuous time, counts sleep). Method `uptimeMs` returns it as Int.
  4. Sources: `UIApplication.protectedDataWillBecomeUnavailableNotification` → `locked`; `protectedDataDidBecomeAvailableNotification` → `unlocked`; `UIApplication.didEnterBackgroundNotification` → `backgrounded`; `willEnterForegroundNotification` → `foregrounded`.
  5. Ordering: in the `didEnterBackground` handler check `UIApplication.shared.isProtectedDataAvailable`. If it is false the device is locked, so emit `locked` BEFORE `backgrounded`. Do not emit `locked` twice for one lock (remember a `isLocked` flag, cleared on `unlocked`).
  6. Document in `docs/device_tests.md` under `## iOS`: lock detection needs a device passcode (protected data); without one the lock is seen only as a background.
- Tests first: Swift cannot be unit-tested in this repo's `flutter test`. Write the manual checks in `docs/device_tests.md` `## iOS` first (they run in T-10.5); the automated gate is `flutter build ios --no-codesign` compiling.
- Done when: flutter analyze clean; flutter test green; `flutter build ios --no-codesign` succeeds.
- Commit: `T-10.2: ios lifecycle plugin`

### T-10.3 [x] iOS plugin: call detection
- Step: 10 (docs/prompt_plan.md, Prompt 10)
- Depends on: T-10.2
- Goal: report phone calls with CallKit.
- Files: `ios/Runner/FocusLifecyclePlugin.swift`.
- Do: add a `CXCallObserver` with a delegate. Keep a `Set<UUID>` of active calls. In `callChanged`: a call that is not ended (`!call.hasEnded`, including ringing and dialing) joins the set; when the set goes from empty to non-empty emit `callStarted`; when a call `hasEnded` it leaves the set, and when the set becomes empty emit `callEnded`. No permission is needed. Events use the same `{type, wallMs, uptimeMs}` map.
- Tests first: add the call cases to the `## iOS` checklist in `docs/device_tests.md` (incoming call answered, incoming call declined, outgoing call, call ended). Automated gate: `flutter build ios --no-codesign` compiles.
- Done when: flutter analyze clean; flutter test green; ios build compiles.
- Commit: `T-10.3: ios call detection`

### T-10.4 [x] Platform bootstrap: native uptime clock and source selection
- Step: 10 (docs/prompt_plan.md, Prompt 10)
- Depends on: T-10.3
- Goal: use the native clock and source when the channel responds, otherwise fall back. Wire it into the app. Ends step 10 code (works unchanged on Android in step 11).
- Files: `lib/platform/native_uptime_clock.dart`, `lib/platform/platform_bootstrap.dart`, `lib/main.dart`, `lib/app/providers.dart`, `test/platform/platform_bootstrap_test.dart`.
- Do:
  1. `NativeUptimeClock implements Clock`: constructed with an initial native uptime `Duration` read once at launch; `uptime()` = initial + a `Stopwatch` started at construction (no channel call per read); `nowWall()` = `DateTime.now()`.
  2. `Future<({Clock clock, LifecycleSource source})> bootstrapPlatform({MethodChannel? channel})`: call `uptimeMs` on `MethodChannel('focus/lifecycle')` with a 1-second timeout. If it returns an int → `NativeUptimeClock(Duration(milliseconds: value))` and `NativeLifecycleSource()`. On `MissingPluginException`, `PlatformException`, timeout, or a non-int → `SystemClock()` and `FallbackLifecycleSource(SystemClock)` (share one clock instance).
  3. `main()` is async: `WidgetsFlutterBinding.ensureInitialized()`, `bootstrapPlatform()`, then `ProviderScope(overrides: [clockProvider.overrideWithValue(clock), lifecycleSourceProvider.overrideWithValue(source)])`. Keep the default providers in `providers.dart` for tests.
- Tests first (mock method channel): responding channel → clock is `NativeUptimeClock` and source `isNative`; `NativeUptimeClock.uptime()` starts at the native value and grows with time (use a test stopwatch seam or `fakeAsync`); `MissingPluginException` → `SystemClock` and a non-native source; a channel that never answers falls back after the timeout; returning a string falls back.
- Done when: flutter analyze clean; flutter test green; on iOS the event log header says `native`.
- Commit: `T-10.4: native clock and source selection`

### T-10.5 [ ] [device] iOS lock, switch, and call checks
- Step: 10 (docs/prompt_plan.md, Prompt 10)
- Depends on: T-10.4
- Goal: prove the iOS bridge tells lock, app switch, and calls apart.
- Files: `docs/device_tests.md`.
- Do: give the user the `## iOS` checklist, wait for results, record pass/fail with notes:
  1. Header of the event log says `native`.
  2. Lock the phone for 1 minute: log shows `locked` before `backgrounded`; unlock: `unlocked`, `foregrounded`; a running session shows no penalty.
  3. Lock for 5 minutes during a 10-minute session: after unlocking, progress is about 50% (uptime counts sleep; if progress is much lower the clock excludes sleep, a bug to fix before continuing).
  4. Switch to another app: `backgrounded` only (no `locked`); returning within 5 s: no penalty; away 30 s: pass used; away 90 s: failed.
  5. Take (or place) a phone call mid-session: `callStarted`, then `callEnded`; backgrounding during the call causes no penalty and no pass.
  6. Pull down Control Center and the notification shade: no events.
- Tests first: none (manual).
- Done when: all iOS checks pass or failures are filed as new tasks; results recorded; flutter analyze clean; flutter test green.
- Commit: `T-10.5: record ios bridge device check`

### T-11.1 [!] Android plugin: foreground/background events and uptime (deferred: iOS first, no Android SDK; user decision 2026-11-09)
- Step: 11 (docs/prompt_plan.md, Prompt 11)
- Depends on: T-10.5
- Goal: Kotlin side with the same channels as iOS: background/foreground events and uptime.
- Files: `android/app/src/main/kotlin/.../FocusLifecyclePlugin.kt`, `.../MainActivity.kt`, `test/platform/platform_bootstrap_test.dart`.
- Do:
  1. `FocusLifecyclePlugin` exposes `EventChannel("focus/lifecycle/events")` and `MethodChannel("focus/lifecycle")`, registered from `MainActivity.configureFlutterEngine`. Events are maps `{type, wallMs, uptimeMs}` like iOS (`wallMs = System.currentTimeMillis()`).
  2. Method `uptimeMs` returns `SystemClock.elapsedRealtime()` (monotonic since boot and counts deep sleep).
  3. Activity events: use `Application.ActivityLifecycleCallbacks` for `MainActivity`: `onActivityStopped` → `backgrounded` (do NOT use `onPause`: it also fires for the notification shade and dialogs); `onActivityStarted` → `foregrounded`.
  4. Lock-state logic comes in T-11.2; here `backgrounded` and `foregrounded` are emitted directly.
- Tests first: Dart side: add a bootstrap test that with `debugDefaultTargetPlatformOverride = TargetPlatform.android` and a responding mock channel the native clock and native source are selected (same code path as iOS, proves nothing is iOS-only). Kotlin gate: `flutter build apk --debug` compiles.
- Done when: flutter analyze clean; flutter test green; debug apk builds.
- Commit: `T-11.1: android lifecycle plugin`

### T-11.2 [!] Android plugin: lock detection (deferred: iOS first, no Android SDK; user decision 2026-11-09)
- Step: 11 (docs/prompt_plan.md, Prompt 11)
- Depends on: T-11.1
- Goal: tell a screen lock from an app switch.
- Files: `.../FocusLifecyclePlugin.kt`, `docs/device_tests.md`.
- Do:
  1. Dynamically registered `BroadcastReceiver` (register when the plugin attaches, unregister on detach): `Intent.ACTION_SCREEN_OFF` → `locked`; `Intent.ACTION_USER_PRESENT` → `unlocked`.
  2. In `onActivityStopped`: if `!powerManager.isInteractive || keyguardManager.isKeyguardLocked` → the device is locked or the screen is off, so emit `locked` BEFORE `backgrounded`. Keep an `isLocked` flag (set on `locked`, cleared on `unlocked`) so `locked` is never emitted twice for one lock.
  3. Write the Android manual checklist skeleton in `docs/device_tests.md` `## Android` (screen off 1 min; app switch; notification shade pull-down must NOT be backgrounded; phone call; recent-apps screen; split screen).
- Tests first: manual checklist written first; gate: `flutter build apk --debug` compiles.
- Done when: flutter analyze clean; flutter test green; debug apk builds.
- Commit: `T-11.2: android lock detection`

### T-11.3 [!] Android plugin: call detection and phone permission (deferred: iOS first, no Android SDK; user decision 2026-11-09)
- Step: 11 (docs/prompt_plan.md, Prompt 11)
- Depends on: T-11.2
- Goal: report phone calls where the OS allows it, and degrade safely where it does not.
- Files: `.../FocusLifecyclePlugin.kt`, `android/app/src/main/AndroidManifest.xml`, `docs/device_tests.md`.
- Do:
  1. Declare `READ_PHONE_STATE` in the manifest. Add MethodChannel methods `hasPhonePermission` (bool) and `startCallDetection` (registers the listener if permission is granted; returns bool). Step 21 (T-21.4) asks for the permission and calls `startCallDetection` after a grant.
  2. Call listener only when permission is granted: API 31+ `TelephonyCallback` (`CallStateListener`), API 29–30 `PhoneStateListener`. `CALL_STATE_RINGING` or `CALL_STATE_OFFHOOK` → `callStarted` (once when entering a call), `CALL_STATE_IDLE` → `callEnded`.
  3. Without the permission calls are unknown: no events and no exemption beyond lock. Document this in `docs/device_tests.md` `## Android` notes.
  4. Do not request the permission in this task.
- Tests first: add call cases to the Android checklist first; gate: `flutter build apk --debug` compiles.
- Done when: flutter analyze clean; flutter test green; debug apk builds.
- Commit: `T-11.3: android call detection`

### T-11.4 [!] [device] Android lock, switch, and call checks (deferred: iOS first, no Android SDK; user decision 2026-11-09)
- Step: 11 (docs/prompt_plan.md, Prompt 11)
- Depends on: T-11.3
- Goal: prove the Android bridge on a physical phone (Samsung or Xiaomi if possible).
- Files: `docs/device_tests.md`.
- Do: give the user the `## Android` checklist, wait for results, record pass/fail with the phone model and Android version:
  1. Event log header says `native`.
  2. Screen off 1 minute: `locked` before `backgrounded`; no penalty. A 5-minute lock in a 10-minute session shows about 50% progress after unlocking.
  3. Switch app: `backgrounded` only; return within 5 s: no penalty; 30 s: pass; 90 s: failed.
  4. Pull down the notification shade: no `backgrounded`.
  5. Recent-apps screen and split screen: record what events appear.
  6. Phone call: `callStarted`/`callEnded` appear only if READ_PHONE_STATE was granted (grant it manually in Settings for this test); without it calls are unknown.
  7. If the OEM battery manager kills the app, reopen and confirm the session resolves from timestamps.
- Tests first: none (manual).
- Done when: results recorded; failures filed as new tasks; flutter analyze clean; flutter test green.
- Commit: `T-11.4: record android bridge device check`

### T-12.1 [x] Notifier interface, FakeNotifier, LocalNotifier
- Step: 12 (docs/prompt_plan.md, Prompt 12)
- Depends on: T-11.4
- Goal: the notification abstraction, a test double, and the real implementation behind a provider.
- Files: `pubspec.yaml`, `lib/platform/notifier.dart`, `lib/platform/local_notifier.dart`, `lib/platform/testing/fake_notifier.dart`, `lib/app/providers.dart`, `lib/main.dart`, platform manifests, `test/platform/fake_notifier_test.dart`.
- Do:
  1. Check pub.dev and pin `flutter_local_notifications`. If scheduling needs the `timezone` package as a direct dependency, STOP and ask the user before adding it (CLAUDE.md dependency rule): explain it is required by `zonedSchedule`.
  2. `abstract class Notifier { Future<bool> requestPermission(); Future<bool> hasPermission(); Future<void> scheduleAwayWarnings({required bool passAvailable}); Future<void> cancelAwayWarnings(); }`.
  3. `LocalNotifier implements Notifier`: fixed ids `kWarningNotificationId = 1001` and `kPassNotificationId = 1002`. `scheduleAwayWarnings`: show immediately id 1001 with the text `Come back! Your builders stop in 10 seconds.`; if `passAvailable`, schedule id 1002 at now + 10 s with the text `Emergency pass used. You have 60 seconds.`. `cancelAwayWarnings` cancels both ids. Android: create a high-importance channel `focus_warnings` (name `Focus warnings`) at initialization; add the `POST_NOTIFICATIONS` permission to the manifest. iOS: request alert/sound permission in `requestPermission`.
  4. `FakeNotifier` records calls: `List<String> calls` (`schedule(passAvailable: true)`, `cancel`, `requestPermission`), `bool permissionGranted` field.
  5. `notifierProvider = Provider<Notifier>((ref) => LocalNotifier())` with initialization done in `main()` before `runApp`.
- Tests first: `FakeNotifier` records `scheduleAwayWarnings(passAvailable: true/false)`, `cancelAwayWarnings`, and permission calls in order; its `hasPermission` follows the flag. (`LocalNotifier` is verified on device in T-12.4.)
- Done when: flutter analyze clean; flutter test green; app builds and launches on both platforms (`flutter build ios --no-codesign`, `flutter build apk --debug`).
- Commit: `T-12.1: notifier interface and local notifier`

### T-12.2 [x] Controller schedules and cancels warnings
- Step: 12 (docs/prompt_plan.md, Prompt 12)
- Depends on: T-12.1
- Goal: wire the notifier into session events; notification failures never affect outcomes.
- Files: `lib/app/focus_controller.dart`, `test/app/focus_controller_notifications_test.dart`.
- Do:
  1. In `onBackgroundedUnlocked`, after the session becomes `away` and is saved: `scheduleAwayWarnings(passAvailable: !session.passUsed)`.
  2. Call `cancelAwayWarnings()` on `onForegrounded`, `onLocked`, and whenever a session finishes (`_finish`: completion, failure, abandon). Also cancel when `build()` resumes a session that is still running.
  3. Wrap every notifier call in a private helper `_safeNotify(Future<void> Function())` that catches all errors and logs them with `debugPrint` (T-22.3 routes it to the local log). A notifier exception must never change the session or state.
- Tests first (`FakeNotifier` override): leave with the pass available → `schedule(passAvailable: true)`; leave after the pass was used → `schedule(passAvailable: false)`; return → `cancel`; lock while away → `cancel`; completion, failure, and abandon each call `cancel`; a notifier whose methods throw does not break leaving, returning, or finishing a session (state identical to the non-throwing case).
- Done when: flutter analyze clean; flutter test green.
- Commit: `T-12.2: controller notification scheduling`

### T-12.3 [x] Debug permission button and status
- Step: 12 (docs/prompt_plan.md, Prompt 12)
- Depends on: T-12.2
- Goal: expose notification permission on the debug screen. Ends step 12 code. (The real prompt moves to onboarding in step 21.)
- Files: `lib/ui/debug_screen.dart`, `test/ui/debug_screen_test.dart`.
- Do: add a `Request notification permission` button that calls `notifierProvider.requestPermission()` and a line `Notifications: granted|denied` (from `hasPermission()`, refreshed after the request and on screen start).
- Tests first (widget, `FakeNotifier`): initial text `denied`; tapping the button records `requestPermission` and the text becomes `granted` when the fake grants it.
- Done when: flutter analyze clean; flutter test green.
- Commit: `T-12.3: debug notification permission`

### T-12.4 [ ] [device] Warnings fire and cancel
- Step: 12 (docs/prompt_plan.md, Prompt 12)
- Depends on: T-12.3
- Goal: verify real notifications on the iPhone (and Android if available).
- Files: `docs/device_tests.md`.
- Do: give the user these steps, record results under `## Step 12: notifications`:
  1. Tap `Request notification permission`, allow. Status shows `granted`.
  2. Start a 10-minute session, switch to another app: within about 1 second the notification `Come back! Your builders stop in 10 seconds.` appears; at +10 s the second one appears if the pass was available.
  3. Return within 5 s: the second notification must not appear (cancelled).
  4. Lock the phone instead of switching: no notification.
  5. Deny permission (Settings) and repeat: nothing shows, rules still apply (session fails after 70 s away).
  6. Repeat the core checks on Android (channel `focus_warnings` exists, heads-up shown).
- Tests first: none (manual).
- Done when: results recorded; flutter analyze clean; flutter test green. Phase C done.
- Commit: `T-12.4: record step 12 device check`

## Phase D: block-town rendering

Reference for steps 13–18: the prototype `docs/reference/focus-town-voxel.html` (open it in a browser; its JavaScript is the source for projection, palette, shapes, and drawing order). Rendering is 2D isometric: each block is three flat faces. Not real 3D.

### T-13.1 [x] Vec2 and isometric projection
- Step: 13 (docs/prompt_plan.md, Prompt 13)
- Depends on: T-12.4
- Goal: pure projection math so rendering bugs are caught by unit tests, not by eye.
- Files: `lib/game/world/vec2.dart`, `lib/game/world/iso.dart`, `test/game/iso_test.dart`.
- Do: (pure Dart, no Flutter or Flame imports)
  1. `Vec2(double x, double y)` immutable with `==`, `hashCode`.
  2. `Vec2 project(double x, double y, double z, double tile, Vec2 origin)` with `sx = ox + (x - y) * tile`, `sy = oy + (x + y) * tile / 2 - z * tile`.
  3. `Vec2 unprojectGround(double sx, double sy, double tile, Vec2 origin)` for the plane `z = 0`: `a = (sx - ox) / tile` (= x - y), `b = (sy - oy) * 2 / tile` (= x + y), result `x = (a + b) / 2`, `y = (b - a) / 2`.
- Tests first (tile 10, origin (100, 50)): `project(0,0,0)` = (100, 50); `(1,0,0)` = (110, 55); `(0,1,0)` = (90, 55); `(0,0,1)` = (100, 40); `(2,3,4)` = (90, 35); `unprojectGround(project(x,y,0))` returns `(x,y)` for 5 sample points including negative and fractional ones (within 1e-9); a different tile and origin still round-trips.
- Done when: flutter analyze clean; flutter test green.
- Commit: `T-13.1: isometric projection`

### T-13.2 [x] Block materials and palette
- Step: 13 (docs/prompt_plan.md, Prompt 13)
- Depends on: T-13.1
- Goal: the prototype's palette as data, with 4 precomputed texture variants per face.
- Files: `lib/game/world/block_material.dart`, `test/game/block_material_test.dart`.
- Do: (pure Dart; colors are `int` ARGB values like `0xFFRRGGBB`)
  1. `int shade(int argb, double f)`: each channel `c = clamp(round(v * (1 + f)), 0, 255)`, alpha 255.
  2. `BlockMaterial { List<int> top; List<int> sideX; List<int> sideY; }`, each list has 5 entries: index 0 is the base color, indexes 1–4 are the variants. `const kVariantOffsets = [-0.09, -0.03, 0.03, 0.08]`. `BlockMaterial.of(int topHex, int sideHex)`: `top` = `[shade(topHex, 0), ...offsets.map((v) => shade(topHex, 0 + v))]`; `sideX` from `sideHex` with base factor `-0.06`; `sideY` from `sideHex` with base factor `-0.26` (variants add the offsets to the base factor).
  3. `abstract final class Blocks` with static finals (top color, side color): grass (`6aa84f`, `866043`), dirt (`8b6a47`, `866043`), path (`bba57c`, `9b875f`), plank (`c69c5d`, `c69c5d`), log (`a8875c`, `6b4e31`), cobble (`9d9d9d`, `8e8e8e`), stone (`bcbfc5`, `a7aab0`), roof (`b04a3c`, `9a3f33`), slate (`56708c`, `4b6178`), glass (`cdeef7`, `a9dcec`), leaves (`4e9a3d`, `3f8531`), water (`3d84c6`, `3574b0`), wool (`e0483e`, `c63d34`), char (`4a4038`, `3b332d`).
  4. `FlatColor { int top; int sideX; int sideY; }` via `FlatColor.of(hex)`: top = `shade(hex, 0.08)`, sideX = `shade(hex, -0.07)`, sideY = `shade(hex, -0.27)`. `abstract final class WorkerColors`: pants `3b4a6b`, vest `ff8a1f`, skin `e2b48c`, helmet `ffd23f`, tool `6b6f78`, shirt `3f9e7a`.
  5. `const kSkyTop = 0xFF8cc9ea; const kSkyBottom = 0xFFcdeaf7;`
- Tests first: `shade` with f = 0 leaves a color unchanged, with f = -1 gives black, clamps at 255 for large f; `Blocks.grass.top[0]` is `0xFF6aa84f`; `Blocks.grass.sideX[0]` equals `shade(0x866043, -0.06)`; `sideY[0]` equals `shade(.., -0.26)`; every list has 5 entries; variant 1 of grass top equals `shade(0x6aa84f, -0.09)`; `FlatColor.of(0xff8a1f).sideY` equals `shade(.., -0.27)`; all 14 materials exist.
- Done when: flutter analyze clean; flutter test green.
- Commit: `T-13.2: block materials`

### T-13.3 [x] VoxelWorld: storage, fill, ring
- Step: 13 (docs/prompt_plan.md, Prompt 13)
- Depends on: T-13.2
- Goal: the block container with the prototype's `set/get/remove/fill/ring` helpers.
- Files: `lib/game/world/voxel_world.dart`, `test/game/voxel_world_test.dart`.
- Do:
  1. `class VoxelWorld`: private map from a packed int key to `BlockMaterial`. Key = `((x + 128) << 16) | ((y + 128) << 8) | (z + 128)`; `assert` each coordinate is in -128..127.
  2. `void set(int x, int y, int z, BlockMaterial m)`, `BlockMaterial? get(int x, int y, int z)`, `bool has(...)`, `void remove(...)`, `int get blockCount`, `void clear()`, `Iterable<({int x, int y, int z, BlockMaterial material})> get blocks`.
  3. `void fill(int x0, int y0, int z0, int x1, int y1, int z1, BlockMaterial m)` over the inclusive box.
  4. `void ring(int x0, int y0, int w, int d, int z, BlockMaterial m, {BlockMaterial? corner})`: the outline of a `w` by `d` rectangle at height `z`; corner cells use `corner` when given.
- Tests first: set/get/has/remove; negative `z` (-1) works; `fill` of a 3x3x2 box adds 18; `ring` of 5x5 adds 16, of 3x3 adds 8; `ring` with a corner material makes exactly the 4 corners that material; `blockCount` and `clear`; overwriting a position keeps count.
- Done when: flutter analyze clean; flutter test green.
- Commit: `T-13.3: voxel world storage`

### T-13.4 [x] VoxelWorld: visible faces and depth order
- Step: 13 (docs/prompt_plan.md, Prompt 13)
- Depends on: T-13.3
- Goal: face culling and the back-to-front draw order from the prototype.
- Files: `lib/game/world/voxel_world.dart`, `test/game/voxel_world_test.dart`.
- Do:
  1. Constants `kFaceTop = 1`, `kFaceX = 2` (+x side), `kFaceY = 4` (+y side).
  2. `int visibleFaces(int x, int y, int z)`: top bit if no block at `(x, y, z+1)`; +x bit if none at `(x+1, y, z)`; +y bit if none at `(x, y+1, z)`.
  3. `class VisibleBlock { int x, y, z; BlockMaterial material; int faces; }` and `List<VisibleBlock> sortedVisible()`: every block with `faces != 0`, sorted by depth key `x + y + z` ascending; ties broken by `z`, then `x`, then `y` (stable, deterministic).
- Tests first: a single block has faces `7` (3 visible); a block with neighbors on +x, +y, and above has `0` and is not returned; stacking one block on another hides the lower top face (`faces & kFaceTop == 0`); a block at x+1 hides only the +x face; depth order: a block at (0,0,0) comes before (1,1,0) which comes before (2,2,0); tie-break order for equal depth (e.g. (1,0,0) and (0,1,0) and (0,0,1)): z lowest first, then x lowest; `sortedVisible` on 5x5x1 fill has 25 entries; same input always gives the same order.
- Done when: flutter analyze clean; flutter test green.
- Commit: `T-13.4: voxel visibility and depth order`

### T-13.5 [x] DebugScreen "World stats" line
- Step: 13 (docs/prompt_plan.md, Prompt 13)
- Depends on: T-13.4
- Goal: wire the world module into the app. Ends step 13.
- Files: `lib/ui/debug_screen.dart`, `test/ui/debug_screen_test.dart`.
- Do: on the debug screen build a `VoxelWorld` with a 32x32 ground (dirt at `z = -1`, grass at `z = 0`) and show `World: <blockCount> blocks, <visibleCount> visible` (`sortedVisible().length`). Build it once (e.g. in `initState` or a memoized provider), not on every refresh tick.
- Tests first (widget): the line shows `2048 blocks` (32 x 32 x 2) and a visible count equal to `sortedVisible().length` of an identically built world (all 1024 grass tops plus the dirt blocks on the two exposed edges, 63 of them, so 1087; assert the computed value, not a guess).
- Done when: flutter analyze clean; flutter test green.
- Commit: `T-13.5: debug world stats`

### T-14.1 [x] Plot layout
- Step: 14 (docs/prompt_plan.md, Prompt 14)
- Depends on: T-13.5
- Goal: a fixed, deterministic list of building plots around crossing roads.
- Files: `lib/game/world/plot_layout.dart`, `test/game/plot_layout_test.dart`.
- Do:
  1. Decision (the prompt asks for 40+ plots of 7x7 on a 32x32 map, which cannot fit; this resolves it): the town map is `kMapSize = 64`. Crossing roads occupy `x = 31..32` and `y = 31..32` across the whole map. `kPlotSize = 7`.
  2. Plots sit on a 7-tile lattice in each of the four quadrants: west/north origins `3, 10, 17, 24` (last tile 30, next to the road), east/south origins `33, 40, 47, 54` (last tile 60). That is 4 x 4 per quadrant, 64 plots. Tiles outside plots and roads (the 3-tile map border) stay free for scenery.
  3. `class Plot { int index; int originX; int originY; }` with `int get size => 7`, `Vec2 get center` = `(originX + 3.5, originY + 3.5)`.
  4. `final List<Plot> kPlots`: all 64 candidates sorted by squared distance from the crossing center `(32, 32)` to the plot center (ascending), ties broken by `originY` then `originX`; then numbered `0..63` in that order. Indexes 0–5 are therefore nearest the crossing; later plots spiral outward.
  5. Helpers: `bool isRoad(int x, int y)` (`x` in 31..32 or `y` in 31..32), `Plot? plotAt(int x, int y)`.
- Tests first: 64 plots, indexes 0..63 in order; distances are non-decreasing with index; plots 0–3 are the four plots touching the crossing corners; no plot overlaps another or a road; every plot lies within 0..63; `isRoad` for 31, 32, 30, 33; `plotAt` returns the right plot for its corner tiles and null on a road; layout is identical across two calls.
- Done when: flutter analyze clean; flutter test green.
- Commit: `T-14.1: plot layout`

### T-14.2 [x] Stage infrastructure, hut and house
- Step: 14 (docs/prompt_plan.md, Prompt 14)
- Depends on: T-14.1
- Goal: stage counts, `stageForProgress`, a shared scaffold helper, and the hut and house shapes.
- Files: `lib/game/world/building_defs.dart`, `test/game/building_defs_test.dart`.
- Do:
  1. `int maxStage(BuildingTier t)`: hut 4, house 7, workshop 6, tower 8, castle 12.
  2. `int stageForProgress(BuildingTier t, double progress)`: `clamp(1 + (progress.clamp(0, 1) * maxStage).floor(), 1, maxStage)`. So stage `s` starts at progress `(s - 1) / maxStage`; progress 0 → 1; progress 1.0 → max.
  3. `void buildTier(VoxelWorld w, BuildingTier t, int plotOriginX, int plotOriginY, {required int stage, bool scaffold = false})`. Building origin `(ox, oy) = (plotOriginX + 1, plotOriginY + 1)` for every tier except the castle (T-14.4). Dispatch to per-tier functions (this task: hut, house; others throw `UnimplementedError` until T-14.3/T-14.4 and are covered by a test marked skip until then).
  4. `_scaffold(w, ox, oy, width, depth, height)`: log posts (z 1..height) at the four outer corners `(ox-1, oy-1)`, `(ox+width, oy-1)`, `(ox-1, oy+depth)`, `(ox+width, oy+depth)`; plank rails at `z = 3` along `x = ox-1..ox+width` at `y = oy+depth`, and along `y = oy-1..oy+depth` at `x = ox+width`.
  5. Hut (3x3 footprint, prototype `hut`): stage 1 `ring(ox, oy, 3, 3, z=1, plank, corner: log)`; stage 2 same at `z = 2`; after the ring at z exists, remove the door cell `(ox+1, oy+2, z)` for z = 1 and 2 (door gap); stage 3 `fill(ox-1, oy-1, 3, ox+3, oy+3, 3, roof)`; stage 4 `fill(ox, oy, 4, ox+2, oy+2, 4, roof)` plus `set(ox+1, oy+1, 5, roof)`. Scaffold (height 4) drawn when `scaffold` is true.
  6. House (5x5, prototype `houseLike`), cumulative by stage: 1 `ring(ox, oy, 5, 5, 1, cobble)`; 2 `ring(.., z=2, plank, corner: log)`; 3 `ring(.., z=3, plank, corner: log)` + glass at `(ox+4, oy+2, 3)`, `(ox+3, oy+4, 3)`, `(ox+1, oy+4, 3)`; door gap: remove `(ox+2, oy+4, 1)` from stage 1 and `(ox+2, oy+4, 2)` from stage 2; 4 `fill(ox-1, oy-1, 4, ox+5, oy+5, 4, roof)`; 5 `fill(ox, oy, 5, ox+4, oy+4, 5, roof)`; 6 `fill(ox+1, oy+1, 6, ox+3, oy+3, 6, roof)`; 7 `set(ox+2, oy+2, 7, roof)`. Scaffold (height 6) when `scaffold` is true.
- Tests first: `maxStage` values; `stageForProgress` at 0 → 1, at 1.0 → max, at 0.5 for house → 4, just below `(s-1)/max` vs at it for each hut stage; block counts (without scaffold) strictly non-decreasing from stage 1 to max for hut and house; hut stage 4 has the peak block at `(ox+1, oy+1, 5)`; house stage 7 has the roof peak at `(ox+2, oy+2, 7)` and a door gap at `(ox+2, oy+4, 1..2)`; all blocks of both (with scaffold) lie inside the plot's 7x7 footprint for plot 0; scaffold adds log posts at the corners and none when `scaffold` is false.
- Done when: flutter analyze clean; flutter test green.
- Commit: `T-14.2: building stages, hut and house`

### T-14.3 [x] Workshop and tower
- Step: 14 (docs/prompt_plan.md, Prompt 14)
- Depends on: T-14.2
- Goal: the workshop (6 stages) and tower (8 stages).
- Files: `lib/game/world/building_defs.dart`, `test/game/building_defs_test.dart`.
- Do:
  1. Workshop (5x5, resized from the prototype's 6x5 so the scaffold fits the 7x7 plot), cumulative: 1 `ring(ox, oy, 5, 5, 1, cobble)`; 2 same at `z = 2`; 3 same at `z = 3`; the door is a 2-wide gap at `(ox+1..ox+2, oy+4)` for z = 1 and 2, removed as soon as those rings exist; 4 glass windows at `(ox+4, oy+1, 2)` and `(ox+4, oy+2, 2)`; 5 `fill(ox, oy, 4, ox+4, oy+4, 4, slate)`; 6 chimney `fill(ox+3, oy+1, 5, ox+3, oy+1, 6, cobble)`. Scaffold (height 4) when `scaffold` is true.
  2. Tower (3x3, prototype `tower`), cumulative layers of `stone` boxes `fill(ox, oy, z, ox+2, oy+2, z)`: 1 z 1–2; 2 z 3–4; 3 z 5–6; 4 z 7–8; 5 z 9; 6 battlements at the four corners `(ox+dx, oy+dy, 10)` for `(dx, dy)` in `(0,0), (2,0), (0,2), (2,2)`; 7 flag pole `fill(ox+1, oy+1, 10, ox+1, oy+1, 12, log)`; 8 flag `fill(ox+2, oy+1, 11, ox+3, oy+1, 12, wool)` (this cell range may extend to `ox+3`; it must stay in the footprint). Features appear with their layer: door gap `(ox+1, oy+2, 1..2)`, glass at `(ox+2, oy+1, 5)` (stage 3) and `(ox+1, oy+2, 7)` (stage 4). Scaffold (height 9) when `scaffold` is true.
  3. Replace the `UnimplementedError` branches for these tiers.
- Tests first: stages monotone non-decreasing in block count for both; final stage block counts are fixed numbers you assert (compute once, then pin); final stage fits the 7x7 footprint for plot 0 and for plot 63 (with scaffold on at stage max-1); tower flag exists only at stage 8; workshop door gap is open at stage 1; `buildTier` for workshop and tower no longer throws.
- Done when: flutter analyze clean; flutter test green.
- Commit: `T-14.3: workshop and tower`

### T-14.4 [x] Castle and ruin
- Step: 14 (docs/prompt_plan.md, Prompt 14)
- Depends on: T-14.3
- Goal: the castle (12 stages, shrunk to fit one 7x7 plot) and the ruin shape.
- Files: `lib/game/world/building_defs.dart`, `test/game/building_defs_test.dart`.
- Do:
  1. Decision (documented in a doc comment): the prototype castle is 9x9; shrink it to fit one 7x7 plot. The castle uses the plot origin itself `(ox, oy) = (plotOriginX, plotOriginY)`, so it has no margin and ignores the `scaffold` flag (no scaffold for castles).
  2. Final shape (all `stone` unless noted): outer wall `ring(ox, oy, 7, 7, z, stone)` for z = 1..4; battlements at `z = 5` on wall cells where `(x + y) % 2 == 0`; gate gap at `x = ox+2..ox+4, y = oy+6, z = 1..3`; four corner towers `fill(tx, ty, 1, tx+1, ty+1, 6)` at `(ox, oy)`, `(ox+5, oy)`, `(ox, oy+5)`, `(ox+5, oy+5)` with merlons at `(tx, ty, 7)` and `(tx+1, ty+1, 7)`; keep `fill(ox+2, oy+2, 1, ox+4, oy+4, 4, cobble)`; keep roof `fill(ox+2, oy+2, 5, ox+4, oy+4, 5, slate)` and peak `set(ox+3, oy+3, 6, slate)`; flags `flag` helper (`log` pole 3 blocks, `wool` pennant) on two corner towers at `z = 8`.
  3. 12 stages, cumulative, bottom-up: stages 1–4 add wall rings z 1–4 (gate gap cleared as the rings are placed); 5 battlements; 6 and 7 corner towers up to z 3 and then z 6; 8 tower merlons; 9 the keep up to z 4; 10 slate roof; 11 roof peak; 12 flags. Stage 12 equals the full shape.
  4. Ruin (prototype `ruin`, 5x5 at `(ox, oy)` = plot origin + 1): `cobble` at z 1 on `(0,0),(1,0),(0,1),(4,0),(4,1),(0,3),(0,4),(3,4),(4,4)`; `plank` at z 2 on `(0,0),(0,1),(4,0)`; `char` at `(0,0,3)` and `(4,4,2)`; `char` fill z 1 on `(1..3, 2)`; `cobble` at `(2, 3, 1)`. Function `buildRuin(VoxelWorld, plotOriginX, plotOriginY)`.
  5. Remove all remaining `UnimplementedError` branches.
- Tests first: castle block count strictly non-decreasing across 12 stages and stage 12 equals the full shape (pin the count); all castle blocks fit inside the plot's 7x7 for plots 0 and 63; gate gap open from stage 1 at `z 1..3`; castle ignores `scaffold`; ruin has only `cobble`, `plank`, and `char` blocks, fits the footprint, and has the same block count every call.
- Done when: flutter analyze clean; flutter test green.
- Commit: `T-14.4: castle and ruin`

### T-14.5 [x] Seeded scenery
- Step: 14 (docs/prompt_plan.md, Prompt 14)
- Depends on: T-14.4
- Goal: trees and a pond that never overlap roads or plots, deterministic from a seed.
- Files: `lib/game/world/scenery.dart`, `test/game/scenery_test.dart`.
- Do:
  1. `void buildTree(VoxelWorld w, int x, int y)` (prototype `tree`): `log` fill `(x, y, 1)..(x, y, 3)`; for `dx, dy` in -1..1 `leaves` at `z = 4`, and at `z = 5` where `|dx| + |dy| < 2`; `leaves` at `(x, y, 6)`.
  2. `void buildPond(VoxelWorld w)`: `water` fill `(56, 0, 0)..(62, 2, 0)` (replaces the grass in the top-right border strip).
  3. `void buildScenery(VoxelWorld w, {int seed = 7})`: the pond plus about 24 trees placed on border tiles only (the 3-tile map border: x or y in 0..2 or 61..63), chosen with `Random(seed)`, at least 3 tiles apart from each other, skipping pond tiles and keeping the full 3x3 leaf canopy inside the map. A tree must never touch a road tile or a plot tile (`plotAt != null`, `isRoad`).
- Tests first: same seed gives identical block sets, different seeds differ; no scenery block lies on a road or inside any of the 64 plots; trees are 3+ tiles apart; all blocks inside 0..63; pond cells are `water`.
- Done when: flutter analyze clean; flutter test green.
- Commit: `T-14.5: seeded scenery`

### T-14.6 [x] buildTownWorld
- Step: 14 (docs/prompt_plan.md, Prompt 14)
- Depends on: T-14.5
- Goal: turn a `TownState` (plus an optional active session) into a `VoxelWorld`.
- Files: `lib/game/world/town_world_builder.dart`, `test/game/town_world_test.dart`.
- Do: `VoxelWorld buildTownWorld(TownState town, {Session? active, double progress = 0})`:
  1. Ground: for every `(x, y)` in 0..63, `dirt` at `z = -1` and `path` (roads) or `grass` at `z = 0`.
  2. Unlocked plots (`index < town.plotsUnlocked`): a subtle `path` border on the plot's outline ring at `z = 0`, skipping road tiles. Locked plots stay plain grass.
  3. Scenery via `buildScenery(w)`.
  4. Each `TownBuilding`: `complete` → `buildTier(w, tier, plot.originX, plot.originY, stage: maxStage(tier))`; `ruin` → `buildRuin(...)`. Queued buildings are not drawn.
  5. Active session: site plot = `nextFreePlot(town)` if not null, otherwise `kPlots[town.plotsUnlocked]` (the first locked plot, used as a temporary site; if out of range use the last plot). Draw `buildTier(.., stage: stageForProgress(tier, progress), scaffold: stage < maxStage(tier))`.
- Tests first: initial town has blocks on plot 0 only (house final stage) and ground everywhere; a 3-building town puts blocks on exactly those plots and none on other plots' interiors; ruin status draws ruin blocks (char present); queued buildings add nothing; active hut at progress 0 draws stage 1 with scaffold posts on the next free plot; progress 1.0 draws the final stage without scaffold; with all unlocked plots occupied the site uses the first locked plot; unlocked plots have the path border and locked plots do not; two builds of the same town are identical.
- Done when: flutter analyze clean; flutter test green.
- Commit: `T-14.6: town world builder`

### T-14.7 [x] World stats from the real town
- Step: 14 (docs/prompt_plan.md, Prompt 14)
- Depends on: T-14.6
- Goal: wire the builder into the app via the debug screen. Ends step 14.
- Files: `lib/ui/debug_screen.dart`, `lib/ui/world_stats_card.dart`, `test/ui/world_stats_card_test.dart`.
- Do: `WorldStatsCard` builds the world from `focusControllerProvider` town state (and the active session with `SessionEngine.progress`) and shows total blocks, visible blocks, and the block count per building (`<tier> <status> plot N: <n> blocks`, counted from the plot's footprint area). Replace the T-13.5 line. Rebuild only when the town or active stage changes (compute in a provider keyed on `TownState` and stage), not every second.
- Tests first (widget, in-memory DB and fake clock): initial town shows one building line `house complete plot 0` with the expected count; after completing a hut a second line appears; a ruin shows `house ruin plot N`.
- Done when: flutter analyze clean; flutter test green.
- Commit: `T-14.7: world stats from real town`

### T-15.1 [x] Block painter (faces, textures, culling) with goldens
- Step: 15 (docs/prompt_plan.md, Prompt 15)
- Depends on: T-14.7
- Goal: draw visible blocks as three textured faces exactly like the prototype, onto a `dart:ui` Canvas.
- Files: `pubspec.yaml`, `lib/game/render/block_painter.dart`, `test/game/block_painter_test.dart`, `test/game/goldens/` (generated).
- Do:
  1. Add `flame` (check pub.dev, pin exactly). It is first used in T-15.3.
  2. `void paintBlocks(Canvas canvas, Iterable<VisibleBlock> blocks, {required double tile, required Vec2 origin, required Size viewSize})`. Per block: `sx = origin.x + (x - y) * tile`, `sy = origin.y + (x + y) * tile * 0.5 - z * tile`. Cull (skip) if `sx < -2*tile || sx > W + 2*tile || sy < -3*tile || sy > H + 2*tile`.
  3. Faces (`T` = tile, `tex = tile >= 9`): top (bit `kFaceTop`) `face(sx, sy - T, T, T*0.5, -T, T*0.5, material.top, seed, tex)`; +x side `face(sx + T, sy - T*0.5, -T, T*0.5, 0, T, material.sideX, seed + 1, tex)`; +y side `face(sx - T, sy - T*0.5, T, T*0.5, 0, T, material.sideY, seed + 2, tex)`. Seed = `(x*73856093) ^ (y*19349663) ^ (z*83492791)`.
  4. `face(ax, ay, ux, uy, vx, vy, colors, seed, tex)`: fill the parallelogram `(ax,ay) → +u → +u+v → +v` with `colors[0]`; if `tex`, split into 2 x 2 sub-quads (half vectors) and fill each with `colors[1 + h]` where `h = (((seed*31 + i*7 + j*13) * 2654435761) & 0xFFFFFFFF) % 4` for `i, j` in 0..1. Use `Canvas.drawPath` with a reused `Paint`.
  5. Also `void paintBox(Canvas, {x,y,z,w,d,h, FlatColor c}, tile, origin)` for worker boxes (prototype `drawBox`): top quad at `P(x, y, z+h)` with u = `(w*T, w*T*0.5)`, v = `(-d*T, d*T*0.5)` in `c.top`; right face at `P(x+w, y, z)` with u = `(-d*T, d*T*0.5)`, v = `(0, -h*T)` in `c.sideX`; left face at `P(x, y+d, z)` with u = `(w*T, w*T*0.5)`, v = `(0, -h*T)` in `c.sideY`, where `P` is the projection.
- Tests first: culling skips an off-screen block (record to a `PictureRecorder` and compare bounds/pixel count to an empty canvas); golden `block_single.png` (one grass block, tile 40, 200x200); golden `block_stack_textured.png` (2x2x2 mixed materials, tile 24); golden `block_small_untextured.png` (same, tile 6, no sub-quads); determinism: painting twice gives identical images. Generate goldens with `flutter test --update-goldens`, open the PNGs and check they look like prototype blocks (3 shaded faces), then commit them. Goldens are macOS-generated; if CI differs, note it in the handoff.
- Done when: flutter analyze clean; flutter test green; goldens reviewed.
- Commit: `T-15.1: block painter`

### T-15.2 [x] Static layer cache with re-record policy
- Step: 15 (docs/prompt_plan.md, Prompt 15)
- Depends on: T-15.1
- Goal: draw the whole static town into a cached `ui.Picture` and re-record it only when needed.
- Files: `lib/game/render/static_layer_cache.dart`, `test/game/static_layer_cache_test.dart`.
- Do:
  1. `StaticLayerCache` holds `Picture? _picture`, recorded `tile`, recorded `origin`, `worldVersion`, `viewSize`, and `int recordCount` (the spy).
  2. `void update({required int worldVersion, required List<VisibleBlock> blocks, required double tile, required Vec2 origin, required Size viewSize})` re-records when: no picture yet; `worldVersion` changed; `tile` changed; `viewSize` changed; or the origin moved from the recorded origin by more than 25% of the view width (x) or height (y). Otherwise do nothing.
  3. Recording covers the viewport enlarged by 25% on every side (culling uses that enlarged rect) so a pan below the threshold shows no gaps.
  4. `void paint(Canvas canvas, Vec2 currentOrigin)`: translates by `currentOrigin - recordedOrigin` and draws the picture.
  5. `recordCount` increments once per recording.
- Tests first: first `update` records (count 1); same arguments again → still 1; world version bump → 2; tile change → 3; pan by 10% of the width → no re-record; pan by 30% → re-record; view size change → re-record; `paint` after a small pan draws shifted by exactly the delta (compare to a direct paint at the new origin for the visible center region).
- Done when: flutter analyze clean; flutter test green.
- Commit: `T-15.2: static layer cache`

### T-15.3 [x] TownRenderer, TownGame, sky, goldens
- Step: 15 (docs/prompt_plan.md, Prompt 15)
- Depends on: T-15.2
- Goal: the Flame game that draws sky plus the cached town from a `TownState`.
- Files: `lib/game/town_renderer.dart`, `lib/game/town_game.dart`, `test/game/town_render_golden_test.dart`, `test/game/goldens/` (generated).
- Do:
  1. `TownRenderer` (plain Dart class, testable without Flame): `setTown(TownState)` builds the world with `buildTownWorld`, bumps `worldVersion`, and stores `sortedVisible()`. `paint(Canvas, Size)` draws the sky (vertical linear gradient `kSkyTop` → `kSkyBottom`), then updates and paints the `StaticLayerCache`.
  2. Camera for now: the prototype's fit, generalized to the 64-tile map `N = 64`: `fitTile = min(W / (2N + 6), H / (N + 18))`, `tile = fitTile`, `origin = (W/2, H/2 - N*tile*0.5 + 5*tile)`. T-16.1 replaces this with `TownCamera`.
  3. `TownGame extends FlameGame` owns a `TownRenderer`; `render(Canvas)` calls `renderer.paint(canvas, size)`; `void setTown(TownState)` forwards; `onGameResize` updates the view size.
- Tests first (`test/game/town_render_golden_test.dart`, render the renderer into a `PictureRecorder` at 400x700): golden `town_initial.png` (`TownState.initial()`); golden `town_five_buildings.png` (initial plus a hut, workshop, tower, ruin on plots 1–4 via `TownState.copyWith`); the renderer records once for two paints of the same town and again after `setTown` with a different town (spy `recordCount`). Generate and review the goldens against `docs/images/block-town-overview.png` (same look: green ground, tan crossing roads, blocky houses).
- Done when: flutter analyze clean; flutter test green; goldens reviewed.
- Commit: `T-15.3: town renderer and game`

### T-15.4 [x] HomeScreen, game bridge, new app home
- Step: 15 (docs/prompt_plan.md, Prompt 15)
- Depends on: T-15.3
- Goal: the real town becomes the home screen; the debug screen stays reachable. Ends step 15 code.
- Files: `lib/ui/home_screen.dart`, `lib/app/app.dart`, `test/ui/home_screen_test.dart`.
- Do:
  1. `HomeScreen` (ConsumerStatefulWidget): creates one `TownGame` in `initState`, shows `GameWidget(game: game)` full screen; `ref.listen(focusControllerProvider, ...)` calls `game.setTown(state.town)` on every change (and once with the initial value). This listener is the bridge.
  2. A transparent 56x56 hit area in the top-left corner; in debug builds only (`kDebugMode`), a long press pushes `DebugScreen`.
  3. `FocusTownApp.home` becomes `HomeScreen` (keep the router and 100 ms flush timer from T-09.5).
  4. There is no Start button yet (T-19.5); sessions are started from the debug screen until then.
- Tests first (widget): `HomeScreen` builds with in-memory DB overrides and shows a `GameWidget`; changing the controller state (complete a hut) calls `game.setTown` with the new town (expose the game through a provider override or constructor param for testing); long press at the top-left corner opens the debug screen in debug mode; long press elsewhere does nothing.
- Done when: flutter analyze clean; flutter test green; app launches into the block town.
- Commit: `T-15.4: home screen with town renderer`

### T-15.5 [ ] [device] Town renders on the iPhone
- Step: 15 (docs/prompt_plan.md, Prompt 15)
- Depends on: T-15.4
- Goal: confirm look, startup time, and smoothness on hardware.
- Files: `docs/device_tests.md`.
- Do: give the user these steps (profile mode: `flutter run --profile -d <iPhone>`), record results under `## Step 15: renderer`:
  1. The town looks like `docs/images/block-town-overview.png` (compare side by side).
  2. Cold start to visible town in under 2 seconds (NFR-5): stopwatch from tapping the icon.
  3. Long-press the top-left corner (debug build) opens the debug screen.
  4. Complete a hut from the debug screen, go back: the new building appears with no flicker.
  5. Note frame times from DevTools (raster thread) if available; no sustained jank is expected because the town is one cached picture.
- Tests first: none (manual).
- Done when: results recorded; flutter analyze clean; flutter test green.
- Commit: `T-15.5: record step 15 device check`

### T-16.1 [x] TownCamera (pure Dart)
- Step: 16 (docs/prompt_plan.md, Prompt 16)
- Depends on: T-15.5
- Goal: camera math with clamping, tested without any UI.
- Files: `lib/game/camera/town_camera.dart`, `test/game/town_camera_test.dart`.
- Do: `TownCamera` with `double tile`, `Vec2 origin`, `Vec2 viewSize`, constant `mapSize = 64`, `kMaxTile = 64`.
  1. `fitMapTile` = `min(W / (2N + 6), H / (N + 18))` (as in T-15.3). `minTile = fitMapTile * 0.7`; `tile` is always clamped to `[minTile, kMaxTile]`.
  2. `fitToMap()`: tile = `fitMapTile`, origin as in T-15.3.
  3. `fitToRegion(Rect worldRegion)` (tile coordinates): project the 4 region corners at `z = 0`, choose the largest tile (clamped) so the projected bounds plus 8% padding fit the view, and center it.
  4. `panBy(Vec2 delta)`: origin += delta, then clamp.
  5. `zoomAt(Vec2 focal, double factor)`: `newTile = clamp(tile * factor)`, `r = newTile / tile`, `origin = focal - (focal - origin) * r`, `tile = newTile`, then clamp. The world point under `focal` stays fixed (except when clamped).
  6. `focusOn(Vec2 worldPoint)` (ground tile coordinates): origin so that the projected point is at the view center, then clamp.
  7. Origin clamp keeps at least 30% of the map on screen in both axes. The map's projected box has width `2*N*tile` (from `ox - N*tile` to `ox + N*tile`) and height `N*tile` (from `oy` to `oy + N*tile`): `ox ∈ [-0.4*N*tile, W + 0.4*N*tile]`, `oy ∈ [-0.7*N*tile, H - 0.3*N*tile]`.
  8. `resize(Vec2 viewSize)`: store the size and re-clamp.
- Tests first: `zoomAt` keeps the focal world point fixed (unproject before and after, within 1e-6) at a mid zoom; zoom clamps at `minTile` and at 64 (repeated factor 2 and 0.5); `fitToMap` makes the whole map's projected corners fit inside the view; `fitToRegion` of plots 0–5 shows them all with the tile larger than `fitMapTile`; `panBy` with huge deltas in all 4 directions leaves >= 30% overlap of the map box with the view; `focusOn(point)` places the projected point at the view center (when not clamped); `resize` re-clamps.
- Done when: flutter analyze clean; flutter test green.
- Commit: `T-16.1: town camera`

### T-16.2 [x] Pan, pinch, wheel, and double-tap gestures
- Step: 16 (docs/prompt_plan.md, Prompt 16)
- Depends on: T-16.1
- Goal: drive the camera from touch and mouse input in the game, replacing the fixed fit.
- Files: `lib/game/town_game.dart`, `lib/game/town_renderer.dart`, `test/game/town_game_gestures_test.dart`.
- Do:
  1. `TownRenderer` uses a `TownCamera` (tile/origin from the camera) and calls `fitToRegion` of the unlocked plots (plot rectangles from `kPlots` for `index < plotsUnlocked`, plus a 4-tile margin) on the first layout.
  2. `TownGame` handles: one-finger drag → `panBy(delta)`; pinch → `zoomAt(focalPoint, scaleFactorDelta)`; mouse wheel → `zoomAt(pointer, exp(-scrollDelta * 0.002))`; double tap → `zoomAt(tapPosition, 1.5)`. Use the gesture mixins available in the pinned Flame version (`ScaleDetector`/`ScrollDetector`/`DoubleTapDetector` or their callback-component equivalents; check the Flame docs for the pinned version).
  3. Gesture handler methods are plain public methods (`onPan(Vec2)`, `onPinch(Vec2 focal, double factor)`, `onWheel(Vec2 pos, double dy)`, `onDoubleTap(Vec2 pos)`) that the Flame callbacks call, so tests do not need real touches.
  4. Camera changes mark the static cache for update (tile change re-records; small pans only translate).
- Tests first: each handler changes the camera as specified (pan moves origin by the delta, pinch factor 1.2 raises tile 20%, wheel up zooms in, double tap zooms 1.5x at the tap with the point fixed); cache `recordCount` stays 1 for a 10% pan and increases for a zoom.
- Done when: flutter analyze clean; flutter test green.
- Commit: `T-16.2: camera gestures`

### T-16.3 [x] Focus-on-site animation and recenter button
- Step: 16 (docs/prompt_plan.md, Prompt 16)
- Depends on: T-16.2
- Goal: when a session starts the camera glides to the site; a button recenters. Ends step 16 code.
- Files: `lib/game/camera/camera_transition.dart`, `lib/game/town_game.dart`, `lib/ui/home_screen.dart`, `test/game/camera_transition_test.dart`, `test/ui/home_screen_test.dart`.
- Do:
  1. `CameraTransition` (pure): animates from the current (center world point, tile) to a target (world point, tile) over `Duration(milliseconds: 400)` with ease-out cubic `1 - (1 - t)^3`; `step(Duration dt)` returns the new camera values; `isDone`.
  2. `TownGame.focusOnSite(Plot plot)`: target point = plot center, target tile = `max(current tile, 14.0)` clamped; run the transition in `update(dt)` (setting `camera` each frame); user drag/pinch cancels it.
  3. `TownGame.recenter()` → `fitToRegion` of the unlocked plots (animate the same way).
  4. `HomeScreen`: when `active` goes from null to a session (also at launch if a session is already active), call `focusOnSite(kPlots[nextFreePlot ?? plotsUnlocked])` (same site rule as `buildTownWorld`). Add a recenter `IconButton` (semantic label `Recenter town`) in a corner overlay.
- Tests first: transition at t = 0 equals the start, t = 400 ms equals the target, midpoint is past halfway (ease-out), never overshoots; user pan cancels; widget test: starting a session via the controller triggers `focusOnSite` once with the right plot; tapping recenter calls `recenter`.
- Done when: flutter analyze clean; flutter test green.
- Commit: `T-16.3: camera focus and recenter`

### T-16.4 [ ] [device] Gestures feel right
- Step: 16 (docs/prompt_plan.md, Prompt 16)
- Depends on: T-16.3
- Goal: tune pan/zoom feel on the iPhone.
- Files: `docs/device_tests.md`.
- Do: give the user these steps and record under `## Step 16: camera`:
  1. Drag pans smoothly; the map can never be dragged fully off screen.
  2. Pinch zooms around the fingers; zoom stops at the whole-map view and at close-up (single worker scale later).
  3. Double-tap zooms in 1.5x at the tap.
  4. Starting a session glides to the site in about 0.4 s; the recenter button returns to the town view.
  5. Note any lag at high zoom (many blocks re-recorded).
- Tests first: none (manual).
- Done when: results recorded (tuning issues filed as new tasks); flutter analyze clean; flutter test green.
- Commit: `T-16.4: record step 16 device check`

### T-17.1 [x] Worker model and poses
- Step: 17 (docs/prompt_plan.md, Prompt 17)
- Depends on: T-16.4
- Goal: the blocky worker built from 4–6 boxes with several poses.
- Files: `lib/game/workers/worker_model.dart`, `test/game/worker_model_test.dart`.
- Do: (pure Dart, no Flame/Flutter)
  1. `enum Pose { idle, hammerUp, hammerDown, walk1, walk2, dead }`.
  2. `class Worker { double x; double y; (int dx, int dy) facing; FlatColor shirt; }`.
  3. `class WorkerBox { double x, y, z, w, d, h; FlatColor color; double get depthKey => x + w/2 + y + d/2 + z + h/2; }`.
  4. `List<WorkerBox> boxesFor(Worker w, Pose p)` (feet at `z = 1`; values from the prototype `worker()`): bob = `0.04` for `hammerDown` and `walk2`, else 0. Alive bodies: pants `(cx-0.18, cy-0.12, 1, 0.36, 0.24, 0.6)`; shirt `(cx-0.22, cy-0.14, 1.6+bob, 0.44, 0.28, 0.5)`; head (skin) `(cx-0.17, cy-0.17, 2.1+bob, 0.34, 0.34, 0.34)`; helmet `(cx-0.2, cy-0.2, 2.44+bob, 0.4, 0.4, 0.1)` (total height 1.54, about 1.6 blocks). Arm box (shirt color, `0.12 x 0.12 x 0.36`) at `(ax, ay, armZ)` where `reach` and `armZ`: `hammerUp` reach 0.26 armZ `2.35`; `hammerDown` reach 0.42 armZ `1.95`; `idle`, `walk1`, `walk2` reach 0.26 armZ `1.3` (arm hangs at the side, no tool); `ax = cx + dx*reach - 0.06 + (dy != 0 ? 0.2 : 0)`, `ay = cy + dy*reach - 0.06 + (dx != 0 ? 0.2 : 0)`. Hammer (tool color `0.22 x 0.22 x 0.12`) only for `hammerUp` (at `armZ + 0.3`) and `hammerDown` (at `armZ - 0.06`), at `(ax + dx*0.12 - 0.05, ay + dy*0.12 - 0.05)`.
  5. `dead`: lying flat: body `(cx-0.7, cy-0.15, 1, 1.1, 0.3, 0.22)` shirt; head `(cx+0.4, cy-0.16, 1, 0.32, 0.32, 0.3)` skin; helmet beside `(cx-0.4, cy+0.45, 1, 0.4, 0.4, 0.1)`; tool `(cx+0.5, cy+0.5, 1, 0.5, 0.1, 0.08)`.
- Tests first: alive pose total height (max `z+h` minus 1) is between 1.5 and 1.7; every pose returns 4–6 boxes; `hammerUp` and `hammerDown` differ and include a tool-colored box; `walk1` and `walk2` differ only by bob; `dead` max height < 0.4; boxes face the right way (arm offset follows `facing`); `depthKey` formula.
- Done when: flutter analyze clean; flutter test green.
- Commit: `T-17.1: worker model and poses`

### T-17.2 [x] Worker assignment, positions, and road walkers
- Step: 17 (docs/prompt_plan.md, Prompt 17)
- Depends on: T-17.1
- Goal: pure logic deciding which workers exist and where they are at a given time.
- Files: `lib/game/workers/worker_layout.dart`, `test/game/worker_layout_test.dart`.
- Do:
  1. `int spareWorkerCount(TownState town, Session? active)` = `min(4, town.workers - (active?.workersAssigned ?? 0))`, never negative. Recovery wanderer: in recovery mode with 0 workers show 1 spare walker (the Last Builder).
  2. `List<PlacedWorker> siteWorkers(Plot site, BuildingTier tier, int count, double seconds, {bool reducedMotion})`: building origin = plot origin + 1 (castle: plot origin). Positions along the two front sides: side A at `y = oy + depth + 0.7`, `x = ox + 0.8 + 1.2*i`, facing `(0, -1)`; side B at `x = ox + width + 0.7`, `y = oy + 0.8 + 1.2*j`, facing `(-1, 0)`; fill side A first then B, alternating, up to `count` (max 8). Each has a phase offset `i % 2`. Pose: `hammerUp`/`hammerDown` alternating every 0.5 s per `floor(seconds*2 + phase) % 2`; with `reducedMotion` always `idle`.
  3. `List<PlacedWorker> spareWalkers(int count, double seconds, {bool reducedMotion})`: road ping-pong, no pathfinding. Vertical road center line `x = 31.6`, horizontal `y = 32.4`, both between 3 and 59 (length 56). Worker `i` alternates road (even = vertical, odd = horizontal), phase offset `i * 14` tiles, speed 1.5 tiles/second. Position `p = (seconds*1.5 + phase) % 112`; forward if `p < 56` at `3 + p`, backward otherwise at `3 + (112 - p)`; facing along travel direction; pose `walk1`/`walk2` alternating every 0.25 s. `reducedMotion` → stationary at the start with `idle`.
  4. `PlacedWorker { Worker worker; Pose pose; }` (shirt: vest color for site workers, shirt color for spare).
- Tests first: spare count for 3 workers/no session = 3; with an assigned castle of 8 on 10 workers = 2; 30 workers → 4; recovery with 0 workers → 1; site positions fit around plot origin (inside plot bounds plus 1) for count 1, 3, 8; poses alternate over time; walkers stay within 3..59 and reverse at the ends; `reducedMotion` gives idle and fixed positions.
- Done when: flutter analyze clean; flutter test green.
- Commit: `T-17.2: worker layout`

### T-17.3 [x] FrameLimiter
- Step: 17 (docs/prompt_plan.md, Prompt 17)
- Depends on: T-17.2
- Goal: a testable frame-rate cap (15 fps, 10 in low power, 0 when hidden).
- Files: `lib/game/frame_limiter.dart`, `test/game/frame_limiter_test.dart`.
- Do: `enum FrameMode { normal, lowPower, paused }` with `fps` 15, 10, 0. `FrameLimiter` has `mode` (settable) and `bool allow(Duration now)`: `paused` always false; otherwise true when `now - lastAllowed >= Duration(microseconds: 1000000 ~/ fps) - 1ms` (first call always true), updating `lastAllowed` when true. Changing mode keeps the last timestamp. Time is passed in, no clock access.
- Tests first: feed 60 Hz timestamps (16 667 µs steps) for 1 s: normal allows 15 (+/-1), lowPower allows 10 (+/-1), paused allows 0; switching normal → lowPower mid-second lowers the rate; first call is allowed; resume from paused allows the next call immediately.
- Done when: flutter analyze clean; flutter test green.
- Commit: `T-17.3: frame limiter`

### T-17.4 [x] Low-power mode reader (native + Dart)
- Step: 17 (docs/prompt_plan.md, Prompt 17)
- Depends on: T-17.3
- Goal: know when iOS Low Power Mode or Android Battery Saver is on.
- Files: `ios/Runner/FocusLifecyclePlugin.swift`, `android/.../FocusLifecyclePlugin.kt`, `lib/platform/power_state.dart`, `lib/app/providers.dart`, `test/platform/power_state_test.dart`.
- Do:
  1. Add method `lowPowerMode` (returns bool) to the existing `focus/lifecycle` MethodChannel: iOS `ProcessInfo.processInfo.isLowPowerModeEnabled`; Android `PowerManager.isPowerSaveMode`.
  2. `PowerState { Future<bool> isLowPower(); }` over the channel; any `MissingPluginException`/`PlatformException` returns `false`.
  3. `lowPowerProvider = StreamProvider<bool>` that emits the current value at start, then re-reads every 30 seconds and on app resume (use `WidgetsBindingObserver`); emits only on change.
  4. No native change observers (polling is enough and keeps native code small).
- Tests first (mock channel): returns true/false from the channel; missing plugin → false; provider emits the initial value and then only changes (use fake timers).
- Done when: flutter analyze clean; flutter test green; `flutter build ios --no-codesign` and `flutter build apk --debug` compile.
- Commit: `T-17.4: low power mode reader`

### T-17.5 [x] Draw workers with local occlusion
- Step: 17 (docs/prompt_plan.md, Prompt 17)
- Depends on: T-17.4
- Goal: draw workers on top of the cached town and correctly hide them behind nearer blocks.
- Files: `lib/game/render/worker_painter.dart`, `lib/game/town_renderer.dart`, `test/game/worker_painter_test.dart`, `test/game/goldens/` (generated).
- Do:
  1. Approach (document it as a doc comment, including limits): after drawing the cached static layer, for each worker (sorted by depth key) paint its boxes with `paintBox`, then redraw only the static blocks within 3 tiles (`|bx - wx| <= 3 and |by - wy| <= 3`) whose depth key `x + y + z + 1.5` is greater than the worker's box key. Limits: blocks further than 3 tiles never occlude a worker (a tall tower far in front is ignored); static blocks are drawn twice (identical pixels), which is fine.
  2. `TownRenderer` keeps a spatial index built when the world changes: `Map<int, List<VisibleBlock>>` keyed by `(x, y)` column, so a worker query is O(neighbors).
  3. `TownRenderer.paintWorkers(Canvas, List<PlacedWorker>)` draws them after the cache each frame.
  4. Do not wire game state yet (T-17.6); expose `setWorkers(List<PlacedWorker>)`.
- Tests first: neighbor query returns blocks only within the radius; a worker standing behind a wall block (smaller depth) is hidden by the redrawn block (golden `worker_behind_wall.png`) and standing in front is fully visible (`worker_in_front.png`); worker boxes drawn in depth order; golden of a 3-worker site beside a house at stage 4. Generate and review goldens.
- Done when: flutter analyze clean; flutter test green; goldens reviewed.
- Commit: `T-17.5: worker painter with occlusion`

### T-17.6 [x] Wire workers, frame cap, reduced motion, pause, fps readout
- Step: 17 (docs/prompt_plan.md, Prompt 17)
- Depends on: T-17.5
- Goal: workers appear in the running app with the frame cap and battery rules. Ends step 17 code.
- Files: `lib/game/town_game.dart`, `lib/ui/home_screen.dart`, `lib/ui/debug_screen.dart`, `lib/app/providers.dart`, `test/game/town_game_test.dart`, `test/ui/home_screen_test.dart`.
- Do:
  1. `TownGame` receives the current `FocusState` (via the HomeScreen bridge) and each allowed frame computes `siteWorkers` (when a session is active; count = `workersAssigned`; in recovery with 0 assigned show 1 site worker for the wanderer) and `spareWalkers`, then `renderer.setWorkers(...)`. Time for animation = seconds since game start.
  2. `FrameLimiter`: `update(dt)` runs the simulation only when `limiter.allow(elapsed)`; `render` draws a fresh frame when allowed, otherwise redraws the last recorded frame `Picture` (no re-rasterizing blocks). Mode: `paused` when the app is not resumed (use `WidgetsBindingObserver` in `HomeScreen`: `paused/inactive/hidden/detached` → `game.pauseEngine()` and mode paused; `resumed` → `resumeEngine()`), `lowPower` when `lowPowerProvider` is true, else `normal`.
  3. Reduced motion: read `MediaQuery.of(context).disableAnimations` in `HomeScreen` and pass `reducedMotion` to the game (workers `idle`, no walking).
  4. Measured fps: `TownGame` counts rendered frames per second into a `ValueNotifier<double>` exposed by `fpsProvider`; the debug screen shows `FPS: <n>`.
- Tests first: with a fake elapsed clock the game renders ~15 frames in 1 s of 60 Hz updates, ~10 in low power, 0 when paused; paused when lifecycle is `paused` and resumed on `resumed`; `reducedMotion` workers are `idle` and spare walkers do not move between frames; assigned count follows the active session; debug screen shows the fps value.
- Done when: flutter analyze clean; flutter test green; workers visible in the app.
- Commit: `T-17.6: workers, frame cap and pause`

### T-17.7 [ ] [device] Frame rate, GPU, and battery
- Step: 17 (docs/prompt_plan.md, Prompt 17)
- Depends on: T-17.6
- Goal: verify NFR-3 and NFR-4 on the iPhone (and an Android phone later).
- Files: `docs/device_tests.md`.
- Do: give the user these steps (profile build), record numbers under `## Step 17: performance`:
  1. Debug screen FPS reads about 15 (10-20) with a session running.
  2. Turn on Low Power Mode: FPS drops to about 10 within 30 seconds.
  3. Lock the phone: in Xcode Instruments (Time Profiler / Metal) or the Flutter performance overlay, GPU and CPU are near zero while locked.
  4. Battery: run a 20-minute session with the screen on; note battery drop (target under 5% per hour on an iPhone 12).
  5. Workers hammer at the site, spare workers walk the roads; with Settings > Accessibility > Reduce Motion on, they stand still.
- Tests first: none (manual).
- Done when: numbers recorded (misses filed as new tasks); flutter analyze clean; flutter test green.
- Commit: `T-17.7: record step 17 device check`

### T-18.1 [x] Site stage in the world, re-record only on stage change
- Step: 18 (docs/prompt_plan.md, Prompt 18)
- Depends on: T-17.7
- Goal: show the building under construction and rebuild the picture only when its stage changes.
- Files: `lib/game/town_renderer.dart`, `lib/game/town_game.dart`, `test/game/town_renderer_site_test.dart`.
- Do:
  1. Design note (deviation from the prompt, recorded in a doc comment): the active site is built into the same `VoxelWorld` via `buildTownWorld(town, active:, progress:)` and the static cache re-records when the site stage changes (at most `maxStage` times per session). This keeps depth order against neighbors fully correct and is cheap; the prompt's separate dynamic layer is not needed.
  2. `ActiveSite { BuildingTier tier; int stage; }` (null when no session). `TownRenderer.setSite(ActiveSite?)` bumps `worldVersion` only if the stage or tier changed. The world progress passed to `buildTownWorld` is the stage's lower threshold `(stage - 1) / maxStage` so `stageForProgress` reproduces the stage exactly.
  3. Scaffolding is drawn while `stage < maxStage` (already in `buildTownWorld`).
- Tests first: setting the same site twice does not re-record; stage 1 → 2 re-records once; walking a hut through stages 1–4 records exactly 4 times (+1 initial); clearing the site records once; goldens are added in T-18.4.
- Done when: flutter analyze clean; flutter test green.
- Commit: `T-18.1: site stage in renderer`

### T-18.2 [x] Progress-driven stage from the real clock
- Step: 18 (docs/prompt_plan.md, Prompt 18)
- Depends on: T-18.1
- Goal: the stage comes from `SessionEngine.progress` computed every frame, never from stored state.
- Files: `lib/game/town_game.dart`, `lib/ui/home_screen.dart`, `test/game/town_game_progress_test.dart`.
- Do: on each allowed update, if `focusState.active != null`: `progress = SessionEngine.progress(active, TimeStamp.now(clock))`; `stage = stageForProgress(active.tier, progress)`; `renderer.setSite(ActiveSite(tier, stage))`. Inject the `Clock` (from `clockProvider`) into `TownGame`. When no session is active call `setSite(null)`.
- Tests first (FakeClock): for each tier, stepping the clock across the session length shows stage changes exactly at `(s - 1) / maxStage` of the planned time (assert first and last 3 thresholds per tier) and re-record count equals the number of stage changes; stage never decreases; after a lock (no lifecycle effect) the stage still follows time; reboot (`simulateReboot`) uses elapsed fallback and does not jump backward.
- Done when: flutter analyze clean; flutter test green.
- Commit: `T-18.2: progress driven construction`

### T-18.3 [x] Completed transition: celebration
- Step: 18 (docs/prompt_plan.md, Prompt 18)
- Depends on: T-18.2
- Goal: when a session completes, show a short celebration and let site workers walk to the roads.
- Files: `lib/game/effects/particles.dart`, `lib/game/effects/site_transition.dart`, `lib/game/town_game.dart`, `test/game/site_transition_test.dart`.
- Do:
  1. `ParticleSystem` (pure, seeded `Random`): `burst(Vec3 origin, List<int> colors, int count)`, `step(Duration dt)`, particles have position, velocity (upward, slight spread), life; `List<Particle> get alive`; fully deterministic for a seed.
  2. `SiteTransition` state machine (pure): phases `celebrate` (1 second) then `done`; `step(dt)`; `double fade` goes 1 → 0 across the second.
  3. In `TownGame`: when `lastResult` appears with outcome `completed` (or `queued`, see T-18.5) for the remembered last site plot: scaffolding already gone (the new town contains the final building); spawn about 40 dust particles in the building's block colors above the plot center; draw them as small quads above the cached layer with alpha = fade; during the 1 second the former site workers lerp from their site positions to the nearest road line, then disappear (spare walkers take over).
  4. Particles are disabled in low-power mode (`FrameMode.lowPower`): no particles, workers just disappear at the end.
- Tests first: particle system deterministic for the same seed; particles move up and die by their lifetime; `SiteTransition` ends at exactly 1 s and fade is monotonic; completed result triggers one celebration; low-power mode spawns zero particles; reduced motion skips the lerp (workers vanish immediately).
- Done when: flutter analyze clean; flutter test green.
- Commit: `T-18.3: completion celebration`

### T-18.4 [x] Failed transition: dead workers, ruin, smoke
- Step: 18 (docs/prompt_plan.md, Prompt 18)
- Depends on: T-18.3
- Goal: show the failure clearly, and add goldens for construction and failure.
- Files: `lib/game/effects/site_transition.dart`, `lib/game/town_game.dart`, `test/game/town_render_golden_test.dart`, `test/game/goldens/` (generated).
- Do:
  1. On a `failed` result: the remembered site workers switch to the `dead` pose at their positions for 3 seconds; the world already shows the ruin on that plot (from `applyFailed`; if no free plot existed no ruin is drawn); spawn smoke particles (grey `char`-colored quads rising slowly, about 25, respawning for 3 seconds) above the plot; after 3 seconds the dead workers disappear. No smoke in low-power mode.
  2. `SiteTransition` gets a `fail` phase of 3 seconds.
- Tests first: failed result triggers dead poses for exactly 3 seconds then none; smoke particles exist during the phase and not after, and not in low power; goldens: `town_mid_construction.png` (hut or house under construction at stage 4 of 7 with 3 hammering workers), `town_failed_site.png` (ruin plus dead workers and smoke at a fixed time step). Generate and review goldens.
- Done when: flutter analyze clean; flutter test green; goldens reviewed.
- Commit: `T-18.4: failure transition and goldens`

### T-18.5 [x] Queued transition and full wiring
- Step: 18 (docs/prompt_plan.md, Prompt 18)
- Depends on: T-18.4
- Goal: when a finished building has no free plot, show it briefly as "ready to place" then queue it. Wire everything to the real controller. Ends step 18 code.
- Files: `lib/game/effects/site_transition.dart`, `lib/game/town_game.dart`, `lib/ui/home_screen.dart`, `test/game/site_transition_test.dart`, `test/ui/home_screen_test.dart`.
- Do:
  1. Outcome `queued` (no free plot): for 2 seconds draw the finished building as a floating outline (the tier's final stage drawn at 40% alpha, lifted 2 blocks) above the road next to the temporary site, plus a text label `Ready to place` (Flutter `Text` overlay anchored to the projected point, or a Flame `TextComponent`), then fade out into the queue.
  2. Confirm the whole chain works from the real `FocusController`: start from the debug screen, the HomeScreen builds the site by progress, then celebration/failure/queued plays when the result arrives.
- Tests first: queued result triggers the outline phase for 2 s and the label exists during it, not after; widget test: a controller session that completes with a full town shows the label then removes it; completed and failed paths still behave as in T-18.3/T-18.4.
- Done when: flutter analyze clean; flutter test green.
- Commit: `T-18.5: queued transition and wiring`

### T-18.6 [x] [device] A 10-minute hut visibly builds
- Step: 18 (docs/prompt_plan.md, Prompt 18)
- Depends on: T-18.5
- Goal: end-to-end visual check on the iPhone. Phase D complete.
- Files: `docs/device_tests.md`.
- Do: give the user these steps and record under `## Step 18: live construction`:
  1. Start a 10-minute hut from the debug screen, go back to the town: the camera glides to the site, scaffolding stands, 1 builder hammers.
  2. Over the session the hut grows through 4 stages (about every 2.5 minutes). Lock the phone and unlock: the stage matches elapsed time.
  3. At completion: dust burst, scaffolding gone, builder leaves.
  4. Start another, use `Leave` + `Return` after 90 s (or switch apps with the native bridge): builders lie down, a ruin with smoke appears.
  5. Fill all plots (debug) and complete one: `Ready to place` appears, then the queue badge later.
- Tests first: none (manual).
- Done when: results recorded; flutter analyze clean; flutter test green.
- Commit: `T-18.6: record step 18 device check`

## Phase D2: choose your plot (added after the first device test)

Idea from the user: instead of the next free plot, the user taps open ground to choose where a building goes. Staff-engineer cut for the MVP (user wants the MVP asap): the user chooses any FREE UNLOCKED PLOT (7x7), not arbitrary tiles. That keeps every rule and the whole renderer on plots and needs only one new nullable column. Arbitrary footprints (landmarks such as a pyramid or a bridge) come later and will replace the plot index with a position; nothing here blocks that. Run after T-18.6 was parked, before step 19.

Decisions (assumed): no choice means the old automatic plot; the chosen plot is stored with the session so a kill and relaunch resumes on it; a plot chosen but no longer free falls back to the automatic one.

Revision after the first iPhone test (user): the whole island is forest, any of the 64 plots can be chosen, and the plot used (building, ruin or site) is cleared and bordered. The unlock rule now caps HOW MANY buildings the town may have (6 at the start, one more per focus day), not WHERE: `TownRules.hasRoom`, `isPlotFree` and `nextFreePlot` check room and an unused plot. `lib/game/world/forest.dart` draws 3 or 4 trees per uncleared plot (about 12.6k blocks in all, 7.2k visible, up from 8.8k and 4.6k): check frame time and the cost of each stage re-record on the iPhone.

### T-18A.1 [x] Chosen plot in the rules (pure)
- Depends on: T-18.5
- Files: `lib/domain/session.dart`, `lib/domain/session_engine.dart`, `lib/domain/town_rules.dart`, tests.
- Do: `Session.plotIndex` (nullable); `SessionEngine.start(..., plotIndex)`; `TownRules.isPlotFree(town, i)` (unlocked and unused); `TownRules.sitePlot(town, session)` returns the chosen plot when free, else `nextFreePlot`; `applyCompleted`, `applyFailed` and `placeQueued` use it.
- Tests first: a chosen free plot gets the building and the ruin; a taken, locked or out-of-range plot falls back to the automatic plot; no choice equals the old behaviour (existing tests unchanged).
- Commit: `T-18A.1: chosen plot in rules`

### T-18A.2 [x] Store the chosen plot (schema v2)
- Depends on: T-18A.1
- Files: `lib/data/database.dart` (+ generated), `lib/data/mappers.dart`, `drift_schemas/drift_schema_v2.json`, tests.
- Do: nullable `plotIndex` column on sessions, schema 2, `onUpgrade` adds it; mappers read and write it.
- Tests first: round trip with and without a plot; a v1 database upgrades with its data kept and `plotIndex` null.
- Commit: `T-18A.2: session plot column`

### T-18A.3 [x] Controller starts on a chosen plot; the world follows it
- Depends on: T-18A.2
- Do: `FocusController.start(minutes, {plotIndex})` (StateError when that plot is not free; null picks and stores `nextFreePlot`); `ActiveSite` gets `plotIndex`; `activeSitePlot(town, plotIndex)`; renderer, game, workers, celebration and home screen use the session's plot.
- Tests first: start on plot 3 builds there, resumes there after a kill and relaunch, completes there; failed leaves the ruin there; invalid plot is refused; existing tests pass.
- Commit: `T-18A.3: build on the chosen plot`

### T-18A.4 [x] Choose-a-plot mode on the home screen
- Depends on: T-18A.3
- Do: a provider holds a pending start (minutes); the debug screen gets a `Place…` button that sets it and returns to the town; the town shows green outlines on free unlocked plots, a tap selects one (thicker outline), `Confirm` starts the session there, `Cancel` clears; pan and zoom keep working; the plain `Start` still uses the automatic plot.
- Tests first: tapping a free plot selects it; tapping a taken or locked one does nothing; Confirm calls `start` with the plot; Cancel starts nothing; an active session hides the mode.
- Commit: `T-18A.4: choose a plot`

### T-18A.5 [x] [device] Place a hut on a plot of your choice
- Depends on: T-18A.4
- Do: give the user steps (place a hut on plot 3, force-quit, relaunch, confirm it resumes there); record under `## Step 18A: placement` in `docs/device_tests.md`.
- Commit: `T-18A.5: record placement device check`

## Phase E: screens and release

### T-19.1 [x] Schema v3: lastDurationMinutes and migration
- Step: 19 (docs/prompt_plan.md, Prompt 19)
- Depends on: T-18.6
- Goal: remember the last chosen duration in the database, with a tested v2 → v3 migration (v2 already holds the session plot column from T-18A.2).
- Files: `lib/data/database.dart` (+ generated), `lib/data/town_repository.dart`, `drift_schemas/drift_schema_v3.json`, `test/generated_migrations/` (generated), `test/data/migration_test.dart`, `test/data/town_repository_test.dart`.
- Do:
  1. Add column `lastDurationMinutes` int, default 25, to `Towns`. `schemaVersion = 3`. `MigrationStrategy.onUpgrade`: `if (from < 3) await m.addColumn(towns, towns.lastDurationMinutes);`.
  2. Dump the new schema: `dart run drift_dev schema dump lib/data/database.dart drift_schemas/`. Generate test helpers: `dart run drift_dev schema generate drift_schemas/ test/generated_migrations/` and use drift's `SchemaVerifier` in the migration test.
  3. Repository: `Future<int> lastDurationMinutes()` and `Future<void> saveLastDuration(int minutes)`; `saveSessionResolved` must not overwrite it.
- Tests first: migration tests v1 → v3 and v2 → v3 keep data (insert an old town, building, and session, migrate, read them back unchanged and `lastDurationMinutes == 25`); fresh v3 database has the default 25; `saveLastDuration(40)` then `lastDurationMinutes()` returns 40 and survives `saveSessionResolved`.
- Done when: flutter analyze clean; flutter test green.
- Commit: `T-19.1: schema v3 last duration`

### T-19.2 [x] Setup options logic
- Step: 19 (docs/prompt_plan.md, Prompt 19)
- Depends on: T-19.1
- Goal: pure logic for the duration picker: which durations are enabled and why not.
- Files: `lib/app/session_setup.dart`, `test/app/session_setup_test.dart`.
- Do:
  1. `class DurationOption { int minutes; BuildingTier tier; int workersAtRisk; int workersGained; bool enabled; String? reason; }`.
  2. `List<DurationOption> durationOptions(TownState town)`: one per `BuildingTier.validDurations()`. `workersAtRisk` = tier risk (0 in recovery mode), `workersGained` = `workersAddedOnSuccess`. Enabled = `TownRules.canStart(town, minutes)`. Reasons when disabled: normal mode `Needs ${tier.workersAtRisk} workers, you have ${town.workers}`; recovery mode `Recovery mode: huts only`.
  3. `int defaultMinutes(List<DurationOption> options, int lastUsed)`: `lastUsed` if enabled; else the largest enabled option not above it; else the smallest enabled option; else 10.
- Tests first: initial town (3 workers): 10–60 enabled (workshop needs 3), 65 disabled with `Needs 5 workers, you have 3`, 95 disabled `Needs 8 workers, you have 3`; recovery town: only 10–20 enabled, others `Recovery mode: huts only`, hut `workersAtRisk` 0; `defaultMinutes` with last 25 → 25; last 95 on a 3-worker town → 60 (largest enabled below); recovery with last 25 → 20; gains: 10 → 1, 25 → 2, 45 → 0.
- Done when: flutter analyze clean; flutter test green.
- Commit: `T-19.2: session setup options`

### T-19.3 [x] Tier preview image
- Step: 19 (docs/prompt_plan.md, Prompt 19)
- Depends on: T-19.2
- Goal: render each tier's final building into a small image using the existing painter.
- Files: `lib/game/render/tier_preview.dart`, `lib/app/providers.dart`, `test/game/tier_preview_test.dart`, `test/game/goldens/tier_previews.png`.
- Do:
  1. `Future<ui.Image> renderTierPreview(BuildingTier tier, {int size = 96})`: build a small `VoxelWorld` (a 9x9 grass patch with the building from `buildTier(.., stage: maxStage(tier))` on a 7x7 plot offset), compute the tile so the building's projected bounds fill about 80% of `size`, paint with `paintBlocks`, return `picture.toImage(size, size)` on a transparent background.
  2. `tierPreviewProvider = FutureProvider.family<ui.Image, BuildingTier>` (cached per tier).
- Tests first: each tier returns an image of the requested size with at least 200 non-transparent pixels; castle preview is not identical to hut preview; golden `tier_previews.png` with all five side by side (generate, review).
- Done when: flutter analyze clean; flutter test green; golden reviewed.
- Commit: `T-19.3: tier preview image`

### T-19.4 [x] SessionSetupSheet widget
- Step: 19 (docs/prompt_plan.md, Prompt 19)
- Depends on: T-19.3
- Goal: the bottom sheet for choosing a duration and starting.
- Files: `lib/ui/session_setup_sheet.dart`, `test/ui/session_setup_sheet_test.dart`.
- Do:
  1. `SessionSetupSheet` (ConsumerStatefulWidget). A wheel (`ListWheelScrollView` with a `FixedExtentScrollController`) over `durationOptions(town)`; disabled items are greyed. Initial item from `defaultMinutes(options, lastDurationMinutes)` (default 25).
  2. Below the wheel: tier name, the tier preview image, `Risks N workers` (hidden in recovery mode), and for tiers that add workers `+N workers if you finish`.
  3. If the selected option is disabled, show its `reason` and disable Start.
  4. In recovery mode show a banner: `The Last Builder. All your builders are gone. A wanderer will build small huts (10 to 20 minutes) and cannot be lost. Finish huts until you have 3 builders.`
  5. Start button: `await controller.start(minutes)`, `await repo.saveLastDuration(minutes)`, then close the sheet. Start errors show a `SnackBar` (see T-22.1 for the retry message; for now show the exception text).
- Tests first (widget, in-memory DB): default selected duration is 25 and the tier line says `house`; jumping the wheel to 10 updates tier to `hut` and shows `+1 worker if you finish` (house shows `+2 workers if you finish`); selecting 95 with 3 workers shows `Needs 8 workers, you have 3` and Start is disabled; recovery town shows the banner and only huts enable Start; Start calls the controller with the chosen minutes, saves the last duration, and closes the sheet; preview image widget is present for the selected tier.
- Done when: flutter analyze clean; flutter test green.
- Commit: `T-19.4: session setup sheet`

### T-19.5 [x] "Start focus" button on HomeScreen
- Step: 19 (docs/prompt_plan.md, Prompt 19)
- Depends on: T-19.4
- Goal: wire the sheet into the home screen. Ends step 19.
- Files: `lib/ui/home_screen.dart`, `test/ui/home_screen_test.dart`.
- Do: when there is no active session show a large `Start focus` button at the bottom of `HomeScreen` that opens `SessionSetupSheet` with `showModalBottomSheet` (scroll-controlled, safe area). Hide the button while a session is active.
- Tests first (widget): button visible with no session; tapping opens the sheet; completing the Start flow hides the button and shows the active session (town camera focuses via T-16.3); button reappears after the session ends.
- Done when: flutter analyze clean; flutter test green; a session starts from the home screen without the debug screen.
- Commit: `T-19.5: start focus button`

### T-20.1 [x] HUD
- Step: 20 (docs/prompt_plan.md, Prompt 20)
- Depends on: T-19.5
- Goal: always-visible streak, level, workers, plots, and queue badge.
- Files: `lib/ui/hud.dart`, `test/ui/hud_test.dart`.
- Do: `Hud` (ConsumerWidget) reads `focusControllerProvider` and `clockProvider`. Shows: streak flame icon + `Progression.currentStreak(town, LocalDate.fromDateTime(now))` (top corner); town level name (`camp`, `village`, ... capitalized) with a progress bar (`Progression.progressToNext(xp)`); workers count; plots `used/unlocked` (placed buildings / `plotsUnlocked`); a queue badge with the count only when `queue.isNotEmpty`. Plain text, no emoji. Level badge is a `GestureDetector` hook for T-22.7.
- Tests first (widget): initial town shows streak 0, `Camp`, workers 3, plots `1/6`, no queue badge; a stored streak of 4 within a day shows 4; stale streak (2 days later) shows 0; xp 450 shows `Village` and a bar at (450-300)/1200; queued building shows badge `1`.
- Done when: flutter analyze clean; flutter test green (HUD wired in T-20.5).
- Commit: `T-20.1: hud`

### T-20.2 [x] Active session panel and abandon confirmation
- Step: 20 (docs/prompt_plan.md, Prompt 20)
- Depends on: T-20.1
- Goal: the in-session view: countdown, tier, progress, hint, abandon.
- Files: `lib/data/town_repository.dart`, `lib/ui/session_panel.dart`, `test/data/town_repository_test.dart`, `test/ui/session_panel_test.dart`.
- Do:
  1. Repository: `Future<int> sessionCount()` (all rows in `Sessions`, including the active one); provider `sessionCountProvider`.
  2. `SessionPanel` shown only when `active != null`: large countdown `mm:ss` (or `h:mm:ss`) of `planned - elapsedBetween(startedAt, now)` clamped at zero, refreshed every second from `clockProvider`; tier name; a `LinearProgressIndicator` from `SessionEngine.progress`; for the first 3 sessions (`sessionCount <= 3`) the hint `Lock your phone and put it face down.`; an `Abandon` button.
  3. Abandon opens a confirmation dialog: title `Abandon this build?`, body `Your N builders will stop and the site becomes a ruin.` (`N` = `workersAssigned`; singular `Your builder will stop...` for 1; for 0 `The site becomes a ruin.`), buttons `Keep focusing` and `Abandon`. `Abandon` calls `controller.abandon()`.
- Tests first: `sessionCount` counts rows; countdown for a 25 minute session after 5 minutes shows `20:00`; at the end shows `00:00`; hint visible for session count 1–3 and hidden for 4; dialog text for 2, 1, and 0 workers; cancel keeps the session; confirm abandons (state failed, `lastResult.failed`).
- Done when: flutter analyze clean; flutter test green (panel wired in T-20.5).
- Commit: `T-20.2: session panel`

### T-20.3 [x] SessionResult extensions
- Step: 20 (docs/prompt_plan.md, Prompt 20)
- Depends on: T-20.2
- Goal: carry everything the result dialogs need from the controller.
- Files: `lib/app/focus_state.dart`, `lib/app/focus_controller.dart`, `test/app/focus_controller_test.dart`.
- Do: add to `SessionResult`: `int xpGained` (completed: planned minutes, else 0), `int awaySeconds` (`session.awayTotal.inSeconds`), `OutcomeReason reason`, `TownLevel? leveledUpTo` (new level when `levelFor(xp)` changed), `bool recoveryStarted` (`!before.inRecoveryMode && after.inRecoveryMode`), `bool recoveryEnded` (`before.inRecoveryMode && !after.inRecoveryMode`). Fill them in `_finish`.
- Tests first: completed 25-minute session → `xpGained` 25; crossing 300 XP sets `leveledUpTo == village`; failure leaving 0 workers → `recoveryStarted`; third recovery hut → `recoveryEnded`; abandon → `reason == abandoned`; away failure → `reason == leftTooLong` and `awaySeconds` about 90; earlier assertions in controller tests stay green.
- Done when: flutter analyze clean; flutter test green.
- Commit: `T-20.3: richer session result`

### T-20.4 [x] Result dialogs
- Step: 20 (docs/prompt_plan.md, Prompt 20)
- Depends on: T-20.3
- Goal: clear feedback for every outcome, in plain active-voice copy with no emoji.
- Files: `lib/ui/result_dialogs.dart`, `test/ui/result_dialogs_test.dart`.
- Do: `Future<void> showResultDialog(BuildContext, SessionResult)` with these variants (copy may be refined but keep it plain and short):
  - completed: title `<Tier> built`; lines for workers gained (`+N workers`, only if > 0), `+N XP`, `Streak: N days`, `New plot unlocked` if `plotGranted`, a banner `Your town is now a <Level>` if `leveledUpTo != null`, and `Your town is back on its feet.` if `recoveryEnded`.
  - queued: title `Ready to place`; body `Your <tier> is finished, but every plot is taken. It will be placed when the next plot unlocks.`
  - failed: title `Your builders stopped` (abandon: `You abandoned the build`); lines `Lost N workers` (if > 0) and, when `reason == leftTooLong`, `You were away for Xm Ys`; if `recoveryStarted`: heading `The Last Builder` and `All your builders are gone. A wanderer arrives who cannot be lost. Build huts (10 to 20 minutes) until you have 3 builders.`
  - A single `Continue` button. Dismissing (button or barrier) returns; the caller clears the result.
- Tests first (widget): each variant renders its title and expected lines (completed with plot + level-up; completed with recoveryEnded; queued; failed with away time; failed abandoned; failed with recoveryStarted); no emoji characters in any string (regex check over rendered text); zero-valued lines are hidden.
- Done when: flutter analyze clean; flutter test green (dialogs wired in T-20.5).
- Commit: `T-20.4: result dialogs`

### T-20.5 [x] Wire HUD, panel, dialogs; trim DebugScreen
- Step: 20 (docs/prompt_plan.md, Prompt 20)
- Depends on: T-20.4
- Goal: the whole session loop works from the home screen. Ends step 20.
- Files: `lib/ui/home_screen.dart`, `lib/ui/focus_debug_panel.dart`, `lib/ui/debug_screen.dart`, `test/ui/home_screen_test.dart`, `test/ui/focus_debug_panel_test.dart`.
- Do:
  1. `HomeScreen` overlays `Hud` (top), `SessionPanel` (when active), and the Start button (when idle). `ref.listen` on `lastResult`: when non-null show `showResultDialog` and then call `clearResult()` (guard against showing twice).
  2. `FocusDebugPanel`: remove the Start button, duration slider usage, Abandon, and its own result dialog (now redundant). Keep `Leave`, `Return`, `Lock` simulators, state readout, and the stored town card. Update its tests accordingly (port nothing that is now covered by the new tests).
- Tests first (widget): full loop on `HomeScreen` with fake clock and in-memory DB: Start from the sheet → panel visible → advance clock → tick → completed dialog → dismiss clears `lastResult` → Start button back; failed loop via `controller.onBackgroundedUnlocked` + 90 s + `onForegrounded` → failed dialog; HUD updates after completion.
- Done when: flutter analyze clean; flutter test green; the full session loop works on the simulator with no debug screen.
- Commit: `T-20.5: home screen session loop`

### T-21.1 [x] Schema v4: tip flags and onboarding access
- Step: 21 (docs/prompt_plan.md, Prompt 21)
- Depends on: T-20.5
- Goal: store onboarding and one-time tip flags, with a tested v3 → v4 migration.
- Files: `lib/data/database.dart` (+ generated), `lib/data/town_repository.dart`, `drift_schemas/drift_schema_v3.json`, `test/generated_migrations/`, `test/data/migration_test.dart`, `test/data/town_repository_test.dart`.
- Do:
  1. Add bool columns to `Towns`, default false: `tipPassShown`, `tipGrowthShown`, `tipRecoveryShown`, `notificationNoteShown`. `schemaVersion = 4`; `onUpgrade`: `if (from < 4)` add the four columns (keep the earlier steps).
  2. `enum Tip { pass, growth, recovery, notificationNote }`. Repository: `Future<bool> isOnboardingDone()`, `Future<void> setOnboardingDone()`, `Future<Set<Tip>> shownTips()`, `Future<void> markTipShown(Tip)`. `saveSessionResolved` must not reset any of them.
  3. Dump schema v4 and regenerate migration helpers.
- Tests first: migration v3 → v4 and v1 → v4 keep data and default all flags false; `setOnboardingDone` persists; `markTipShown` per tip persists and is independent; resolved saves keep flags.
- Done when: flutter analyze clean; flutter test green.
- Commit: `T-21.1: schema v4 tips and onboarding`

### T-21.2 [x] Onboarding screen: pages and indicator
- Step: 21 (docs/prompt_plan.md, Prompt 21)
- Depends on: T-21.1
- Goal: three onboarding pages with a page indicator and navigation.
- Files: `lib/ui/onboarding/onboarding_screen.dart`, `lib/ui/onboarding/page_indicator.dart`, `test/ui/onboarding_screen_test.dart`.
- Do: `OnboardingScreen` with a `PageView` of 3 pages, a 3-dot indicator, and a `Next` button (last page shows `Start` instead). Titles (exact): `Your town grows while you focus.`, `Leave the app, and your builders stop.`, `Start your first build.` Page 3 also shows `10-minute hut` as the preselected build. Each page has an area (a `SizedBox` of fixed aspect ratio) reserved for the live render added in T-21.3. Swiping and tapping Next both move pages. Callback `onStart` is a constructor parameter (wired in T-21.4).
- Tests first (widget): titles appear in order; indicator highlights the current page; Next advances; swipe advances and goes back; last page shows `Start` and calls `onStart`; the `10-minute hut` text is on page 3.
- Done when: flutter analyze clean; flutter test green (screen routed in T-21.6).
- Commit: `T-21.2: onboarding pages`

### T-21.3 [x] Looping town demos for onboarding
- Step: 21 (docs/prompt_plan.md, Prompt 21)
- Depends on: T-21.2
- Goal: each page shows a small looping render from the real `TownGame`, not a static image.
- Files: `lib/game/demo/demo_script.dart`, `lib/ui/onboarding/town_demo.dart`, `lib/ui/onboarding/onboarding_screen.dart`, `test/game/demo_script_test.dart`, `test/ui/town_demo_test.dart`.
- Do:
  1. `DemoScript` (pure): `DemoFrame at(DemoKind kind, double seconds)` returning the town state, optional `ActiveSite`, site worker poses, and effect phase. Loop length 6 s. `DemoKind.build`: initial town plus a house site whose stage rises 1 → 7 over the loop with 3 hammering workers. `DemoKind.ruin`: a house at stage 5 for 3 s, then the failure transition (dead workers, ruin, smoke) for 3 s. `DemoKind.start`: initial town with a hut site at stage 1 and one hammering worker, camera focused on the site.
  2. `TownDemo` widget: a `GameWidget` with a lightweight `TownGame` fed by the script (no controller, no database), camera `fitToRegion` of the first plots; pauses when the page is not visible; honors reduced motion (static final frame).
  3. Use `TownDemo` on the three pages.
- Tests first: script is deterministic and loops (`at(k, 0) == at(k, 6)`); build demo stage is non-decreasing and reaches 7; ruin demo switches to the failure phase at 3 s; widget test: each page builds a `TownDemo`; reduced motion shows a static frame.
- Done when: flutter analyze clean; flutter test green.
- Commit: `T-21.3: onboarding town demos`

### T-21.4 [x] Permissions on page 3 and the Start action
- **Deferred (Android, 2026-11-10):** only the iOS part was built. Still open for when Android work resumes (T-11.x): `lib/platform/phone_permission.dart`, the Kotlin `requestPhonePermission` channel method, the explanation line `Android only: allow phone state so phone calls never count against you.` shown before the prompt, a test that the Android path calls it and other platforms do not, and the `flutter build apk --debug` gate.
- Step: 21 (docs/prompt_plan.md, Prompt 21)
- Depends on: T-21.3
- Goal: ask for notification permission (and Android call permission) with an explanation, then start the first 10-minute hut.
- Files: `lib/ui/onboarding/onboarding_screen.dart`, `lib/app/onboarding_controller.dart`, `android/.../FocusLifecyclePlugin.kt`, `lib/platform/phone_permission.dart`, `test/app/onboarding_controller_test.dart`.
- Do:
  1. Page 3 text: `So we can warn you before your builders stop.` shown above the Start button.
  2. `OnboardingController.finish()`: request notification permission via `notifierProvider.requestPermission()` exactly once; on Android also request `READ_PHONE_STATE` through a new MethodChannel method `requestPhonePermission` (Kotlin: `ActivityCompat.requestPermissions`, result via `onRequestPermissionsResult`; on grant call `startCallDetection`) with its own explanation line shown first (`Android only: allow phone state so phone calls never count against you.`). Denial of either does not block the flow. Then `repo.setOnboardingDone()` and `focusController.start(10)` and report completion for navigation.
  3. `phone_permission.dart`: Dart wrapper with `Future<bool> requestPhonePermission()`; returns false on non-Android or errors.
- Tests first (fake notifier, mock channel): `finish` requests notification permission once even if called twice; denied permission still starts the session; onboarding flag set; a 10-minute hut session is active (workers at risk 1); Android path calls the phone permission method, other platforms do not; permission channel failure does not throw.
- Done when: flutter analyze clean; flutter test green; `flutter build apk --debug` compiles.
- Commit: `T-21.4: onboarding permissions and start`

### T-21.5 [x] In-context tips and denied-notification note
- Step: 21 (docs/prompt_plan.md, Prompt 21)
- Depends on: T-21.4
- Goal: explain rules at the right moment, once each.
- Files: `lib/app/tips.dart`, `lib/ui/home_screen.dart`, `lib/ui/result_dialogs.dart`, `test/app/tips_test.dart`, `test/ui/home_screen_test.dart`.
- Do:
  1. `tipsProvider` (AsyncNotifier) loads `shownTips()` and exposes `Future<bool> shouldShow(Tip)` / `markShown(Tip)`.
  2. Pass tip: in `HomeScreen`'s `ref.listen`, when `active.passUsed` changes false → true, show once a dialog `Emergency pass used. You were away more than 10 seconds, so we spent your free pass. You get one per session.`
  3. Growth tip: after the first completed hut or house (`workersGained > 0` and not shown), append `Huts and houses add builders to your town.` to the completed dialog.
  4. Recovery tip: the Last Builder explanation in the failed dialog is shown in full only the first time (`tipRecoveryShown`); later recoveries show `Recovery mode again. Build huts to get back to 3 builders.`
  5. Denied note: on the first `HomeScreen` build after onboarding, if `notifier.hasPermission()` is false and `notificationNoteShown` is false, show a one-time banner `Warnings are off. We can't tell you before your builders stop. Turn on notifications in Settings.` with a dismiss button that marks it shown.
- Tests first: each tip appears once and never again (second trigger does nothing; flags persist across a new container); pass tip fires on the pass transition only; growth line only on the first hut/house; recovery full text then short text; denied note shows with no permission, not with permission, and not after dismissal.
- Done when: flutter analyze clean; flutter test green.
- Commit: `T-21.5: tips and notification note`

### T-21.6 [x] Route app start by onboarding state
- Step: 21 (docs/prompt_plan.md, Prompt 21)
- Depends on: T-21.5
- Goal: wire onboarding into app start. Ends step 21 code.
- Files: `lib/app/app.dart`, `lib/app/providers.dart`, `test/app/app_routing_test.dart`.
- Do: `onboardingDoneProvider` (FutureProvider from the repository). `FocusTownApp.home`: while loading show a plain sky-colored splash; if not done show `OnboardingScreen`; otherwise `HomeScreen`. After `OnboardingController.finish()` navigate to `HomeScreen` (invalidate the provider). Keep the router and flush timer.
- Tests first: fresh database shows onboarding; `setOnboardingDone` then restart shows `HomeScreen`; finishing onboarding lands on `HomeScreen` with an active 10-minute session and no second onboarding on rebuild; app start with an existing active session and `onboardingDone` shows `HomeScreen` and resolves the session.
- Done when: flutter analyze clean; flutter test green.
- Commit: `T-21.6: onboarding routing`

### T-21.7 [x] [device] Fresh install to first session under 30 seconds
- **Deferred (Android, 2026-11-10):** checklist item 6 (phone-state explanation and system prompt; denying still continues) was not run. Run it with the Android tasks.
- Step: 21 (docs/prompt_plan.md, Prompt 21)
- Depends on: T-21.6
- Goal: verify the first-run flow on the iPhone (and Android).
- Files: `docs/device_tests.md`.
- Do: give the user these steps and record under `## Step 21: onboarding`:
  1. Delete the app, install fresh. Time from launch to a running session with the stopwatch: under 30 seconds.
  2. The three pages loop live town animations; notification prompt appears on the last page with the one-line reason; allow it.
  3. First session is a 10-minute hut; the hint `Lock your phone...` shows.
  4. Switch apps and return after 30 s: the pass tip appears once. Repeat: no tip.
  5. Deny notifications on a second fresh install: the one-time note shows on the home screen.
  6. Android: the phone-state explanation and system prompt appear; denying still continues.
- Tests first: none (manual).
- Done when: results recorded; flutter analyze clean; flutter test green.
- Commit: `T-21.7: record step 21 device check`

### T-22.1 [x] Database write retry and save-failed message
- Step: 22 (docs/prompt_plan.md, Prompt 22)
- Depends on: T-21.7
- Goal: retry a failed write once; never start a session that was not saved; show the right message.
- Files: `lib/data/town_repository.dart`, `lib/app/focus_controller.dart`, `lib/ui/session_setup_sheet.dart`, `test/data/retry_test.dart`, `test/app/focus_controller_test.dart`.
- Do:
  1. Repository write methods (`saveSessionStarted`, `saveSessionUpdated`, `saveSessionResolved`, tip/onboarding/duration writes) go through a private `_write(Future<void> Function())` that runs the operation, and on any exception retries exactly once, then throws `SaveFailedException` (message `Couldn't save your session. Try again.`).
  2. `FocusController.start` lets `SaveFailedException` propagate with the state unchanged (already persisted-first from T-08.2). In `_finish` and lifecycle forwards: if saving throws, keep the previous state unchanged (last good state) and rethrow nothing to the UI; the next `tick()` or event retries because the stored session is still active.
  3. `SessionSetupSheet` shows the exception message in a `SnackBar` and keeps the sheet open.
- Tests first (mocktail repository or a database wrapper that fails N times): one failure then success → saved, no error; two failures → `SaveFailedException`; `start` with failing repo leaves `active == null` and the session is not active in the DB; `_finish` failure keeps state `active` and a later `tick()` succeeds once the repo recovers; sheet shows `Couldn't save your session. Try again.`
- Done when: flutter analyze clean; flutter test green.
- Commit: `T-22.1: write retry and save error`

### T-22.2 [ ] Pre-migration backup, restore, fresh-town fallback
- Step: 22 (docs/prompt_plan.md, Prompt 22)
- Depends on: T-22.1
- Goal: never lose the town to a failed migration or corrupt file.
- Files: `pubspec.yaml`, `lib/data/db_recovery.dart`, `lib/app/providers.dart`, `lib/main.dart`, `test/data/db_recovery_test.dart`.
- Do:
  1. `drift_flutter` needs a real file path to copy the database. Ask the user before adding `path_provider` as a direct dependency (explain: needed to locate the database file; `drift_flutter` already depends on it). If the user declines, mark `[!]`.
  2. `Future<OpenResult> openDatabaseSafely({required Directory dir, required int schemaVersion, required AppDatabase Function(File) open})` in `db_recovery.dart` (file logic injected so it is testable with a temp directory):
     - Sidecar file `schema_version.txt` stores the last successfully opened schema version.
     - Before opening, if the database file exists and the sidecar is missing or lower than `schemaVersion`, copy the file to `focus_town.backup.sqlite`.
     - Open and run a trivial query (e.g. `SELECT 1` plus `loadOrCreate`). On success write the sidecar.
     - On any exception: close, restore the backup over the database file if it exists, and try once more; if that fails or no backup exists, delete the database file and open a fresh one. Return `OpenResult { AppDatabase db; bool startedFresh; }`.
  3. `main()` uses it; `startedFresh == true` sets a provider `startupMessageProvider` and `HomeScreen` shows once a `SnackBar`/dialog `We couldn't load your town and started a new one.` Log each step to the local log once T-22.3 exists (until then `debugPrint`).
- Tests first (temp directory, fake `open` function that throws on demand): first launch (no file) opens fine and writes the sidecar; version bump copies the backup; migration failure restores the backup and succeeds; failure with no backup creates a fresh database and reports `startedFresh`; a corrupt (random bytes) file with no backup starts fresh; the backup is not overwritten when the sidecar already equals the current version.
- Done when: flutter analyze clean; flutter test green.
- Commit: `T-22.2: database backup and recovery`

### T-22.3 [ ] LocalLog ring buffer
- Step: 22 (docs/prompt_plan.md, Prompt 22)
- Depends on: T-22.2
- Goal: a small persistent log (last 200 lines) that all caught errors use.
- Files: `lib/platform/local_log.dart`, `lib/app/providers.dart`, `lib/app/focus_controller.dart`, `lib/platform/native_lifecycle_source.dart`, `lib/data/db_recovery.dart`, `test/platform/local_log_test.dart`.
- Do:
  1. `LocalLog(File file, Clock clock)`: `void write(String message)` adds `ISO-wall-time message`; keeps the last 200 lines (the oldest is dropped); persists the whole buffer to the file after each write (small, so no batching); `Future<void> load()` reads it back; `List<String> get lines`. File errors are swallowed (logging must never throw).
  2. `localLogProvider`; created in `main()` with a file in the app support directory.
  3. Replace the `debugPrint` placeholders added earlier (controller `_safeNotify`, native source `onMalformed`, db recovery, tamper detection: when `wallClockTampered` is true at a session resolve, write `clock tamper detected`) with `localLog.write`.
- Tests first: 201 writes keep 200 lines and drop the first; persistence round trip through a temp file; a read-only/missing directory does not throw; malformed native event writes one line; notifier exception writes one line and does not break the session; tamper detection writes a line when wall time is shifted 2 hours.
- Done when: flutter analyze clean; flutter test green.
- Commit: `T-22.3: local log`

### T-22.4 [ ] Resilient lifecycle source (silent native bridge fallback)
- Step: 22 (docs/prompt_plan.md, Prompt 22)
- Depends on: T-22.3
- Goal: if the native bridge is silent when Flutter says the app went to the background, fall back to the lenient Flutter-only source.
- Files: `lib/platform/resilient_lifecycle_source.dart`, `lib/platform/platform_bootstrap.dart`, `test/platform/resilient_lifecycle_source_test.dart`.
- Do:
  1. `ResilientLifecycleSource(LifecycleSource native, LifecycleSource fallback, Clock clock, LocalLog log)` implements `LifecycleSource`. It forwards the native events. It also listens to the fallback source: a fallback `LockedEvent` (Flutter `paused`) starts a 2-second deadline. If any native event with a timestamp within 2 s of it has not arrived by the deadline (checked on the next event and by `void check()`, which the app's 100 ms timer calls), the bridge is declared silent: log it, drop the native subscription, forward fallback events only from then on, and report `isNative == false`.
  2. When the native bridge is healthy, fallback events are not forwarded (no duplicates).
  3. `bootstrapPlatform` returns a `ResilientLifecycleSource` when the native channel responds; keeps the plain fallback otherwise. The router timer also calls `check()`.
- Tests first (`FakeLifecycleSource` x2, `FakeClock`): healthy native (events arrive) forwards only native events; silent native after a fallback `locked` and 2 s switches to fallback, logs once, and `isNative` flips to false; a late native event within 2 s keeps the native source; after the switch fallback `unlocked`/`foregrounded` are forwarded; no switch when the fallback never reports a background.
- Done when: flutter analyze clean; flutter test green.
- Commit: `T-22.4: resilient lifecycle source`

### T-22.5 [ ] Render guard: static fallback on errors or low fps
- Step: 22 (docs/prompt_plan.md, Prompt 22)
- Depends on: T-22.4
- Goal: if rendering throws or stays below 5 fps, show the last cached town as a static picture; the timer keeps running.
- Files: `lib/game/render_guard.dart`, `lib/game/town_game.dart`, `test/game/render_guard_test.dart`.
- Do:
  1. `RenderGuard`: `bool degraded`; `void recordFps(double fps, Duration at)` sets `degraded = true` after fps stays below 5 for 5 consecutive seconds; `void recordError(Object)` sets `degraded = true` immediately and logs; `void reset()` is not exposed (stays degraded until restart).
  2. `TownGame.render` runs the normal paint inside try/catch; once degraded it only draws the last recorded frame `Picture` (sky + static layer), stops the worker simulation and effects, and keeps `pauseEngine`-free so the session timer (which lives in the controller/HUD) is unaffected.
  3. Entering degraded writes `render degraded: <reason>` to the local log.
- Tests first: 4 s at 3 fps then 5 s at 3 fps → degraded on the fifth consecutive second; a recovery above 5 fps within the window resets the counter; an exception in paint sets `degraded` and the game still draws without throwing; degraded game does not advance workers; the controller session keeps ticking (HUD countdown) while degraded.
- Done when: flutter analyze clean; flutter test green.
- Commit: `T-22.5: render guard`

### T-22.6 [ ] Beta stats queries
- Step: 22 (docs/prompt_plan.md, Prompt 22)
- Depends on: T-22.5
- Goal: on-device beta numbers with no analytics SDK.
- Files: `lib/data/town_repository.dart`, `lib/app/providers.dart`, `test/data/beta_stats_test.dart`.
- Do: `Future<BetaStats> betaStats()` and `betaStatsProvider`. `BetaStats { int sessionsStarted; int completed; int failed; double completionRate; int daysActive; DateTime firstOpen; bool returnedAfterDay7; }`. `sessionsStarted` = all session rows; `completed`/`failed` by state; `completionRate = completed / (completed + failed)` (0 when none finished); `daysActive` = distinct local calendar dates of `startedAtWall`; `firstOpen` = `towns.createdAt`; `returnedAfterDay7` = true if some session started at least 7 calendar days after the first-open date (day-7 retention marker).
- Tests first: empty database → zeros and `firstOpen` set; 3 completed + 1 failed → rate 0.75; sessions on 3 distinct days → `daysActive` 3; session 7 days after first open → `returnedAfterDay7` true, 6 days → false; running sessions count as started but not finished.
- Done when: flutter analyze clean; flutter test green (shown in T-22.7).
- Commit: `T-22.6: beta stats`

### T-22.7 [ ] Debug screen: log viewer, beta stats, hidden release access
- Step: 22 (docs/prompt_plan.md, Prompt 22)
- Depends on: T-22.6
- Goal: let testers read and export the log and stats; hide the screen from normal users.
- Files: `lib/ui/debug_screen.dart`, `lib/ui/debug_log_view.dart`, `lib/ui/hud.dart`, `lib/ui/home_screen.dart`, `test/ui/debug_screen_test.dart`, `test/ui/hud_test.dart`.
- Do:
  1. Add a "Log" section listing `localLog.lines` (newest first) with a `Copy log` button that puts all lines on the clipboard (`Clipboard.setData`). No share package (would need the user's approval first; clipboard is enough for testers).
  2. Add a "Beta stats" card from `betaStatsProvider`: sessions started, completed, failed, completion rate as a percent, days active, first-open date, `Returned after day 7: yes/no`.
  3. Access: debug builds keep the top-left long press (T-15.4). Release builds: 7 taps within 5 seconds on the level badge in the HUD (T-20.1) open the debug screen. Count taps with the `Clock`.
- Tests first (widget): log lines render and `Copy log` writes the joined text to the clipboard (mock `SystemChannels.platform`); stats card shows the values from a seeded database; 7 quick taps on the level badge open the debug screen, 6 do not, 7 taps spread over 6+ seconds do not; the secret gesture works even when `kDebugMode` is false (inject a `bool allowDebugAccess` for tests).
- Done when: flutter analyze clean; flutter test green.
- Commit: `T-22.7: debug log viewer and stats`

### T-22.8 [ ] Accessibility: semantics labels
- Step: 22 (docs/prompt_plan.md, Prompt 22)
- Depends on: T-22.7
- Goal: VoiceOver/TalkBack labels on every control and HUD value (NFR-8).
- Files: `lib/ui/hud.dart`, `lib/ui/home_screen.dart`, `lib/ui/session_panel.dart`, `lib/ui/session_setup_sheet.dart`, `lib/ui/onboarding/*`, `lib/ui/result_dialogs.dart`, `test/ui/semantics_test.dart`.
- Do: add `Semantics`/`semanticsLabel` so that: streak reads `Streak, N days` (`Streak, 1 day` for one); level reads `Town level, <Level>, <P> percent to next level`; workers `Workers, N`; plots `Plots, X of Y used`; queue badge `N buildings waiting for a plot`; Start button `Start focus`; recenter `Recenter town`; countdown `Time left, M minutes S seconds`; progress bar `Build progress, P percent`; Abandon `Abandon build`; wheel items `<minutes> minutes, <tier>, <enabled/disabled reason>`; onboarding Next/Start and page indicator `Page X of 3`. Decorative things (particles, hint icons) are excluded from semantics.
- Tests first: using `tester.getSemantics` / `find.bySemanticsLabel`, assert each label above for a seeded state (streak 4 → `Streak, 4 days`; one day → `Streak, 1 day`); every `IconButton`/`ElevatedButton` in the home screen has a non-empty label (iterate and check); no unlabeled tappable nodes on the setup sheet.
- Done when: flutter analyze clean; flutter test green.
- Commit: `T-22.8: semantics labels`

### T-22.9 [ ] Town summary, Dynamic Type, reduced-motion audit
- Step: 22 (docs/prompt_plan.md, Prompt 22)
- Depends on: T-22.8
- Goal: a screen-reader summary of the town, layouts that survive large text, and reduced motion respected everywhere.
- Files: `lib/ui/home_screen.dart`, `lib/game/camera/camera_transition.dart`, `lib/ui/onboarding/onboarding_screen.dart`, `test/ui/accessibility_test.dart`.
- Do:
  1. Wrap the `GameWidget` in `Semantics(label: townSummary(town))` where `townSummary` returns e.g. `Your town has 6 buildings and 7 workers.` (count of `complete` buildings; append ` and 1 ruin` / `, and 2 ruins` when ruins exist; singular forms for 1 building / 1 worker).
  2. Dynamic Type: the setup sheet, dialogs, HUD, session panel, and onboarding must not overflow with `textScaler: TextScaler.linear(2.0)` on a 390x844 screen (use `Flexible`/scroll views; the HUD may wrap onto two lines).
  3. Reduced motion audit: with `MediaQuery.disableAnimations` true: camera transitions jump instantly, onboarding page changes use no animation, worker walking/hammering and particles are off, the town demos show a static frame.
- Tests first: summary text for initial town (`1 building and 3 workers`), for 6 buildings 7 workers, and with ruins; at text scale 2.0 no overflow exceptions (`tester.takeException()` is null) for HUD, sheet, each dialog variant, onboarding page 3; reduced-motion camera transition completes in a single step and workers are idle.
- Done when: flutter analyze clean; flutter test green.
- Commit: `T-22.9: town summary, dynamic type, reduced motion`

### T-22.10 [ ] Release assets: icon, splash, ids, version, privacy manifest
- Step: 22 (docs/prompt_plan.md, Prompt 22)
- Depends on: T-22.9
- Goal: everything the stores need except signing.
- Files: `tool/generate_icon_test.dart`, `ios/Runner/Assets.xcassets/AppIcon.appiconset/*`, `android/app/src/main/res/mipmap-*/*`, `ios/Runner/PrivacyInfo.xcprivacy`, launch screens, `pubspec.yaml`, `docs/release.md`.
- Do:
  1. Ask the user for the final bundle id / application id and app display name; until answered keep `com.example.focus_town`. Apply it in `ios/Runner.xcodeproj` and `android/app/build.gradle*`/`AndroidManifest.xml`.
     - Signing cleanup: `ios/Runner.xcodeproj/project.pbxproj` currently holds the user's personal test values, committed in `06b2050` (bundle id `com.shashank.focusTown`, `DEVELOPMENT_TEAM = 5RLKRL9U6T`, from running on a real iPhone). They are not secrets (the team id is printed in every signed app; no keys, certificates or passwords are in the repo). Replace them with the final bundle id and the team the release will use, then grep the repo for `com.shashank`, `com.example` and `5RLKRL9U6T` and confirm nothing personal is left. Also update the bundle id in `CLAUDE.md` (the simulator `simctl` commands) and `docs/device_tests.md`.
  2. App icon (a small block house, original art): generate PNGs by drawing a `VoxelWorld` house with the existing painter inside a Flutter test (`flutter test tool/generate_icon_test.dart` writes files; no new package). Produce a 1024x1024 iOS icon (no transparency, no rounded corners) and Android sizes 48, 72, 96, 144, 192 plus an adaptive icon foreground (432x432, content inside the central 66%) and a background color (sky blue `#8cc9ea`). Review the images.
  3. Splash/launch screens: iOS `LaunchScreen.storyboard` with the sky color and the icon; Android launch theme with `windowSplashScreenBackground` = sky color and the icon. Do not add a splash package.
  4. Versioning: `version: 1.0.0+1` in `pubspec.yaml`.
  5. `ios/Runner/PrivacyInfo.xcprivacy`: `NSPrivacyTracking` false, empty `NSPrivacyTrackingDomains`, empty `NSPrivacyCollectedDataTypes`, and `NSPrivacyAccessedAPITypes` for the required-reason APIs actually used: system boot time `35F9.1` (the monotonic uptime clock), file timestamp `C617.1` (SQLite files), user defaults `CA92.1` (if any plugin uses it). Run `flutter build ios --no-codesign` and inspect the built app's aggregated privacy report in Xcode (Product > Archive > Generate Privacy Report) later in T-22.15; list any extra reasons it reports.
  6. `docs/release.md`: store data-safety answers (Play Console: no data collected, no data shared, no encryption in transit needed since there is no network; App Store privacy label: Data Not Collected), permissions used (notifications; Android `READ_PHONE_STATE` optional for call detection with the reason text), and a note that the app has no network permission.
- Tests first: none can be unit tests; automated gates are `flutter build apk --release` and `flutter build ios --no-codesign --release` succeeding, plus a small test that parses `pubspec.yaml` version `1.0.0+1`.
- Done when: flutter analyze clean; flutter test green; both release builds compile; icon files reviewed.
- Commit: `T-22.10: release assets and privacy manifest`

### T-22.11 [ ] Release signing setup and keystore notes
- Step: 22 (docs/prompt_plan.md, Prompt 22)
- Depends on: T-22.10
- Goal: make signed release builds possible without committing secrets.
- Files: `android/app/build.gradle*`, `.gitignore`, `docs/release.md`.
- Do:
  1. Android: `build.gradle` reads `android/key.properties` (`storePassword`, `keyPassword`, `keyAlias`, `storeFile`) into `signingConfigs.release`; if the file is missing the release build falls back to debug signing with a clear Gradle warning. Add `android/key.properties`, `*.jks`, `*.keystore` to `.gitignore`.
  2. `docs/release.md` section "Signing": the exact `keytool -genkey -v -keystore ~/focus-town-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload` command; a sample `key.properties` (placeholder values only); where to store the keystore and passwords safely (password manager plus an offline encrypted backup in a second place; losing the key means the app can only be updated with Play App Signing recovery); recommend Play App Signing. iOS: select the Team in Xcode (Signing & Capabilities, automatic signing), the App ID with no extra capabilities, and an Apple Developer account ($99/year) requirement.
  3. Do not generate or commit any real keystore or password.
- Tests first: none (config); gate: `git check-ignore android/key.properties` succeeds; `flutter build apk --release` still builds (debug-signed) without `key.properties`.
- Done when: flutter analyze clean; flutter test green; release build works without secrets.
- Commit: `T-22.11: release signing setup`

### T-22.12 [ ] Integration test: full flow
- Step: 22 (docs/prompt_plan.md, Prompt 22)
- Depends on: T-22.11
- Goal: one automated end-to-end test of the whole app with an injected fake clock.
- Files: `pubspec.yaml` (add `integration_test` SDK dev dependency if missing), `integration_test/full_flow_test.dart`.
- Do: build the real `FocusTownApp` in a `ProviderScope` overriding `clockProvider` with a `FakeClock`, `databaseProvider` with an in-memory database, `notifierProvider` with `FakeNotifier`, and `lifecycleSourceProvider` with `FakeLifecycleSource`. Script: onboarding (Next, Next, Start) → a 10-minute hut is running → emit backgrounded, `advance(5 s)`, emit foregrounded → no penalty → `advance(10 min)` and pump → completed dialog, streak 1, workers 4, plots 7 → dismiss → Start a 25-minute house from the sheet → backgrounded, `advance(90 s)`, foregrounded → failed dialog, workers 2, a ruin → dismiss → `advance(24 h)` → Start a 10-minute hut, advance 10 min → completed, streak 2, plots 8.
- Tests first: this file is the test; write it first against the existing app and make it pass (fix real bugs it exposes by adding focused unit tests, not by weakening the script).
- Done when: flutter analyze clean; flutter test green; `flutter test integration_test/full_flow_test.dart -d <iOS simulator>` passes.
- Commit: `T-22.12: integration test full flow`

### T-22.13 [ ] [device] Full manual checklist on the iPhone
- Step: 22 (docs/prompt_plan.md, Prompt 22)
- Depends on: T-22.12
- Goal: run the complete spec checklist on iPhone hardware.
- Files: `docs/device_tests.md`.
- Do: give the user this list, wait for results, record pass/fail with date and build under `## Final checklist: iPhone`:
  1. Start 10-min session, lock phone 5 min, unlock: session continues.
  2. Switch to another app, return in 5 s: no penalty.
  3. Switch away 30 s: pass spent, session continues.
  4. Switch away 90 s: workers die, ruin appears.
  5. Receive and take a phone call mid-session: no penalty, no pass.
  6. Pull down Control Center: no penalty.
  7. Force-quit mid-session, reopen: outcome resolved correctly.
  8. Reboot mid-session: treated as away, resolved on launch.
  9. Change device time forward 2 hours mid-session: session does not complete early.
  10. Deny notifications: one-time note shown, rules still apply.
  11. Complete sessions on 2 different days: streak 2, plots 8.
  12. Fill all plots, complete another session: building queued, placed when next plot unlocks.
  13. Lose all workers: recovery mode starts; 3 huts later it ends.
  14. Low Power Mode on: frame rate drops, no effects.
  15. Acceptance: town persists across restarts; rendering at or below 20 fps and paused when hidden; cold start under 2 s; battery under 5% per hour with the screen on.
- Tests first: none (manual).
- Done when: results recorded; every failure filed as a new task or fixed; flutter analyze clean; flutter test green.
- Commit: `T-22.13: record iphone final checklist`

### T-22.14 [ ] [device] Full manual checklist on an Android phone
- Step: 22 (docs/prompt_plan.md, Prompt 22)
- Depends on: T-22.13
- Goal: the same checklist on a physical Android phone (Samsung or Xiaomi ideally).
- Files: `docs/device_tests.md`.
- Do: give the user the 15-item list from T-22.13 adapted for Android (notification shade instead of Control Center, Battery Saver instead of Low Power Mode, `READ_PHONE_STATE` granted for the call test), plus: the OEM battery manager killing the app mid-session resolves correctly on reopen; split screen and recent apps behavior noted. Record under `## Final checklist: Android` with phone model and Android version.
- Tests first: none (manual).
- Done when: results recorded; failures filed; flutter analyze clean; flutter test green.
- Commit: `T-22.14: record android final checklist`

### T-22.15 [ ] [device] TestFlight upload
- Step: 22 (docs/prompt_plan.md, Prompt 22)
- Depends on: T-22.14
- Goal: ship the iOS beta to testers.
- Files: `docs/release.md`.
- Do: give the user these steps and wait for results; record under `## TestFlight`:
  1. Apple Developer Program membership active; the app record exists in App Store Connect with the final bundle id.
  2. `flutter build ipa --release` (or Xcode Product > Archive), then upload with Xcode Organizer or Transporter.
  3. Generate the privacy report from the archive and compare with `PrivacyInfo.xcprivacy`; fix any missing required-reason entries (new task if code changes).
  4. Fill the privacy answers `Data Not Collected`, add 15–30 internal/external testers in TestFlight, enable the build.
  5. Record the build number, upload date, and tester count. Beta plan: 2 weeks; exit criteria are day-7 retention at least 20%, completion rate at least 70%, zero data-loss bugs (read from the hidden debug screen stats).
- Tests first: none (manual).
- Done when: build visible in TestFlight and testers invited; results recorded; flutter analyze clean; flutter test green. The queue is complete.
- Commit: `T-22.15: record testflight upload`

## Phase V2: forgiveness and return (after the MVP ships)

Decided with the user: the MVP comes first; these two items come right after it and are already v2 in `docs/spec.md` ("cleanup sessions" and "earned passes"). Payments (a small paid pass pack, building styles and landmarks as one-time purchases) are deferred: they need the `in_app_purchase` package, which needs the user's approval, and belong near step 22. When work starts, update `docs/spec.md` (FR-5 says ruins are permanent; the rules for passes) first.

Note: the spec's existing pass is a 60-second grace, one per session. The "emergency pause" below is different: a longer, once-a-week allowance that the user chooses to use.

Open questions (assumed answers):
- Repair session length: 10 minutes for any building. (Assumed.)
- A failed repair costs nothing more: the ruin stays, no workers die, no streak change. (Assumed.)
- Emergency pause: 1 per week, extends the away window to 10 minutes once, chosen by pressing a button before leaving. (Assumed.)

### T-V2.1 [ ] Repair rule (pure)
- Depends on: MVP done (T-22.15), T-18A.4
- Goal: a ruin can be cleared by a short session.
- Files: `lib/domain/town_rules.dart`, `lib/domain/session.dart`, tests.
- Do: session kind `repair` (10 minutes, no tier, no workers at risk); `TownRules.applyRepairCompleted(town, ruin)` removes the ruin and frees its footprint; a failed or abandoned repair changes nothing.
- Tests first: completing clears exactly that ruin; failing leaves the town identical; XP and streak rules for a repair are explicit tests; only an existing ruin can be repaired.
- Commit: `T-V2.1: repair rule`

### T-V2.2 [ ] Start a repair from the ruin
- Depends on: T-V2.1
- Do: controller `startRepair(ruinId)`; the site shows scaffolding on the ruin and clears it at the end; home screen: tap a ruin to see "Repair (10 min)"; same celebration as a completed building.
- Tests first: controller round trip; widget test: tapping a ruin offers repair and starts it; kill and relaunch resumes it.
- Commit: `T-V2.2: repair sessions`

### T-V2.3 [ ] Weekly emergency pause (rule and storage)
- Depends on: T-V2.1
- Do: `TownState.emergencyPauses` (1 per week, refilled on a new week from the injected clock; the next schema version and a migration); session field `emergencyUsed`; away limit becomes 10 minutes once when set.
- Tests first: refill on the first session of a new week (never more than 1 stored); using it moves the away limit to 10 minutes exactly once; none left means the old rules; clock changes never grant extra.
- Commit: `T-V2.3: emergency pause rule`

### T-V2.4 [ ] Emergency pause button and first-time explanation
- Depends on: T-V2.3
- Do: a button on the session screen that arms the pause (disabled when none are left, shows when the next one arrives); the first time the user leaves mid-session explain both the pass and the pause; notifications reflect the longer window.
- Tests first: widget tests for armed, disabled and explanation-once; notification scheduling uses the 10-minute limit.
- Commit: `T-V2.4: emergency pause screen`

### T-V2.5 [ ] [device] Repair and emergency pause on the iPhone
- Depends on: T-V2.4
- Do: give the user steps: fail a session, repair the ruin in 10 minutes; arm the pause, leave for 5 minutes, return without penalty; record in `docs/device_tests.md`.
- Commit: `T-V2.5: record v2 device check`

## Phase V3: building looks and landmarks (after V2)

Decided with the user: more kinds of building, such as apartments and pyramids. The five tiers and their rules stay as they are; each tier gets two or three looks, and big landmarks come last. Looks and landmarks may later be sold as one-time purchases (see the payments note in Phase V2). When work starts, update `docs/spec.md` first (the spec fixes one look per tier).

Open questions (assumed answers):
- Which look a session builds: the user picks it in the setup sheet, with a random default. (Assumed.)
- Looks per tier: hut: cabin, tent, windmill; house: cottage, townhouse; workshop: bakery, smithy; tower: apartments, lighthouse; castle: castle, pyramid. (Assumed.)
- Landmarks (Eiffel Tower, bridge, big pyramid) span 2 x 2 plots and take several sessions. (Assumed; needs multi-plot placement.)

### T-V3.1 [ ] Look rule and storage
- Depends on: MVP done (T-22.15)
- Goal: a building has a look within its tier.
- Files: `lib/domain/building_look.dart`, `lib/domain/session.dart`, `lib/domain/town.dart`, `lib/data/database.dart` (next schema version and a migration), tests.
- Do: `BuildingLook` enum with its tier; session and building store the look; a look must belong to the session's tier; old rows get each tier's first look.
- Tests first: every tier has at least one look; a mismatched look is refused; migration keeps old buildings; the look survives a restart.
- Commit: `T-V3.1: building looks`

### T-V3.2 [ ] Look layouts and previews
- Depends on: T-V3.1
- Do: block layouts and build stages per look in `lib/game/world/building_defs.dart`; the tier preview takes a look; a golden of all looks on one scale.
- Tests first: each look builds inside its plot, finishes at its last stage and differs from the others in its tier; goldens.
- Commit: `T-V3.2: building look layouts`

### T-V3.3 [ ] Pick a look in the setup sheet
- Depends on: T-V3.2
- Do: a small look picker under the dial (random by default); the preview and the town show the chosen look.
- Tests first: widget tests for picking, the default, and a start that stores the look.
- Commit: `T-V3.3: look picker`

### T-V3.4 [ ] Landmarks (multi-plot, multi-session)
- Depends on: T-V3.3, multi-plot placement
- Do: a landmark takes 2 x 2 plots and several sessions, with damage on failure; start with the pyramid; write the rules into `docs/spec.md` first.
- Tests first: footprint and placement rules, progress across sessions, failure damage.
- Commit: `T-V3.4: landmarks`

### T-V3.5 [ ] [device] Looks and landmarks on the iPhone
- Depends on: T-V3.4
- Do: give the user steps to pick looks, finish a few and look at them from the town view; record in `docs/device_tests.md`.
- Commit: `T-V3.5: record v3 device check`

## Phase V4: focus trends (after V3, or earlier if the user asks)

Requested by the user: a screen that shows how their focus time is going and whether it is improving. Everything it needs is already stored (the `sessions` table), so no new data is collected and no package is needed (charts are drawn with a `CustomPainter`).

Open questions (assumed answers):
- Where it lives: tap the HUD (streak and level) to open "Your focus". (Assumed.)
- What counts as focus time: the planned minutes of completed sessions; failed and abandoned sessions count as 0 but show in the completion rate. (Assumed.)
- Shown: minutes per day for the last 7 days and per week for the last 8 weeks, current and longest streak, completion rate, average and longest session, and one plain sentence on the trend ("12% more than last week"). (Assumed.)
- Days and weeks use the local date from the injected clock (Monday starts a week). (Assumed.)

### T-V4.1 [ ] Stats rule (pure)
- Depends on: MVP done (T-22.15)
- Goal: turn stored sessions into the numbers the screen shows.
- Files: `lib/domain/focus_stats.dart`, `test/domain/focus_stats_test.dart`.
- Do: `FocusStats.from(List<Session>, LocalDate today)` giving minutes per day (7), minutes per week (8), completion rate, average and longest completed session, current and longest streak, and the change against the previous week as a ratio or null when there is no earlier data.
- Tests first: empty history; one day; a week boundary on a Monday; failed sessions add 0 minutes and lower the rate; the change is null with no previous week and signed otherwise; a clock set backwards never counts future days.
- Commit: `T-V4.1: focus stats rule`

### T-V4.2 [ ] Read sessions
- Depends on: T-V4.1
- Do: `TownRepository.resolvedSessions({DateTime? since})` and a `focusStatsProvider` that recomputes when a session ends.
- Tests first: only resolved sessions are returned, in time order; the provider updates after a completed and a failed session.
- Commit: `T-V4.2: stats provider`

### T-V4.3 [ ] "Your focus" screen
- Depends on: T-V4.2
- Do: a screen with the two bar charts (painted, no package), the numbers, the trend sentence and an empty state before the first session; opened from the HUD; accessible labels for the bars.
- Tests first: widget tests for the empty state, the numbers for a seeded history, the trend sentence, and opening from the HUD; one golden of the charts.
- Commit: `T-V4.3: focus trends screen`

### T-V4.4 [ ] [device] Trends on the iPhone
- Depends on: T-V4.3
- Do: give the user steps (finish a few sessions, open the screen, check the numbers against what they did); record in `docs/device_tests.md`.
- Commit: `T-V4.4: record trends device check`

## Phase V6: grow your world (after V3)

Idea from the user: the player builds their own world while regaining focus. The island is not finite: the player chooses where it grows (for example to keep open land or a garden around a castle). Later the world can be viewed as a rotatable globe and shown off. Gardens and open space count as things to build, so not every plot has to hold a building.

Decided with the user: one island that grows parcel by parcel; a second island is a later option (about 25 parcels), not part of the first version.

Design (assumed, to confirm before work starts):
- The app stays 2D, as `docs/spec.md` says. Real 3D voxels on a sphere are out of scope.
- Land comes in parcels: a parcel is one plot-sized square (7 x 7 tiles). The island is a set of parcels (a sparse list in the database), with no fixed size. Today's 64 plots are the starting parcels.
- Space and buildings are separate: the daily plot unlock still limits how many buildings the town may have; a land session claims a parcel (space). Gardens, parks, ponds and orchards are buildable things that take a plot and a session, add no workers and leave no ruin.
- The player picks which parcel to claim: in "Extend land" mode the free parcels around the coast are outlined, like the choose-a-plot step. The new parcel starts as forest.
- Land sessions get longer as the island grows: 25 minutes for the first, rising by 5 minutes per 4 parcels claimed, capped at 90.
- The coast is organic (a few lakes and bays), not a square.
- Roads: paths between built parcels and the hub are drawn automatically; the player never places roads.
- Three views: plot view (today's isometric blocks), island view (zoomed out, low detail, outlined claimable parcels, a "World" button) and globe view (a painted low-poly planet; drag to spin with inertia; the island is a picture of the real island placed on the sphere).
- Showcase: the globe auto-spins with no buttons and a save-picture button. Saving or sharing needs a package: ask the user and name it before adding anything.
- Frame rate: a bigger island must stay at 15 fps normal and 10 fps in Low Power Mode. The renderer draws only parcels near the screen. Measure on the iPhone (T-17.7) before growing past today's size.

### T-V6.1 [ ] Spec and parcel model
- Depends on: MVP done (T-22.15), T-V3.1
- Goal: the island is a set of parcels instead of a fixed 64 x 64 map.
- Files: `docs/spec.md` (first), `lib/domain/parcel.dart`, `lib/domain/town.dart`, `lib/domain/town_rules.dart`, `lib/game/world/plot_layout.dart`, `lib/data/database.dart` (next schema version and a migration), tests.
- Do: `Parcel` (grid position) and `TownState.parcels`; every plot is a parcel; the map-size and plot constants come from the parcels; old towns get today's 64 parcels so nothing moves; neighbours of the island are the claimable parcels.
- Tests first: migration keeps every building on the same plot; the 64 starting parcels match today's layout; the claimable set is exactly the free neighbours of the island; plots outside the island are refused.
- Commit: `T-V6.1: parcel model`

### T-V6.2 [ ] Renderer draws only nearby parcels
- Depends on: T-V6.1
- Do: the world builder, forest and cached picture work per parcel and draw only parcels near the view; roads and paths are generated between built parcels and the hub; a coast with a few lakes.
- Tests first: the block count for a 64-parcel island matches today's world; a far parcel adds no blocks while off screen; the world is deterministic for the same parcels.
- Commit: `T-V6.2: parcel renderer`

### T-V6.3 [ ] Gardens and open space as buildable things
- Depends on: T-V3.2
- Do: park, pond, orchard and garden looks: they take a plot and a session, no workers at risk, no ruin on failure (the plot goes back to forest).
- Tests first: a garden session loses no workers and leaves no ruin; layouts fit the plot; goldens.
- Commit: `T-V6.3: gardens`

### T-V6.4 [ ] Land sessions claim parcels
- Depends on: T-V6.2
- Do: session kind `land` (length from the parcel count as above); "Extend land" mode outlines the claimable parcels and the player picks one; completing claims it; a failed one claims nothing and costs no workers.
- Tests first: length rule per parcel count and the 90 minute cap; completing adds exactly the chosen parcel; failing adds none; only a claimable parcel can be chosen.
- Commit: `T-V6.4: land sessions`

### T-V6.5 [ ] Island view
- Depends on: T-V6.4
- Do: zoom out to a low-detail island view with outlined claimable parcels and a "World" button; the camera glides between plot view and island view.
- Tests first: zoom thresholds switch the detail level; the claimable outlines show only in extend mode; widget test for the button.
- Commit: `T-V6.5: island view`

### T-V6.6 [ ] World globe
- Depends on: T-V6.5
- Do: the painted globe screen (a `CustomPainter`, no package): drag to spin with inertia, the island picture placed on the sphere, tap it to dive into the island.
- Tests first: rotation and projection maths (pure); picking the island under a tap; a widget test for spin and tap; a golden of the globe.
- Commit: `T-V6.6: world globe`

### T-V6.7 [ ] Show off the world
- Depends on: T-V6.6
- Do: showcase mode (auto-spin, no controls) and saving a picture. Saving or sharing needs a package: ask the user and name it before adding anything.
- Tests first: the showcase hides the controls and spins; the picture has the globe's size (no sharing in tests).
- Commit: `T-V6.7: showcase`

### T-V6.8 [ ] [device] Growing world on the iPhone
- Depends on: T-V6.7
- Do: give the user steps (claim a parcel, build a garden beside a castle, zoom out, spin the globe, showcase), measure frame rate and battery, and record in `docs/device_tests.md`.
- Commit: `T-V6.8: record v6 device check`
