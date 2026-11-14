import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/app/focus_controller.dart';
import 'package:focus_town/app/focus_state.dart';
import 'package:focus_town/app/providers.dart';
import 'package:focus_town/app/short_sessions.dart';
import 'package:focus_town/data/database.dart';
import 'package:focus_town/data/mappers.dart';
import 'package:focus_town/domain/district.dart';
import 'package:focus_town/domain/testing/fake_clock.dart';
import 'package:focus_town/domain/town.dart';
import 'package:focus_town/platform/testing/fake_live_status_sink.dart';
import 'package:focus_town/platform/testing/fake_notifier.dart';

late AppDatabase _db;
late FakeClock _clock;

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

  // A town at City level, where districts are unlocked.
  Future<(ProviderContainer, FocusController)> ready({int xp = 6000}) async {
    final seed = TownState.initial().copyWith(xp: xp);
    await _db.transaction(() async {
      await _db
          .into(_db.towns)
          .insert(
            townToRow(seed)
                .copyWith(id: const Value(1), createdAt: const Value(0)),
          );
      await _db.batch(
        (b) => b.insertAll(
          _db.buildings,
          buildingsToRows(seed, now: _clock.nowWall()),
        ),
      );
    });
    final c = _container();
    await c.read(focusControllerProvider.future);
    return (c, c.read(focusControllerProvider.notifier));
  }

  Future<void> finish(FocusController n, int minutes) async {
    _clock.advance(Duration(minutes: minutes + 1));
    await n.tick();
    n.clearResult();
    _clock.advance(const Duration(minutes: 1));
  }

  test('a district is never locked: a new town can start one', () async {
    final (c, n) = await ready(xp: 0);
    await n.startDistrict(DistrictSide.east, 60);
    expect(_state(c).active!.district, DistrictSide.east);
  });

  test('starting one begins the project and risks nothing', () async {
    final (c, n) = await ready();
    await n.startDistrict(DistrictSide.east, 60);
    final s = _state(c).active!;
    expect(s.isDistrict, isTrue);
    expect(s.district, DistrictSide.east);
    expect(s.plannedMinutes, 60);
    expect(s.workersAssigned, 0);
    expect(
      _state(c).town.districtProject,
      const DistrictProject(DistrictSide.east, 0),
    );
  });

  test('a finished hour is one row of land, and counts for xp', () async {
    final (c, n) = await ready();
    await n.startDistrict(DistrictSide.east, 60);
    _clock.advance(const Duration(minutes: 61));
    await n.tick();
    final town = _state(c).town;
    expect(town.parcels, districtRow(DistrictSide.east, 0, 0));
    expect(town.districtProject!.progress, 60);
    expect(town.xp, 6060);
    final r = _state(c).lastResult!;
    expect(r.district, DistrictSide.east);
    expect(r.districtRows, 1);
    expect(r.districtFinished, isFalse);
  });

  test(
    'two hours make two rows, and the leftover minutes carry over',
    () async {
      final (c, n) = await ready();
      await n.startDistrict(DistrictSide.east, 120);
      await finish(n, 120);
      expect(_state(c).town.parcels, hasLength(16));
      await n.startDistrict(DistrictSide.east, 45);
      await finish(n, 45);
      expect(_state(c).town.districtProject!.progress, 165);
      expect(_state(c).town.parcels, hasLength(16)); // not a third row yet
      await n.startDistrict(DistrictSide.east, 15);
      await finish(n, 15);
      expect(_state(c).town.parcels, hasLength(24)); // 180 minutes: row three
    },
  );

  test('another side has to wait for the district being built', () async {
    final (_, n) = await ready();
    await n.startDistrict(DistrictSide.east, 60);
    await finish(n, 60);
    await expectLater(n.startDistrict(DistrictSide.west, 60), throwsStateError);
    await n.startDistrict(DistrictSide.east, 60); // the same one goes on
  });

  test(
    'giving up loses the minutes toward the next row, never the land',
    () async {
      final (c, n) = await ready();
      await n.startDistrict(DistrictSide.east, 90);
      await finish(n, 90); // one row and 30 minutes toward the next
      await n.startDistrict(DistrictSide.east, 60);
      final parcels = _state(c).town.parcels;
      await n.abandon();
      final town = _state(c).town;
      expect(town.districtProject!.progress, 60);
      expect(town.parcels, parcels);
      expect(_state(c).lastResult!.outcome, SessionOutcome.failed);
      expect(_state(c).lastResult!.districtRows, 1);
    },
  );

  test('the district is done after 8 hours', () async {
    final (c, n) = await ready();
    for (var i = 0; i < 4; i++) {
      await n.startDistrict(DistrictSide.north, 120);
      if (i < 3) await finish(n, 120);
    }
    _clock.advance(const Duration(minutes: 121));
    await n.tick();
    final town = _state(c).town;
    expect(town.parcels, hasLength(64));
    expect(town.districts, [DistrictSide.north]);
    expect(town.districtProject, isNull);
    expect(_state(c).lastResult!.districtFinished, isTrue);
  });

  test('short test sessions count the minutes you chose, not 1', () async {
    final (c, n) = await ready();
    c.read(shortSessionsProvider.notifier).toggle();
    await n.startDistrict(DistrictSide.south, 120);
    expect(_state(c).active!.plannedMinutes, 1);
    expect(_state(c).active!.creditMinutes, 120);
    _clock.advance(const Duration(minutes: 2));
    await n.tick();
    expect(_state(c).town.parcels, hasLength(16)); // two rows
  });

  test(
    'giving up near the end of a 120-minute test keeps the first row',
    () async {
      final (c, n) = await ready();
      c.read(shortSessionsProvider.notifier).toggle();
      await n.startDistrict(DistrictSide.north, 120);
      _clock.advance(const Duration(seconds: 55)); // 55 of 60 seconds
      await n.abandon();
      final town = _state(c).town;
      expect(town.parcels, districtRow(DistrictSide.north, 0, 0)); // one row
      expect(town.districtProject!.progress, 60);
      final r = _state(c).lastResult!;
      expect(r.outcome, SessionOutcome.failed);
      expect(r.districtRows, 1);
    },
  );

  test('giving up before the first hour earns no row', () async {
    final (c, n) = await ready();
    await n.startDistrict(DistrictSide.north, 120);
    _clock.advance(const Duration(minutes: 59));
    await n.abandon();
    expect(_state(c).town.parcels, isEmpty);
    expect(_state(c).town.districtProject!.progress, 0);
  });

  test('giving up 90 minutes into a 120-minute run keeps one row', () async {
    final (c, n) = await ready();
    await n.startDistrict(DistrictSide.north, 120);
    _clock.advance(const Duration(minutes: 90));
    await n.abandon();
    expect(_state(c).town.parcels, hasLength(8)); // 90 min: one row
  });

  test('no district while a session is running', () async {
    final (_, n) = await ready();
    await n.startDistrict(DistrictSide.east, 60);
    await expectLater(n.startDistrict(DistrictSide.east, 60), throwsStateError);
  });
}
