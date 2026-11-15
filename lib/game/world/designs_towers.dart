// The tower designs of the landmarks, drawn on a Vox (see vox.dart). They are
// ported from the sketches the player chose (docs/reference/
// landmark_island.html), and tests/scratch checks keep every block in place.
// ignore_for_file: cascade_invocations

import 'dart:math' as math;

import 'package:focus_town/game/world/block_material.dart';
import 'package:focus_town/game/world/vox.dart';

/// The Space Needle on a 2 x 2 block: the footprint is set by the wide saucer,
/// the legs under it are far narrower. Three legs that lean in from the base,
/// a slim waist, a shaft that opens out like a trumpet, and the saucer with
/// an orange ring, a glass level, a roof, a spire and a red beacon.
Vox spaceNeedleDesign({int width = 12, int depth = 12, int height = 36}) {
  final v = Vox(width, depth);
  final c = (width - 1) / 2;
  final cc = jsRound(c);
  v.box(0, 0, 0, width - 1, depth - 1, 0, Blocks.stone);
  final sr = math.max(1.5, c - 0.2);
  final baseHalf = math.max(1, jsRound(c * 0.42));
  final sz = jsRound(height * 0.74);
  final legTop = jsRound(sz * 0.28);
  final waistTop = jsRound(sz * 0.52);
  for (var z = 1; z <= waistTop; z++) {
    if (z <= legTop) {
      final r = math.max(0, jsRound(baseHalf * (1 - (z - 1) / legTop)));
      for (final (x, y) in [(cc - r, cc - r), (cc + r, cc - r), (cc, cc + r)]) {
        v
          ..set(x, y, z, Blocks.marble)
          ..set(x + 1, y, z, Blocks.marble);
      }
      v.set(cc, cc, z, Blocks.marble);
      if (z % 4 == 0 && r > 0) {
        for (var t = cc - r; t <= cc + r; t++) {
          v
            ..set(t, cc - r, z, Blocks.travertine)
            ..set(t, cc + r, z, Blocks.travertine)
            ..set(cc - r, t, z, Blocks.travertine)
            ..set(cc + r, t, z, Blocks.travertine);
        }
      }
    } else {
      v
        ..set(cc, cc, z, Blocks.marble)
        ..set(cc + 1, cc, z, Blocks.marble);
      if (z % 4 == 0) v.box(cc - 1, cc, z, cc + 2, cc, z, Blocks.travertine);
    }
  }
  for (var z = waistTop + 1; z <= sz; z++) {
    final k = (z - waistTop) / (sz - waistTop);
    final r = 0.9 + (sr - 0.9) * math.pow(k, 2.2);
    v.disc(c, c, r, z, z, z % 3 == 0 ? Blocks.travertine : Blocks.marble);
  }
  v
    ..disc(c, c, sr, sz + 1, sz + 1, Blocks.flame)
    ..disc(c, c, sr, sz + 2, sz + 2, Blocks.glass)
    ..disc(c, c, sr, sz + 3, sz + 3, Blocks.glass);
  final posts = math.max(8, jsRound(sr * 3));
  for (var a = 0; a < posts; a++) {
    final x = c + math.cos(a * 2 * math.pi / posts) * sr;
    final y = c + math.sin(a * 2 * math.pi / posts) * sr;
    v
      ..set(x, y, sz + 2, Blocks.marble)
      ..set(x, y, sz + 3, Blocks.marble);
  }
  v
    ..disc(c, c, sr, sz + 4, sz + 4, Blocks.marble)
    ..disc(c, c, math.max(0.8, sr * 0.55), sz + 5, sz + 5, Blocks.marble)
    ..disc(c, c, math.max(0.6, sr * 0.3), sz + 6, sz + 6, Blocks.marble)
    ..box(cc, cc, sz + 7, cc, cc, height, Blocks.iron)
    ..set(cc, cc, height + 1, Blocks.roof);
  return v;
}

/// The Pagoda on a 2 x 2 block: a stone base with stairs, five tiers each
/// with white walls, dark wood corners and a red roof whose corners turn up,
/// a gold spire with rings, and trees in the courtyard corners.
Vox pagodaDesign({int width = 12, int depth = 12, int height = 20}) {
  final v = Vox(width, depth);
  v.box(0, 0, 0, width - 1, depth - 1, 0, Blocks.travertine);
  final c = (width - 1) / 2;
  final cc = jsRound(c);
  final bs = width - 3;
  final a = jsRound(c - bs / 2);
  final b = a + bs - 1;
  v
    ..box(a, a, 1, b, b, 1, Blocks.stone)
    ..box(a + 1, a + 1, 2, b - 1, b - 1, 2, Blocks.cobble)
    ..box(cc - 1, b + 1, 1, cc, b + 1, 1, Blocks.cobble);
  const tiers = 5;
  final th = math.max(3, (height - 5) ~/ tiers);
  var z = 3;
  for (var t = 0; t < tiers; t++) {
    final s =
        math.max<int>(
          3,
          width - 6 - t * math.max<int>(1, (width - 7) ~/ tiers),
        ) |
        1;
    final h = s >> 1;
    final lo = jsRound(c - h);
    final hi = jsRound(c + h);
    for (var q = z; q < z + th - 1; q++) {
      v.ring(lo, lo, hi, hi, q, q, Blocks.marble);
      for (final (x, y) in [(lo, lo), (hi, lo), (lo, hi), (hi, hi)]) {
        v.set(x, y, q, Blocks.log);
      }
    }
    if (t == 0) {
      v
        ..set(cc, hi, z, Blocks.char)
        ..set(cc, hi, z + 1, Blocks.char);
    }
    final rz = z + th - 1;
    v
      ..box(lo - 1, lo - 1, rz, hi + 1, hi + 1, rz, Blocks.roof)
      ..box(lo, lo, rz + 1, hi, hi, rz + 1, Blocks.wool);
    for (final (x, y) in [
      (lo - 1, lo - 1),
      (hi + 1, lo - 1),
      (lo - 1, hi + 1),
      (hi + 1, hi + 1),
    ]) {
      v.set(x, y, rz + 1, Blocks.roof);
    }
    z = rz + 2;
  }
  for (var i = 0; i < 4; i++) {
    v.set(cc, cc, z + i, i.isOdd ? Blocks.gold : Blocks.sandstoneDark);
  }
  v.box(cc - 1, cc, z + 1, cc + 1, cc, z + 1, Blocks.gold);
  for (final (x, y) in [
    (0, 0),
    (width - 1, 0),
    (0, depth - 1),
    (width - 1, depth - 1),
  ]) {
    v
      ..box(x, y, 1, x, y, 2, Blocks.log)
      ..box(x - 1, y - 1, 3, x + 1, y + 1, 3, Blocks.leaves)
      ..set(x, y, 4, Blocks.leaves);
  }
  return v;
}

/// The Eiffel Tower on a 3 x 3 block: four legs that lean in as continuous
/// strips, arches between them, three platforms with railings, a lattice of
/// cross beams, a cupola and an antenna.
Vox eiffelDesign({int width = 19, int depth = 19, int height = 44}) {
  final v = Vox(width, depth);
  v.box(0, 0, 0, width - 1, depth - 1, 0, Blocks.stone);
  final c = (width - 1) / 2;
  final p1 = jsRound(height * 0.30);
  final p2 = jsRound(height * 0.56);
  final p3 = jsRound(height * 0.82);
  int half(int z) => math.max(
    1,
    jsRound((width / 2 - 1.5) * (1 - math.pow(z / height, 0.62))),
  );
  int? pa;
  int? pb;
  (int, int) leg(int z) {
    final h = half(z);
    final a = jsRound(c - h);
    final b = jsRound(c + h);
    final qa = pa ?? a;
    final qb = pb ?? b;
    for (final (x, y, qx, qy) in [
      (a, a, qa, qa),
      (b, a, qb, qa),
      (a, b, qa, qb),
      (b, b, qb, qb),
    ]) {
      final thick = z < p1 - 1 ? 1 : 0;
      final x0 = math.min(x, qx) - (x == a ? thick : 0);
      final x1 = math.max(x, qx) + (x == b ? thick : 0);
      final y0 = math.min(y, qy) - (y == a ? thick : 0);
      final y1 = math.max(y, qy) + (y == b ? thick : 0);
      v.box(x0, y0, z, x1, y1, z, Blocks.iron);
    }
    pa = a;
    pb = b;
    return (a, b);
  }

  void beams(int a, int b, int z) {
    for (var t = a; t <= b; t++) {
      v
        ..set(t, a, z, Blocks.iron)
        ..set(t, b, z, Blocks.iron)
        ..set(a, t, z, Blocks.iron)
        ..set(b, t, z, Blocks.iron);
    }
  }

  for (var z = 1; z <= height; z++) {
    final (a, b) = leg(z);
    if (z == p1 || z == p2 || z == p3) {
      final e = z == p3 ? 1 : 0;
      v
        ..box(a - 1 + e, a - 1 + e, z, b + 1 - e, b + 1 - e, z, Blocks.bronze)
        ..ring(
          a - 1 + e,
          a - 1 + e,
          b + 1 - e,
          b + 1 - e,
          z + 1,
          z + 1,
          Blocks.iron,
        );
    } else if (z < p1) {
      if (z == p1 - 1 || z == p1 - 2) beams(a, b, z);
    } else if (z < p3) {
      if ((z - p1) % 3 == 0) beams(a, b, z);
    }
  }
  final cc = jsRound(c);
  v
    ..box(cc - 1, cc - 1, p3 + 1, cc + 1, cc + 1, p3 + 2, Blocks.bronze)
    ..box(cc, cc, p3 + 3, cc, cc, height, Blocks.iron);
  return v;
}

/// The Statue of Liberty on a 3 x 3 block: Fort Wood, a star-shaped fort in
/// the water, a pedestal with steps and a loggia, and the robed figure with
/// folds, a face, a crown of seven rays, the raised arm with the torch and
/// the tablet on the other arm.
Vox statueOfLibertyDesign({int width = 19, int depth = 19, int height = 26}) {
  final v = Vox(width, depth);
  final c = (width - 1) / 2;
  final cc = jsRound(c);
  final r = math.min(width, depth) / 2 - 0.5;
  for (var x = 0; x < width; x++) {
    for (var y = 0; y < depth; y++) {
      final dx = (x - c).abs();
      final dy = (y - c).abs();
      final inSquare = dx <= r - 1 && dy <= r - 1;
      final inDiamond = dx + dy <= r * 1.5;
      final on = inSquare || inDiamond;
      v.set(x, y, 0, on ? Blocks.stone : Blocks.water);
      if (on &&
          inSquare &&
          inDiamond &&
          (dx > r - 2.6 || dy > r - 2.6 || dx + dy > r * 1.5 - 1.6)) {
        v.set(x, y, 1, Blocks.cobble);
        if ((x + y).isEven) v.set(x, y, 2, Blocks.cobble);
      }
    }
  }
  final ph = math.max(4, jsRound(height * 0.25));
  final pw = math.max(2, jsRound(r * 0.42));
  v
    ..box(
      cc - pw - 2,
      cc - pw - 2,
      1,
      cc + pw + 2,
      cc + pw + 2,
      2,
      Blocks.stone,
    )
    ..box(
      cc - pw - 1,
      cc - pw - 1,
      3,
      cc + pw + 1,
      cc + pw + 1,
      3,
      Blocks.cobble,
    )
    ..box(cc - pw, cc - pw, 4, cc + pw, cc + pw, ph, Blocks.stone);
  for (var z = ph - 3; z <= ph - 1; z++) {
    for (var t = -pw; t <= pw; t += 2) {
      for (final (x, y) in [
        (cc + t, cc - pw),
        (cc + t, cc + pw),
        (cc - pw, cc + t),
        (cc + pw, cc + t),
      ]) {
        v.set(x, y, z, Blocks.cobble);
      }
    }
  }
  v.ring(
    cc - pw - 1,
    cc - pw - 1,
    cc + pw + 1,
    cc + pw + 1,
    ph + 1,
    ph + 1,
    Blocks.cobble,
  );
  final green = Blocks.verdigris;
  final dark = Blocks.verdigrisDark;
  final light = Blocks.copper;
  final z0 = ph + 2;
  final top = height - 5;
  final robeTop = z0 + jsRound((top - z0) * 0.45);
  final chestZ = z0 + jsRound((top - z0) * 0.74);
  BlockMaterial fold(int x, int z) => (x * 3 + (z ~/ 3)) % 4 < 2 ? green : dark;
  for (var z = z0; z <= robeTop; z++) {
    final k = (z - z0) / math.max(1, robeTop - z0);
    final hw = k < 0.35 ? 2 : 1;
    for (var x = cc - hw; x <= cc + hw; x++) {
      for (var y = cc - 1; y <= cc + 1; y++) {
        v.set(x, y, z, fold(x, z));
      }
    }
  }
  v
    ..set(cc - 1, cc + 2, z0, dark)
    ..set(cc - 1, cc + 2, z0 + 1, dark)
    ..set(cc - 1, cc + 2, z0 + 2, green);
  for (var z = robeTop + 1; z <= chestZ; z++) {
    for (var x = cc - 1; x <= cc + 1; x++) {
      for (var y = cc - 1; y <= cc + 1; y++) {
        v.set(x, y, z, fold(x, z));
      }
    }
  }
  for (var x = cc - 2; x <= cc + 2; x++) {
    for (var y = cc - 1; y <= cc + 1; y++) {
      v.set(x, y, chestZ + 1, light);
    }
  }
  final neck = chestZ + 2;
  v.set(cc, cc, neck, green);
  final hz = neck + 1;
  for (var z = hz; z <= hz + 2; z++) {
    for (var x = cc - 1; x <= cc + 1; x++) {
      for (var y = cc - 1; y <= cc + 1; y++) {
        v.set(x, y, z, light);
      }
    }
  }
  v
    ..set(cc - 1, cc + 1, hz + 1, Blocks.char)
    ..set(cc + 1, cc + 1, hz + 1, Blocks.char)
    ..set(cc, cc + 2, hz, light);
  final cz = hz + 3;
  for (var x = cc - 1; x <= cc + 1; x++) {
    for (var y = cc - 1; y <= cc + 1; y++) {
      v.set(x, y, cz, dark);
    }
  }
  for (final (dx, dy, up) in [
    (-3, 0, 1),
    (-2, -2, 2),
    (0, -3, 2),
    (2, -2, 2),
    (3, 0, 1),
    (-2, 2, 1),
    (2, 2, 1),
  ]) {
    v
      ..set(cc + dx, cc + dy, cz, light)
      ..set(cc + jsRound(dx * 0.66), cc + jsRound(dy * 0.66), cz, light)
      ..set(cc + dx, cc + dy, cz + up, light);
  }
  final ax = cc + 3;
  for (var z = chestZ; z <= height + 2; z++) {
    v.set(ax, cc, z, green);
    if (z < chestZ + 3) v.set(ax - 1, cc, z, light);
  }
  v
    ..box(
      ax - 1,
      cc - 1,
      height + 3,
      ax + 1,
      cc + 1,
      height + 3,
      Blocks.sandstoneDark,
    )
    ..box(ax, cc, height + 4, ax, cc, height + 5, Blocks.flame)
    ..box(ax - 1, cc, height + 5, ax + 1, cc, height + 5, Blocks.gold)
    ..box(ax, cc, height + 6, ax, cc, height + 7, Blocks.gold)
    ..set(ax, cc, height + 8, Blocks.flame)
    ..set(cc - 2, cc, chestZ - 1, green)
    ..set(cc - 3, cc, chestZ - 1, green)
    ..set(cc - 3, cc + 1, chestZ - 2, green)
    ..box(cc - 4, cc - 1, chestZ - 4, cc - 3, cc + 2, chestZ - 1, Blocks.marble)
    ..box(cc - 4, cc - 1, chestZ - 4, cc - 4, cc + 2, chestZ - 4, Blocks.stone);
  return v;
}
