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
const kMaxSpareWalkers = 4;

/// How many workers are not on the building site and walk the roads: at most
/// four. In recovery mode with no workers, one (the Last Builder) wanders.
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
  BuildingTier.castle => (14, 14),
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
  final margin = tier == BuildingTier.castle ? 0 : 1;
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

/// [count] workers walking up and down the two roads (no path finding).
List<PlacedWorker> spareWalkers(
  int count,
  double seconds, {
  bool reducedMotion = false,
}) {
  const length = 56.0;
  const speed = 1.5; // tiles per second
  final t = reducedMotion ? 0.0 : seconds;
  final out = <PlacedWorker>[];
  for (var i = 0; i < count; i++) {
    final vertical = i.isEven;
    final p = (t * speed + i * 14) % (2 * length);
    final forward = p < length;
    final along = forward ? 3 + p : 3 + (2 * length - p);
    final facing = vertical
        ? (forward ? (0, 1) : (0, -1))
        : (forward ? (1, 0) : (-1, 0));
    final worker = Worker(
      x: vertical ? 31.6 : along,
      y: vertical ? along : 32.4,
      facing: facing,
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
