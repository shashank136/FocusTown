import 'package:focus_town/domain/building_tier.dart';
import 'package:focus_town/domain/town.dart';
import 'package:focus_town/domain/town_rules.dart';

/// One choice in the duration picker.
class DurationOption {
  /// Creates an option.
  const new({
    required this.minutes,
    required this.tier,
    required this.workersAtRisk,
    required this.workersGained,
    required this.enabled,
    this.reason,
  });

  /// Planned minutes.
  final int minutes;

  /// What this session builds.
  final BuildingTier tier;

  /// Workers lost if the session fails (0 in recovery mode).
  final int workersAtRisk;

  /// Workers gained if it completes.
  final int workersGained;

  /// Whether the user may start it.
  final bool enabled;

  /// Why it is disabled, or null when enabled.
  final String? reason;
}

/// Every valid duration with whether [town] may start it and why not.
List<DurationOption> durationOptions(TownState town) => [
  for (final minutes in BuildingTier.validDurations()) _option(town, minutes),
];

DurationOption _option(TownState town, int minutes) {
  final tier = BuildingTier.forMinutes(minutes);
  final enabled = TownRules.canStart(town, minutes);
  return DurationOption(
    minutes: minutes,
    tier: tier,
    workersAtRisk: town.inRecoveryMode ? 0 : tier.workersAtRisk,
    workersGained: tier.workersAddedOnSuccess,
    enabled: enabled,
    reason: enabled
        ? null
        : town.inRecoveryMode
        ? 'Recovery mode: huts only'
        : 'Needs ${tier.workersAtRisk} workers, you have ${town.workers}',
  );
}

/// The duration the picker opens on: [lastUsed] when enabled, else the largest
/// enabled one below it, else the smallest enabled one, else 10.
int defaultMinutes(List<DurationOption> options, int lastUsed) {
  final enabled = [
    for (final o in options)
      if (o.enabled) o.minutes,
  ];
  if (enabled.isEmpty) return 10;
  if (enabled.contains(lastUsed)) return lastUsed;
  final below = enabled.where((m) => m < lastUsed);
  return below.isEmpty ? enabled.first : below.last;
}
