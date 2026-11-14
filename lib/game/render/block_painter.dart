import 'dart:ui';

import 'package:focus_town/game/world/block_material.dart';
import 'package:focus_town/game/world/vec2.dart';
import 'package:focus_town/game/world/voxel_world.dart';

final Paint _paint = Paint()..style = PaintingStyle.fill;
final Path _path = Path();

// Fills the parallelogram (ax, ay) -> +u -> +u+v -> +v.
void _quad(
  Canvas canvas,
  double ax,
  double ay,
  double ux,
  double uy,
  double vx,
  double vy,
  int color,
) {
  _path
    ..reset()
    ..moveTo(ax, ay)
    ..lineTo(ax + ux, ay + uy)
    ..lineTo(ax + ux + vx, ay + uy + vy)
    ..lineTo(ax + vx, ay + vy)
    ..close();
  canvas.drawPath(_path, _paint..color = Color(color));
}

/// Which of the 16 cells (a 4 x 4 grid) of a face are bloom, picked from
/// [seed]: always exactly 8, so a bush is half green and half bloom on every
/// face, and the pattern differs from face to face.
List<bool> dotPattern(int seed) {
  const masks = [0xA5A5, 0x5A5A, 0xC33C, 0x3CC3];
  final h = (((seed * 2654435761) & 0xFFFFFFFF) >> 8) % masks.length;
  return [for (var i = 0; i < 16; i++) (masks[h] >> i) & 1 == 1];
}

// A face: the base color, plus (when [tex]) four sub-quads that each take one
// of the four texture variants, picked from [seed] so it never flickers.
void _face(
  Canvas canvas,
  double ax,
  double ay,
  double ux,
  double uy,
  double vx,
  double vy,
  List<int> colors,
  int seed,
  bool tex, [
  List<int>? dots,
]) {
  _quad(canvas, ax, ay, ux, uy, vx, vy, colors[0]);
  if (dots != null) {
    // A flower bush: a 4 x 4 grid, each cell green or bloom.
    final pattern = dotPattern(seed);
    final qux = ux / 4;
    final quy = uy / 4;
    final qvx = vx / 4;
    final qvy = vy / 4;
    for (var i = 0; i < 4; i++) {
      for (var j = 0; j < 4; j++) {
        final h =
            (((seed * 31 + i * 7 + j * 13) * 2654435761) & 0xFFFFFFFF) % 4;
        _quad(
          canvas,
          ax + qux * i + qvx * j,
          ay + quy * i + qvy * j,
          qux,
          quy,
          qvx,
          qvy,
          (pattern[i * 4 + j] ? dots : colors)[1 + h],
        );
      }
    }
    return;
  }
  if (!tex) return;
  final hux = ux / 2;
  final huy = uy / 2;
  final hvx = vx / 2;
  final hvy = vy / 2;
  for (var i = 0; i < 2; i++) {
    for (var j = 0; j < 2; j++) {
      final h = (((seed * 31 + i * 7 + j * 13) * 2654435761) & 0xFFFFFFFF) % 4;
      _quad(
        canvas,
        ax + hux * i + hvx * j,
        ay + huy * i + hvy * j,
        hux,
        huy,
        hvx,
        hvy,
        colors[1 + h],
      );
    }
  }
}

/// Draws [blocks] (already sorted back to front) as three-face blocks.
///
/// Blocks whose screen position is outside [viewSize] (plus a margin) are
/// skipped. Below a tile size of 9 and from 32 up the texture sub-quads are
/// left out.
void paintBlocks(
  Canvas canvas,
  Iterable<VisibleBlock> blocks, {
  required double tile,
  required Vec2 origin,
  required Size viewSize,
}) {
  // Textures only help in the middle: too small to see below 9, and past 32
  // the 4 x 4 sub-quads show up as visible rectangles.
  final tex = tile >= 9 && tile < 32;
  // Dots are drawn from the first size at which they can be seen, at any
  // zoom above it.
  final showDots = tile >= 9;
  final t = tile;
  for (final b in blocks) {
    final sx = origin.x + (b.x - b.y) * t;
    final sy = origin.y + (b.x + b.y) * t * 0.5 - b.z * t;
    if (sx < -2 * t ||
        sx > viewSize.width + 2 * t ||
        sy < -3 * t ||
        sy > viewSize.height + 2 * t) {
      continue;
    }
    final seed = (b.x * 73856093) ^ (b.y * 19349663) ^ (b.z * 83492791);
    final m = b.material;
    if (b.faces & kFaceTop != 0) {
      _face(
        canvas,
        sx,
        sy - t,
        t,
        t * 0.5,
        -t,
        t * 0.5,
        m.top,
        seed,
        tex,
        showDots ? m.dotTop : null,
      );
    }
    if (b.faces & kFaceX != 0) {
      _face(
        canvas,
        sx + t,
        sy - t * 0.5,
        -t,
        t * 0.5,
        0,
        t,
        m.sideX,
        seed + 1,
        tex,
        showDots ? m.dotSideX : null,
      );
    }
    if (b.faces & kFaceY != 0) {
      _face(
        canvas,
        sx - t,
        sy - t * 0.5,
        t,
        t * 0.5,
        0,
        t,
        m.sideY,
        seed + 2,
        tex,
        showDots ? m.dotSideY : null,
      );
    }
  }
}

/// Draws a [w] x [d] x [h] box (worker parts) at world position ([x], [y],
/// [z]) in one flat color, shaded per face.
void paintBox(
  Canvas canvas, {
  required double x,
  required double y,
  required double z,
  required double w,
  required double d,
  required double h,
  required FlatColor color,
  required double tile,
  required Vec2 origin,
}) {
  final t = tile;
  Vec2 p(double px, double py, double pz) =>
      Vec2(origin.x + (px - py) * t, origin.y + (px + py) * t * 0.5 - pz * t);
  final top = p(x, y, z + h);
  _quad(
    canvas,
    top.x,
    top.y,
    w * t,
    w * t * 0.5,
    -d * t,
    d * t * 0.5,
    color.top,
  );
  final right = p(x + w, y, z);
  _quad(canvas, right.x, right.y, -d * t, d * t * 0.5, 0, -h * t, color.sideX);
  final left = p(x, y + d, z);
  _quad(canvas, left.x, left.y, w * t, w * t * 0.5, 0, -h * t, color.sideY);
}
