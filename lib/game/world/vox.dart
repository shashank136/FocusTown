import 'dart:math' as math;

import 'package:focus_town/game/world/block_material.dart';
import 'package:focus_town/game/world/voxel_world.dart';

/// A block of a design, with coordinates inside the design's own area (from
/// 0, 0, 0).
typedef DesignBlock = ({int x, int y, int z, BlockMaterial material});

/// A design being drawn on a [width] x [depth] area, at heights from 0 up.
/// Blocks outside the area are ignored and a block placed again replaces the
/// one there. The landmarks are drawn with this, then put into the town stage
/// by stage with [paintDesign].
class Vox {
  /// Creates an empty design for an area of [width] x [depth] tiles.
  new(this.width, this.depth);

  /// Tiles along x.
  final int width;

  /// Tiles along y.
  final int depth;

  final Map<int, DesignBlock> _blocks = {};

  /// The blocks of the design.
  Iterable<DesignBlock> get blocks => _blocks.values;

  /// Places one block.
  void set(int x, int y, int z, BlockMaterial m) {
    if (x < 0 || y < 0 || z < 0 || x >= width || y >= depth) return;
    _blocks[(x * 256 + y) * 256 + z] = (x: x, y: y, z: z, material: m);
  }

  /// Takes the block at ([x], [y], [z]) away.
  void remove(int x, int y, int z) {
    _blocks.remove((x * 256 + y) * 256 + z);
  }

  /// Fills the inclusive box from ([x0], [y0], [z0]) to ([x1], [y1], [z1]).
  void box(int x0, int y0, int z0, int x1, int y1, int z1, BlockMaterial m) {
    for (var x = x0; x <= x1; x++) {
      for (var y = y0; y <= y1; y++) {
        for (var z = z0; z <= z1; z++) {
          set(x, y, z, m);
        }
      }
    }
  }

  /// The outline of the rectangle from ([x0], [y0]) to ([x1], [y1]) on every
  /// level from [z0] to [z1].
  void ring(int x0, int y0, int x1, int y1, int z0, int z1, BlockMaterial m) {
    for (var x = x0; x <= x1; x++) {
      for (var y = y0; y <= y1; y++) {
        if (x != x0 && x != x1 && y != y0 && y != y1) continue;
        for (var z = z0; z <= z1; z++) {
          set(x, y, z, m);
        }
      }
    }
  }

  /// A filled round disc of radius [r] about ([cx], [cy]) on levels [z0] to
  /// [z1].
  void disc(double cx, double cy, double r, int z0, int z1, BlockMaterial m) {
    for (var x = (cx - r).floor(); x <= (cx + r).ceil(); x++) {
      for (var y = (cy - r).floor(); y <= (cy + r).ceil(); y++) {
        final dx = x - cx;
        final dy = y - cy;
        if (dx * dx + dy * dy > r * r + 0.25) continue;
        for (var z = z0; z <= z1; z++) {
          set(x, y, z, m);
        }
      }
    }
  }
}

/// Puts [design] into [w] with its corner at ([ox], [oy]), as far as [stage]
/// of [stages] has got: it grows from the ground up, every stage adding the
/// next layers, and the last stage shows all of it. Stage 0 draws nothing.
void paintDesign(
  VoxelWorld w,
  Vox design,
  int ox,
  int oy,
  int stage,
  int stages,
) {
  if (stage <= 0) return;
  final levels = {for (final b in design.blocks) b.z}.toList()..sort();
  if (levels.isEmpty) return;
  final shown = stage >= stages
      ? levels.length
      : math.max(1, (levels.length * stage / stages).ceil());
  final top = levels[shown - 1];
  for (final b in design.blocks) {
    if (b.z <= top) w.set(ox + b.x, oy + b.y, b.z, b.material);
  }
}
