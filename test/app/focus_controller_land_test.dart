import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/app/focus_state.dart';
import 'package:focus_town/app/providers.dart';
import 'package:focus_town/data/database.dart';
import 'package:focus_town/domain/parcel.dart';
import 'package:focus_town/domain/testing/fake_clock.dart';
import 'package:focus_town/platform/testing/fake_live_status_sink.dart';
import 'package:focus_town/platform/testing/fake_notifier.dart';

late AppDatabase _db;
late FakeClock _clock;

const _west = Parcel(-1, 3);

ProviderContainer _container() {
  final c = ProviderContainer(
    overrides: [
      clockProvider.overrideWithValue(_clock),
      databaseProvider.overrideWithValue(_db),
      notifierProvider.overrideWithValue(FakeNotifier()),
      liveStatusSinkProvider.overrideWithValue(FakeLiveStatusSink()),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

FocusState _state(ProviderContainer c) =>
    c.read(focusControllerProvider).requireValue;

void main() {
  setUp(() {
    _clock = FakeClock();
    _db = AppDatabase(NativeDatabase.memory());
    addTearDown(_db.close);
  });

  Future<ProviderContainer> ready() async {
    final c = _container();
    await c.read(focusControllerProvider.future);
    return c;
  }

  test('startLand starts a 25-minute session that risks nothing', () async {
    final c = await ready();
    await c.read(focusControllerProvider.notifier).startLand(_west);
    final s = _state(c).active!;
    expect(s.isLand, isTrue);
    expect(s.land, _west);
    expect(s.plannedMinutes, 25);
    expect(s.workersAssigned, 0);
  });

  test('a garden parcel is remembered as one', () async {
    final c = await ready();
    const garden = Parcel(-1, 3, garden: true);
    await c.read(focusControllerProvider.notifier).startLand(garden);
    expect(_state(c).active!.land, garden);
  });

  test('only a claimable parcel can be chosen, and not mid-session', () async {
    final c = await ready();
    final n = c.read(focusControllerProvider.notifier);
    await expectLater(n.startLand(const Parcel(3, 3)), throwsStateError);
    await n.startLand(_west);
    await expectLater(n.startLand(const Parcel(-1, 4)), throwsStateError);
  });

  test(
    'finishing claims the parcel, counts as focus, and survives a restart',
    () async {
      final c = await ready();
      final n = c.read(focusControllerProvider.notifier);
      await n.startLand(_west);
      _clock.advance(const Duration(minutes: 26));
      await n.tick();
      expect(_state(c).town.parcels, [_west]);
      expect(_state(c).town.xp, 25);
      final r = _state(c).lastResult!;
      expect(r.land, isTrue);
      expect(r.outcome, SessionOutcome.completed);
      expect(r.xpGained, 25);
      expect(r.workersLost, 0);
      final again = _container();
      await again.read(focusControllerProvider.future);
      expect(_state(again).town.parcels, [_west]);
    },
  );

  test('giving up claims nothing and costs nothing', () async {
    final c = await ready();
    final n = c.read(focusControllerProvider.notifier);
    final before = _state(c).town;
    await n.startLand(_west);
    await n.abandon();
    final after = _state(c).town;
    expect(after.parcels, before.parcels);
    expect(after.workers, before.workers);
    expect(after.xp, before.xp);
    expect(after.buildings, before.buildings);
    final r = _state(c).lastResult!;
    expect(r.outcome, SessionOutcome.failed);
    expect(r.land, isTrue);
    expect(r.workersLost, 0);
  });

  test('the next land session is longer after 4 parcels', () async {
    final c = await ready();
    final n = c.read(focusControllerProvider.notifier);
    for (final p in const [
      Parcel(-1, 0),
      Parcel(-1, 1),
      Parcel(-1, 2),
      Parcel(-1, 3),
    ]) {
      await n.startLand(p);
      _clock.advance(const Duration(minutes: 26));
      await n.tick();
      n.clearResult();
      _clock.advance(const Duration(minutes: 1));
    }
    await n.startLand(const Parcel(-1, 4));
    expect(_state(c).active!.plannedMinutes, 30);
  });
}
