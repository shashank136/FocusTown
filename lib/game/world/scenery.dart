import 'dart:math' as math;

import 'package:focus_town/game/world/block_material.dart';
import 'package:focus_town/game/world/plot_layout.dart';
import 'package:focus_town/game/world/voxel_world.dart';

/// A tree with its trunk at ([x], [y]): trunk z 1..3, 3x3 canopy at z 4, a
/// plus-shaped layer at z 5 and a tip at z 6.
void buildTree(VoxelWorld w, int x, int y) {
  w.fill(x, y, 1, x, y, 3, Blocks.log);
  for (var dx = -1; dx <= 1; dx++) {
    for (var dy = -1; dy <= 1; dy++) {
      w.set(x + dx, y + dy, 4, Blocks.leaves);
      if (dx.abs() + dy.abs() < 2) w.set(x + dx, y + dy, 5, Blocks.leaves);
    }
  }
  w.set(x, y, 6, Blocks.leaves);
}

/// A pond in the top-right border strip, replacing the grass there.
void buildPond(VoxelWorld w) => w.fill(56, 0, 0, 62, 2, 0, Blocks.water);

bool _inPond(int x, int y) => x >= 56 && x <= 62 && y >= 0 && y <= 2;

// A tree here keeps its whole 3x3 canopy on the map, off roads, plots and the
// pond.
bool _canopyClear(int x, int y) {
  for (var dx = -1; dx <= 1; dx++) {
    for (var dy = -1; dy <= 1; dy++) {
      final tx = x + dx;
      final ty = y + dy;
      if (tx < 0 || ty < 0 || tx >= kMapSize || ty >= kMapSize) return false;
      if (isRoad(tx, ty) || plotAt(tx, ty) != null || _inPond(tx, ty)) {
        return false;
      }
    }
  }
  return true;
}

/// The pond plus 24 trees on the map border, chosen deterministically from
/// [seed]. Trees keep at least 3 tiles between each other.
void buildScenery(VoxelWorld w, {int seed = 7}) {
  buildPond(w);
  final candidates = <(int, int)>[
    for (var x = 0; x < kMapSize; x++)
      for (var y = 0; y < kMapSize; y++)
        if ((x <= 2 || x >= 61 || y <= 2 || y >= 61) && _canopyClear(x, y))
          (x, y),
  ]..shuffle(math.Random(seed));
  final placed = <(int, int)>[];
  for (final (x, y) in candidates) {
    if (placed.length == 24) break;
    final apart = placed.every(
      (p) => math.max((p.$1 - x).abs(), (p.$2 - y).abs()) >= 3,
    );
    if (!apart) continue;
    placed.add((x, y));
    buildTree(w, x, y);
  }
}
