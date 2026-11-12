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

## Final checklist: iPhone (T-22.13, 2026-11-11)

Profile build (`flutter run --profile`) on the iPhone 15 Pro Max. User-reported: "these all check looks good." Recorded as a pass for all 15 items; the user gave no per-item detail.

- [x] 1 Lock 5 minutes: session continues. CORRECTED 2026-11-11: the first release build lost the builders on a real lock (the lock signal came too late). Fixed with the Darwin lock notification and a router fix (a lock just before the background is a lock); re-tested on the iPhone: 3 minutes locked, no penalty, event log `locked`, `locked`, `backgrounded`, then `foregrounded`, `unlocked`.
- [x] 2 App switch under 5 seconds: no penalty.
- [x] 3 Away 30 seconds: pass spent, session continues.
- [x] 4 Away 90 seconds: workers die, ruin appears.
- [x] 5 Phone call: no penalty, no pass.
- [x] 6 Control Center: no penalty.
- [x] 7 Force-quit and reopen: outcome resolved correctly.
- [x] 8 Reboot mid-session: resolved on launch.
- [x] 9 Clock forward 2 hours: no early completion (log line not separately confirmed).
- [x] 10 Notifications denied: one-time note, rules still apply.
- [x] 11 Two different days: streak 2, plots 8.
- [x] 12 Full town: building queued, placed when a plot unlocks.
- [x] 13 Recovery mode starts and ends.
- [x] 14 Low Power Mode: frame rate drops, no effects.
- [x] 15 Persistence, cold start, battery, smoothness.

## V2 repair and emergency pause on the iPhone (T-V2.5, 2026-11-11)

Profile build on the iPhone 15 Pro Max. User-reported: "both repair and pause work on the iPhone." No per-step detail was given.

- [x] Repair: tap a ruin, "Repair (10 min)", the ruin is cleared at the end.
- [x] Emergency pause: armed before leaving, away for minutes, back with no penalty.
- [ ] Not separately confirmed: a lost repair leaving the ruin, the notification texts for the 10-minute window, the disabled button with "Next pause on …".


## Lock detection fixes (2026-11-11)

Release build on the iPhone 15 Pro Max, found by the user while testing a fresh install.

- [x] Real lock for about 3 minutes in a 10-minute session: no penalty (after the fixes).
- [x] Switching to another app for 30 seconds: the free pass is spent, as designed.
- [x] Opening the debug screen no longer turns the town into a still picture (render guard ignores a covered town). The two `render degraded` lines in the log are from before that fix.
- [ ] Not yet confirmed: the odd bursts of `callStarted`/`callEnded` pairs in the event log at app resume (21:52:29 on the first test).

## Lock screen status on the iPhone (T-LA.3, 2026-11-12)

Release build on the iPhone 15 Pro Max, in-place install, user-reported.

- [x] The card appears on the lock screen when a session starts.
- [x] The countdown matches the app's timer.
- [x] The Dynamic Island shows the icon and time.
- [x] Away shows the "Away" text and returns to "Builders working" on coming back.
- [x] It disappears when the session ends.
- [x] Swiping the app away removes the card (iOS ends a force-quit app's Live Activities); reopening the app shows it again, and the away warning notification still arrives.
- [x] The card icon is fine after adding an icon set to the extension (`ios/FocusStatus/Assets.xcassets`).
- [x] The away warning banner still shows the Flutter icon after a fresh install, though the installed app and its icon set contain the house icon and no other Flutter app is on the phone. Treated as an iOS display issue; look again after a phone restart or a TestFlight install.

## V3, V4 and V6 on the iPhone (to do, built 2026-11-12)

Install the release build in place (`xcrun devicectl device install app ...`), then:

- [ ] V3: finish a few sessions. Buildings show a classic or a second look (tent, townhouse, smithy, lighthouse, pyramid); the starter house stays the classic house.
- [ ] V4: tap the flame (streak) in the HUD: "Your focus" opens. Before any session it says to finish one; afterwards the bars, streak, completion rate and the sentence match what you did.
- [ ] V6: Start focus > "Extend land…": the camera steps back, the coast parcels are outlined, the bar says "Choose land for your 25-minute session". Tap a parcel, Confirm: a 25-minute session starts (no workers at risk). Finish it: "Land claimed", the new land appears and is forest.
- [ ] V6: repeat with "Make it a garden" switched on: the new land is a park, pond, orchard or flower beds, and it is not a plot.
- [ ] V6: abandon a land session: nothing is lost and no land is added.
- [ ] V6: the camera can zoom out over the grown island and pan to the new land.

## Road network on the iPhone (T-V7.4, to do, built 2026-11-12)

- [x] Every building has a road around its plot (a castle or pyramid around its whole 2 x 2 block), and those roads join the two main roads, along plot edges where needed. (User: "the roads look good", 2026-11-12.)
- [x] Up to 8 spare workers walk the whole network, not only the two main roads, and keep to roads. (User: "workers walk fine".)
- [ ] Workers walking past a castle or tower hide behind its walls and show again after (no see-through, no flicker).
- [ ] The castle and pyramid are 12 x 12 inside their block, leaving the road tile free.

## Android
