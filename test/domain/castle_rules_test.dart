import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/domain/building_tier.dart';
import 'package:focus_town/domain/parcel.dart';
import 'package:focus_town/domain/plot_grid.dart';
import 'package:focus_town/domain/session.dart';
import 'package:focus_town/domain/session_engine.dart';
import 'package:focus_town/domain/time_stamp.dart';
import 'package:focus_town/domain/town.dart';
import 'package:focus_town/domain/town_rules.dart';

int _at(int gx, int gy) => plotAtCell(gx, gy, const [])!;

TownBuilding _b(
  int plot,
  BuildingTier tier, [
  BuildingStatus status = BuildingStatus.complete,
]) => TownBuilding(id: 'b$plot', tier: tier, status: status, plotIndex: plot);

TownState _town({
  int unlocked = 12,
  List<TownBuilding> buildings = const [],
  List<QueuedBuilding> queue = const [],
  List<Parcel> parcels = const [],
}) => TownState(
  workers: 8,
  plotsUnlocked: unlocked,
  buildings: buildings,
  queue: queue,
  inRecoveryMode: false,
  parcels: parcels,
);

// A hut on every other plot of the starting island: free plots, no free block.
TownState _crowded() => _town(
  buildings: [
    for (var gx = 0; gx < 8; gx += 1)
      for (var gy = 0; gy < 8; gy += 1)
        if ((gx + gy).isEven) _b(_at(gx, gy), BuildingTier.hut),
  ],
);

Session _castle({int? plot}) => SessionEngine.start(
  id: 'c',
  minutes: 120,
  workersAvailable: 8,
  now: TimeStamp(DateTime(2026, 11, 11, 9), Duration.zero),
  plotIndex: plot,
);

void main() {
  final block = _at(0, 0); // covers (0,0) (1,0) (0,1) (1,1)

  test('a castle counts as four plots used', () {
    final town = _town(buildings: [_b(block, BuildingTier.castle)]);
    expect(TownRules.occupied(town), {block, _at(1, 0), _at(0, 1), _at(1, 1)});
  });

  test('a castle needs a free block, a hut just a free plot', () {
    final crowded = _crowded();
    expect(TownRules.hasRoom(crowded), isTrue);
    expect(TownRules.hasRoom(crowded, BuildingTier.castle), isFalse);
    expect(TownRules.hasRoom(_town(), BuildingTier.castle), isTrue);
  });

  test('a castle needs a free block, even with room', () {
    final town = _town(buildings: [_b(_at(1, 1), BuildingTier.hut)]);
    expect(TownRules.isPlotFree(town, block, BuildingTier.castle), isFalse);
    expect(TownRules.isPlotFree(town, _at(0, 4), BuildingTier.castle), isTrue);
    expect(TownRules.isPlotFree(town, _at(3, 0), BuildingTier.castle), isFalse);
    // A hut can still use the plots next to it.
    expect(TownRules.isPlotFree(town, _at(0, 0)), isTrue);
  });

  test('the lowest free block is the automatic site', () {
    final town = _town();
    final anchor = TownRules.nextFreePlot(town, BuildingTier.castle)!;
    expect(footprintOf(BuildingTier.castle, anchor, const []), isNotNull);
    // It is the first anchor in plot order that fits.
    for (var i = 0; i < anchor; i++) {
      expect(
        footprintOf(BuildingTier.castle, i, const []),
        isNull,
        reason: '$i',
      );
    }
  });

  test('a finished castle stands on the chosen block', () {
    final done = _castle(plot: block).copyWith(state: SessionState.completed);
    final town = TownRules.applyCompleted(_town(), done);
    expect(town.buildings.single.plotIndex, block);
    expect(town.buildings.single.tier, BuildingTier.castle);
  });

  test('a castle with no free block waits in the queue, then is placed', () {
    final crowded = _crowded();
    final done = _castle().copyWith(state: SessionState.completed);
    final queued = TownRules.applyCompleted(crowded, done);
    expect(queued.queue.single.tier, BuildingTier.castle);
    expect(
      queued.buildings.where((b) => b.tier == BuildingTier.castle),
      isEmpty,
    );
  });

  test('a queued castle waits for a block, then is placed', () {
    const queue = [QueuedBuilding(id: 'q', tier: BuildingTier.castle)];
    final placed = TownRules.placeQueued(_town(queue: queue));
    expect(placed.queue, isEmpty);
    expect(placed.buildings.single.tier, BuildingTier.castle);
    final waiting = TownRules.placeQueued(_crowded().copyWith(queue: queue));
    expect(waiting.queue, hasLength(1));
  });

  test('a failed castle leaves one ruin over its block', () {
    final failed = _castle(plot: block).copyWith(
      state: SessionState.failed,
      outcomeReason: OutcomeReason.abandoned,
    );
    final town = TownRules.applyFailed(_town(), failed);
    final ruin = town.buildings.single;
    expect(ruin.status, BuildingStatus.ruin);
    expect(ruin.tier, BuildingTier.castle);
    expect(TownRules.occupied(town), hasLength(4));
  });

  test('with no block left the failed castle leaves a one-plot ruin', () {
    final crowded = _crowded();
    final failed = _castle().copyWith(
      state: SessionState.failed,
      outcomeReason: OutcomeReason.abandoned,
    );
    final town = TownRules.applyFailed(crowded, failed);
    expect(town.buildings.length, crowded.buildings.length + 1);
    expect(town.buildings.last.tier, BuildingTier.hut);
    expect(town.buildings.last.status, BuildingStatus.ruin);
  });

  test('any of the four plots of a castle ruin can be repaired, all clear', () {
    final town = _town(
      buildings: [_b(block, BuildingTier.castle, BuildingStatus.ruin)],
    );
    for (final p in [block, _at(1, 0), _at(0, 1), _at(1, 1)]) {
      expect(TownRules.canRepair(town, p), isTrue);
    }
    expect(TownRules.canRepair(town, _at(2, 0)), isFalse);
    final repair = SessionEngine.startRepair(
      id: 'r',
      plot: _at(1, 1),
      now: TimeStamp(DateTime(2026, 11, 11, 9), Duration.zero),
    );
    final cleared = TownRules.applyRepairCompleted(town, repair);
    expect(cleared.buildings, isEmpty);
    expect(TownRules.occupied(cleared), isEmpty);
  });
}
