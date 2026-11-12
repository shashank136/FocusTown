import 'dart:ui';

import 'package:focus_town/game/render/block_painter.dart';
import 'package:focus_town/game/workers/worker_layout.dart';
import 'package:focus_town/game/workers/worker_model.dart';
import 'package:focus_town/game/world/vec2.dart';
import 'package:focus_town/game/world/voxel_world.dart';

/// Finds the blocks that could hide a worker without scanning the whole town.
///
/// Blocks are grouped by the screen column they fall in (`x - y`): a block
/// can only cover a worker whose column is within a block's width of its own,
/// however far toward the viewer it stands. (A tall tower on the same
/// diagonal hides a worker many tiles behind it.)
class BlockIndex {
  /// Builds an index of [sortedBlocks] (already in draw order).
  new(List<VisibleBlock> sortedBlocks) {
    for (var i = 0; i < sortedBlocks.length; i++) {
      final b = sortedBlocks[i];
      (_bands[b.x - b.y] ??= []).add((i, b));
    }
  }

  final Map<int, List<(int, VisibleBlock)>> _bands = {};

  /// The blocks nearer the viewer than [w] whose pixels overlap the worker's
  /// own pixels, in the order of the list the index was built from (back to
  /// front).
  List<VisibleBlock> inFront(
    PlacedWorker w, {
    required double tile,
    required Vec2 origin,
  }) {
    final key = _workerKey(w);
    final bounds = workerScreenBounds(w, tile: tile, origin: origin);
    final column = (w.worker.x - w.worker.y).floor();
    final found = <(int, VisibleBlock)>[];
    // A block is two tiles wide on screen and a worker about one.
    for (var c = column - 2; c <= column + 2; c++) {
      for (final (i, b) in _bands[c] ?? const <(int, VisibleBlock)>[]) {
        if (b.x + b.y + b.z + 1.5 <= key) continue;
        // The block's screen box: its top corner down to its bottom corner.
        final left = origin.x + (b.x - b.y - 1) * tile;
        final top = origin.y + ((b.x + b.y) / 2 - b.z - 1) * tile;
        final box = Rect.fromLTRB(left, top, left + 2 * tile, top + 3 * tile);
        if (box.overlaps(bounds)) found.add((i, b));
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

/// The pixels [w] covers on screen, rounded out to whole pixels (plus one for
/// anti-aliased edges).
Rect workerScreenBounds(
  PlacedWorker w, {
  required double tile,
  required Vec2 origin,
}) {
  var bounds = Rect.zero;
  var first = true;
  for (final b in boxesFor(w.worker, w.pose)) {
    for (final x in [b.x, b.x + b.w]) {
      for (final y in [b.y, b.y + b.d]) {
        for (final z in [b.z, b.z + b.h]) {
          final sx = origin.x + (x - y) * tile;
          final sy = origin.y + (x + y) * tile / 2 - z * tile;
          final point = Rect.fromLTWH(sx, sy, 0, 0);
          bounds = first ? point : bounds.expandToInclude(point);
          first = false;
        }
      }
    }
  }
  final r = bounds.inflate(1);
  return Rect.fromLTRB(
    r.left.floorToDouble(),
    r.top.floorToDouble(),
    r.right.ceilToDouble(),
    r.bottom.ceilToDouble(),
  );
}

/// Draws [workers] over a town that is already painted.
///
/// Approach: each worker's boxes are painted on top; then, when an [index] is
/// given, the static blocks that are nearer the viewer than the worker (depth
/// key `x + y + z + 1.5` above the worker's) and cover some of its pixels are
/// painted again over it, so a worker hides behind a wall.
///
/// The repainting is clipped to the worker's own screen rectangle.
///
/// Each covering block is drawn twice.
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
    final nearer = index.inFront(w, tile: tile, origin: origin);
    if (nearer.isNotEmpty) {
      // Only inside the worker's own pixels: anywhere else a second coat of
      // anti-aliased edges would show as seams that move with the worker.
      canvas
        ..save()
        ..clipRect(
          workerScreenBounds(w, tile: tile, origin: origin),
          doAntiAlias: false,
        );
      paintBlocks(
        canvas,
        nearer,
        tile: tile,
        origin: origin,
        viewSize: viewSize,
      );
      canvas.restore();
    }
  }
}
