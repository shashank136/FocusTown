import 'package:focus_town/domain/building_tier.dart';
import 'package:focus_town/domain/town.dart';
import 'package:focus_town/domain/town_rules.dart';
import 'package:focus_town/game/effects/site_transition.dart';
import 'package:focus_town/game/workers/worker_layout.dart';
import 'package:focus_town/game/world/active_site.dart';
import 'package:focus_town/game/world/building_defs.dart';
import 'package:focus_town/game/world/plot_layout.dart';

/// Length of every demo loop, in seconds.
const kDemoLoop = 6;

/// Which onboarding demo to show.
enum DemoKind {
  /// A house rising stage by stage with three builders.
  build,

  /// A house failing: dead builders, a ruin and smoke.
  ruin,

  /// A hut just started by one builder.
  start,
}

/// What a demo shows at one moment.
class DemoFrame {
  /// Creates a frame.
  const new(this.town, this.site, this.workers, {this.smoke = false});

  /// The town drawn (the starter, plus a ruin in the failure part).
  final TownState town;

  /// The building under construction, or null.
  final ActiveSite? site;

  /// Everyone drawn over the town.
  final List<PlacedWorker> workers;

  /// Whether smoke rises over the ruin.
  final bool smoke;
}

/// The demo [kind] at [seconds]; repeats every [kDemoLoop] seconds. Pure: the
/// frame depends on [seconds] only.
DemoFrame demoFrame(DemoKind kind, double seconds) {
  final t = seconds % kDemoLoop;
  final town = TownState.initial();
  final plotIndex = TownRules.firstUnusedPlot(town)!;
  final plot = kPlots[plotIndex];
  switch (kind) {
    case DemoKind.build:
      const tier = BuildingTier.house;
      final last = maxStage(tier);
      final stage = (1 + (t / kDemoLoop * last).floor()).clamp(1, last);
      return DemoFrame(
        town,
        ActiveSite(tier, stage, plotIndex: plotIndex),
        siteWorkers(plot, tier, 3, t),
      );
    case DemoKind.ruin:
      const tier = BuildingTier.house;
      final builders = siteWorkers(plot, tier, 3, t);
      if (t < kDemoLoop / 2) {
        return DemoFrame(
          town,
          ActiveSite(tier, 5, plotIndex: plotIndex),
          builders,
        );
      }
      return DemoFrame(
        town.copyWith(
          buildings: [
            ...town.buildings,
            TownBuilding(
              id: 'demo-ruin',
              tier: tier,
              status: BuildingStatus.ruin,
              plotIndex: plotIndex,
            ),
          ],
        ),
        null,
        deadWorkers(siteWorkers(plot, tier, 3, kDemoLoop / 2)),
        smoke: true,
      );
    case DemoKind.start:
      return DemoFrame(
        town,
        ActiveSite(BuildingTier.hut, 1, plotIndex: plotIndex),
        siteWorkers(plot, BuildingTier.hut, 1, t),
      );
  }
}
