# Device tests

Manual device checklists. See the manual device checklist in `spec.md`.

## iOS

### Step 7: persistence

Run on the iPhone 18 Pro **simulator** (Device Hub), 2026-11-09. No physical iPhone yet, so repeat on a real phone once one is available (TestFlight, step 22).

- [x] App shows the "Stored town" card: workers 3, plots 6, XP 0, streak 0, buildings 1 (user-confirmed).
- [x] Force-quit and reopen: same values, no error (user-confirmed; also checked by Claude: `created_at` unchanged, 1 building row).
- [x] Delete app, reinstall, run: fresh database with the same initial values and a new `created_at` (checked by Claude via `simctl uninstall`).
- [ ] Same three checks on a physical iPhone.

## Android
