import 'dart:math';

import 'package:focus_town/domain/building_tier.dart';
import 'package:focus_town/domain/local_date.dart';
import 'package:focus_town/domain/parcel.dart';
import 'package:focus_town/domain/plot_grid.dart';
import 'package:focus_town/domain/session.dart';
import 'package:focus_town/domain/town.dart';

/// Pure town rules: each function reads a [TownState] and returns a result.
class TownRules {
  new _();

  /// How many plots the starting island has.
  static const plotCount = 64;

  /// How many plots [town]'s island has: the starting ones plus one per
  /// claimed parcel.
  static int plotCountOf(TownState town) =>
      plotCount + town.parcels.where((p) => !p.garden).length;

  /// The plots covered by the buildings and ruins of [town].
  static Set<int> occupied(TownState town) => {
    for (final b in town.buildings)
      ...(footprintOf(b.tier, b.plotIndex, town.parcels) ?? [b.plotIndex]),
  };

  /// Whether the town may still take a building of [tier] (a hut by default):
  /// the plots used by buildings and ruins plus the plots it needs fit in the
  /// plots unlocked. Which plots they stand on is the player's choice.
  static bool hasRoom(TownState town, [BuildingTier tier = BuildingTier.hut]) =>
      occupied(town).length + plotsOf(tier) <= town.plotsUnlocked;

  /// Lowest plot a building of [tier] could be anchored on, or null when the
  /// town has no room left.
  static int? nextFreePlot(
    TownState town, [
    BuildingTier tier = BuildingTier.hut,
  ]) => hasRoom(town, tier) ? firstUnusedPlot(town, tier) : null;

  /// Whether a building of [tier] may be anchored on plot [i]: its plots are
  /// on the island, nothing stands there, and the town has room.
  static bool isPlotFree(
    TownState town,
    int i, [
    BuildingTier tier = BuildingTier.hut,
  ]) => hasRoom(town, tier) && _blockFree(town, i, tier);

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
              QueuedBuilding(id: session.id, tier: session.tier),
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

  /// Whether [parcel] touches the island and nobody has claimed it.
  static bool canClaim(TownState town, Parcel parcel) =>
      claimableParcels(town.parcels)
          .any((p) => p.gx == parcel.gx && p.gy == parcel.gy);

  /// Applies a completed land [session]: its parcel becomes part of the island.
  /// A parcel that cannot be claimed any more changes nothing.
  static TownState applyLandCompleted(TownState town, Session session) {
    final parcel = session.land;
    if (parcel == null || !canClaim(town, parcel)) return town;
    return town.copyWith(parcels: [...town.parcels, parcel]);
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
