import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/app/focus_state.dart';
import 'package:focus_town/app/providers.dart';
import 'package:focus_town/data/database.dart';
import 'package:focus_town/domain/local_date.dart';
import 'package:focus_town/domain/session.dart';
import 'package:focus_town/domain/testing/fake_clock.dart';
import 'package:focus_town/platform/testing/fake_notifier.dart';

late AppDatabase _db;
late FakeClock _clock;

ProviderContainer _container() {
  final c = ProviderContainer(
    overrides: [
      clockProvider.overrideWithValue(_clock),
      databaseProvider.overrideWithValue(_db),
      notifierProvider.overrideWithValue(FakeNotifier()),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

FocusState _state(ProviderContainer c) =>
    c.read(focusControllerProvider).requireValue;

Future<ProviderContainer> _started({int minutes = 60}) async {
  final c = _container();
  await c.read(focusControllerProvider.future);
  await c.read(focusControllerProvider.notifier).start(minutes);
  return c;
}

void main() {
  setUp(() {
    // Thursday 2026-01-01; its week starts on Monday 2025-12-29.
    _clock = FakeClock();
    _db = AppDatabase(NativeDatabase.memory());
    addTearDown(_db.close);
  });

  test('the first session records the week and keeps the one pause', () async {
    final c = await _started();
    expect(_state(c).town.emergencyPauses, 1);
    expect(_state(c).town.emergencyWeek, const LocalDate(2025, 12, 29));
  });

  test('arming uses up the pause and survives a restart', () async {
    final c = await _started();
    final ok = await c
        .read(focusControllerProvider.notifier)
        .armEmergencyPause();
    expect(ok, isTrue);
    expect(_state(c).town.emergencyPauses, 0);
    expect(_state(c).active!.emergencyArmed, isTrue);
    final again = _container();
    await again.read(focusControllerProvider.future);
    expect(_state(again).town.emergencyPauses, 0);
    expect(_state(again).active!.emergencyArmed, isTrue);
  });

  test('an armed pause that is never used comes back at the end', () async {
    final c = await _started(minutes: 25);
    final n = c.read(focusControllerProvider.notifier);
    await n.armEmergencyPause();
    _clock.advance(const Duration(minutes: 26));
    await n.tick();
    expect(_state(c).town.emergencyPauses, 1);
  });

  test('a second arming is refused', () async {
    final c = await _started();
    final n = c.read(focusControllerProvider.notifier);
    expect(await n.armEmergencyPause(), isTrue);
    expect(await n.armEmergencyPause(), isFalse);
  });

  test('with the pause armed, 5 minutes away costs nothing', () async {
    final c = await _started();
    final n = c.read(focusControllerProvider.notifier);
    await n.armEmergencyPause();
    await n.onBackgroundedUnlocked();
    _clock.advance(const Duration(minutes: 5));
    await n.onForegrounded();
    final s = _state(c).active!;
    expect(s.state, SessionState.running);
    expect(s.emergencyUsed, isTrue);
    expect(s.passUsed, isFalse);
  });

  test('without it, 5 minutes away loses the builders', () async {
    final c = await _started();
    final n = c.read(focusControllerProvider.notifier);
    await n.onBackgroundedUnlocked();
    _clock.advance(const Duration(minutes: 5));
    await n.onForegrounded();
    expect(_state(c).lastResult!.outcome, SessionOutcome.failed);
  });

  test('the pause comes back in a new week, not in the same one', () async {
    final c = await _started();
    final n = c.read(focusControllerProvider.notifier);
    await n.armEmergencyPause();
    // Use the pause on a 2-minute absence, so it is really spent.
    await n.onBackgroundedUnlocked();
    _clock.advance(const Duration(minutes: 2));
    await n.onForegrounded();
    await n.abandon();
    n.clearResult();
    _clock.advance(const Duration(days: 2)); // still the same week
    await n.start(10);
    expect(_state(c).town.emergencyPauses, 0);
    await n.abandon();
    n.clearResult();
    _clock.advance(const Duration(days: 5)); // next Monday or later
    await n.start(10);
    expect(_state(c).town.emergencyPauses, 1);
  });

  test('a repair cannot arm the pause', () async {
    final c = await _started(minutes: 25);
    final n = c.read(focusControllerProvider.notifier);
    await n.abandon();
    n.clearResult();
    _clock.advance(const Duration(minutes: 1));
    await n.startRepair(1);
    expect(await n.armEmergencyPause(), isFalse);
  });
}
