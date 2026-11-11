import 'dart:math';

import 'package:focus_town/domain/building_tier.dart';
import 'package:focus_town/domain/session.dart';
import 'package:focus_town/domain/town.dart';

/// Pure town rules: each function reads a [TownState] and returns a result.
class TownRules {
  new _();

  /// Lowest unlocked plot with no building or ruin on it, or null if full.
  static int? nextFreePlot(TownState town) {
    final used = {for (final b in town.buildings) b.plotIndex};
    for (var i = 0; i < town.plotsUnlocked; i++) {
      if (!used.contains(i)) return i;
    }
    return null;
  }

  /// Whether plot [i] is unlocked and has no building or ruin.
  static bool isPlotFree(TownState town, int i) =>
      i >= 0 &&
      i < town.plotsUnlocked &&
      !town.buildings.any((b) => b.plotIndex == i);

  /// Where [session] builds: the plot the user chose while it is still free,
  /// else the next free plot, or null when the town is full.
  static int? sitePlot(TownState town, Session session) {
    final chosen = session.plotIndex;
    return chosen != null && isPlotFree(town, chosen)
        ? chosen
        : nextFreePlot(town);
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

  /// Moves queued buildings onto free plots, oldest first.
  static TownState placeQueued(TownState town) {
    var t = town;
    for (
      var plot = nextFreePlot(t);
      t.queue.isNotEmpty && plot != null;
      plot = nextFreePlot(t)
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
    final plot = sitePlot(hurt, session);
    final ruined = plot == null
        ? hurt
        : hurt.copyWith(
            buildings: [
              ...hurt.buildings,
              TownBuilding(
                id: session.id,
                tier: session.tier,
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
