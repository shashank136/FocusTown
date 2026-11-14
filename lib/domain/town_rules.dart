import 'dart:math';

import 'package:focus_town/domain/building_tier.dart';
import 'package:focus_town/domain/district.dart';
import 'package:focus_town/domain/landmark.dart';
import 'package:focus_town/domain/local_date.dart';
import 'package:focus_town/domain/parcel.dart';
import 'package:focus_town/domain/plot_grid.dart';
import 'package:focus_town/domain/session.dart';
import 'package:focus_town/domain/town.dart';
import 'package:focus_town/domain/town_level.dart';

/// Where a district side stands for a town: not unlocked, waiting for the
/// district being built, at the limit, with no room on that side, ready to
/// start, or in progress.
enum DistrictState {
  /// Below the town level that unlocks districts.
  locked,

  /// Another district is being built.
  busy,

  /// The most districts a town can have are built.
  limit,

  /// The next district on this side would leave the world.
  noRoom,

  /// Can be started.
  ready,

  /// This is the district being built.
  inProgress,
}

/// Where a landmark stands for a town.
enum LandmarkState {
  /// Not unlocked yet: the town is below its level.
  locked,

  /// Unlocked, but another landmark is being built: one at a time.
  busy,

  /// Unlocked, but there is no free 2 x 2 block to start it on.
  noRoom,

  /// Unlocked and can be started.
  ready,

  /// Being built over several sessions.
  inProgress,

  /// Finished.
  built,
}

/// Pure town rules: each function reads a [TownState] and returns a result.
class TownRules {
  new _();

  /// How many plots the starting island has.
  static const plotCount = 64;

  /// How many plots [town]'s island has: the starting ones plus one per
  /// claimed parcel.
  static int plotCountOf(TownState town) =>
      plotCount + town.parcels.where((p) => !p.garden).length;

  /// The plots covered by the buildings and ruins of [town], and the squares
  /// of the island that were turned into gardens.
  static Set<int> occupied(TownState town) => {
    for (final b in town.buildings)
      ...(footprintOf(b.tier, b.plotIndex, town.parcels) ?? [b.plotIndex]),
    for (final p in town.parcels)
      if (p.garden && kBaseCells.contains((p.gx, p.gy)))
        kBaseCells.indexOf((p.gx, p.gy)),
  };

  /// Whether the town may still take a building of [tier]: some block of free
  /// plots can hold it. Space is the only limit; the player chooses which
  /// plots to use.
  static bool hasRoom(TownState town, [BuildingTier tier = BuildingTier.hut]) =>
      firstUnusedPlot(town, tier) != null;

  /// Lowest plot a building of [tier] could be anchored on, or null when the
  /// town has no room left.
  static int? nextFreePlot(
    TownState town, [
    BuildingTier tier = BuildingTier.hut,
  ]) => firstUnusedPlot(town, tier);

  /// Whether a building of [tier] may be anchored on plot [i]: its plots are
  /// on the island and nothing stands there.
  static bool isPlotFree(
    TownState town,
    int i, [
    BuildingTier tier = BuildingTier.hut,
  ]) => _blockFree(town, i, tier);

  // The plots [tier] would cover from [i] exist and nothing stands on them.
  static bool _blockFree(TownState town, int i, BuildingTier tier) {
    final block = footprintOf(tier, i, town.parcels);
    return block != null && !block.any(occupied(town).contains);
  }

  /// Where [session] builds: the plot the user chose while it is still free,
  /// else the next free plot, or null when the town has no room.
  static int? sitePlot(TownState town, Session session) {
    final chosen = session.plotIndex;
    return chosen != null && isPlotFree(town, chosen, session.tier)
        ? chosen
        : nextFreePlot(town, session.tier);
  }

  /// The plot a failed [session] leaves its ruin on: where it was building, or
  /// when the town has no room the first plot nothing stands on. A failure
  /// always leaves a ruin (null only when every plot is used).
  static int? ruinPlot(TownState town, Session session) =>
      sitePlot(town, session) ?? firstUnusedPlot(town, session.tier);

  /// The lowest plot a building of [tier] could be anchored on with nothing
  /// standing on its plots, room or not.
  static int? firstUnusedPlot(
    TownState town, [
    BuildingTier tier = BuildingTier.hut,
  ]) {
    for (var i = 0; i < plotCountOf(town); i++) {
      if (_blockFree(town, i, tier)) return i;
    }
    return null;
  }

  /// Whether a session of [minutes] may start. Invalid minutes give false.
  static bool canStart(TownState town, int minutes) {
    if (!BuildingTier.validDurations().contains(minutes)) return false;
    final tier = BuildingTier.forMinutes(minutes);
    return town.inRecoveryMode
        ? tier == BuildingTier.hut
        : town.workers >= tier.workersAtRisk;
  }

  /// Applies a completed [session]: gains workers, places or queues the
  /// building, then updates recovery mode.
  static TownState applyCompleted(TownState town, Session session) {
    final grown = town.copyWith(
      workers: town.workers + session.tier.workersAddedOnSuccess,
    );
    final plot = sitePlot(grown, session);
    final placed = plot == null
        ? grown.copyWith(
            queue: [
              ...grown.queue,
              QueuedBuilding(
                id: session.id,
                tier: session.tier,
                look: session.look,
              ),
            ],
          )
        : grown.copyWith(
            buildings: [
              ...grown.buildings,
              TownBuilding(
                id: session.id,
                tier: session.tier,
                status: BuildingStatus.complete,
                plotIndex: plot,
                look: session.look,
              ),
            ],
          );
    return _updateRecovery(placed);
  }

  /// The Monday of the week that [date] falls in.
  static LocalDate weekStart(LocalDate date) {
    final day = DateTime.utc(date.year, date.month, date.day);
    final monday = day.subtract(Duration(days: day.weekday - 1));
    return LocalDate(monday.year, monday.month, monday.day);
  }

  /// Gives the weekly emergency pause back on the first session of a new
  /// week. Never more than one is kept, and a date earlier than the stored
  /// week (the clock moved back) gives nothing.
  static TownState refillEmergency(TownState town, LocalDate today) {
    final week = weekStart(today);
    final stored = town.emergencyWeek;
    if (stored != null && stored.daysBetween(week) <= 0) return town;
    return town.copyWith(emergencyPauses: 1, emergencyWeek: week);
  }

  /// Switches the emergency pause on for [session]: one pause is used up and
  /// the next absence may last 10 minutes. Null when it is not allowed (none
  /// left, already armed or spent, a repair, or the user is already away).
  static (TownState, Session)? armEmergency(TownState town, Session session) {
    if (town.emergencyPauses < 1 ||
        session.state != SessionState.running ||
        session.isRepair ||
        session.isLand ||
        session.isLandmark ||
        session.isDistrict ||
        session.emergencyArmed ||
        session.emergencyUsed) {
      return null;
    }
    return (
      town.copyWith(emergencyPauses: town.emergencyPauses - 1),
      session.copyWith(emergencyArmed: true),
    );
  }

  /// Gives the weekly pause back when [session] ended with it armed but
  /// never needed: not used, no time away, finished or abandoned.
  static TownState refundEmergency(TownState town, Session session) {
    final unused =
        session.emergencyArmed &&
        !session.emergencyUsed &&
        session.awayTotal == Duration.zero &&
        (session.state == SessionState.completed ||
            session.outcomeReason == OutcomeReason.abandoned);
    return unused ? town.copyWith(emergencyPauses: 1) : town;
  }

  /// Whether plot [plot] holds a ruin that a repair could clear.
  static bool canRepair(TownState town, int plot) =>
      _ruinOn(town, plot) != null;

  // The ruin whose plots include [plot], if any.
  static TownBuilding? _ruinOn(TownState town, int plot) {
    for (final b in town.buildings) {
      if (b.status != BuildingStatus.ruin) continue;
      final plots = footprintOf(b.tier, b.plotIndex, town.parcels);
      if ((plots ?? [b.plotIndex]).contains(plot)) return b;
    }
    return null;
  }

  /// Applies a completed repair [session]: the ruin on its plot is cleared
  /// and a waiting building may take the freed plot. Workers and recovery
  /// mode are untouched. A plot that no longer holds a ruin changes nothing.
  static TownState applyRepairCompleted(TownState town, Session session) {
    final plot = session.repairPlot;
    final ruin = plot == null ? null : _ruinOn(town, plot);
    if (ruin == null) return town;
    return placeQueued(
      town.copyWith(
        buildings: [
          for (final b in town.buildings)
            if (b != ruin) b,
        ],
      ),
    );
  }

  /// Minutes of a land session when [claimed] parcels are already claimed: 25
  /// for the first, 5 more for every 4, at most 90.
  static int landMinutes(int claimed) => min(90, 25 + 5 * (claimed ~/ 4));

  /// Minutes it takes to turn a forest square of the island into a garden.
  static const gardenMinutes = 15;

  /// Minutes of the land session for [parcel]: [gardenMinutes] for a square of
  /// the island, else [landMinutes].
  static int landMinutesFor(TownState town, Parcel parcel) =>
      _isIsland(parcel) ? gardenMinutes : landMinutes(town.parcels.length);

  static bool _isIsland(Parcel p) => kBaseCells.contains((p.gx, p.gy));

  /// Whether [parcel] can be claimed: land that touches the island and
  /// nobody has claimed, or a free forest square of the island that is to
  /// become a garden.
  static bool canClaim(TownState town, Parcel parcel) {
    if (_isIsland(parcel)) {
      return parcel.garden &&
          !occupied(town).contains(kBaseCells.indexOf((parcel.gx, parcel.gy)));
    }
    return claimableParcels(town.parcels)
        .any((p) => p.gx == parcel.gx && p.gy == parcel.gy);
  }

  /// Applies a completed land [session]: its parcel becomes part of the island.
  /// A parcel that cannot be claimed any more changes nothing.
  static TownState applyLandCompleted(TownState town, Session session) {
    final parcel = session.land;
    if (parcel == null || !canClaim(town, parcel)) return town;
    return town.copyWith(parcels: [...town.parcels, parcel]);
  }

  /// The [landmark] being built, if it is in progress.
  static TownBuilding? landmarkProject(TownState town, Landmark landmark) {
    for (final b in town.buildings) {
      if (b.landmark == landmark && b.status == BuildingStatus.building) {
        return b;
      }
    }
    return null;
  }

  /// Where [landmark] stands for this town: not unlocked, waiting for another
  /// landmark, with no free 2 x 2 block, ready to start, in progress, or built.
  static LandmarkState landmarkState(TownState town, Landmark landmark) {
    if (landmarkProject(town, landmark) != null) {
      return LandmarkState.inProgress;
    }
    if (town.buildings.any((b) => b.landmark == landmark)) {
      return LandmarkState.built;
    }
    if (town.xp < landmark.unlockLevel.minXp) return LandmarkState.locked;
    final other = town.buildings.any(
      (b) => b.landmark != null && b.status == BuildingStatus.building,
    );
    if (other) return LandmarkState.busy;
    return nextFreePlot(town, BuildingTier.castle) == null
        ? LandmarkState.noRoom
        : LandmarkState.ready;
  }

  /// A look-only copy of [town] for the debug screen: the island cleared and
  /// every landmark standing finished, each on its own 2 x 2 block (the
  /// stored town is never changed).
  static TownState landmarkShowcase(TownState town) {
    var show = town.copyWith(buildings: const []);
    for (final l in Landmark.values) {
      final anchor = nextFreePlot(show, BuildingTier.castle);
      if (anchor == null) break;
      show = show.copyWith(
        buildings: [
          ...show.buildings,
          TownBuilding(
            id: 'showcase-${l.name}',
            tier: BuildingTier.castle,
            status: BuildingStatus.complete,
            plotIndex: anchor,
            landmark: l,
            progress: l.totalMinutes,
          ),
        ],
      );
    }
    return show;
  }

  /// Whether the user may work on [landmark]: it is in progress, or it is
  /// unlocked, not built and a free 2 x 2 block is there to start it on.
  static bool canStartLandmark(TownState town, Landmark landmark) {
    final state = landmarkState(town, landmark);
    return state == LandmarkState.inProgress || state == LandmarkState.ready;
  }

  /// Starts [landmark] on the block anchored at plot [anchor]. Null when that
  /// block is not free.
  static TownState? beginLandmark(
    TownState town,
    Landmark landmark,
    int anchor,
  ) {
    if (!isPlotFree(town, anchor, BuildingTier.castle)) return null;
    return town.copyWith(
      buildings: [
        ...town.buildings,
        TownBuilding(
          id: 'landmark-${landmark.name}',
          tier: BuildingTier.castle,
          status: BuildingStatus.building,
          plotIndex: anchor,
          landmark: landmark,
        ),
      ],
    );
  }

  static TownState _withProgress(
    TownState town,
    Landmark l,
    int Function(int) f,
  ) {
    return town.copyWith(
      buildings: [
        for (final b in town.buildings)
          if (b.landmark == l && b.status == BuildingStatus.building)
            _progressed(b, l, f(b.progress))
          else
            b,
      ],
    );
  }

  static TownBuilding _progressed(TownBuilding b, Landmark l, int progress) {
    final done = progress >= l.totalMinutes;
    return TownBuilding(
      id: b.id,
      tier: b.tier,
      status: done ? BuildingStatus.complete : BuildingStatus.building,
      plotIndex: b.plotIndex,
      look: b.look,
      landmark: l,
      progress: done ? l.totalMinutes : progress,
    );
  }

  /// Applies a completed landmark [session]: its minutes join the landmark's
  /// progress, which is done at the landmark's total (a session under 10
  /// minutes counts as a stage).
  static TownState applyLandmarkCompleted(TownState town, Session session) {
    final l = session.landmark;
    if (l == null) return town;
    // A session under 10 minutes can only come from the testing aid (short
    // test sessions): it counts as a whole stage so landmarks can be tried.
    final credit = session.plannedMinutes < 10
        ? l.minutesPerStage
        : session.plannedMinutes;
    return _withProgress(town, l, (p) => p + credit);
  }

  /// Applies a failed landmark [session]: the landmark loses one stage of
  /// progress, never going below nothing.
  static TownState applyLandmarkFailed(TownState town, Session session) {
    final l = session.landmark;
    if (l == null) return town;
    return _withProgress(town, l, (p) => max(0, p - l.minutesPerStage));
  }

  /// Where a district on [side] stands for [town].
  static DistrictState districtState(TownState town, DistrictSide side) {
    final project = town.districtProject;
    if (project != null) {
      return project.side == side
          ? DistrictState.inProgress
          : DistrictState.busy;
    }
    if (town.xp < TownLevel.city.minXp) return DistrictState.locked;
    if (town.districts.length >= kMaxDistricts) return DistrictState.limit;
    return districtFits(side, town.districts.where((d) => d == side).length)
        ? DistrictState.ready
        : DistrictState.noRoom;
  }

  /// Starts a district on [side]. Null when it cannot be started.
  static TownState? beginDistrict(TownState town, DistrictSide side) =>
      districtState(town, side) == DistrictState.ready
      ? town.copyWith(districtProject: DistrictProject(side, 0))
      : null;

  /// Adds [minutes] to the district being built: every row the minutes
  /// finish becomes land at once (parcels already claimed are skipped and
  /// stay as they are), and the district is done at [kDistrictMinutes].
  static TownState applyDistrictMinutes(TownState town, int minutes) {
    final project = town.districtProject;
    if (project == null) return town;
    final index = town.districts.where((d) => d == project.side).length;
    final progress = min(project.progress + minutes, kDistrictMinutes);
    final owned = {for (final p in town.parcels) (p.gx, p.gy)};
    final added = [
      for (
        var r = project.rows;
        r < DistrictProject(project.side, progress).rows;
        r++
      )
        for (final p in districtRow(project.side, index, r))
          if (!owned.contains((p.gx, p.gy))) p,
    ];
    final parcels = [...town.parcels, ...added];
    return progress >= kDistrictMinutes
        ? town.copyWith(
            parcels: parcels,
            districts: [...town.districts, project.side],
            clearDistrictProject: true,
          )
        : town.copyWith(
            parcels: parcels,
            districtProject: DistrictProject(project.side, progress),
          );
  }

  /// Applies a completed district [session]: its minutes build the district (a
  /// session under 10 minutes can only come from the testing aid and counts as
  /// a whole row).
  static TownState applyDistrictCompleted(TownState town, Session session) =>
      applyDistrictMinutes(
        town,
        session.plannedMinutes < 10
            ? kMinutesPerDistrictRow
            : session.plannedMinutes,
      );

  /// Applies a failed district session: the minutes toward the next row are
  /// lost. Rows already built stay, because buildings may stand on them.
  static TownState applyDistrictFailed(TownState town) {
    final project = town.districtProject;
    if (project == null) return town;
    return town.copyWith(
      districtProject: DistrictProject(
        project.side,
        project.rows * kMinutesPerDistrictRow,
      ),
    );
  }

  /// Moves queued buildings onto free plots, oldest first.
  static TownState placeQueued(TownState town) {
    var t = town;
    // The oldest waiting building goes first; if it has no room, the ones
    // behind it wait too.
    for (
      var plot = t.queue.isEmpty ? null : nextFreePlot(t, t.queue.first.tier);
      t.queue.isNotEmpty && plot != null;
      plot = t.queue.isEmpty ? null : nextFreePlot(t, t.queue.first.tier)
    ) {
      final next = t.queue.first;
      t = t.copyWith(
        buildings: [
          ...t.buildings,
          TownBuilding(
            id: next.id,
            tier: next.tier,
            status: BuildingStatus.complete,
            plotIndex: plot,
            look: next.look,
          ),
        ],
        queue: t.queue.skip(1).toList(),
      );
    }
    return t;
  }

  /// Applies a failed [session]: workers die, a ruin takes a free plot, and
  /// recovery mode starts at 0 workers.
  static TownState applyFailed(TownState town, Session session) {
    final hurt = town.copyWith(
      workers: max(0, town.workers - session.workersAssigned),
    );
    var tier = session.tier;
    var plot = ruinPlot(hurt, session);
    if (plot == null && tier == BuildingTier.castle) {
      // No free block: the castle leaves a one-plot ruin instead.
      tier = BuildingTier.hut;
      plot = firstUnusedPlot(hurt);
    }
    final ruined = plot == null
        ? hurt
        : hurt.copyWith(
            buildings: [
              ...hurt.buildings,
              TownBuilding(
                id: session.id,
                tier: tier,
                status: BuildingStatus.ruin,
                plotIndex: plot,
              ),
            ],
          );
    return _updateRecovery(ruined);
  }

  // 3+ workers leaves recovery, 0 enters it, otherwise unchanged.
  static TownState _updateRecovery(TownState town) {
    if (town.workers >= 3) return town.copyWith(inRecoveryMode: false);
    if (town.workers == 0) return town.copyWith(inRecoveryMode: true);
    return town;
  }
}
