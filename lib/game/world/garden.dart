import 'package:focus_town/game/world/block_material.dart';
import 'package:focus_town/game/world/flower_bush.dart';
import 'package:focus_town/game/world/voxel_world.dart';

/// How many gardens there are: park, pond, orchard and flower beds.
const kGardenLooks = 4;

/// Draws open space on the 7 x 7 parcel at ([ox], [oy]); [look] is 0..3. The
/// ground below is already there, and nothing leaves the parcel. Every garden
/// has flowers in several colours.
void buildGarden(VoxelWorld w, int ox, int oy, int look) {
  // A flower at ([dx], [dy]) in the parcel; [i] picks its colour.
  void flower(int dx, int dy, int i) =>
      w.set(ox + dx, oy + dy, 1, flowerColors[i % flowerColors.length]);

  // The ground is a carpet of flowers in patches of colour, never grass; the
  // paths and the water of each garden are laid over it.
  for (var dx = 0; dx < 7; dx++) {
    for (var dy = 0; dy < 7; dy++) {
      final patch = (dx ~/ 2) + 2 * (dy ~/ 2) + look;
      w.set(ox + dx, oy + dy, 0, flowerColors[patch % flowerColors.length]);
    }
  }

  switch (look % kGardenLooks) {
    case 0: // park: a cross of paths, two trees, a bench, flowers by the paths
      for (var i = 0; i < 7; i++) {
        w
          ..set(ox + 3, oy + i, 0, Blocks.path)
          ..set(ox + i, oy + 3, 0, Blocks.path);
      }
      w.fill(ox + 5, oy + 1, 1, ox + 5, oy + 2, 1, Blocks.plank);
      var i = 0;
      for (final (dx, dy) in [
        (2, 0),
        (4, 0),
        (2, 6),
        (4, 6),
        (0, 2),
        (0, 4),
        (6, 2),
        (6, 4),
        (2, 2),
        (4, 4),
        (4, 2),
        (2, 4),
      ]) {
        flower(dx, dy, i++);
      }
      buildFlowerBush(w, ox + 1, oy + 1, 0);
      buildFlowerBush(w, ox + 5, oy + 5, 3);
    case 1: // pond: water with stones and flowers round it
      w.fill(ox + 2, oy + 2, 0, ox + 4, oy + 4, 0, Blocks.water);
      for (final (dx, dy) in [(1, 1), (5, 1), (1, 5), (5, 5), (3, 1), (3, 5)]) {
        w.set(ox + dx, oy + dy, 1, Blocks.cobble);
      }
      var i = 0;
      for (final (dx, dy) in [
        (1, 2),
        (1, 4),
        (5, 2),
        (5, 4),
        (2, 1),
        (4, 1),
        (2, 5),
        (4, 5),
        (6, 0),
        (6, 6),
        (0, 6),
      ]) {
        flower(dx, dy, i++);
      }
      // Two bushes in the far corners, over the stones there.
      buildFlowerBush(w, ox + 1, oy + 1, 1);
      buildFlowerBush(w, ox + 5, oy + 5, 4);
    case 2: // orchard: four flower bushes, flowers in the grass
      var i = 0;
      for (final (dx, dy) in [
        (3, 1),
        (3, 3),
        (3, 5),
        (1, 3),
        (5, 3),
        (0, 0),
        (6, 0),
        (0, 6),
        (6, 6),
        (2, 3),
        (4, 3),
      ]) {
        flower(dx, dy, i++);
      }
      var n = 0;
      for (final (dx, dy) in [(1, 1), (5, 1), (1, 5), (5, 5)]) {
        buildFlowerBush(w, ox + dx, oy + dy, n++ * 2);
      }
    default: // flower beds: rows of colour, with a bush in each front corner
      for (var dx = 1; dx <= 5; dx++) {
        for (var dy = 1; dy <= 5; dy++) {
          // The even squares are taller blooms, the rest low ones.
          flower(dx, dy, dx + 2 * dy);
          if (dx.isEven && dy.isEven) {
            w.set(ox + dx, oy + dy, 2, flowerColors[(dx + dy + 1) % 5]);
          }
        }
      }
      w.fill(ox, oy, 1, ox + 6, oy, 1, Blocks.plank); // a fence on one side
      // Two bushes in the corners at the front.
      buildFlowerBush(w, ox + 1, oy + 5, 2);
      buildFlowerBush(w, ox + 5, oy + 5, 5);
  }
}
