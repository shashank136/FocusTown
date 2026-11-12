import 'dart:math' as math;

import 'package:focus_town/domain/building_tier.dart';
import 'package:focus_town/domain/session.dart';
import 'package:focus_town/domain/town.dart';
import 'package:focus_town/game/workers/worker_model.dart';
import 'package:focus_town/game/world/block_material.dart';
import 'package:focus_town/game/world/plot_layout.dart';

/// A worker with the pose it has right now.
class PlacedWorker {
  /// Creates a placed worker.
  const new(this.worker, this.pose);

  /// Where it stands and what it wears.
  final Worker worker;

  /// What it is doing.
  final Pose pose;
}

/// At most this many workers are drawn around one building.
const kMaxSiteWorkers = 8;

/// At most this many spare workers walk the roads.
const kMaxSpareWalkers = 8;

/// How many workers are not on the building site and walk the roads: at most
/// eight. In recovery mode with no workers, one (the Last Builder) wanders.
int spareWorkerCount(TownState town, Session? active) {
  final spare = math.max(
    0,
    math.min(kMaxSpareWalkers, town.workers - (active?.workersAssigned ?? 0)),
  );
  if (spare == 0 && town.inRecoveryMode && town.workers == 0) return 1;
  return spare;
}

final FlatColor _vest = FlatColor.of(WorkerColors.vest);
final FlatColor _shirt = FlatColor.of(WorkerColors.shirt);

// Footprint (width, depth) of a tier's building.
(int, int) _footprint(BuildingTier t) => switch (t) {
  BuildingTier.hut || BuildingTier.tower => (3, 3),
  BuildingTier.house || BuildingTier.workshop => (5, 5),
  BuildingTier.castle => (12, 12),
};

/// Up to [count] (max 8) hammering workers along the two front sides of the
/// building on [site], at [seconds] of game time.
List<PlacedWorker> siteWorkers(
  Plot site,
  BuildingTier tier,
  int count,
  double seconds, {
  bool reducedMotion = false,
}) {
  final (width, depth) = _footprint(tier);
  const margin = 1;
  final ox = site.originX + margin;
  final oy = site.originY + margin;
  final out = <PlacedWorker>[];
  // A castle's walls are twice as long: spread its builders out.
  final step = width > 7 ? 2.2 : 1.2;
  for (var k = 0; k < math.min(count, kMaxSiteWorkers); k++) {
    final index = k ~/ 2; // position along its side
    final onSideA = k.isEven;
    final worker = onSideA
        ? Worker(
            x: ox + 0.8 + step * index,
            y: oy + depth + 0.7,
            facing: (0, -1),
            shirt: _vest,
          )
        : Worker(
            x: ox + width + 0.7,
            y: oy + 0.8 + step * index,
            facing: (-1, 0),
            shirt: _vest,
          );
    final phase = index % 2;
    final up = ((seconds * 2 + phase).floor() % 2) == 0;
    out.add(
      PlacedWorker(
        worker,
        reducedMotion ? Pose.idle : (up ? Pose.hammerUp : Pose.hammerDown),
      ),
    );
  }
  return out;
}

/// One spare worker for each of [routes] (road tiles one step apart), walking
/// to the end of its route and back (no path finding: the routes come from the
/// road network). Later workers start further along, so they are spread out.
List<PlacedWorker> spareWalkers(
  List<List<(int, int)>> routes,
  double seconds, {
  bool reducedMotion = false,
}) {
  const speed = 1.5; // tiles per second
  final t = reducedMotion ? 0.0 : seconds;
  final out = <PlacedWorker>[];
  for (var i = 0; i < routes.length; i++) {
    final route = routes[i];
    if (route.length < 2) continue;
    final steps = route.length - 1;
    final p = (t * speed + i * 7) % (2 * steps);
    final forward = p < steps;
    final along = forward ? p : 2 * steps - p;
    final k = along.floor().clamp(0, steps - 1);
    final from = route[k];
    final to = route[k + 1];
    final f = along - k;
    final dx = to.$1 - from.$1;
    final dy = to.$2 - from.$2;
    final worker = Worker(
      x: from.$1 + dx * f + 0.5,
      y: from.$2 + dy * f + 0.5,
      facing: forward ? (dx, dy) : (-dx, -dy),
      shirt: _shirt,
    );
    final stepOne = (seconds * 4).floor().isEven;
    out.add(
      PlacedWorker(
        worker,
        reducedMotion ? Pose.idle : (stepOne ? Pose.walk1 : Pose.walk2),
      ),
    );
  }
  return out;
}
