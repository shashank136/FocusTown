import 'dart:math' as math;

import 'package:focus_town/game/world/block_material.dart';
import 'package:focus_town/game/world/voxel_world.dart';

/// [n] rounded the way a design's author rounds: halves go up, also below 0.
int jsRound(num n) => (n + 0.5).floor();

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

  /// Places one block. Coordinates are rounded to whole tiles ([jsRound]).
  void set(num x, num y, num z, BlockMaterial m) {
    final ix = jsRound(x);
    final iy = jsRound(y);
    final iz = jsRound(z);
    if (ix < 0 || iy < 0 || iz < 0 || ix >= width || iy >= depth) return;
    _blocks[(ix * 256 + iy) * 256 + iz] = (x: ix, y: iy, z: iz, material: m);
  }

  /// Takes the block at ([x], [y], [z]) away.
  void remove(num x, num y, num z) {
    _blocks.remove((jsRound(x) * 256 + jsRound(y)) * 256 + jsRound(z));
  }

  /// Fills the inclusive box from ([x0], [y0], [z0]) to ([x1], [y1], [z1]).
  void box(num x0, num y0, num z0, num x1, num y1, num z1, BlockMaterial m) {
    for (var x = jsRound(x0); x <= jsRound(x1); x++) {
      for (var y = jsRound(y0); y <= jsRound(y1); y++) {
        for (var z = jsRound(z0); z <= jsRound(z1); z++) {
          set(x, y, z, m);
        }
      }
    }
  }

  /// The outline of the rectangle from ([x0], [y0]) to ([x1], [y1]) on every
  /// level from [z0] to [z1].
  void ring(num x0, num y0, num x1, num y1, num z0, num z1, BlockMaterial m) {
    final ax = jsRound(x0);
    final ay = jsRound(y0);
    final bx = jsRound(x1);
    final by = jsRound(y1);
    for (var x = ax; x <= bx; x++) {
      for (var y = ay; y <= by; y++) {
        if (x != ax && x != bx && y != ay && y != by) continue;
        for (var z = jsRound(z0); z <= jsRound(z1); z++) {
          set(x, y, z, m);
        }
      }
    }
  }

  /// A filled round disc of radius [r] about ([cx], [cy]) on levels [z0] to
  /// [z1].
  void disc(num cx, num cy, num r, num z0, num z1, BlockMaterial m) {
    for (var x = (cx - r).floor(); x <= (cx + r).ceil(); x++) {
      for (var y = (cy - r).floor(); y <= (cy + r).ceil(); y++) {
        final dx = x - cx;
        final dy = y - cy;
        if (dx * dx + dy * dy > r * r + 0.25) continue;
        for (var z = jsRound(z0); z <= jsRound(z1); z++) {
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
