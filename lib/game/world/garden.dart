import 'package:focus_town/game/world/block_material.dart';
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
      _tree(w, ox + 1, oy + 1, Blocks.flowerPink);
      _tree(w, ox + 5, oy + 5, Blocks.flowerViolet);
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
    case 1: // pond: water with stones and flowers round it
      w.fill(ox + 2, oy + 2, 0, ox + 4, oy + 4, 0, Blocks.water);
      for (final (dx, dy) in [(1, 1), (5, 1), (1, 5), (5, 5), (3, 1), (3, 5)]) {
        w.set(ox + dx, oy + dy, 1, Blocks.cobble);
      }
      w.fill(ox, oy, 1, ox, oy, 2, Blocks.log);
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
    case 2: // orchard: four fruit trees, flowers in the grass
      for (final (dx, dy) in [(1, 1), (5, 1), (1, 5), (5, 5)]) {
        _tree(
          w,
          ox + dx,
          oy + dy,
          (dx + dy) % 4 == 2 ? Blocks.flowerPink : Blocks.flowerYellow,
        );
        w.set(ox + dx + 1, oy + dy, 3, Blocks.wool); // an apple
      }
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
    default: // flower beds: rows of colour between low hedges
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
  }
}

// A small blossom tree whose canopy stays inside the 3 x 3 around its trunk.
void _tree(VoxelWorld w, int x, int y, BlockMaterial canopy) {
  w.fill(x, y, 1, x, y, 2, Blocks.log);
  for (var dx = -1; dx <= 1; dx++) {
    for (var dy = -1; dy <= 1; dy++) {
      w.set(x + dx, y + dy, 3, canopy);
    }
  }
}
