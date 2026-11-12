import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/app/focus_state.dart';
import 'package:focus_town/app/providers.dart';
import 'package:focus_town/data/database.dart';
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

/// A town with a ruin on plot 1: a 25-minute house, abandoned.
Future<ProviderContainer> _withRuin() async {
  final c = _container();
  await c.read(focusControllerProvider.future);
  final n = c.read(focusControllerProvider.notifier);
  await n.start(25);
  await n.abandon();
  n.clearResult();
  // Session ids come from the clock, so let it move on.
  _clock.advance(const Duration(minutes: 1));
  return c;
}

void main() {
  setUp(() {
    _clock = FakeClock();
    _db = AppDatabase(NativeDatabase.memory());
    addTearDown(_db.close);
  });

  test('startRepair starts a 10-minute repair of that ruin', () async {
    final c = await _withRuin();
    await c.read(focusControllerProvider.notifier).startRepair(1);
    final s = _state(c).active!;
    expect(s.isRepair, isTrue);
    expect(s.repairPlot, 1);
    expect(s.plannedMinutes, 10);
    expect(s.workersAssigned, 0);
  });

  test('only a ruin can be repaired, and not during a session', () async {
    final c = await _withRuin();
    final n = c.read(focusControllerProvider.notifier);
    await expectLater(n.startRepair(0), throwsStateError); // the starter
    await expectLater(n.startRepair(5), throwsStateError); // empty
    await n.startRepair(1);
    await expectLater(n.startRepair(1), throwsStateError);
  });

  test('finishing clears the ruin, adds XP and a streak, no workers', () async {
    final c = await _withRuin();
    final before = _state(c).town;
    final n = c.read(focusControllerProvider.notifier);
    await n.startRepair(1);
    _clock.advance(const Duration(minutes: 10));
    await n.tick();
    final s = _state(c);
    expect(s.active, isNull);
    expect(s.town.buildings.any((b) => b.plotIndex == 1), isFalse);
    expect(s.town.workers, before.workers);
    expect(s.town.xp, before.xp + 10);
    expect(s.lastResult!.repair, isTrue);
    expect(s.lastResult!.outcome, SessionOutcome.completed);
    expect(s.lastResult!.workersGained, 0);
    expect(s.lastResult!.xpGained, 10);
  });

  test('a lost repair leaves the town exactly as it was', () async {
    final c = await _withRuin();
    final before = _state(c).town;
    final n = c.read(focusControllerProvider.notifier);
    await n.startRepair(1);
    await n.abandon();
    final s = _state(c);
    expect(s.town, before);
    expect(s.lastResult!.repair, isTrue);
    expect(s.lastResult!.outcome, SessionOutcome.failed);
    expect(s.lastResult!.workersLost, 0);
  });

  test('a repair resumes after the app is killed', () async {
    final c = await _withRuin();
    await c.read(focusControllerProvider.notifier).startRepair(1);
    final again = _container();
    await again.read(focusControllerProvider.future);
    expect(_state(again).active!.repairPlot, 1);
  });

  test('a repair also works in recovery mode', () async {
    final c = _container();
    await c.read(focusControllerProvider.future);
    final n = c.read(focusControllerProvider.notifier);
    // Lose everything: a 25-minute house risks 2 of 3 workers, twice.
    await n.start(25);
    await n.abandon();
    n.clearResult();
    _clock.advance(const Duration(minutes: 1));
    await n.start(20);
    await n.abandon();
    _clock.advance(const Duration(minutes: 1));
    expect(_state(c).town.inRecoveryMode, isTrue);
    await n.startRepair(1);
    expect(_state(c).active!.isRepair, isTrue);
  });
}
