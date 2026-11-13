import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/domain/building_tier.dart';
import 'package:focus_town/domain/parcel.dart';
import 'package:focus_town/domain/session.dart';
import 'package:focus_town/domain/time_stamp.dart';
import 'package:focus_town/domain/town.dart';
import 'package:focus_town/game/world/block_material.dart';
import 'package:focus_town/game/world/garden.dart';
import 'package:focus_town/game/world/town_world_builder.dart';
import 'package:focus_town/game/world/voxel_world.dart';

Set<(int, int, int, Object)> _blocks(VoxelWorld w) => {
  for (final b in w.blocks) (b.x, b.y, b.z, b.material),
};

TownState _town(List<Parcel> parcels) => TownState(
  workers: 3,
  plotsUnlocked: 6,
  buildings: const [],
  queue: const [],
  inRecoveryMode: false,
  parcels: parcels,
);

void main() {
  test('there are four gardens, all different, and all stay on their land', () {
    final worlds = <Set<(int, int, int, Object)>>[];
    for (var v = 0; v < kGardenLooks; v++) {
      final w = VoxelWorld();
      buildGarden(w, 10, 10, v);
      expect(w.blockCount, greaterThan(0));
      for (final b in w.blocks) {
        expect(b.x, inInclusiveRange(10, 16));
        expect(b.y, inInclusiveRange(10, 16));
      }
      worlds.add(_blocks(w));
    }
    expect(worlds.toSet(), hasLength(kGardenLooks));
  });

  test('every garden is colourful: flowers of at least four colours', () {
    for (var v = 0; v < kGardenLooks; v++) {
      final w = VoxelWorld();
      buildGarden(w, 10, 10, v);
      final flowers = [
        for (final b in w.blocks)
          if (flowerColors.contains(b.material)) b.material,
      ];
      expect(flowers.length, greaterThanOrEqualTo(8), reason: 'garden $v');
      expect(
        flowers.toSet().length,
        greaterThanOrEqualTo(4),
        reason: 'garden $v',
      );
    }
  });

  test('a garden parcel is drawn as a garden, not as forest', () {
    const garden = Parcel(-1, 3, garden: true);
    const forest = Parcel(-1, 3);
    final g = buildTownWorld(_town([garden]));
    final f = buildTownWorld(_town([forest]));
    expect(_blocks(g), isNot(_blocks(f)));
    expect(g.get(-4, 24, 0), isNotNull); // ground
  });

  test('a land session shows its parcel as ground while it runs', () {
    final session = Session(
      id: 'l',
      plannedMinutes: 25,
      tier: BuildingTier.hut,
      workersAssigned: 0,
      state: SessionState.running,
      startedAt: TimeStamp(DateTime(2026), Duration.zero),
      land: const Parcel(-1, 3),
    );
    final w = buildTownWorld(_town(const []), active: session);
    expect(w.get(-4, 24, 0), isNotNull);
    expect(w.get(-4, 24, -1), isNotNull);
  });

  test('the site of a land session is its parcel', () {
    final session = Session(
      id: 'l',
      plannedMinutes: 25,
      tier: BuildingTier.hut,
      workersAssigned: 0,
      state: SessionState.running,
      startedAt: TimeStamp(DateTime(2026), Duration.zero),
      land: const Parcel(-1, 3),
    );
    final plot = sessionSitePlot(_town(const []), session);
    expect((plot.originX, plot.originY), (-4, 24));
  });
}
