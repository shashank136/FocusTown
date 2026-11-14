import 'package:focus_town/domain/building_look.dart';
import 'package:focus_town/domain/building_tier.dart';
import 'package:focus_town/domain/plot_grid.dart';
import 'package:focus_town/domain/session.dart';
import 'package:focus_town/domain/town.dart';
import 'package:focus_town/domain/town_rules.dart';
import 'package:focus_town/game/world/active_site.dart';
import 'package:focus_town/game/world/block_material.dart';
import 'package:focus_town/game/world/building_defs.dart';
import 'package:focus_town/game/world/forest.dart';
import 'package:focus_town/game/world/garden.dart';
import 'package:focus_town/game/world/landmark_defs.dart';
import 'package:focus_town/game/world/plot_layout.dart';
import 'package:focus_town/game/world/road_network.dart';
import 'package:focus_town/game/world/scenery.dart';
import 'package:focus_town/game/world/voxel_world.dart';

/// The plot a running session of [tier] builds on: the plot the user [chosen]
/// while it is free, else the next free plot, or when the town has no room the
/// first plot nothing stands on (a temporary site). A castle's plot spans its
/// 2 x 2 block.
Plot activeSitePlot(
  TownState town, [
  int? chosen,
  BuildingTier tier = BuildingTier.hut,
]) {
  final int index;
  if (chosen != null && TownRules.isPlotFree(town, chosen, tier)) {
    index = chosen;
  } else {
    index =
        TownRules.nextFreePlot(town, tier) ??
        TownRules.firstUnusedPlot(town, tier) ??
        0;
  }
  return plotForTier(index, tier, town.parcels);
}

/// Where [session] works: the ruin of a repair, else its building site.
Plot sessionSitePlot(TownState town, Session session) {
  if (session.isRepair) return plotFor(session.repairPlot!, town.parcels);
  final land = session.land;
  if (land != null) {
    return Plot(-1, parcelOrigin(land.gx), parcelOrigin(land.gy));
  }
  if (session.isLandmark) {
    return plotForTier(session.plotIndex!, BuildingTier.castle, town.parcels);
  }
  return activeSitePlot(town, session.plotIndex, session.tier);
}

ActiveSite? _landmarkSite(TownState town, Session active, double progress) {
  final stage = landmarkLiveStage(town, active, progress);
  return stage < 1
      ? null
      : ActiveSite(
          BuildingTier.castle,
          stage,
          plotIndex: active.plotIndex,
          landmark: active.landmark,
        );
}

/// The stage a landmark session has reached at [progress] (0 to 1): the
/// stages its project has plus what the session has done so far.
int landmarkLiveStage(TownState town, Session session, double progress) {
  final l = session.landmark!;
  final project = TownRules.landmarkProject(town, l);
  final now = (project?.progress ?? 0) + progress * session.plannedMinutes;
  return (now ~/ l.minutesPerStage).clamp(0, l.stages);
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
  final building =
      site ??
      (active == null
          ? null
          : active.isLandmark
          ? _landmarkSite(town, active, progress)
          : ActiveSite(
              active.tier,
              stageForProgress(active.tier, progress),
              plotIndex: active.plotIndex,
              look: active.look ?? lookIndex(active.id),
            ));
  final sitePlot = building == null
      ? null
      : building.landmark != null
      ? plotForTier(building.plotIndex!, BuildingTier.castle, town.parcels)
      : activeSitePlot(town, building.plotIndex, building.tier);
  // Plots in use (a building, a ruin or the site) are cleared and bordered;
  // all others stay forest.
  // Claimed land is ground too: forest, or a garden. A land session shows
  // its parcel while it runs.
  final land = [...town.parcels, ?active?.land];
  for (final p in land) {
    final ox = parcelOrigin(p.gx);
    final oy = parcelOrigin(p.gy);
    for (var x = ox; x < ox + kPlotSize; x++) {
      for (var y = oy; y < oy + kPlotSize; y++) {
        w
          ..set(x, y, -1, Blocks.dirt)
          ..set(x, y, 0, Blocks.grass);
      }
    }
  }
  // A garden being made is a garden from the start: its square is cleared of
  // forest too.
  final making = active?.land;
  final gardens = [
    ...town.parcels.where((p) => p.garden),
    if (making != null && making.garden) making,
  ];
  final inUse = {...TownRules.occupied(town)};
  if (making != null && making.garden) {
    final base = kBaseCells.indexOf((making.gx, making.gy));
    if (base >= 0) inUse.add(base);
  }
  if (sitePlot != null) {
    inUse.addAll(
      footprintOf(building!.tier, sitePlot.index, town.parcels) ??
          [sitePlot.index],
    );
  }
  // Roads: the main ones, a ring around every used plot or block, and the
  // connectors that join them up.
  for (final (x, y) in RoadNetwork(town, site: sitePlot).tiles) {
    if (w.has(x, y, 0)) w.set(x, y, 0, Blocks.path);
  }
  buildScenery(w);
  // A tree top hides what lies up to three tiles behind it, so the trees in a
  // garden and the ones just in front of it (towards the viewer) are flower
  // bushes, so they do not hide the garden with green.
  buildForest(
    w,
    cleared: inUse,
    parcels: town.parcels,
    bushZones: [
      for (final p in gardens)
        (
          parcelOrigin(p.gx) - 1,
          parcelOrigin(p.gy) - 1,
          parcelOrigin(p.gx) + kPlotSize + 4,
          parcelOrigin(p.gy) + kPlotSize + 4,
        ),
    ],
  );
  for (final p in gardens) {
    buildGarden(
      w,
      parcelOrigin(p.gx),
      parcelOrigin(p.gy),
      (p.gx + 2 * p.gy).abs(),
    );
  }
  for (final b in town.buildings) {
    final p = plotFor(b.plotIndex, town.parcels);
    final landmark = b.landmark;
    if (landmark != null) {
      buildLandmark(w, landmark, p.originX + 1, p.originY + 1, b.stage);
    } else if (b.status == BuildingStatus.complete) {
      buildTier(
        w,
        b.tier,
        p.originX,
        p.originY,
        stage: maxStage(b.tier),
        look: b.effectiveLook,
      );
    } else {
      // A castle ruin is a ruin on each plot of its block.
      for (final i
          in footprintOf(b.tier, b.plotIndex, town.parcels) ?? [b.plotIndex]) {
        final q = plotFor(i, town.parcels);
        buildRuin(w, q.originX, q.originY);
      }
    }
  }
  if (building != null && sitePlot != null) {
    final plot = sitePlot;
    final landmark = building.landmark;
    if (landmark != null) {
      buildLandmark(
        w,
        landmark,
        plot.originX + 1,
        plot.originY + 1,
        building.stage,
      );
    } else {
      buildTier(
        w,
        building.tier,
        plot.originX,
        plot.originY,
        stage: building.stage,
        scaffold: building.stage < maxStage(building.tier),
        look: building.look,
      );
    }
  }
  return w;
}
