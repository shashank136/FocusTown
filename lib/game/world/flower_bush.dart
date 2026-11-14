import 'package:focus_town/game/world/block_material.dart';
import 'package:focus_town/game/world/voxel_world.dart';

/// A rounded flower bush centred on ([x], [y]): 3 x 3 blocks with a bump of
/// five on top, green with dots of bloom half and half. [colour] picks one of
/// the six bloom colours (any integer).
void buildFlowerBush(VoxelWorld w, int x, int y, int colour) {
  final m = Blocks.bushes[colour.abs() % Blocks.bushes.length];
  w.fill(x - 1, y - 1, 1, x + 1, y + 1, 1, m);
  for (final (dx, dy) in [(0, 0), (1, 0), (-1, 0), (0, 1), (0, -1)]) {
    w.set(x + dx, y + dy, 2, m);
  }
}
