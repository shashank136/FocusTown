import 'package:focus_town/domain/building_tier.dart';
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

  /// Whether a session of [minutes] may start. Invalid minutes give false.
  static bool canStart(TownState town, int minutes) {
    if (!BuildingTier.validDurations().contains(minutes)) return false;
    final tier = BuildingTier.forMinutes(minutes);
    return town.inRecoveryMode
        ? tier == BuildingTier.hut
        : town.workers >= tier.workersAtRisk;
  }
}
