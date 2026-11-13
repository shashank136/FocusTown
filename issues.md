# Code review findings (main branch)

Scope: read the domain, app, data and platform layers, `main.dart`, and the Swift lifecycle bridge (about 4,000 of roughly 8,000 hand-written lines).
Not read: `lib/game/**`, most of `lib/ui/**`, tests, the Android stub, generated `database.g.dart`.
Nothing was run; every finding comes from reading the code. No security vulnerabilities found (offline app, no network, auth or user-supplied input).

## Summary

| # | Severity | Area | Title |
|---|----------|------|-------|
| 1 | Medium | `lib/data/db_recovery.dart` | Failed open can silently roll the town back to an old backup |
| 2 | Medium | `lib/app/focus_controller.dart`, `lib/app/placement.dart` | Double-tap on Start/Confirm can create two active sessions |
| 3 | Medium (unverified) | `lib/platform/native_uptime_clock.dart` | Possible clock drift across device sleep |
| 4 | Low | `lib/platform/lifecycle_router.dart` | `_inCall` can get stuck |
| 5 | Low | `lib/domain/progression.dart` | Date changes grant unlimited daily plots |
| 6 | Low | `lib/app/focus_controller.dart` | Streak/plot day uses detection time, not completion time |
| 7 | Low | `lib/data/town_repository.dart`, `lib/app/focus_controller.dart` | Unhandled `StateError` drops events |
| 8 | Low | `lib/domain/town_rules.dart` | Armed emergency pause is spent even if unused |
| 9 | Low | `ios/Runner/FocusLifecyclePlugin.swift` | Private Darwin notification (App Store risk) |
| 10 | Info | `lib/platform/local_notifier.dart` | Hard-coded time zone |

## 1. Medium: failed open can silently roll the town back to an old backup

**File:** `lib/data/db_recovery.dart:41-72`

**Problem:** the backup is only taken when the schema version changes, so it is as old as the last upgrade. If `attempt()` fails on any later launch, even for a transient reason, the code moves the live DB aside and copies that old backup in. It then returns `startedFresh: false`, so the user sees no message and silently loses everything since the upgrade.

**Evidence:** `_copy(dbFile, backup)` runs only inside `seen != '$schemaVersion'`. The restore branch has no check that the failure was real corruption.

**Fix:**
- Refresh the backup after each successful open (or at least daily).
- Only restore on a corruption or migration error, not on any `Object`.
- Show a "we restored an older save" message.

## 2. Medium: double-tap on Start/Confirm can create two active sessions

**Files:** `lib/app/focus_controller.dart:52-76`, `lib/app/placement.dart:54`

**Problem:** `start()` checks `current.active != null`, then awaits the DB write, and only afterwards sets `state`. A second call during that window passes the check and inserts a second row. `placement.confirm()` has the same gap, because `state = null` is set only after the await. Neither button disables itself while a start is in flight.

**Evidence:** `ui/session_setup_sheet.dart:198`, `ui/home_screen.dart:363` and `ui/home_screen.dart:195` call the controller with no in-flight flag. `activeSession()` uses `limit(1)`, so the orphan row stays `running` in the DB. After a relaunch it can resolve as completed and grant a second building and XP.

**Fix:** add an `_starting` guard in `FocusController` covering `start`, `startRepair` and `armEmergencyPause`, so the invariant lives in one place.

## 3. Medium (unverified): possible clock drift across device sleep

**File:** `lib/platform/native_uptime_clock.dart:20-25`

**Problem:** `uptime()` is the native uptime read once at launch plus a Dart `Stopwatch`. The Swift comment says the native value counts sleep. If the Dart `Stopwatch` pauses during device sleep (believed possible on iOS, not confirmed), the two time bases drift apart after any lock in the same process. Controller-made stamps (`start`, `tick`) use the Dart clock, while event stamps use the native `uptimeMs`. A session started after a long lock would then measure too long between start and leave.

**Fix:** reproduce on the iPhone first. If confirmed, read native uptime for every stamp, or re-sync `initial` on each `foregrounded` event.

## 4. Low: `_inCall` can get stuck

**File:** `lib/platform/lifecycle_router.dart:26,95-99`

**Problem:** if `callEnded` is missed (for example the app was suspended during the call), `_inCall` stays true and no background is penalised until the app restarts. It is never reset on `ForegroundedEvent`.

**Fix:** clear it on foreground, or reconcile with `CXCallObserver.calls` in Swift.

## 5. Low: date changes grant unlimited daily plots

**File:** `lib/domain/progression.dart:64`

**Problem:** the check is `lastPlotGrantDate != today`, not "later than". Setting the device clock back a day and finishing a session grants a plot. Setting it forward again grants another. The same date skew resets the streak to 1.

**Fix:** grant only when `today` is after `lastPlotGrantDate`.

## 6. Low: streak and plot day use detection time, not completion time

**File:** `lib/app/focus_controller.dart:223-240`

**Problem:** `_finish` is passed the time the app noticed completion, not the planned end. A session that ends at 23:55 and is noticed at 00:05 counts toward the next day. After an app kill, the relaunch time is used.

**Fix:** use `startedAt.wall + planned` (or `leftAt` plus the allowed window) as the completion time.

## 7. Low: unhandled `StateError` drops events

**Files:** `lib/data/town_repository.dart:192`, `lib/app/focus_controller.dart:182-188`

**Problem:** `saveSessionUpdated` throws `StateError('No stored session')`, but `_forward` only catches `SaveFailedException`. The error escapes into the router queue's uncaught-error handler and the event is dropped silently.

**Fix:** catch and log it, or fold it into `SaveFailedException`.

## 8. Low: armed emergency pause is spent even if unused

**File:** `lib/domain/town_rules.dart:116-128`

**Problem:** arming deducts the weekly pause immediately. If the session ends without an absence, the pause is lost with no refund.

**Fix:** if that is not intended, refund the pause when a session completes with `emergencyArmed` still true.

## 9. Low (App Store risk): private Darwin notification

**File:** `ios/Runner/FocusLifecyclePlugin.swift:105`

**Problem:** lock detection relies on `com.apple.springboard.lockcomplete`, a private notification name. It is widely used and is a string rather than a private API call, but review could still flag it. `deinit` also never calls `CFNotificationCenterRemoveObserver`, which is safe only while the plugin lives for the whole app.

**Fix:** keep it, since the device tests depend on it, but prepare a review note. Add the remove-observer call in `deinit`.

## 10. Info: hard-coded time zone

**File:** `lib/platform/local_notifier.dart:32-34`

**Problem:** the zone is fixed to `America/New_York` ("for testing"). There is no practical effect today, because every schedule is "now plus a duration".

**Fix:** delete the stale comment, or detect the zone, before it matters.

## Checked and found clean

- **Session engine and town rules:** `resolve` and `onForegrounded` agree on the 10 s window, the 60 s pass and the 10-minute emergency window. The completion-while-away boundary is correct, `applyFailed` is clamped with `max(0, ...)`, and the queue and plot logic holds up.
- **Database writes:** `_writeTown` runs inside a transaction, session and town saves are atomic, and the migrations (`from < N`) cover v2 to v6.
- **Injection:** none. All SQL goes through drift's typed API.

## Still to review

`lib/game/town_game.dart`, `lib/ui/home_screen.dart` and `lib/game/workers/*` are the largest unread files.

## Status of fixes

Fixed: 1, 2, 4, 5, 6, 7, 9 (remove-observer only), 10.
- 1: the backup is refreshed (`VACUUM INTO`) after every clean open; a restore shows "restored a recent save". Any failed open still triggers the restore (no way to tell corruption from a transient error).
- 4: a call with no end event stops counting after 3 hours.
- 5: plots are granted only for a later day; a date in the past changes no streak or plot date (this changed the old "past date resets the streak to 1" rule).
- 6: the day counts from the planned end of the session.

Not changed:
- 3: not an issue. Device test: a 25-minute session, phone locked for 20+ minutes, the counter was right on return, so the Dart stopwatch counts through sleep on iOS.
- 8: the armed pause is spent by design; refunding it is a product decision.
- 9: the private Darwin notification stays; add a review note in Phase L.
