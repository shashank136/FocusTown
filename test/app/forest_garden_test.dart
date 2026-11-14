import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/app/placement.dart';
import 'package:focus_town/app/providers.dart';
import 'package:focus_town/data/database.dart';
import 'package:focus_town/data/mappers.dart';
import 'package:focus_town/domain/parcel.dart';
import 'package:focus_town/domain/plot_grid.dart';
import 'package:focus_town/domain/testing/fake_clock.dart';
import 'package:focus_town/domain/town.dart';
import 'package:focus_town/platform/testing/fake_live_status_sink.dart';
import 'package:focus_town/platform/testing/fake_notifier.dart';

late AppDatabase _db;
late FakeClock _clock;

const _cell = Parcel(5, 5, garden: true);
final int _plot = plotAtCell(5, 5, const [])!;

Future<ProviderContainer> _ready() async {
  final seed = TownState.initial();
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
  final c = ProviderContainer(
    overrides: [
      clockProvider.overrideWithValue(_clock),
      databaseProvider.overrideWithValue(_db),
      notifierProvider.overrideWithValue(FakeNotifier()),
      liveStatusSinkProvider.overrideWithValue(FakeLiveStatusSink()),
    ],
  );
  addTearDown(c.dispose);
  await c.read(focusControllerProvider.future);
  return c;
}

void main() {
  setUp(() {
    _clock = FakeClock();
    _db = AppDatabase(NativeDatabase.memory());
    addTearDown(_db.close);
  });

  test(
    'a garden session lasts 15 minutes and makes the square a garden',
    () async {
      final c = await _ready();
      final n = c.read(focusControllerProvider.notifier);
      await n.startLand(_cell);
      final s = c.read(focusControllerProvider).requireValue.active!;
      expect(s.land, _cell);
      expect(s.plannedMinutes, 15);
      _clock.advance(const Duration(minutes: 16));
      await n.tick();
      final town = c.read(focusControllerProvider).requireValue.town;
      expect(town.parcels, [_cell]);
      expect(plotAtCell(5, 5, town.parcels), isNull);
    },
  );

  test('a square with a building on it cannot become a garden', () async {
    final c = await _ready();
    final used = c
        .read(focusControllerProvider)
        .requireValue
        .town
        .buildings
        .single
        .plotIndex;
    final cell = kBaseCells[used];
    await expectLater(
      c
          .read(focusControllerProvider.notifier)
          .startLand(Parcel(cell.$1, cell.$2, garden: true)),
      throwsStateError,
    );
  });

  test(
    'choosing a forest square: only free squares of the island count',
    () async {
      final c = await _ready();
      final used = c
          .read(focusControllerProvider)
          .requireValue
          .town
          .buildings
          .single
          .plotIndex;
      final p = c.read(placementProvider.notifier)..beginGarden();
      final start = c.read(placementProvider)!;
      expect(start.minutes, 15);
      expect(start.garden, isTrue);
      p.select(used); // the starter house
      expect(c.read(placementProvider)!.plot, isNull);
      p.select(kBaseCells.length); // not a square of the island
      expect(c.read(placementProvider)!.plot, isNull);
      p.select(_plot);
      expect(c.read(placementProvider)!.plot, _plot);
      await p.confirm();
      final s = c.read(focusControllerProvider).requireValue.active!;
      expect(s.land, _cell);
      expect(c.read(placementProvider), isNull);
    },
  );
}
