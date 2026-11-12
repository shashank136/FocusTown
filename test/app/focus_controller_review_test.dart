import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/app/providers.dart';
import 'package:focus_town/data/database.dart';
import 'package:focus_town/domain/local_date.dart';
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

void main() {
  setUp(() {
    _clock = FakeClock(start: DateTime(2026, 5, 1, 23, 40));
    _db = AppDatabase(NativeDatabase.memory());
    addTearDown(_db.close);
  });

  test('a double tap on start creates one session', () async {
    final c = _container();
    await c.read(focusControllerProvider.future);
    final n = c.read(focusControllerProvider.notifier);
    await Future.wait([n.start(10), n.start(10)]);
    expect(await _db.select(_db.sessions).get(), hasLength(1));
  });

  test('a double tap on repair creates one session', () async {
    final c = _container();
    await c.read(focusControllerProvider.future);
    final n = c.read(focusControllerProvider.notifier);
    await n.start(25);
    await n.abandon();
    _clock.advance(const Duration(minutes: 1));
    await Future.wait([n.startRepair(1), n.startRepair(1)]);
    expect(await _db.select(_db.sessions).get(), hasLength(2));
  });

  test(
    'the day counts from the planned end, not when it was noticed',
    () async {
      final c = _container();
      await c.read(focusControllerProvider.future);
      final n = c.read(focusControllerProvider.notifier);
      await n.start(10); // ends 23:50
      _clock.advance(const Duration(minutes: 20)); // noticed at 00:00
      await n.tick();
      final town = c.read(focusControllerProvider).requireValue.town;
      expect(town.lastStreakDate, const LocalDate(2026, 5, 1));
    },
  );

  test(
    'an event for a session that is not stored is logged, not thrown',
    () async {
      final c = _container();
      await c.read(focusControllerProvider.future);
      final n = c.read(focusControllerProvider.notifier);
      await n.start(25);
      await _db.delete(_db.sessions).go();
      await n.onBackgroundedUnlocked();
      expect(c.read(focusControllerProvider).hasError, isFalse);
    },
  );
}
