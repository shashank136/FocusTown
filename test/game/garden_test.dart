import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/domain/building_tier.dart';
import 'package:focus_town/domain/district.dart';
import 'package:focus_town/domain/parcel.dart';
import 'package:focus_town/domain/session.dart';
import 'package:focus_town/domain/session_engine.dart';
import 'package:focus_town/domain/time_stamp.dart';
import 'package:focus_town/domain/town.dart';
import 'package:focus_town/domain/town_rules.dart';
import 'package:focus_town/game/world/block_material.dart';
import 'package:focus_town/game/world/garden.dart';
import 'package:focus_town/game/world/plot_layout.dart';
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

  test('the ground of a garden is not grass: it is flowers, path or water', () {
    for (var v = 0; v < kGardenLooks; v++) {
      final w = VoxelWorld()..fill(10, 10, 0, 16, 16, 0, Blocks.grass);
      buildGarden(w, 10, 10, v);
      for (var x = 10; x <= 16; x++) {
        for (var y = 10; y <= 16; y++) {
          expect(w.get(x, y, 0), isNot(Blocks.grass), reason: 'garden $v');
        }
      }
    }
  });

  test('there is nothing green in a garden: no leaves, no grass', () {
    for (var v = 0; v < kGardenLooks; v++) {
      final w = VoxelWorld();
      buildGarden(w, 10, 10, v);
      for (final b in w.blocks) {
        expect(b.material, isNot(Blocks.leaves), reason: 'garden $v');
        expect(b.material, isNot(Blocks.grass), reason: 'garden $v');
      }
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

  test('a forest square turned into a garden is a garden, not forest', () {
    const cell = Parcel(5, 5, garden: true);
    final w = buildTownWorld(_town(const [cell]));
    final ox = parcelOrigin(5);
    final oy = parcelOrigin(5);
    expect(flowerColors, contains(w.get(ox + 3, oy + 3, 0)));
    // No forest tree stands in it (a tree canopy is at height 3 or more).
    for (final b in w.blocks) {
      if (b.z >= 3 && b.x >= ox && b.x < ox + 7 && b.y >= oy && b.y < oy + 7) {
        expect(
          b.material,
          isNot(Blocks.leaves),
          reason: '${b.x},${b.y},${b.z}',
        );
      }
    }
  });

  test('there are flower bushes in and around a garden, no trees', () {
    const cell = Parcel(5, 5, garden: true);
    final w = buildTownWorld(_town(const [cell]));
    final ox = parcelOrigin(5);
    final oy = parcelOrigin(5);
    var bushes = 0;
    // The forest trees in the garden and in the 3 tiles in front of it
    // (towards the viewer) are flower bushes instead.
    for (final b in w.blocks) {
      if (b.x >= ox && b.x < ox + 10 && b.y >= oy && b.y < oy + 10) {
        expect(
          b.material,
          isNot(Blocks.leaves),
          reason: '${b.x},${b.y},${b.z}',
        );
        expect(b.material, isNot(Blocks.log), reason: '${b.x},${b.y},${b.z}');
        if (Blocks.bushes.contains(b.material)) bushes++;
      }
    }
    expect(bushes, greaterThan(0));
    // The forest elsewhere stays trees.
    expect(w.blocks.where((b) => b.material == Blocks.leaves), isNotEmpty);
  });

  test('the garden trees are flower bushes: low, rounded, in many colours', () {
    for (final v in [0, 2]) {
      final w = VoxelWorld();
      buildGarden(w, 10, 10, v);
      final blocks = w.blocks.toList();
      for (final b in blocks) {
        expect(b.material, isNot(Blocks.leaves), reason: 'garden $v');
        expect(b.material, isNot(Blocks.log), reason: 'garden $v');
        expect(b.z, lessThanOrEqualTo(2), reason: 'low: garden $v');
      }
      final bush = blocks.where((b) => Blocks.bushes.contains(b.material));
      expect(bush.map((b) => b.material).toSet().length, greaterThan(1));
      // Each is 3 x 3 with a bump on top: 9 blocks at z = 1 and 5 at z = 2.
      final count = v == 0 ? 2 : 4;
      expect(bush.where((b) => b.z == 2).length, 5 * count);
    }
  });

  test('every garden look has flower bushes and no tree or post', () {
    for (var v = 0; v < kGardenLooks; v++) {
      final w = VoxelWorld();
      buildGarden(w, 10, 10, v);
      final blocks = w.blocks.toList();
      for (final b in blocks) {
        expect(b.material, isNot(Blocks.log), reason: 'garden $v');
        expect(b.material, isNot(Blocks.leaves), reason: 'garden $v');
        expect(b.z, lessThanOrEqualTo(2), reason: 'garden $v');
      }
      // Each bush has a bump of five on top: at least two bushes.
      final bumps = blocks.where(
        (b) => Blocks.bushes.contains(b.material) && b.z == 2,
      );
      expect(bumps.length, greaterThanOrEqualTo(10), reason: 'garden $v');
    }
  });

  test('a forest square turned into a garden has the bushes, and no tree', () {
    // Squares of the island whose look is a pond or flower beds.
    for (final (gx, gy) in [(5, 5), (4, 5), (6, 5), (5, 6)]) {
      final cell = Parcel(gx, gy, garden: true);
      final w = buildTownWorld(_town([cell]));
      final ox = parcelOrigin(gx);
      final oy = parcelOrigin(gy);
      var bush = 0;
      for (final b in w.blocks) {
        if (b.x < ox || b.x >= ox + 7 || b.y < oy || b.y >= oy + 7) continue;
        expect(b.material, isNot(Blocks.leaves), reason: '$gx,$gy');
        expect(b.material, isNot(Blocks.log), reason: '$gx,$gy');
        if (Blocks.bushes.contains(b.material)) bush++;
      }
      expect(bush, greaterThan(10), reason: '$gx,$gy');
    }
  });

  test('while a garden session runs its square is already a garden', () {
    const cell = Parcel(5, 5, garden: true);
    final session = Session(
      id: 'g',
      plannedMinutes: 15,
      tier: BuildingTier.hut,
      workersAssigned: 0,
      state: SessionState.running,
      startedAt: TimeStamp(DateTime(2026), Duration.zero),
      land: cell,
    );
    final w = buildTownWorld(_town(const []), active: session);
    final ox = parcelOrigin(5);
    final oy = parcelOrigin(5);
    expect(flowerColors, contains(w.get(ox + 3, oy + 3, 0)));
    for (final b in w.blocks) {
      if (b.z >= 3 && b.x >= ox && b.x < ox + 7 && b.y >= oy && b.y < oy + 7) {
        expect(
          b.material,
          isNot(Blocks.leaves),
          reason: '${b.x},${b.y},${b.z}',
        );
      }
    }
  });

  test('a district session is sited on the row being built', () {
    final town = TownRules.beginDistrict(
      TownState.initial().copyWith(xp: 6000),
      DistrictSide.east,
    )!;
    final session = SessionEngine.startDistrict(
      id: 'd',
      side: DistrictSide.east,
      minutes: 60,
      now: TimeStamp(DateTime(2026), Duration.zero),
    );
    final plot = sessionSitePlot(town, session);
    // The first row of the east district: parcel column 8, row 0.
    expect((plot.originX, plot.originY), (parcelOrigin(8), parcelOrigin(0)));
    final later = TownRules.applyDistrictMinutes(town, 120);
    final next = sessionSitePlot(later, session);
    expect((next.originX, next.originY), (parcelOrigin(10), parcelOrigin(0)));
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
