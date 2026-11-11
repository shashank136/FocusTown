import 'dart:math' as math;

import 'package:focus_town/game/world/plot_layout.dart';
import 'package:focus_town/game/world/scenery.dart';
import 'package:focus_town/game/world/voxel_world.dart';

/// Fills every plot with 3 or 4 trees, except the plots in [cleared] (the ones
/// with a building, a ruin or a site on them). Each tree's whole 3 x 3 canopy
/// stays inside its plot, so clearing a plot removes exactly its trees and
/// never touches a neighbour. The layout depends only on [seed] and the plot.
void buildForest(VoxelWorld w, {required Set<int> cleared, int seed = 11}) {
  for (final plot in kPlots) {
    if (cleared.contains(plot.index)) continue;
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
      buildTree(w, plot.originX + dx, plot.originY + dy);
    }
  }
}
