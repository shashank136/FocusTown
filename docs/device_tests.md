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

Checklist:

- [ ] Event log header says `native`.
- [ ] Lock for 1 minute: log shows `locked` before `backgrounded`; unlock shows `unlocked`, `foregrounded`; a running session shows no penalty.
- [ ] Lock for 5 minutes during a 10-minute session: after unlocking, progress is about 50% (uptime counts sleep).
- [ ] Switch to another app: `backgrounded` only (no `locked`). Return within 5 s: no penalty. Away 30 s: pass used. Away 90 s: failed.
- [ ] Phone call mid-session (incoming answered, incoming declined, outgoing, ended): `callStarted` then `callEnded`; backgrounding during the call causes no penalty and no pass.
- [ ] Control Center and the notification shade: no events.

## Android
