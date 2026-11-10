import 'dart:ui';

import 'package:focus_town/game/render/block_painter.dart';
import 'package:focus_town/game/workers/worker_layout.dart';
import 'package:focus_town/game/workers/worker_model.dart';
import 'package:focus_town/game/world/vec2.dart';
import 'package:focus_town/game/world/voxel_world.dart';

/// Finds the blocks around a spot without scanning the whole town.
///
/// Blocks are grouped by their (x, y) column; every query returns blocks in
/// the order of the list the index was built from (back to front).
class BlockIndex {
  /// Builds an index of [sortedBlocks] (already in draw order).
  new(List<VisibleBlock> sortedBlocks) {
    for (var i = 0; i < sortedBlocks.length; i++) {
      final b = sortedBlocks[i];
      (_columns[_key(b.x, b.y)] ??= []).add((i, b));
    }
  }

  final Map<int, List<(int, VisibleBlock)>> _columns = {};

  static int _key(int x, int y) => ((x + 1024) << 16) | (y + 1024);

  /// Blocks whose column is within [radius] tiles of ([x], [y]).
  List<VisibleBlock> near(double x, double y, {int radius = 3}) {
    final wx = x.floor();
    final wy = y.floor();
    final found = <(int, VisibleBlock)>[];
    for (var bx = wx - radius; bx <= wx + radius; bx++) {
      for (var by = wy - radius; by <= wy + radius; by++) {
        final column = _columns[_key(bx, by)];
        if (column != null) found.addAll(column);
      }
    }
    found.sort((a, b) => a.$1.compareTo(b.$1));
    return [for (final (_, block) in found) block];
  }
}

/// Depth of a worker: the middle of its legs, summed. Larger is nearer.
double _workerKey(PlacedWorker w) => boxesFor(w.worker, w.pose)[0].depthKey;

/// [workers] back to front.
List<PlacedWorker> sortWorkersByDepth(List<PlacedWorker> workers) =>
    [...workers]..sort((a, b) => _workerKey(a).compareTo(_workerKey(b)));

/// Draws [workers] over a town that is already painted.
///
/// Approach: each worker's boxes are painted on top; then, when an [index] is
/// given, the static blocks within 3 tiles that are nearer the viewer than the
/// worker (depth key `x + y + z + 1.5` above the worker's) are painted again
/// over it, so a worker hides behind a wall. The re-painted blocks produce
/// the same pixels as before.
///
/// Limits: a block further than 3 tiles never hides a worker (a tall tower
/// far in front is ignored), and each nearby block is drawn twice.
void paintWorkers(
  Canvas canvas,
  List<PlacedWorker> workers, {
  required double tile,
  required Vec2 origin,
  required Size viewSize,
  BlockIndex? index,
}) {
  for (final w in sortWorkersByDepth(workers)) {
    final boxes = boxesFor(w.worker, w.pose)
      ..sort((a, b) => a.depthKey.compareTo(b.depthKey));
    for (final b in boxes) {
      paintBox(
        canvas,
        x: b.x,
        y: b.y,
        z: b.z,
        w: b.w,
        d: b.d,
        h: b.h,
        color: b.color,
        tile: tile,
        origin: origin,
      );
    }
    if (index == null) continue;
    final key = _workerKey(w);
    final nearer = [
      for (final b in index.near(w.worker.x, w.worker.y))
        if (b.x + b.y + b.z + 1.5 > key) b,
    ];
    if (nearer.isNotEmpty) {
      paintBlocks(
        canvas,
        nearer,
        tile: tile,
        origin: origin,
        viewSize: viewSize,
      );
    }
  }
}
