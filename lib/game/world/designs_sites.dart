// The site designs of the landmarks (rock-cut, walled and pyramid shapes),
// drawn on a Vox (see vox.dart). They are ported from the sketches the player
// chose (docs/reference/landmark_island.html).
// ignore_for_file: cascade_invocations

import 'dart:math' as math;

import 'package:focus_town/game/world/block_material.dart';
import 'package:focus_town/game/world/vox.dart';

/// Petra on a 3 x 2 block: a red cliff with a narrow canyon in front of it
/// that gets lower towards the viewer, the rock-cut Treasury with a row of
/// columns, a doorway, a round tholos between two half pediments and an urn,
/// and steps down to the canyon floor.
Vox petraDesign({int width = 19, int depth = 12, int height = 12}) {
  final v = Vox(width, depth);
  v.box(0, 0, 0, width - 1, depth - 1, 0, Blocks.travertine);
  v.box(0, 0, 1, width - 1, 2, height + 3, Blocks.redRock);
  int wall(int y) => math.max(2, height + 2 - jsRound(y * 1.3));
  for (var y = 0; y < depth; y++) {
    v
      ..box(0, y, 1, 2, y, wall(y), Blocks.redRock)
      ..box(width - 3, y, 1, width - 1, y, wall(y), Blocks.redRock);
  }
  for (var z = 2; z <= height + 3; z += 2) {
    v.box(0, 0, z, width - 1, 2, z, Blocks.redRockLight);
    for (var y = 0; y < depth; y++) {
      if (z <= wall(y)) {
        v
          ..box(0, y, z, 2, y, z, Blocks.redRockLight)
          ..box(width - 3, y, z, width - 1, y, z, Blocks.redRockLight);
      }
    }
  }
  const fy = 3;
  final cx = jsRound((width - 1) / 2);
  final fw = math.max(5, width - 8);
  final fx0 = cx - (fw >> 1);
  final fx1 = fx0 + fw - 1;
  final lo = math.max(3, jsRound(height * 0.5));
  for (var x = fx0; x <= fx1; x += 2) {
    v.box(x, fy, 1, x, fy, lo, Blocks.rose);
  }
  v
    ..box(fx0, fy, lo + 1, fx1, fy, lo + 1, Blocks.rose)
    ..box(cx, fy, 1, cx, fy, math.max(2, lo - 1), Blocks.char)
    ..box(cx - 1, fy, 1, cx - 1, fy, math.max(2, lo - 1), Blocks.char)
    ..box(cx - 1, fy, lo + 2, cx, fy, height, Blocks.rose)
    ..box(cx - 1, fy, height + 1, cx, fy, height + 1, Blocks.redRockLight)
    ..set(cx, fy, height + 2, Blocks.rose)
    ..box(fx0, fy, lo + 2, cx - 3, fy, lo + 3, Blocks.rose)
    ..box(cx + 2, fy, lo + 2, fx1, fy, lo + 3, Blocks.rose)
    ..set(cx - 1, fy, height + 3, Blocks.rose)
    ..box(fx0, fy + 1, 1, fx1, fy + 1, 1, Blocks.travertine)
    ..box(fx0, fy + 2, 1, fx1, fy + 2, 0, Blocks.travertine);
  return v;
}

/// The Great Sphinx on a 4 x 2 block: a lion's body with a raised haunch,
/// folded hind legs and a tail, the chest, two forelegs stretched out with
/// toes, the head in a headdress of gold and blue stripes with a flat face
/// (the nose long broken off) and a cobra on the brow, in the pit it was cut
/// from, with the pillars of its temple in front.
Vox sphinxDesign({int width = 26, int depth = 12, int height = 12}) {
  final v = Vox(width, depth);
  final skin = Blocks.sandstone;
  final skin2 = Blocks.sandstoneDark;
  final skin3 = Blocks.path;
  final wall = Blocks.travertine;
  final wall2 = Blocks.sandstoneDark;
  v.box(0, 0, 0, width - 1, depth - 1, 0, Blocks.path);
  final cy = jsRound((depth - 1) / 2);
  const hw = 2;
  final hx1 = width - 6;
  final hx0 = hx1 - 4;
  final bodyEnd = hx0 - 2;
  v
    ..box(0, 0, 1, math.max(0, width - 9), 0, 3, wall2)
    ..box(0, depth - 1, 1, math.max(0, width - 9), depth - 1, 1, wall2)
    ..box(0, 0, 1, 0, depth - 1, 3, wall2);
  for (final (x, y) in [(2, 1), (4, depth - 2), (9, 1), (7, depth - 2)]) {
    v.set(x, y, 1, wall);
  }
  for (var x = 2; x <= bodyEnd; x++) {
    final rear = x <= 6;
    final top = rear ? 5 : 4;
    v
      ..box(x, cy - hw, 1, x, cy + hw, top - 1, skin)
      ..box(x, cy - hw + 1, top, x, cy + hw - 1, top, skin);
    if (rear) v.box(x, cy - hw + 1, top + 1, x, cy + hw - 1, top + 1, skin2);
  }
  for (final y in [cy - hw - 1, cy + hw + 1]) {
    v.box(3, y, 1, 6, y, 2, skin2);
  }
  v
    ..box(2, cy + hw + 1, 1, 2, cy + hw + 3, 1, skin3)
    ..box(3, cy + hw + 3, 1, 5, cy + hw + 3, 1, skin3)
    ..box(bodyEnd + 1, cy - hw, 1, hx0 + 1, cy + hw, 5, skin);
  for (final y in [cy - hw - 1, cy + hw]) {
    v.box(hx0, y, 1, width - 3, y + 1, 2, skin);
    for (var x = width - 5; x <= width - 3; x++) {
      if ((x + y).isEven) v.set(x, y, 2, skin2);
    }
    v
      ..set(width - 3, y, 1, skin3)
      ..set(width - 3, y + 1, 1, skin3);
  }
  v.box(hx0, cy - hw, 5, hx1, cy + hw, 11, skin);
  for (var x = hx0; x <= hx1; x++) {
    for (var y = cy - hw; y <= cy + hw; y++) {
      v.set(x, y, 11, Blocks.gold);
    }
  }
  for (final y in [cy - hw - 1, cy + hw + 1]) {
    for (var x = hx0 + 1; x <= hx1 - 1; x++) {
      for (var z = 6; z <= 10; z++) {
        v.set(x, y, z, z.isOdd ? Blocks.gold : Blocks.lapis);
      }
    }
  }
  for (var z = 5; z <= 10; z++) {
    for (var y = cy - hw; y <= cy + hw; y++) {
      v.set(hx0, y, z, z.isOdd ? Blocks.gold : Blocks.lapis);
    }
  }
  for (var y = cy - hw; y <= cy + hw; y++) {
    v.set(hx1, y, 10, Blocks.gold);
  }
  v
    ..set(hx1, cy - 1, 9, Blocks.char)
    ..set(hx1, cy + 1, 9, Blocks.char)
    ..set(hx1, cy - 1, 8, skin3)
    ..set(hx1, cy + 1, 8, skin3)
    ..set(hx1 + 1, cy, 7, skin2)
    ..set(hx1, cy, 7, Blocks.char)
    ..set(hx1, cy, 8, skin)
    ..box(hx1, cy - 1, 6, hx1, cy + 1, 6, Blocks.char)
    ..box(hx1 + 1, cy - 1, 5, hx1 + 1, cy + 1, 5, skin)
    ..set(hx1 + 1, cy, 10, Blocks.gold)
    ..set(hx1 + 1, cy, 11, Blocks.gold);
  for (final y in [cy - 3, cy, cy + 3]) {
    v
      ..box(width - 1, y, 1, width - 1, y, 3, wall)
      ..set(width - 1, y, 4, wall2);
  }
  v
    ..box(math.max(0, width - 8), 0, 1, width - 3, 0, 1, wall2)
    ..box(math.max(0, width - 8), depth - 1, 1, width - 3, depth - 1, 1, wall2);
  return v;
}

/// Chichén Itzá (El Castillo) on a 3 x 3 block: a plaza, a stepped pyramid
/// with four stairways, each a light strip between dark rails, a temple with a
/// door on top, and a ball court beside it.
Vox chichenItzaDesign({int width = 19, int depth = 19, int height = 11}) {
  final v = Vox(width, depth);
  v.box(0, 0, 0, width - 1, depth - 1, 0, Blocks.travertine);
  final m = math.min(width, depth) - (width >= 19 ? 6 : 3);
  final x0 = jsRound((width - m) / 2);
  final y0 = jsRound((depth - m) / 2);
  final cx = x0 + (m >> 1);
  final cy = y0 + (m >> 1);
  final t = math.min<int>(9, height - 3);
  final th = math.max<int>(1, (height - 3) ~/ t);
  for (var i = 0; i < t; i++) {
    final ins = (i * (m / 2 - 2) / t).floor();
    for (var z = 1 + i * th; z <= (i + 1) * th; z++) {
      v.box(
        x0 + ins,
        y0 + ins,
        z,
        x0 + m - 1 - ins,
        y0 + m - 1 - ins,
        z,
        Blocks.stone,
      );
    }
  }
  final top = t * th;
  for (var z = 1; z <= top; z++) {
    final ins = (((z - 1) / th) * (m / 2 - 2) / t).floor();
    for (final (sx, sy, dx, dy) in [
      (cx, y0 + m - 1 - ins, 1, 0),
      (cx, y0 + ins, 1, 0),
      (x0 + m - 1 - ins, cy, 0, 1),
      (x0 + ins, cy, 0, 1),
    ]) {
      v
        ..set(sx, sy, z, Blocks.marble)
        ..set(sx + dx, sy + dy, z, Blocks.marble)
        ..set(sx - dx, sy - dy, z, Blocks.cobble)
        ..set(sx + 2 * dx, sy + 2 * dy, z, Blocks.cobble);
    }
  }
  final tw = math.max<int>(3, ((m / 2 - 1) * 0.9).floor());
  final tx = cx - (tw >> 1);
  final ty = cy - (tw >> 1);
  v
    ..ring(tx, ty, tx + tw, ty + tw, top + 1, top + 2, Blocks.stone)
    ..set(cx, ty + tw, top + 1, Blocks.char)
    ..set(cx, ty + tw, top + 2, Blocks.char)
    ..box(
      tx - 1,
      ty - 1,
      top + 3,
      tx + tw + 1,
      ty + tw + 1,
      top + 3,
      Blocks.cobble,
    )
    ..box(
      tx + 1,
      ty + 1,
      top + 4,
      tx + tw - 1,
      ty + tw - 1,
      top + 4,
      Blocks.stone,
    );
  if (width >= 19) {
    final end = math.max(4, x0 - 2);
    v
      ..box(1, depth - 3, 0, end, depth - 2, 0, Blocks.path)
      ..box(1, depth - 4, 1, end, depth - 4, 2, Blocks.cobble)
      ..box(1, depth - 1, 1, end, depth - 1, 2, Blocks.cobble);
  }
  return v;
}

/// The Colosseum on a 4 x 4 block: an oval of three storeys of arches under a
/// solid attic, ruined at the back, the seats rising in rings, and the arena
/// floor with the lines of the hypogeum.
Vox colosseumDesign({int width = 26, int depth = 26, int height = 12}) {
  final v = Vox(width, depth);
  final cx = (width - 1) / 2;
  final cy = (depth - 1) / 2;
  final rx = width / 2;
  final ry = depth / 2;
  final tierH = math.max<int>(2, (height - 1) ~/ 3);
  for (var x = 0; x < width; x++) {
    for (var y = 0; y < depth; y++) {
      final dx = (x - cx) / rx;
      final dy = (y - cy) / ry;
      final r = math.sqrt(dx * dx + dy * dy);
      if (r > 1) continue;
      if (r > 0.86) {
        final back = (dx + dy) < -0.45;
        final hh = back
            ? math.max(2, height - 2 - jsRound((-(dx + dy) - 0.45) * 6))
            : height;
        for (var z = 0; z < hh; z++) {
          final inArch =
              z > 0 && z < height - 1 && z % tierH != 0 && (x + y).isEven;
          v.set(
            x,
            y,
            z + 1,
            inArch
                ? Blocks.char
                : ((z ~/ tierH).isOdd ? Blocks.sandstone : Blocks.travertine),
          );
        }
        v.set(x, y, 0, Blocks.sandstone);
      } else if (r > 0.5) {
        final ring = ((r - 0.5) / 0.36 * (height - 3)).floor();
        final top = 1 + ring;
        for (var z = 0; z <= top; z++) {
          v.set(
            x,
            y,
            z + 1,
            ring.isOdd ? Blocks.sandstoneDark : Blocks.sandstone,
          );
        }
        v.set(x, y, 0, Blocks.sandstone);
      } else {
        v.set(
          x,
          y,
          0,
          (x % 3 == 0 || y % 3 == 0) && r < 0.42
              ? Blocks.sandstoneDark
              : Blocks.travertine,
        );
      }
    }
  }
  v
    ..set(jsRound(cx), depth - 1, 1, Blocks.char)
    ..set(jsRound(cx), depth - 1, 2, Blocks.char);
  return v;
}

/// The Taj Mahal on a 5 x 4 block: a garden with a cross of water, a pool,
/// paths and cypress trees; the tomb on its white platform with four
/// minarets, an iwan arch, an onion dome with a gold finial and four kiosks;
/// two red sandstone buildings with white domes; a red gate with a row of
/// small domes.
Vox tajMahalDesign({int width = 33, int depth = 26, int height = 16}) {
  final v = Vox(width, depth);
  final cx = jsRound((width - 1) / 2);
  v.box(0, 0, 0, width - 1, depth - 1, 0, Blocks.grass);
  final gy0 = jsRound(depth * 0.42);
  final gy1 = depth - 5;
  final my = jsRound((gy0 + gy1) / 2);
  v
    ..box(cx - 1, gy0, 0, cx + 1, gy1, 0, Blocks.travertine)
    ..box(0, my - 1, 0, width - 1, my + 1, 0, Blocks.travertine)
    ..box(cx, gy0, 0, cx, gy1, 0, Blocks.water)
    ..box(1, my, 0, width - 2, my, 0, Blocks.water)
    ..box(cx - 2, my - 2, 0, cx + 2, my + 2, 0, Blocks.marble)
    ..box(cx - 1, my - 1, 0, cx + 1, my + 1, 0, Blocks.water);
  for (var y = gy0 + 1; y <= gy1; y += 2) {
    for (final x in [cx - 3, cx + 3]) {
      if ((y - my).abs() > 2) {
        v
          ..set(x, y, 1, Blocks.leaves)
          ..set(x, y, 2, Blocks.leaves);
      }
    }
  }
  final pw = jsRound(width * 0.5);
  final px0 = cx - (pw >> 1);
  final px1 = px0 + pw - 1;
  final py1 = math.max(5, gy0 - 1);
  v.box(px0, 0, 1, px1, py1, 2, Blocks.marble);
  for (final x in [px0, px1]) {
    for (final y in [0, py1]) {
      v
        ..box(x, y, 3, x, y, jsRound(height * 0.78), Blocks.marble)
        ..box(
          x - 1,
          y - 1,
          jsRound(height * 0.5),
          x + 1,
          y + 1,
          jsRound(height * 0.5),
          Blocks.marble,
        )
        ..box(
          x - 1,
          y - 1,
          jsRound(height * 0.74),
          x + 1,
          y + 1,
          jsRound(height * 0.74),
          Blocks.marble,
        )
        ..box(
          x,
          y,
          jsRound(height * 0.79),
          x,
          y,
          jsRound(height * 0.85),
          Blocks.gold,
        );
    }
  }
  final tb = math.max<int>(5, (pw >> 1) | 1);
  final tx0 = cx - (tb >> 1);
  final ty0 = math.max(1, jsRound((py1 - tb) / 2));
  final th = jsRound(height * 0.46);
  for (var z = 3; z <= th; z++) {
    v
      ..box(tx0, ty0, z, tx0 + tb - 1, ty0 + tb - 1, z, Blocks.marble)
      ..remove(tx0, ty0, z)
      ..remove(tx0 + tb - 1, ty0, z)
      ..remove(tx0, ty0 + tb - 1, z)
      ..remove(tx0 + tb - 1, ty0 + tb - 1, z);
  }
  v
    ..box(
      cx - 1,
      ty0 + tb - 1,
      4,
      cx + 1,
      ty0 + tb - 1,
      jsRound(th * 0.8),
      Blocks.stone,
    )
    ..box(
      cx,
      ty0 + tb - 1,
      4,
      cx,
      ty0 + tb - 1,
      3 + jsRound(th * 0.6),
      Blocks.char,
    );
  final dr = math.max(2, tb / 2 - 1);
  final zb = th + 1;
  final dc = ty0 + (tb >> 1);
  v.disc(cx, dc, dr, zb, zb + 1, Blocks.marble);
  final n = math.max<int>(4, jsRound(height * 0.38));
  for (var k = 0; k < n; k++) {
    final r =
        dr *
        (0.6 + 0.55 * math.sin((k + 1) / n * math.pi * 0.85)) *
        (1 - k / n * 0.7);
    v.disc(cx, dc, math.max(0.4, r), zb + 2 + k, zb + 2 + k, Blocks.marble);
  }
  v.box(cx, dc, zb + 2 + n, cx, dc, zb + 4 + n, Blocks.gold);
  for (final (x, y) in [
    (tx0, ty0),
    (tx0 + tb - 1, ty0),
    (tx0, ty0 + tb - 1),
    (tx0 + tb - 1, ty0 + tb - 1),
  ]) {
    v
      ..box(x, y, th + 1, x, y, th + 2, Blocks.marble)
      ..set(x, y, th + 3, Blocks.marble);
  }
  if (px0 - 3 >= 3) {
    for (final (x0, x1) in [(1, px0 - 2), (px1 + 2, width - 2)]) {
      v.box(x0, 0, 1, x1, math.min(py1, 9), 4, Blocks.roof);
      for (var x = x0; x <= x1; x += 2) {
        v.set(x, math.min(py1, 9), 5, Blocks.marble);
      }
    }
  }
  final gw = jsRound(width * 0.5);
  final gx0 = cx - (gw >> 1);
  v
    ..box(
      gx0,
      depth - 3,
      0,
      gx0 + gw - 1,
      depth - 1,
      jsRound(height * 0.34),
      Blocks.roof,
    )
    ..box(
      cx - 1,
      depth - 1,
      0,
      cx,
      depth - 1,
      jsRound(height * 0.24),
      Blocks.char,
    );
  for (var x = gx0; x < gx0 + gw; x += 2) {
    v.set(x, depth - 2, jsRound(height * 0.34) + 1, Blocks.marble);
  }
  v
    ..box(1, depth - 1, 0, gx0 - 1, depth - 1, 2, Blocks.roof)
    ..box(gx0 + gw, depth - 1, 0, width - 2, depth - 1, 2, Blocks.roof);
  return v;
}

/// The Great Pyramid on a 5 x 5 block: a desert floor, the pyramid in courses
/// with a white cap and a dark entrance on the front, a causeway to it, three
/// small queens' pyramids beside it, boat pits and a mortuary temple wall.
Vox greatPyramidDesign({int width = 33, int depth = 33, int height = 22}) {
  final v = Vox(width, depth);
  v.box(0, 0, 0, width - 1, depth - 1, 0, Blocks.travertine);
  final m = math.max<int>(7, (math.min(width, depth) * 0.68).floor());
  const x0 = 1;
  const y0 = 1;
  final cx = x0 + (m >> 1);
  for (var z = 1; z <= height; z++) {
    final ins = ((z - 1) * (m / 2 - 1) / height).floor();
    final course = z > height - 2
        ? Blocks.marble
        : (z.isOdd ? Blocks.sandstone : Blocks.sandstoneDark);
    v.box(x0 + ins, y0 + ins, z, x0 + m - 1 - ins, y0 + m - 1 - ins, z, course);
  }
  final ez = jsRound(height * 0.35);
  final entranceInset = ((ez - 1) * (m / 2 - 1) / height).floor();
  v
    ..set(cx, y0 + m - 1 - entranceInset, ez, Blocks.char)
    ..set(cx, y0 + m - 1 - entranceInset, ez + 1, Blocks.char)
    ..box(cx - 1, y0 + m, 0, cx, depth - 1, 0, Blocks.cobble);
  final q = width - (x0 + m) - 2;
  if (q >= 3) {
    final s = math.min<int>(q, math.max<int>(3, m ~/ 3));
    for (var i = 0; i < 3; i++) {
      final yy = y0 + i * (s + 1);
      if (yy + s > depth - 1) break;
      for (var z = 1; z <= (s / 2).ceil(); z++) {
        final ins = z - 1;
        v.box(
          x0 + m + 2 + ins,
          yy + ins,
          z,
          x0 + m + 1 + s - ins,
          yy + s - 1 - ins,
          z,
          z.isOdd ? Blocks.sandstone : Blocks.sandstoneDark,
        );
      }
    }
  }
  v
    ..box(x0 + m + 2, depth - 4, 0, width - 2, depth - 3, 0, Blocks.dirt)
    ..ring(1, y0 + m + 1, cx - 3, depth - 2, 0, 1, Blocks.cobble);
  return v;
}
