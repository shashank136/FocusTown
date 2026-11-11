import 'dart:math' as math;

import 'package:focus_town/game/world/block_material.dart';
import 'package:focus_town/game/world/plot_layout.dart';
import 'package:focus_town/game/world/voxel_world.dart';

/// Fills every plot with 3 or 4 trees, except the plots in [cleared] (the ones
/// with a building, a ruin or a site on them). Each tree's whole 3 x 3 canopy
/// stays inside its plot, so clearing a plot removes exactly its trees and
/// never touches a neighbour. The layout depends only on [seed] and the plot.
void buildForest(VoxelWorld w, {required Set<int> cleared, int seed = 11}) {
  for (final plot in kPlots) {
    if (cleared.contains(plot.index)) continue;
    final fixed = _roadSideTrees(plot);
    if (fixed != null) {
      for (final (dx, dy) in fixed) {
        _lowTree(w, plot.originX + dx, plot.originY + dy);
      }
      continue;
    }
    final random = math.Random(seed * 1000 + plot.index);
    // Trunks sit on the 5 x 5 inner tiles so the canopy fits the 7 x 7 plot:
    // up to one near each corner, at least 3 tiles apart (the left and top
    // ones may shift one tile inward, the far ones stay put).
    final corners = <(int, int)>[
      (1 + random.nextInt(2), 1 + random.nextInt(2)),
      (5, 1 + random.nextInt(2)),
      (1 + random.nextInt(2), 5),
      (5, 5),
    ]..shuffle(random);
    for (final (dx, dy) in corners.take(3 + random.nextInt(2))) {
      _lowTree(w, plot.originX + dx, plot.originY + dy);
    }
  }
}

// A squat tree (4 blocks tall against 6): tall canopies hide the roads and
// paths behind them in the isometric view.
void _lowTree(VoxelWorld w, int x, int y) {
  w.fill(x, y, 1, x, y, 2, Blocks.log);
  for (var dx = -1; dx <= 1; dx++) {
    for (var dy = -1; dy <= 1; dy++) {
      w.set(x + dx, y + dy, 3, Blocks.leaves);
      if (dx.abs() + dy.abs() < 2) w.set(x + dx, y + dy, 4, Blocks.leaves);
    }
  }
}

// Plots just south or east of a road (origin 33): a tree near the road edge
// would hide the road behind it in the isometric view, so their trees stand
// on the far side only.
List<(int, int)>? _roadSideTrees(Plot plot) {
  final east = plot.originX == 33;
  final south = plot.originY == 33;
  if (east && south) return [(4, 5), (5, 4), (5, 5)];
  if (east) return [(5, 1), (5, 3), (5, 5)];
  if (south) return [(1, 5), (3, 5), (5, 5)];
  return null;
}
