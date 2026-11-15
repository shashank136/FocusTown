import 'dart:math' as math;

import 'package:focus_town/game/world/block_material.dart';
import 'package:focus_town/game/world/vox.dart';

/// Christ the Redeemer on one plot: a [width] x [depth] area (5 x 5 inside
/// the road). A hill of rock with grass on its slope, a chapel with a dark
/// doorway under the statue, a long white robe, the arms stretched across the
/// whole width, hands, a neck and a head, [height] blocks tall.
Vox christRedeemerDesign({int width = 5, int depth = 5, int height = 16}) {
  final v = Vox(width, depth);
  final cc = width ~/ 2;
  // The hill.
  v
    ..box(0, 0, 0, width - 1, depth - 1, 0, Blocks.grass)
    ..box(0, 0, 1, width - 1, depth - 1, 1, Blocks.stone)
    ..box(1, 1, 2, width - 2, depth - 2, 2, Blocks.stone);
  // The chapel under the statue, with a dark door in front.
  final ph = (height * 0.3).round().clamp(5, height);
  v
    ..box(cc - 1, cc - 1, 3, cc + 1, cc + 1, ph, Blocks.cobble)
    ..set(cc, cc + 1, 4, Blocks.char)
    ..set(cc, cc + 1, 5, Blocks.char);
  // The robe, a wide skirt and then the body; the arms stretched out with
  // the hands hanging at the ends; the neck and the head.
  final shoulders = height - 3;
  for (var z = ph + 1; z <= shoulders; z++) {
    v.box(cc - 1, cc, z, cc + 1, cc, z, Blocks.marble);
    if (z > ph + 3) v.set(cc, cc + 1, z, Blocks.marble);
  }
  v
    ..box(0, cc, shoulders, width - 1, cc, shoulders, Blocks.marble)
    ..set(0, cc, shoulders - 1, Blocks.marble)
    ..set(width - 1, cc, shoulders - 1, Blocks.marble)
    ..box(cc, cc, shoulders + 1, cc, cc, shoulders + 2, Blocks.marble)
    ..set(cc, cc, shoulders + 3, Blocks.marble);
  return v;
}

/// The Lighthouse of Alexandria on a 2 x 2 block ([width] x [depth] tiles
/// inside the road): an island in the sea joined to the shore by a causeway,
/// a square base with a door and windows, an octagon, a round top with a
/// lantern whose fire burns between four pillars, and a gold figure above,
/// [height] blocks tall without the figure.
Vox lighthouseDesign({int width = 12, int depth = 12, int height = 30}) {
  final v = Vox(width, depth);
  final c = (width - 1) / 2;
  final cc = c.round();
  final reach = math.min(width, depth) / 2 - 0.5;
  // The sea, a shore of sand and the rock of the island.
  for (var x = 0; x < width; x++) {
    for (var y = 0; y < depth; y++) {
      final d = math.sqrt((x - c) * (x - c) + (y - c) * (y - c));
      v.set(
        x,
        y,
        0,
        d > reach
            ? Blocks.water
            : (d > reach - 1 ? Blocks.travertine : Blocks.path),
      );
    }
  }
  // The square base: seven wide, a door in front and three rows of windows.
  final side = math.max(5, (width * 0.5).round()) | 1;
  final a = (c - (side >> 1)).round();
  final b = a + side - 1;
  final baseTop = (height * 0.42).round();
  final octagonHeight = (height * 0.30).round();
  for (var z = 1; z <= baseTop; z++) {
    v.ring(a, a, b, b, z, z, z % 3 != 0 ? Blocks.stone : Blocks.cobble);
  }
  v
    ..set(cc, b, 1, Blocks.char)
    ..set(cc, b, 2, Blocks.char);
  for (var z = 3; z < baseTop; z += 3) {
    v
      ..set(cc + 1, b, z, Blocks.char)
      ..set(cc - 1, b, z, Blocks.char)
      ..set(b, cc, z, Blocks.char);
  }
  v.box(a + 1, a + 1, baseTop, b - 1, b - 1, baseTop, Blocks.cobble);
  // The octagon: a ring a tile in, with its four corners cut off.
  final a2 = a + 1;
  final b2 = b - 1;
  for (var z = baseTop + 1; z <= baseTop + octagonHeight; z++) {
    v
      ..ring(
        a2,
        a2,
        b2,
        b2,
        z,
        z,
        z % 3 != 0 ? Blocks.marble : Blocks.travertine,
      )
      ..remove(a2, a2, z)
      ..remove(b2, b2, z)
      ..remove(a2, b2, z)
      ..remove(b2, a2, z);
  }
  // The round top, the lantern with its fire on four pillars, and a gold
  // figure on the roof.
  final roundBottom = baseTop + octagonHeight + 1;
  final roundHeight = math.max(1, (height * 0.12).round());
  final radius = math.max(1, ((side - 2) >> 1) - 1);
  v.disc(
    c,
    c,
    radius.toDouble(),
    roundBottom,
    roundBottom + roundHeight,
    Blocks.marble,
  );
  final lantern = roundBottom + roundHeight + 1;
  for (final dx in [-1, 1]) {
    for (final dy in [-1, 1]) {
      v.box(
        cc + dx,
        cc + dy,
        lantern,
        cc + dx,
        cc + dy,
        lantern + 1,
        Blocks.cobble,
      );
    }
  }
  v
    ..set(cc, cc, lantern, Blocks.flame)
    ..set(cc, cc, lantern + 1, Blocks.gold)
    ..box(
      cc - 1,
      cc - 1,
      lantern + 2,
      cc + 1,
      cc + 1,
      lantern + 2,
      Blocks.cobble,
    )
    ..set(cc, cc, lantern + 3, Blocks.gold)
    ..set(cc, cc, lantern + 4, Blocks.gold);
  // Steps lead from the shore up to the door; the island reaches the road.
  for (var i = 0; i < 3; i++) {
    v.box(
      cc - 1,
      b + 1 + i,
      0,
      cc,
      b + 1 + i,
      math.max(0, 2 - i),
      Blocks.cobble,
    );
  }
  return v;
}
