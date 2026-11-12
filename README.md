# Focus Town

Focus Town is a mobile app where you build a small block-style island town by staying off your phone. Start a focus session, and little blocky workers build a hut, a house, a tower or even a castle while you focus. Leave the app before the time is up and the builders stop, and the site becomes a ruin. Finish, and your town grows.

It is built with Flutter, works fully offline, and has no accounts, ads or analytics. The first release is iPhone only; Android comes after launch.

![Block-style town overview](docs/images/block-town-overview.png)

## What you get

**Focus sessions**
- Pick 10 to 120 minutes on a wheel dial that clicks and taps as you turn it.
- The longer you focus, the bigger the building: hut, house, workshop, tower, castle.
- Lock your phone, put it face down, or take a phone call: none of that counts against you.
- Switch to another app and you have a short grace period (10 seconds, plus one free 60-second pass per session) before the builders stop. A notification warns you before that happens.
- Close the app and come back later: the result is worked out from the clock, so nothing is lost.

**Your town**
- An isometric island of blocks with workers who hammer away on the site, walk the roads and celebrate when a building is done.
- The whole island starts as forest. You choose a plot, only that plot is cleared, and the builders work there.
- Finish sessions to unlock more plots, grow a daily streak, earn XP and raise your town level.
- Completed buildings add builders to your town. Fail, and builders are lost; lose them all and the Last Builder rule lets you recover with short huts.
- Pan, pinch and double-tap to explore; the camera glides to the site when you start.

**Gentle and light**
- A short onboarding with live demos, and one-time tips that appear only when they matter.
- Frame rate is capped and drops in Low Power Mode; nothing is drawn while the app is in the background.

## What is coming

Planned after the first release (see `docs/tasks.md`):
- Repair a ruin with a short session, and a weekly emergency pause.
- More kinds of building (apartments, pyramids, gardens) and landmarks.
- A focus trends screen: how your focus time is improving.
- A world that grows: extend the island where you want, view it on a rotatable globe, and show it off.
- Android (after the iPhone launch).

## Run it

You need Flutter (stable) and Xcode. On the iOS simulator or a plugged-in iPhone:

```
flutter pub get
flutter run                     # pick a simulator or device
flutter analyze
flutter test
```

Debug builds on a real iPhone can only be launched from `flutter run`, and stop when the phone locks. See `CLAUDE.md` for the simulator workflow.

## Folder layout

```
CLAUDE.md                 guidance for Claude Code
lib/
  domain/                 pure rules: sessions, town, progression (no Flutter)
  data/                   local SQLite database (drift)
  platform/               iOS bridge, notifications, power state
  game/                   the isometric town (Flame): world, render, workers, effects
  app/                    state and controllers (Riverpod)
  ui/                     screens: home, setup sheet, onboarding, dialogs
docs/
  spec.md                 requirements
  tasks.md                task queue, handoff notes and planned phases
  todo.md                 progress checklist
  device_tests.md         manual device test results
  prompt_plan.md          the original build prompts
  images/, reference/     visual target for the art
```

## Status

The first release is being finished: steps 1 to 21 are done and tested on an iPhone. Step 22 (error handling, release assets, TestFlight) is in progress. The next task is always the first unchecked one in `docs/tasks.md`.
