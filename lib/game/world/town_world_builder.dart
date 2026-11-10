import 'package:focus_town/domain/session.dart';
import 'package:focus_town/domain/town.dart';
import 'package:focus_town/domain/town_rules.dart';
import 'package:focus_town/game/world/block_material.dart';
import 'package:focus_town/game/world/building_defs.dart';
import 'package:focus_town/game/world/plot_layout.dart';
import 'package:focus_town/game/world/scenery.dart';
import 'package:focus_town/game/world/voxel_world.dart';

/// Builds the whole town as blocks: ground, plot borders, scenery, the
/// buildings and ruins, and the site of the [active] session at [progress].
VoxelWorld buildTownWorld(
  TownState town, {
  Session? active,
  double progress = 0,
}) {
  final w = VoxelWorld();
  for (var x = 0; x < kMapSize; x++) {
    for (var y = 0; y < kMapSize; y++) {
      w
        ..set(x, y, -1, Blocks.dirt)
        ..set(x, y, 0, isRoad(x, y) ? Blocks.path : Blocks.grass);
    }
  }
  for (final p in kPlots.take(town.plotsUnlocked)) {
    w.ring(p.originX, p.originY, kPlotSize, kPlotSize, 0, Blocks.path);
  }
  buildScenery(w);
  for (final b in town.buildings) {
    final p = kPlots[b.plotIndex];
    if (b.status == BuildingStatus.complete) {
      buildTier(w, b.tier, p.originX, p.originY, stage: maxStage(b.tier));
    } else {
      buildRuin(w, p.originX, p.originY);
    }
  }
  if (active != null) {
    final free = TownRules.nextFreePlot(town);
    // Out of free plots: borrow the first locked plot as a temporary site.
    final site = kPlots[free ?? town.plotsUnlocked.clamp(0, kPlots.length - 1)];
    final stage = stageForProgress(active.tier, progress);
    buildTier(
      w,
      active.tier,
      site.originX,
      site.originY,
      stage: stage,
      scaffold: stage < maxStage(active.tier),
    );
  }
  return w;
}
