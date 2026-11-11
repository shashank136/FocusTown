# Device tests

Manual device checklists. See the manual device checklist in `spec.md`.

## iOS

### Step 7: persistence

Run on the iPhone 18 Pro **simulator** (Device Hub), 2026-11-09. No physical iPhone yet, so repeat on a real phone once one is available (TestFlight, step 22).

- [x] App shows the "Stored town" card: workers 3, plots 6, XP 0, streak 0, buildings 1 (user-confirmed).
- [x] Force-quit and reopen: same values, no error (user-confirmed; also checked by Claude: `created_at` unchanged, 1 building row).
- [x] Delete app, reinstall, run: fresh database with the same initial values and a new `created_at` (checked by Claude via `simctl uninstall`).
- [ ] Same three checks on a physical iPhone.

### Step 10: iOS lifecycle bridge (checks run in T-10.5)

Notes:

- Lock detection uses protected-data notifications, so it needs a device passcode. Without a passcode a lock is seen only as a background.
- Uptime uses `CLOCK_MONOTONIC_RAW`, which keeps counting while the phone sleeps. `ProcessInfo.systemUptime` is not used because it pauses during sleep.

Checklist (simulator results by Claude, iPhone 18 Pro simulator, 2026-11-09; the lock and call rows need a physical iPhone):

- [x] Event log header says `native`; `backgrounded` then `foregrounded` appear after switching to Settings and back (simulator).
- [ ] Lock for 1 minute: log shows `locked` before `backgrounded`, then `unlocked`, `foregrounded`. The simulator lock button (via XcodeBuildMCP) produced no events and no penalty: a 25-minute session stayed `running`, progress 6% after 1 min 38 s, matching elapsed time. Needs a physical iPhone.
- [ ] Lock for 5 minutes during a 10-minute session: progress about 50% (uptime counts sleep). Needs a physical iPhone. Seen so far: native uptime `458:29:36` is the host's continuous time, and progress matched elapsed time.
- [x] Switch to another app (simulator, Settings and back, 25-minute session): away 3 s: running, no pass. Away 30 s: running, `Pass used: true` (29.4 s away stored). Away 90 s after the pass: failed `leftTooLong` (118.8 s away stored), "Session failed" dialog, workers reduced.
- [ ] Phone call mid-session (incoming answered, incoming declined, outgoing, ended): `callStarted` then `callEnded`; no penalty and no pass when backgrounding during the call. Cannot be tested in the simulator. Needs a physical iPhone.
- [ ] Control Center and the notification shade: no events. The simulator top-edge swipe did not visibly open Control Center, so this is inconclusive (the session was unaffected). Needs a physical iPhone.


### Step 8: controller

Run on the iPhone 18 Pro **simulator** (Device Hub), 2026-11-09, debug build. No physical iPhone yet; repeat on one when available. "Force-quit" here is `xcrun simctl terminate`.

- [x] Pick 10 minutes, Start: `State: running` (user-confirmed; session saved as `running` in the database).
- [x] Force-quit and reopen mid-session: still `running` (Claude checked earlier: progress 1% after relaunch; user relaunched the 10-minute session at about 70% and it kept going).
- [x] Force-quit, reopen after the 10 minutes passed: "Session completed" dialog, workers gained 1, Workers 4, XP 10, streak 1, hut on plot 1 (user-confirmed; database matches).
- [x] Start, Leave, wait, Return: "Session failed", workers reduced by 1 (user-confirmed; session failed as `leftTooLong` after about 71 s away, resolved by the live tick).
- [x] Start, Leave, force-quit, wait 100 s, reopen: "Session failed" popup at launch, `Workers lost: 2`, session resolved at 20:47:53 (reopen time), not earlier (Claude ran this).
- [ ] Same checks on a physical iPhone.

## iPhone 15 Pro Max results (steps 18 to 20, 2026-11-10)

Debug build over `flutter run` on a fresh install (user-reported). Build with the session-setup sheet, choose-a-plot mode, HUD, session panel and result dialogs.

- [x] Test 1, Start focus from the home screen: the sheet, a 10-minute hut, camera glide to the site, scaffolding and hammering builder, countdown and top bar all fine. Zoomed in the blocks are still not perfectly smooth; the user accepts it for now (textures are already off past tile 32).
- [x] Test 2, Choose plot: outlined plots can be selected, Confirm starts the build there and it resumes on the same plot after a relaunch. Only the 6 unlocked plots can be chosen; the rest of the green island is locked on purpose (one new plot per focus day). The user finds the empty green area a waste; see the plan note about opening more land.
- [x] Test 3, a session runs to its end and zoomed-in watching: no glitch when a worker walks past a building (fixed by clipping the occlusion repaint). The user will keep watching for it.
- [x] Test 4, leave the app for 90 s and come back: passes (failed dialog, ruin).
- [ ] Still unverified on the phone: notification banners, real lock and call events, pinch and double-tap feel (T-16.4), frame rate and battery (T-17.7).

## iPhone 15 Pro Max results (step 21 and the island polish, 2026-11-10)

Debug build over `flutter run` (user-reported: "everything works as expected").

- [x] T-21.7 Step 21 onboarding: fresh install to a running 10-minute hut, three pages with live demos, notification prompt on the last page, the free-pass tip once, and the denied-notifications note.
- [x] Dial with exactly three rows (clear centre, faded neighbours), tap and click per step.
- [x] Forest island: roads and paths visible through the forest; the ruin fix and the plot choice anywhere on the island.
- [ ] Still unverified: Android phone-state prompt (Android deferred), notification banners with a real lock or call, pinch and double-tap feel (T-16.4), frame rate and battery (T-17.7).

## Android
