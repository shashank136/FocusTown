import 'package:focus_town/domain/landmark.dart';
import 'package:focus_town/game/world/block_material.dart';
import 'package:focus_town/game/world/voxel_world.dart';

/// Builds [landmark] up to [stage] (0 draws nothing, past the last stage is
/// the last) on the 12 x 12 tiles from ([ox], [oy]): the block of its 2 x 2
/// plots, one tile in from the edge (the outer tile is the road).
void buildLandmark(VoxelWorld w, Landmark landmark, int ox, int oy, int stage) {
  switch (landmark) {
    case Landmark.greatPyramid:
      _greatPyramid(w, ox, oy, stage);
    case Landmark.lighthouse:
      _lighthouse(w, ox, oy, stage);
    case Landmark.pagoda:
      _pagoda(w, ox, oy, stage);
    case Landmark.tajMahal:
      _tajMahal(w, ox, oy, stage);
    case Landmark.statueOfLiberty:
      _statueOfLiberty(w, ox, oy, stage);
    case Landmark.colosseum:
      _colosseum(w, ox, oy, stage);
    case Landmark.eiffel:
      _eiffel(w, ox, oy, stage);
  }
}

// The Eiffel Tower: four legs that lean in and meet, two platforms, a mast, a
// spire and a flag, 24 blocks tall. Two levels of the tower per stage.
void _eiffel(VoxelWorld w, int ox, int oy, int stage) {
  // How far in from the corner the legs are at height [z]: 0, 1, 2, 3, then
  // 4, where the four legs meet in one column.
  int lean(int z) => z <= 6 ? (z - 1) ~/ 2 : (z <= 8 ? 3 : 4);

  // Stages 1-6: the legs, two levels each.
  for (var z = 1; z <= 12 && z <= stage * 2; z++) {
    final c = lean(z);
    for (final x in [c, c + 1, 10 - c, 11 - c]) {
      for (final y in [c, c + 1, 10 - c, 11 - c]) {
        w.set(ox + x, oy + y, z, Blocks.log);
      }
    }
  }
  // The platforms, with the legs they join (the first at the third stage).
  if (stage >= 3) w.ring(ox + 2, oy + 2, 8, 8, 6, Blocks.plank);
  if (stage >= 6) w.ring(ox + 3, oy + 3, 6, 6, 12, Blocks.plank);
  // Stages 7-9: the mast and its balcony.
  for (var z = 13; z <= 18 && z <= 12 + (stage - 6) * 2; z++) {
    w.fill(ox + 5, oy + 5, z, ox + 6, oy + 6, z, Blocks.log);
  }
  if (stage >= 9) w.ring(ox + 4, oy + 4, 4, 4, 17, Blocks.plank);
  // Stages 10-12: the spire, the antenna and the flag.
  if (stage >= 10) w.fill(ox + 5, oy + 5, 19, ox + 5, oy + 5, 20, Blocks.log);
  if (stage >= 11) {
    w
      ..fill(ox + 5, oy + 5, 21, ox + 5, oy + 5, 22, Blocks.log)
      ..set(ox + 5, oy + 5, 23, Blocks.wool);
  }
  if (stage >= 12) w.fill(ox + 5, oy + 5, 24, ox + 5, oy + 5, 26, Blocks.log);
}

// The Great Pyramid: a stepped pyramid, one level per stage (11 levels, each
// step two levels high and two tiles narrower), then a gold cap and two
// pillars at the entrance on the last stage.
void _greatPyramid(VoxelWorld w, int ox, int oy, int stage) {
  for (var z = 1; z <= 11 && z <= stage; z++) {
    final inset = (z - 1) ~/ 2;
    final size = 12 - 2 * inset;
    w.fill(
      ox + inset,
      oy + inset,
      z,
      ox + inset + size - 1,
      oy + inset + size - 1,
      z,
      Blocks.plank,
    );
  }
  // The entrance, 2 wide and 2 deep, is open from the start.
  for (final x in [5, 6]) {
    for (final y in [10, 11]) {
      w
        ..remove(ox + x, oy + y, 1)
        ..remove(ox + x, oy + y, 2);
    }
  }
  if (stage >= 12) {
    w
      ..fill(ox + 5, oy + 5, 12, ox + 6, oy + 6, 12, Blocks.wool)
      ..fill(ox + 3, oy + 11, 3, ox + 3, oy + 11, 4, Blocks.stone)
      ..fill(ox + 8, oy + 11, 3, ox + 8, oy + 11, 4, Blocks.stone);
  }
}

// The Lighthouse of Alexandria: a square base, a narrower middle with a ledge
// at its foot, a narrow glass lantern and a fire on top. Two levels per stage;
// the door in the base is open from the start.
void _lighthouse(VoxelWorld w, int ox, int oy, int stage) {
  // Stages 1-4: the square base, an 8 x 8 ring (z 1-8).
  for (var z = 1; z <= 8 && z <= stage * 2; z++) {
    w.ring(ox + 2, oy + 2, 8, 8, z, Blocks.stone);
  }
  w
    ..remove(ox + 5, oy + 9, 1)
    ..remove(ox + 6, oy + 9, 1)
    ..remove(ox + 5, oy + 9, 2)
    ..remove(ox + 6, oy + 9, 2);
  // Stages 5-8: the middle, a 6 x 6 ring (z 9-16), with a ledge at its foot.
  if (stage >= 5) w.ring(ox + 1, oy + 1, 10, 10, 9, Blocks.plank);
  for (var z = 9; z <= 16 && z <= stage * 2; z++) {
    w.ring(ox + 3, oy + 3, 6, 6, z, Blocks.cobble);
  }
  // Stages 9-11: the top, a 4 x 4 ring (z 17-22); the lantern is glass.
  for (var z = 17; z <= 22 && z <= stage * 2; z++) {
    w.ring(ox + 4, oy + 4, 4, 4, z, z >= 21 ? Blocks.glass : Blocks.stone);
  }
  // Stage 12: the roof and the fire.
  if (stage >= 12) {
    w
      ..fill(ox + 4, oy + 4, 23, ox + 7, oy + 7, 23, Blocks.slate)
      ..fill(ox + 5, oy + 5, 24, ox + 6, oy + 6, 25, Blocks.wool);
  }
}

// The Pagoda: five tiers narrowing as they rise, each a wooden wall (two
// levels) under a wider red roof (one level), then a spire. A tier takes two
// stages (walls, then roof); the door in the first tier is open from the start.
void _pagoda(VoxelWorld w, int ox, int oy, int stage) {
  // (wall inset, wall size, roof inset) of each tier.
  const tiers = [(2, 8, 1), (3, 6, 2), (3, 6, 2), (4, 4, 3), (4, 4, 3)];
  for (var t = 0; t < tiers.length; t++) {
    final (inset, size, roofInset) = tiers[t];
    final z = 3 * t + 1;
    if (stage >= 2 * t + 1) {
      for (final level in [z, z + 1]) {
        w.ring(ox + inset, oy + inset, size, size, level, Blocks.plank);
      }
    }
    if (stage >= 2 * t + 2) {
      final side = 12 - 2 * roofInset;
      w.fill(
        ox + roofInset,
        oy + roofInset,
        z + 2,
        ox + roofInset + side - 1,
        oy + roofInset + side - 1,
        z + 2,
        Blocks.roof,
      );
    }
  }
  for (final x in [5, 6]) {
    for (final z in [1, 2]) {
      w.remove(ox + x, oy + 9, z);
    }
  }
  // Stage 11: the spire. Stage 12: a gold finial and the upturned eaves.
  if (stage >= 11) {
    w
      ..fill(ox + 5, oy + 5, 16, ox + 6, oy + 6, 16, Blocks.plank)
      ..fill(ox + 5, oy + 5, 17, ox + 5, oy + 5, 19, Blocks.log);
  }
  if (stage >= 12) {
    w.set(ox + 5, oy + 5, 20, Blocks.wool);
    for (final (x, y) in [(1, 1), (10, 1), (1, 10), (10, 10)]) {
      w.set(ox + x, oy + y, 4, Blocks.wool);
    }
  }
}

// The Taj Mahal: a two-step marble platform, a hall with a door and a flat
// roof, a dome with a finial, four minarets at the platform corners and a
// pool in front (the +y side). Stages: 1-2 platform, 3-4 hall, 5-6 minarets,
// 7 roof, 8-9 dome, 10 finial, 11 pool, 12 minaret caps.
void _tajMahal(VoxelWorld w, int ox, int oy, int stage) {
  if (stage >= 1) w.fill(ox + 1, oy, 1, ox + 10, oy + 7, 1, Blocks.stone);
  if (stage >= 2) w.fill(ox + 2, oy + 1, 2, ox + 9, oy + 6, 2, Blocks.stone);
  // The hall: a 6 x 4 ring, two levels per stage.
  for (var z = 3; z <= 6 && z <= stage * 2 - 2; z++) {
    w.ring(ox + 3, oy + 2, 6, 4, z, Blocks.stone);
  }
  if (stage >= 3) {
    for (final x in [5, 6]) {
      for (final z in [3, 4]) {
        w.remove(ox + x, oy + 5, z);
      }
    }
  }
  // The minarets: four columns at the corners, from the first platform level.
  final top = stage >= 6 ? 10 : (stage >= 5 ? 6 : 0);
  for (final (x, y) in [(1, 0), (10, 0), (1, 7), (10, 7)]) {
    if (top >= 2) w.fill(ox + x, oy + y, 2, ox + x, oy + y, top, Blocks.stone);
    if (stage >= 12) w.set(ox + x, oy + y, 11, Blocks.wool);
  }
  if (stage >= 7) w.fill(ox + 3, oy + 2, 7, ox + 8, oy + 5, 7, Blocks.stone);
  // The dome: a 4 x 4 drum, then narrower.
  if (stage >= 8) w.fill(ox + 4, oy + 2, 8, ox + 7, oy + 5, 9, Blocks.stone);
  if (stage >= 9) w.fill(ox + 5, oy + 3, 10, ox + 6, oy + 4, 11, Blocks.stone);
  if (stage >= 10) {
    w
      ..fill(ox + 5, oy + 3, 12, ox + 5, oy + 3, 13, Blocks.log)
      ..set(ox + 5, oy + 3, 14, Blocks.wool);
  }
  if (stage >= 11) w.fill(ox + 4, oy + 8, 1, ox + 7, oy + 10, 1, Blocks.water);
}

// The Statue of Liberty: a two-step square base, a pedestal with a door and a
// ledge, then the green statue: robe, torso, head, a crown with rays, the
// raised arm with a torch, and a tablet. One part per stage.
void _statueOfLiberty(VoxelWorld w, int ox, int oy, int stage) {
  if (stage >= 1) w.fill(ox + 1, oy + 1, 1, ox + 10, oy + 10, 1, Blocks.stone);
  if (stage >= 2) w.fill(ox + 2, oy + 2, 2, ox + 9, oy + 9, 2, Blocks.stone);
  // The pedestal, 4 x 4: two levels at stage 3, two at stage 4.
  if (stage >= 3) w.fill(ox + 4, oy + 4, 3, ox + 7, oy + 7, 4, Blocks.cobble);
  if (stage >= 4) w.fill(ox + 4, oy + 4, 5, ox + 7, oy + 7, 6, Blocks.cobble);
  if (stage >= 3) {
    for (final x in [5, 6]) {
      for (final z in [3, 4]) {
        w.remove(ox + x, oy + 7, z);
      }
    }
  }
  if (stage >= 5) w.fill(ox + 3, oy + 3, 7, ox + 8, oy + 8, 7, Blocks.plank);
  // The statue is 2 x 2 at the middle: robe, torso, head.
  if (stage >= 6) w.fill(ox + 5, oy + 5, 8, ox + 6, oy + 6, 11, Blocks.leaves);
  if (stage >= 7) w.fill(ox + 5, oy + 5, 12, ox + 6, oy + 6, 14, Blocks.leaves);
  if (stage >= 8) w.fill(ox + 5, oy + 5, 15, ox + 6, oy + 6, 16, Blocks.leaves);
  if (stage >= 9) {
    for (final (x, y) in [(4, 5), (7, 6), (5, 7), (6, 4)]) {
      w.set(ox + x, oy + y, 16, Blocks.wool);
    }
    w.fill(ox + 5, oy + 5, 17, ox + 6, oy + 6, 17, Blocks.leaves);
  }
  // The raised arm, the tablet, the torch and its flame.
  if (stage >= 10) {
    w.fill(ox + 7, oy + 5, 14, ox + 7, oy + 5, 18, Blocks.leaves);
  }
  if (stage >= 11) {
    w
      ..set(ox + 7, oy + 5, 19, Blocks.log)
      ..set(ox + 4, oy + 6, 13, Blocks.plank);
  }
  if (stage >= 12) w.fill(ox + 7, oy + 5, 20, ox + 7, oy + 5, 21, Blocks.wool);
}

// The Colosseum: a ring (a 12 x 12 square without its four corner cells) of
// three tiers of arches, each closed by a solid band, an attic with windows,
// seating terraces inside, a podium in the arena and banners on top. The
// arches are every other cell; the main gate on the front is open from the
// start. Stages: 1 floor, 2-7 the tiers (arches, then band), 8 attic,
// 9-10 terraces, 11 podium, 12 banners.
void _colosseum(VoxelWorld w, int ox, int oy, int stage) {
  bool onRing(int x, int y) {
    final edge = x == 0 || x == 11 || y == 0 || y == 11;
    final corner = (x == 0 || x == 11) && (y == 0 || y == 11);
    return edge && !corner;
  }

  // Every ring cell at [z] (a solid band), or only the pillars (even cells)
  // between arches, with [window] in the arches when given.
  void ring(int z, {bool solid = false, BlockMaterial? window}) {
    for (var x = 0; x < 12; x++) {
      for (var y = 0; y < 12; y++) {
        if (!onRing(x, y)) continue;
        final arch = (x + y).isOdd && !solid;
        if (arch && window == null) continue;
        w.set(ox + x, oy + y, z, arch ? window! : Blocks.stone);
      }
    }
  }

  if (stage >= 1) w.fill(ox + 2, oy + 2, 1, ox + 9, oy + 9, 1, Blocks.plank);
  // Three tiers: arches over two levels (stage 2, 4, 6), a band (3, 5, 7).
  for (var tier = 0; tier < 3; tier++) {
    final base = 3 * tier + 1;
    if (stage >= 2 * tier + 2) {
      ring(base);
      ring(base + 1);
    }
    if (stage >= 2 * tier + 3) ring(base + 2, solid: true);
  }
  if (stage >= 8) {
    ring(10, window: Blocks.glass);
    ring(11, window: Blocks.glass);
  }
  // The gate on the front.
  for (final z in [1, 2]) {
    w
      ..remove(ox + 5, oy + 11, z)
      ..remove(ox + 6, oy + 11, z);
  }
  // Seating terraces inside: three stepped rings.
  if (stage >= 9) w.ring(ox + 2, oy + 2, 8, 8, 2, Blocks.cobble);
  if (stage >= 10) {
    w
      ..ring(ox + 3, oy + 3, 6, 6, 3, Blocks.cobble)
      ..ring(ox + 4, oy + 4, 4, 4, 4, Blocks.cobble);
  }
  if (stage >= 11) w.fill(ox + 5, oy + 5, 2, ox + 6, oy + 6, 2, Blocks.stone);
  if (stage >= 12) {
    for (final (x, y) in [(1, 0), (10, 0), (1, 11), (10, 11)]) {
      w.set(ox + x, oy + y, 12, Blocks.wool);
    }
  }
}
