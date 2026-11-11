import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/domain/building_tier.dart';
import 'package:focus_town/domain/town.dart';
import 'package:focus_town/game/world/active_site.dart';
import 'package:focus_town/game/world/block_material.dart';
import 'package:focus_town/game/world/forest.dart';
import 'package:focus_town/game/world/plot_layout.dart';
import 'package:focus_town/game/world/town_world_builder.dart';
import 'package:focus_town/game/world/voxel_world.dart';

// Blocks above the ground inside plot [p].
int _above(VoxelWorld w, Plot p) => w.blocks
    .where(
      (b) =>
          b.z >= 1 &&
          b.x >= p.originX &&
          b.x < p.originX + kPlotSize &&
          b.y >= p.originY &&
          b.y < p.originY + kPlotSize,
    )
    .length;

VoxelWorld _forest([Set<int> cleared = const {}]) {
  final w = VoxelWorld();
  buildForest(w, cleared: cleared);
  return w;
}

void main() {
  test('every plot of the island has trees', () {
    final w = _forest();
    for (final p in kPlots) {
      expect(_above(w, p), greaterThan(30), reason: 'plot ${p.index}');
    }
  });

  test('3 or 4 trees per plot', () {
    final w = _forest();
    for (final p in kPlots) {
      final trunks = w.blocks
          .where(
            (b) =>
                b.z == 1 &&
                b.material == Blocks.log &&
                b.x >= p.originX &&
                b.x < p.originX + kPlotSize &&
                b.y >= p.originY &&
                b.y < p.originY + kPlotSize,
          )
          .length;
      expect(trunks, inInclusiveRange(3, 4), reason: 'plot ${p.index}');
    }
  });

  test('a tree never reaches outside its plot, roads included', () {
    final w = _forest();
    for (final b in w.blocks) {
      expect(plotAt(b.x, b.y), isNotNull, reason: '(${b.x}, ${b.y})');
      expect(isRoad(b.x, b.y), isFalse);
    }
  });

  test('a cleared plot has no trees and its neighbours keep theirs', () {
    final with3 = _forest();
    final cleared = _forest({3});
    expect(_above(cleared, kPlots[3]), 0);
    for (final p in kPlots.where((p) => p.index != 3)) {
      expect(_above(cleared, p), _above(with3, p), reason: 'plot ${p.index}');
    }
  });

  test('the forest is the same every time', () {
    List<String> all(VoxelWorld w) =>
        [for (final b in w.blocks) '${b.x},${b.y},${b.z}']..sort();
    expect(all(_forest({2})), all(_forest({2})));
  });

  group('in the town', () {
    TownState town(List<TownBuilding> b) =>
        TownState.initial().copyWith(buildings: b);

    int trees(VoxelWorld w, Plot p) => w.blocks
        .where(
          (b) =>
              b.material == Blocks.leaves &&
              b.x >= p.originX &&
              b.x < p.originX + kPlotSize &&
              b.y >= p.originY &&
              b.y < p.originY + kPlotSize,
        )
        .length;

    test('a building clears its plot and the others stay forested', () {
      final w = buildTownWorld(
        town([
          const TownBuilding(
            id: 'b',
            tier: BuildingTier.hut,
            status: BuildingStatus.complete,
            plotIndex: 7,
          ),
        ]),
      );
      expect(trees(w, kPlots[7]), 0);
      expect(trees(w, kPlots[8]), greaterThan(0));
    });

    test('a ruin clears its plot too', () {
      final w = buildTownWorld(
        town([
          const TownBuilding(
            id: 'r',
            tier: BuildingTier.hut,
            status: BuildingStatus.ruin,
            plotIndex: 9,
          ),
        ]),
      );
      expect(trees(w, kPlots[9]), 0);
    });

    test('the plot under construction is cleared', () {
      final w = buildTownWorld(
        TownState.initial(),
        site: const ActiveSite(BuildingTier.hut, 2, plotIndex: 12),
      );
      expect(trees(w, kPlots[12]), 0);
      expect(trees(w, kPlots[1]), greaterThan(0));
    });
  });
}
