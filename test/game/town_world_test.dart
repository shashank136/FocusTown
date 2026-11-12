import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/domain/building_look.dart';
import 'package:focus_town/domain/building_tier.dart';
import 'package:focus_town/domain/session.dart';
import 'package:focus_town/domain/time_stamp.dart';
import 'package:focus_town/domain/town.dart';
import 'package:focus_town/game/world/block_material.dart';
import 'package:focus_town/game/world/building_defs.dart';
import 'package:focus_town/game/world/plot_layout.dart';
import 'package:focus_town/game/world/town_world_builder.dart';
import 'package:focus_town/game/world/voxel_world.dart';

TownBuilding _b(
  int plot,
  BuildingTier tier, [
  BuildingStatus status = BuildingStatus.complete,
]) => TownBuilding(id: 'b$plot', tier: tier, status: status, plotIndex: plot);

TownState _town({
  List<TownBuilding> buildings = const [],
  List<QueuedBuilding> queue = const [],
  int plots = 6,
}) => TownState(
  workers: 3,
  plotsUnlocked: plots,
  buildings: buildings,
  queue: queue,
  inRecoveryMode: false,
);

Session _hut() => Session(
  id: 's',
  plannedMinutes: 10,
  tier: BuildingTier.hut,
  workersAssigned: 1,
  state: SessionState.running,
  startedAt: TimeStamp(DateTime(2026), Duration.zero),
);

// Blocks above the ground inside a plot.
int _above(VoxelWorld w, Plot p) => w.blocks
    .where(
      (b) =>
          b.z >= 1 &&
          b.x >= p.originX &&
          b.x < p.originX + 7 &&
          b.y >= p.originY &&
          b.y < p.originY + 7,
    )
    .length;

// Tree leaves inside a plot: a plot with a building or site has none.
int _leaves(VoxelWorld w, Plot p) => w.blocks
    .where(
      (b) =>
          b.material == Blocks.leaves &&
          b.x >= p.originX &&
          b.x < p.originX + 7 &&
          b.y >= p.originY &&
          b.y < p.originY + 7,
    )
    .length;

Set<(int, int, int, BlockMaterial)> _all(VoxelWorld w) => {
  for (final b in w.blocks) (b.x, b.y, b.z, b.material),
};

void main() {
  test('ground: dirt under grass or road everywhere', () {
    final w = buildTownWorld(_town());
    for (var x = 0; x < 64; x += 7) {
      for (var y = 0; y < 64; y += 5) {
        expect(w.get(x, y, -1), Blocks.dirt);
        expect(w.has(x, y, 0), isTrue);
      }
    }
    expect(w.get(31, 10, 0), Blocks.path); // road
    expect(w.get(10, 32, 0), Blocks.path); // road
    expect(w.get(10, 10, 0), Blocks.grass);
  });

  test('initial town has a building on plot 0 and forest on every other', () {
    final w = buildTownWorld(TownState.initial());
    expect(_above(w, kPlots[0]), greaterThan(0));
    expect(_leaves(w, kPlots[0]), 0);
    for (final p in kPlots.skip(1)) {
      expect(_leaves(w, p), greaterThan(0), reason: 'plot ${p.index}');
    }
  });

  test('a 3-building town fills exactly those plots', () {
    final w = buildTownWorld(
      _town(
        buildings: [
          _b(0, BuildingTier.house),
          _b(2, BuildingTier.workshop),
          _b(4, BuildingTier.tower),
        ],
      ),
    );
    for (final p in kPlots) {
      final built = {0, 2, 4}.contains(p.index);
      expect(_leaves(w, p) == 0, built, reason: 'plot ${p.index}');
      if (built) expect(_above(w, p), greaterThan(0));
    }
  });

  test('a complete building is drawn at its final stage', () {
    final w = buildTownWorld(_town(buildings: [_b(1, BuildingTier.castle)]));
    final direct = VoxelWorld();
    buildTier(
      direct,
      BuildingTier.castle,
      kPlots[1].originX,
      kPlots[1].originY,
      stage: 12,
      look: lookIndex('b1'),
    );
    expect(_above(w, kPlots[1]), direct.blockCount);
  });

  test('a building is drawn with the look its id gives', () {
    String idWith(int look) =>
        [for (var i = 0; i < 20; i++) 'b$i']
            .firstWhere((id) => lookIndex(id) == look);
    TownBuilding at(String id) => TownBuilding(
      id: id,
      tier: BuildingTier.castle,
      status: BuildingStatus.complete,
      plotIndex: 1,
    );
    int count(String id) =>
        _above(buildTownWorld(_town(buildings: [at(id)])), kPlots[1]);
    for (final look in [0, 1]) {
      final direct = VoxelWorld();
      buildTier(
        direct,
        BuildingTier.castle,
        kPlots[1].originX,
        kPlots[1].originY,
        stage: 12,
        look: look,
      );
      expect(count(idWith(look)), direct.blockCount, reason: 'look $look');
    }
  });

  test('a ruin draws ruin blocks with char', () {
    final w = buildTownWorld(
      _town(buildings: [_b(1, BuildingTier.house, BuildingStatus.ruin)]),
    );
    final p = kPlots[1];
    expect(
      w.blocks.any(
        (b) =>
            b.material == Blocks.char &&
            b.x >= p.originX &&
            b.x < p.originX + 7 &&
            b.y >= p.originY &&
            b.y < p.originY + 7,
      ),
      isTrue,
    );
    expect(_above(w, p), 18);
  });

  test('queued buildings add nothing', () {
    final without = buildTownWorld(_town());
    final withQueue = buildTownWorld(
      _town(
        queue: [const QueuedBuilding(id: 'q', tier: BuildingTier.castle)],
      ),
    );
    expect(_all(withQueue), _all(without));
  });

  group('active session', () {
    test(
      'a hut at progress 0 is stage 1 with scaffold on the next free plot',
      () {
        final town = TownState.initial(); // plot 0 taken, so plot 1 is free
        final w = buildTownWorld(town, active: _hut());
        final p = kPlots[1];
        expect(w.get(p.originX, p.originY, 4), Blocks.log); // scaffold post
        final direct = VoxelWorld();
        buildTier(
          direct,
          BuildingTier.hut,
          p.originX,
          p.originY,
          stage: 1,
          scaffold: true,
        );
        expect(_above(w, p), direct.blockCount);
      },
    );

    test('progress 1.0 draws the final stage without scaffold', () {
      final w = buildTownWorld(
        TownState.initial(),
        active: _hut(),
        progress: 1,
      );
      final p = kPlots[1];
      expect(w.has(p.originX, p.originY, 1), isFalse); // no scaffold post
      final direct = VoxelWorld();
      buildTier(direct, BuildingTier.hut, p.originX, p.originY, stage: 4);
      expect(_above(w, p), direct.blockCount);
    });

    test('with no room left the site is the first unused plot', () {
      final town = _town(
        buildings: [for (var i = 0; i < 6; i++) _b(i, BuildingTier.hut)],
      );
      final w = buildTownWorld(town, active: _hut());
      expect(_above(w, kPlots[6]), greaterThan(0));
      expect(_leaves(w, kPlots[6]), 0); // cleared for the site
      expect(_leaves(w, kPlots[7]), greaterThan(0)); // still forest
    });
  });

  test('only plots in use get a path border', () {
    final w = buildTownWorld(_town(buildings: [_b(0, BuildingTier.hut)]));
    final used = kPlots[0];
    final other = kPlots[1];
    expect(w.get(used.originX, used.originY + 3, 0), Blocks.path);
    expect(w.get(used.originX + 3, used.originY, 0), Blocks.path);
    expect(w.get(used.originX + 3, used.originY + 3, 0), Blocks.grass);
    expect(w.get(other.originX, other.originY + 3, 0), Blocks.grass);
  });

  test('two builds of the same town are identical', () {
    final town = _town(buildings: [_b(0, BuildingTier.house)]);
    expect(
      _all(buildTownWorld(town, active: _hut(), progress: 0.5)),
      _all(buildTownWorld(town, active: _hut(), progress: 0.5)),
    );
  });
}
