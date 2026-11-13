import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/domain/building_tier.dart';
import 'package:focus_town/domain/parcel.dart';
import 'package:focus_town/domain/plot_grid.dart';
import 'package:focus_town/domain/session.dart';
import 'package:focus_town/domain/time_stamp.dart';
import 'package:focus_town/domain/town.dart';
import 'package:focus_town/domain/town_rules.dart';

// A forest square of the starting island that is not near the starter house.
const _cell = Parcel(5, 5, garden: true);
final int _plot = plotAtCell(5, 5, const [])!;

Session _session(Parcel p) => Session(
  id: 'g',
  plannedMinutes: 15,
  tier: BuildingTier.hut,
  workersAssigned: 0,
  state: SessionState.running,
  startedAt: TimeStamp(DateTime(2026), Duration.zero),
  land: p,
);

void main() {
  test('a garden session takes 15 minutes', () {
    expect(TownRules.gardenMinutes, 15);
    final town = TownState.initial();
    expect(TownRules.landMinutesFor(town, _cell), 15);
    expect(
      TownRules.landMinutesFor(town, const Parcel(-1, 3)),
      TownRules.landMinutes(0),
    );
  });

  test('a free forest square of the island can become a garden', () {
    expect(TownRules.canClaim(TownState.initial(), _cell), isTrue);
  });

  test('not a square with a building, a ruin or a garden on it', () {
    final hut = TownBuilding(
      id: 'h',
      tier: BuildingTier.hut,
      status: BuildingStatus.complete,
      plotIndex: _plot,
    );
    final ruin = TownBuilding(
      id: 'r',
      tier: BuildingTier.hut,
      status: BuildingStatus.ruin,
      plotIndex: _plot,
    );
    for (final b in [hut, ruin]) {
      final town = TownState.initial().copyWith(buildings: [b]);
      expect(TownRules.canClaim(town, _cell), isFalse);
    }
    final done = TownRules.applyLandCompleted(
      TownState.initial(),
      _session(_cell),
    );
    expect(TownRules.canClaim(done, _cell), isFalse);
  });

  test(
    'a square of the island is only ever a garden, never claimed as land',
    () {
      expect(
        TownRules.canClaim(TownState.initial(), const Parcel(5, 5)),
        isFalse,
      );
    },
  );

  test('the garden stops being a plot: nothing can be built on it', () {
    final done = TownRules.applyLandCompleted(
      TownState.initial(),
      _session(_cell),
    );
    expect(done.parcels, [_cell]);
    expect(plotAtCell(5, 5, done.parcels), isNull);
    expect(TownRules.occupied(done), contains(_plot));
    expect(TownRules.isPlotFree(done, _plot), isFalse);
    expect(TownRules.isPlotFree(TownState.initial(), _plot), isTrue);
    // The number of plots is still the island's 64.
    expect(
      TownRules.plotCountOf(done),
      TownRules.plotCountOf(TownState.initial()),
    );
  });

  test('a castle block cannot include the garden', () {
    final done = TownRules.applyLandCompleted(
      TownState.initial(),
      _session(_cell),
    );
    // Cell (4,4) with its neighbours (5,4), (4,5), (5,5): the garden is one.
    final anchor = plotAtCell(4, 4, done.parcels)!;
    expect(footprintOf(BuildingTier.castle, anchor, done.parcels), isNull);
  });
}
