import 'package:focus_town/domain/session.dart';
import 'package:focus_town/domain/town.dart';
import 'package:focus_town/domain/town_rules.dart';
import 'package:focus_town/game/world/active_site.dart';
import 'package:focus_town/game/world/block_material.dart';
import 'package:focus_town/game/world/building_defs.dart';
import 'package:focus_town/game/world/plot_layout.dart';
import 'package:focus_town/game/world/scenery.dart';
import 'package:focus_town/game/world/voxel_world.dart';

/// The plot a running session builds on: the next free unlocked plot, or when
/// none is free the first locked plot as a temporary site.
Plot activeSitePlot(TownState town) {
  final free = TownRules.nextFreePlot(town);
  return kPlots[free ?? town.plotsUnlocked.clamp(0, kPlots.length - 1)];
}

/// Builds the whole town as blocks: ground, plot borders, scenery, the
/// buildings and ruins, and the building under construction.
///
/// The site is either given as [site] (a tier and an exact stage) or derived
/// from the [active] session at [progress] (0 to 1).
VoxelWorld buildTownWorld(
  TownState town, {
  ActiveSite? site,
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
  final building =
      site ??
      (active == null
          ? null
          : ActiveSite(active.tier, stageForProgress(active.tier, progress)));
  if (building != null) {
    final plot = activeSitePlot(town);
    buildTier(
      w,
      building.tier,
      plot.originX,
      plot.originY,
      stage: building.stage,
      scaffold: building.stage < maxStage(building.tier),
    );
  }
  return w;
}
