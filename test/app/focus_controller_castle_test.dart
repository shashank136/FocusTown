import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/app/placement.dart';
import 'package:focus_town/app/providers.dart';
import 'package:focus_town/data/database.dart';
import 'package:focus_town/data/mappers.dart';
import 'package:focus_town/domain/building_tier.dart';
import 'package:focus_town/domain/landmark.dart';
import 'package:focus_town/domain/plot_grid.dart';
import 'package:focus_town/domain/testing/fake_clock.dart';
import 'package:focus_town/domain/town.dart';
import 'package:focus_town/platform/testing/fake_live_status_sink.dart';
import 'package:focus_town/platform/testing/fake_notifier.dart';

late AppDatabase _db;
late FakeClock _clock;

int _at(int gx, int gy) => plotAtCell(gx, gy, const [])!;

// A town with the workers and plots for a castle and a hut in the way.
Future<ProviderContainer> _ready({
  List<TownBuilding> extra = const [],
  int xp = 0,
}) async {
  final seed = TownState.initial().copyWith(
    workers: 8,
    plotsUnlocked: 12,
    buildings: extra,
    xp: xp,
  );
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

  test('a castle starts on a free block and finishes standing on it', () async {
    final c = await _ready();
    final block = _at(0, 0);
    final n = c.read(focusControllerProvider.notifier);
    await n.start(120, plotIndex: block);
    expect(
      c.read(focusControllerProvider).requireValue.active!.plotIndex,
      block,
    );
    _clock.advance(const Duration(minutes: 121));
    await n.tick();
    final town = c.read(focusControllerProvider).requireValue.town;
    final castle = town.buildings.singleWhere(
      (b) => b.tier == BuildingTier.castle,
    );
    expect(castle.plotIndex, block);
  });

  test('a castle cannot start on a block with something on it', () async {
    final hut = TownBuilding(
      id: 'h',
      tier: BuildingTier.hut,
      status: BuildingStatus.complete,
      plotIndex: _at(1, 1),
    );
    final c = await _ready(extra: [hut]);
    final n = c.read(focusControllerProvider.notifier);
    await expectLater(n.start(120, plotIndex: _at(0, 0)), throwsStateError);
    await expectLater(n.start(120, plotIndex: _at(3, 0)), throwsStateError);
    await n.start(120, plotIndex: _at(0, 4)); // a free block
    expect(c.read(focusControllerProvider).requireValue.active, isNotNull);
  });

  test('choosing a plot for a castle accepts only free blocks', () async {
    final hut = TownBuilding(
      id: 'h',
      tier: BuildingTier.hut,
      status: BuildingStatus.complete,
      plotIndex: _at(1, 1),
    );
    final c = await _ready(extra: [hut]);
    final p = c.read(placementProvider.notifier)
      ..begin(120)
      ..select(_at(0, 0)); // the hut stands in this block
    expect(c.read(placementProvider)!.plot, isNull);
    p.select(_at(0, 4));
    expect(c.read(placementProvider)!.plot, _at(0, 4));
    // The same plot is fine for a hut.
    p
      ..cancel()
      ..begin(10)
      ..select(_at(0, 0));
    expect(c.read(placementProvider)!.plot, _at(0, 0));
  });

  test('a landmark is placed on the free block the user chooses', () async {
    final hut = TownBuilding(
      id: 'h',
      tier: BuildingTier.hut,
      status: BuildingStatus.complete,
      plotIndex: _at(1, 1),
    );
    final c = await _ready(extra: [hut], xp: 300);
    final p = c.read(placementProvider.notifier)
      ..begin(60, landmark: Landmark.eiffel)
      ..select(_at(0, 0)); // the hut stands in this block
    expect(c.read(placementProvider)!.plot, isNull);
    p.select(_at(0, 4));
    expect(c.read(placementProvider)!.plot, _at(0, 4));
    expect(c.read(placementProvider)!.tier, BuildingTier.castle);
    await p.confirm();
    final town = c.read(focusControllerProvider).requireValue.town;
    final project = town.buildings.singleWhere(
      (b) => b.landmark == Landmark.eiffel,
    );
    expect(project.plotIndex, _at(0, 4));
    final s = c.read(focusControllerProvider).requireValue.active!;
    expect(s.landmark, Landmark.eiffel);
    expect(s.plannedMinutes, 60);
    expect(c.read(placementProvider), isNull);
  });
}
