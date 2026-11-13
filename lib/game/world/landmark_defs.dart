import 'dart:math' as math;

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

// The Statue of Liberty: a star-shaped fort base, a stepped pedestal with a
// door and a ledge, then the copper-green lady: a wide robe, a torso, a head
// with a crown of rays, the raised arm with a gold torch and its flame, and a
// tablet on the other side. One part per stage.
void _statueOfLiberty(VoxelWorld w, int ox, int oy, int stage) {
  // The fort: a 10 x 10 square with its corners cut off.
  if (stage >= 1) {
    for (var x = 1; x <= 10; x++) {
      for (var y = 1; y <= 10; y++) {
        final cut = (x < 3 || x > 8) && (y < 3 || y > 8);
        if (!cut) w.set(ox + x, oy + y, 1, Blocks.stone);
      }
    }
  }
  if (stage >= 2) w.fill(ox + 2, oy + 3, 2, ox + 9, oy + 8, 2, Blocks.cobble);
  if (stage >= 2) w.fill(ox + 3, oy + 2, 2, ox + 8, oy + 9, 2, Blocks.cobble);
  // The pedestal, 6 x 6 and then 4 x 4, with a door at the front.
  if (stage >= 3) w.fill(ox + 3, oy + 3, 3, ox + 8, oy + 8, 4, Blocks.stone);
  if (stage >= 4) w.fill(ox + 4, oy + 4, 5, ox + 7, oy + 7, 8, Blocks.stone);
  if (stage >= 3) {
    for (final x in [5, 6]) {
      for (final z in [3, 4]) {
        w.remove(ox + x, oy + 8, z);
      }
    }
  }
  if (stage >= 5) w.fill(ox + 3, oy + 3, 9, ox + 8, oy + 8, 9, Blocks.cobble);
  // The robe widens to the feet; the torso and the head are 2 x 2.
  if (stage >= 6) {
    w
      ..fill(ox + 4, oy + 4, 10, ox + 7, oy + 7, 11, Blocks.copper)
      ..fill(ox + 5, oy + 5, 12, ox + 6, oy + 6, 13, Blocks.copper);
  }
  if (stage >= 7) w.fill(ox + 5, oy + 5, 14, ox + 6, oy + 6, 17, Blocks.copper);
  if (stage >= 8) w.fill(ox + 5, oy + 5, 18, ox + 6, oy + 6, 19, Blocks.copper);
  // The crown: rays around the head.
  if (stage >= 9) {
    for (final (x, y) in [(4, 5), (4, 6), (7, 5), (7, 6), (5, 4), (6, 7)]) {
      w.set(ox + x, oy + y, 20, Blocks.plank);
    }
    w.fill(ox + 5, oy + 5, 20, ox + 6, oy + 6, 20, Blocks.copper);
  }
  // The raised arm.
  if (stage >= 10) {
    w.fill(ox + 7, oy + 4, 15, ox + 7, oy + 4, 23, Blocks.copper);
  }
  // The torch and the tablet.
  if (stage >= 11) {
    w
      ..fill(ox + 7, oy + 4, 24, ox + 7, oy + 4, 24, Blocks.plank)
      ..fill(ox + 4, oy + 7, 14, ox + 4, oy + 7, 15, Blocks.plank);
  }
  if (stage >= 12) w.fill(ox + 7, oy + 4, 25, ox + 7, oy + 4, 26, Blocks.wool);
}

// The Colosseum, round: a ring of three tiers of arches, each closed by a
// solid band, an attic with windows, seating terraces inside that step up
// toward the wall, a sand arena with a podium and banners on top. The arches
// are every other of 20 slices; the gate on the front is open from the start.
// Stages: 1 floor, 2-7 the tiers (arches, then band), 8 attic, 9-10 seating,
// 11 podium, 12 banners.
void _colosseum(VoxelWorld w, int ox, int oy, int stage) {
  double dist(int x, int y) =>
      math.sqrt(math.pow(x - 5.5, 2) + math.pow(y - 5.5, 2));
  bool inWall(int x, int y) => dist(x, y) > 4.8 && dist(x, y) <= 5.9;
  // True for the cells of the arches, every other slice of the ring.
  bool archSlice(int x, int y) {
    final a = math.atan2(y - 5.5, x - 5.5) + math.pi;
    return (a / (2 * math.pi) * 20).floor().isEven;
  }

  // Every wall cell at [z] (a solid band), or the pillars with a dark opening
  // in each arch.
  void ring(int z, {bool solid = false}) {
    for (var x = 0; x < 12; x++) {
      for (var y = 0; y < 12; y++) {
        if (!inWall(x, y)) continue;
        final arch = archSlice(x, y) && !solid;
        w.set(ox + x, oy + y, z, arch ? Blocks.char : Blocks.travertine);
      }
    }
  }

  // Cells inside the wall: [from] to [to] away from the middle.
  void inside(double from, double to, int top, BlockMaterial m) {
    for (var x = 0; x < 12; x++) {
      for (var y = 0; y < 12; y++) {
        final d = dist(x, y);
        if (d >= from && d < to) {
          w.fill(ox + x, oy + y, 1, ox + x, oy + y, top, m);
        }
      }
    }
  }

  if (stage >= 1) inside(0, 4.8, 1, Blocks.path);
  // Three tiers: arches (stage 2, 4, 6), then a band (3, 5, 7).
  for (var tier = 0; tier < 3; tier++) {
    final base = 2 * tier + 1;
    if (stage >= 2 * tier + 2) ring(base);
    if (stage >= 2 * tier + 3) ring(base + 1, solid: true);
  }
  if (stage >= 8) {
    ring(7);
    ring(8);
  }
  // The gate on the front.
  for (final z in [1, 2]) {
    for (final x in [5, 6]) {
      w.remove(ox + x, oy + 11, z);
    }
  }
  // Seating inside: terraces that rise toward the wall.
  if (stage >= 9) inside(3.7, 4.8, 5, Blocks.travertine);
  if (stage >= 10) inside(2.8, 3.7, 3, Blocks.stone);
  if (stage >= 11) inside(0, 1.2, 2, Blocks.plank);
  if (stage >= 12) {
    for (final (x, y) in [(5, 0), (6, 11), (0, 5), (11, 6)]) {
      w.set(ox + x, oy + y, 9, Blocks.wool);
    }
  }
}
