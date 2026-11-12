import 'package:focus_town/game/world/block_material.dart';
import 'package:focus_town/game/world/voxel_world.dart';

/// How many gardens there are: park, pond, orchard and flower beds.
const kGardenLooks = 4;

/// Draws open space on the 7 x 7 parcel at ([ox], [oy]); [look] is 0..3. The
/// ground below is already there, and nothing leaves the parcel.
void buildGarden(VoxelWorld w, int ox, int oy, int look) {
  switch (look % kGardenLooks) {
    case 0: // park: a cross of paths, two trees and a bench
      for (var i = 0; i < 7; i++) {
        w
          ..set(ox + 3, oy + i, 0, Blocks.path)
          ..set(ox + i, oy + 3, 0, Blocks.path);
      }
      _tree(w, ox + 1, oy + 1);
      _tree(w, ox + 5, oy + 5);
      w.fill(ox + 5, oy + 1, 1, ox + 5, oy + 2, 1, Blocks.plank);
    case 1: // pond: water with stones round it
      w.fill(ox + 2, oy + 2, 0, ox + 4, oy + 4, 0, Blocks.water);
      for (final (dx, dy) in [(1, 1), (5, 1), (1, 5), (5, 5), (3, 1), (3, 5)]) {
        w.set(ox + dx, oy + dy, 1, Blocks.cobble);
      }
      w.fill(ox, oy, 1, ox, oy, 2, Blocks.log);
    case 2: // orchard: four fruit trees
      for (final (dx, dy) in [(1, 1), (5, 1), (1, 5), (5, 5)]) {
        _tree(w, ox + dx, oy + dy);
        w.set(ox + dx + 1, oy + dy, 3, Blocks.wool); // an apple
      }
    default: // flower beds
      for (var dx = 1; dx <= 5; dx += 2) {
        for (var dy = 1; dy <= 5; dy += 2) {
          w.set(
            ox + dx,
            oy + dy,
            1,
            (dx + dy) % 4 == 0 ? Blocks.wool : Blocks.leaves,
          );
        }
      }
      w.fill(ox, oy, 1, ox + 6, oy, 1, Blocks.plank); // a fence on one side
  }
}

// A small tree whose canopy stays inside the 3 x 3 around its trunk.
void _tree(VoxelWorld w, int x, int y) {
  w.fill(x, y, 1, x, y, 2, Blocks.log);
  for (var dx = -1; dx <= 1; dx++) {
    for (var dy = -1; dy <= 1; dy++) {
      w.set(x + dx, y + dy, 3, Blocks.leaves);
    }
  }
}
