import 'dart:math' as math;

import 'package:focus_town/domain/building_tier.dart';
import 'package:focus_town/game/world/block_material.dart';
import 'package:focus_town/game/world/voxel_world.dart';

/// Number of build stages of [t].
int maxStage(BuildingTier t) => switch (t) {
  BuildingTier.hut => 4,
  BuildingTier.house => 7,
  BuildingTier.workshop => 6,
  BuildingTier.tower => 8,
  BuildingTier.castle => 12,
};

/// The stage shown at [progress] (0..1). Stage `s` starts at `(s - 1) / max`.
int stageForProgress(BuildingTier t, double progress) {
  final max = maxStage(t);
  final p = math.max(0, math.min(1, progress));
  return math.max(1, math.min(max, 1 + (p * max).floor()));
}

/// Builds [t] on the plot whose corner is ([plotOriginX], [plotOriginY]) up to
/// [stage]; [scaffold] adds the builders' posts and rails around it. [look] 0
/// is the classic building, 1 the second look of the tier.
void buildTier(
  VoxelWorld w,
  BuildingTier t,
  int plotOriginX,
  int plotOriginY, {
  required int stage,
  bool scaffold = false,
  int look = 0,
}) {
  final ox = plotOriginX + 1;
  final oy = plotOriginY + 1;
  final second = look == 1;
  if (t == BuildingTier.castle) {
    (second ? _pyramid : _castle)(w, plotOriginX, plotOriginY, stage);
    return;
  }
  switch (t) {
    case BuildingTier.hut:
      (second ? _tent : _hut)(w, ox, oy, stage);
      if (scaffold) _scaffold(w, ox, oy, 3, 3, 4);
    case BuildingTier.house:
      (second ? _townhouse : _house)(w, ox, oy, stage);
      if (scaffold) _scaffold(w, ox, oy, 5, 5, 6);
    case BuildingTier.workshop:
      (second ? _smithy : _workshop)(w, ox, oy, stage);
      if (scaffold) _scaffold(w, ox, oy, 5, 5, 4);
    case BuildingTier.tower:
      (second ? _lighthouse : _tower)(w, ox, oy, stage);
      if (scaffold) _scaffold(w, ox, oy, 3, 3, 9);
    case BuildingTier.castle:
      break; // handled above
  }
}

void _scaffold(VoxelWorld w, int ox, int oy, int width, int depth, int height) {
  // Rails first, so the corner posts stay whole where a rail meets them.
  for (var x = ox - 1; x <= ox + width; x++) {
    w.set(x, oy + depth, 3, Blocks.plank);
  }
  for (var y = oy - 1; y <= oy + depth; y++) {
    w.set(ox + width, y, 3, Blocks.plank);
  }
  for (final (x, y) in [
    (ox - 1, oy - 1),
    (ox + width, oy - 1),
    (ox - 1, oy + depth),
    (ox + width, oy + depth),
  ]) {
    for (var z = 1; z <= height; z++) {
      w.set(x, y, z, Blocks.log);
    }
  }
}

void _hut(VoxelWorld w, int ox, int oy, int stage) {
  for (var z = 1; z <= math.min(stage, 2); z++) {
    w
      ..ring(ox, oy, 3, 3, z, Blocks.plank, corner: Blocks.log)
      ..remove(ox + 1, oy + 2, z); // door
  }
  if (stage >= 3) w.fill(ox - 1, oy - 1, 3, ox + 3, oy + 3, 3, Blocks.roof);
  if (stage >= 4) {
    w
      ..fill(ox, oy, 4, ox + 2, oy + 2, 4, Blocks.roof)
      ..set(ox + 1, oy + 1, 5, Blocks.roof);
  }
}

void _house(VoxelWorld w, int ox, int oy, int stage) {
  w.ring(ox, oy, 5, 5, 1, Blocks.cobble);
  if (stage >= 2) w.ring(ox, oy, 5, 5, 2, Blocks.plank, corner: Blocks.log);
  if (stage >= 3) {
    w
      ..ring(ox, oy, 5, 5, 3, Blocks.plank, corner: Blocks.log)
      ..set(ox + 4, oy + 2, 3, Blocks.glass)
      ..set(ox + 3, oy + 4, 3, Blocks.glass)
      ..set(ox + 1, oy + 4, 3, Blocks.glass);
  }
  w.remove(ox + 2, oy + 4, 1); // door
  if (stage >= 2) w.remove(ox + 2, oy + 4, 2);
  if (stage >= 4) w.fill(ox - 1, oy - 1, 4, ox + 5, oy + 5, 4, Blocks.roof);
  if (stage >= 5) w.fill(ox, oy, 5, ox + 4, oy + 4, 5, Blocks.roof);
  if (stage >= 6) w.fill(ox + 1, oy + 1, 6, ox + 3, oy + 3, 6, Blocks.roof);
  if (stage >= 7) w.set(ox + 2, oy + 2, 7, Blocks.roof);
}

void _workshop(VoxelWorld w, int ox, int oy, int stage) {
  for (var z = 1; z <= math.min(stage, 3); z++) {
    w.ring(ox, oy, 5, 5, z, Blocks.cobble);
    if (z <= 2) {
      // The 2-wide door is open as soon as the ring exists.
      w
        ..remove(ox + 1, oy + 4, z)
        ..remove(ox + 2, oy + 4, z);
    }
  }
  if (stage >= 4) {
    w
      ..set(ox + 4, oy + 1, 2, Blocks.glass)
      ..set(ox + 4, oy + 2, 2, Blocks.glass);
  }
  if (stage >= 5) w.fill(ox, oy, 4, ox + 4, oy + 4, 4, Blocks.slate);
  if (stage >= 6) w.fill(ox + 3, oy + 1, 5, ox + 3, oy + 1, 6, Blocks.cobble);
}

void _tower(VoxelWorld w, int ox, int oy, int stage) {
  // Solid stone layers: stages 1-4 add two layers each, stage 5 adds one.
  const layers = [2, 4, 6, 8, 9];
  for (var s = 1; s <= math.min(stage, 5); s++) {
    final top = layers[s - 1];
    final bottom = s == 1 ? 1 : layers[s - 2] + 1;
    w.fill(ox, oy, bottom, ox + 2, oy + 2, top, Blocks.stone);
  }
  // Features appear with their layer.
  w
    ..remove(ox + 1, oy + 2, 1)
    ..remove(ox + 1, oy + 2, 2);
  if (stage >= 3) w.set(ox + 2, oy + 1, 5, Blocks.glass);
  if (stage >= 4) w.set(ox + 1, oy + 2, 7, Blocks.glass);
  if (stage >= 6) {
    for (final (dx, dy) in [(0, 0), (2, 0), (0, 2), (2, 2)]) {
      w.set(ox + dx, oy + dy, 10, Blocks.stone);
    }
  }
  if (stage >= 7) w.fill(ox + 1, oy + 1, 10, ox + 1, oy + 1, 12, Blocks.log);
  if (stage >= 8) w.fill(ox + 2, oy + 1, 11, ox + 3, oy + 1, 12, Blocks.wool);
}

// Second looks. Each keeps the footprint and the stage count of its tier.

// A wool tent with a pole and a pennant.
void _tent(VoxelWorld w, int ox, int oy, int stage) {
  w.fill(ox, oy, 1, ox + 2, oy + 2, 1, Blocks.wool);
  if (stage >= 2) w.fill(ox, oy, 2, ox + 2, oy + 2, 2, Blocks.wool);
  if (stage >= 3) {
    w
      ..fill(ox + 1, oy, 3, ox + 1, oy + 2, 3, Blocks.wool)
      ..fill(ox, oy + 1, 3, ox + 2, oy + 1, 3, Blocks.wool);
  }
  if (stage >= 4) {
    w
      ..fill(ox + 1, oy + 1, 4, ox + 1, oy + 1, 5, Blocks.log)
      ..set(ox + 2, oy + 1, 5, Blocks.wool);
  }
  w.remove(ox + 1, oy + 2, 1); // door
}

// A tall plank house with a flat roof and a chimney.
void _townhouse(VoxelWorld w, int ox, int oy, int stage) {
  w.ring(ox, oy, 5, 5, 1, Blocks.cobble);
  for (var z = 2; z <= math.min(stage, 4); z++) {
    w.ring(ox, oy, 5, 5, z, Blocks.plank, corner: Blocks.log);
    if (z >= 3) {
      w
        ..set(ox + 4, oy + 2, z, Blocks.glass)
        ..set(ox, oy + 2, z, Blocks.glass);
    }
  }
  w
    ..remove(ox + 2, oy + 4, 1)
    ..remove(ox + 2, oy + 4, 2);
  if (stage >= 5) w.fill(ox - 1, oy - 1, 5, ox + 5, oy + 5, 5, Blocks.slate);
  if (stage >= 6) w.ring(ox - 1, oy - 1, 7, 7, 6, Blocks.cobble);
  if (stage >= 7) w.fill(ox + 3, oy + 1, 6, ox + 3, oy + 1, 8, Blocks.cobble);
}

// A stone smithy with a red roof and a tall chimney.
void _smithy(VoxelWorld w, int ox, int oy, int stage) {
  for (var z = 1; z <= math.min(stage, 3); z++) {
    w.ring(ox, oy, 5, 5, z, Blocks.stone, corner: Blocks.cobble);
    if (z <= 2) {
      w
        ..remove(ox + 1, oy + 4, z)
        ..remove(ox + 2, oy + 4, z);
    }
  }
  if (stage >= 4) w.set(ox + 4, oy + 2, 2, Blocks.glass);
  if (stage >= 5) w.fill(ox, oy, 4, ox + 4, oy + 4, 4, Blocks.roof);
  if (stage >= 6) {
    w
      ..fill(ox + 3, oy + 1, 5, ox + 3, oy + 1, 7, Blocks.cobble)
      ..set(ox + 3, oy + 1, 8, Blocks.char);
  }
}

// A striped lighthouse with a glass lantern.
void _lighthouse(VoxelWorld w, int ox, int oy, int stage) {
  const layers = [2, 4, 6, 8, 9];
  for (var s = 1; s <= math.min(stage, 5); s++) {
    final top = layers[s - 1];
    final bottom = s == 1 ? 1 : layers[s - 2] + 1;
    w.fill(
      ox,
      oy,
      bottom,
      ox + 2,
      oy + 2,
      top,
      s.isEven ? Blocks.wool : Blocks.stone,
    );
  }
  w
    ..remove(ox + 1, oy + 2, 1)
    ..remove(ox + 1, oy + 2, 2);
  if (stage >= 6) w.ring(ox, oy, 3, 3, 10, Blocks.glass);
  if (stage >= 7) w.fill(ox, oy, 11, ox + 2, oy + 2, 11, Blocks.slate);
  if (stage >= 8) w.fill(ox + 1, oy + 1, 12, ox + 1, oy + 1, 13, Blocks.log);
}

// A stepped pyramid on the whole 7x7 plot, with pillars and a flag.
void _pyramid(VoxelWorld w, int ox, int oy, int stage) {
  void layer(int z, int inset, {required bool full}) {
    final size = 7 - 2 * inset;
    final o = (x: ox + inset, y: oy + inset);
    if (full) {
      w.fill(o.x, o.y, z, o.x + size - 1, o.y + size - 1, z, Blocks.plank);
    } else {
      w.ring(o.x, o.y, size, size, z, Blocks.plank);
    }
  }

  layer(1, 0, full: stage >= 2);
  // The entrance is open from the start.
  w
    ..remove(ox + 3, oy + 6, 1)
    ..remove(ox + 3, oy + 5, 1);
  if (stage >= 3) layer(2, 1, full: stage >= 4);
  if (stage >= 5) layer(3, 2, full: stage >= 6);
  if (stage >= 7) w.set(ox + 3, oy + 3, 4, Blocks.plank);
  if (stage >= 8) w.set(ox + 3, oy + 3, 5, Blocks.slate);
  const corners = [(0, 0), (6, 0), (0, 6), (6, 6)];
  if (stage >= 9) {
    for (final (dx, dy) in corners) {
      w.fill(ox + dx, oy + dy, 2, ox + dx, oy + dy, 3, Blocks.stone);
    }
  }
  if (stage >= 10) {
    for (final (dx, dy) in corners) {
      w.set(ox + dx, oy + dy, 4, Blocks.wool);
    }
  }
  if (stage >= 11) w.set(ox + 3, oy + 6, 2, Blocks.wool); // entrance banner
  if (stage >= 12) _flag(w, ox + 3, oy + 3, 6);
}

/// The castle. The prototype castle is 9x9; this one is shrunk to fit one 7x7
/// plot, so it uses the plot origin itself (no margin) and has no scaffold.
void _castle(VoxelWorld w, int ox, int oy, int stage) {
  // Stages 1-4: wall rings from the ground up; the gate gap is cleared as the
  // rings are placed.
  for (var z = 1; z <= math.min(stage, 4); z++) {
    w.ring(ox, oy, 7, 7, z, Blocks.stone);
    if (z <= 3) {
      for (var x = ox + 2; x <= ox + 4; x++) {
        w.remove(x, oy + 6, z);
      }
    }
  }
  // Stage 5: battlements on every other wall cell (counted from the corner).
  if (stage >= 5) {
    for (var dx = 0; dx < 7; dx++) {
      for (var dy = 0; dy < 7; dy++) {
        final onWall = dx == 0 || dx == 6 || dy == 0 || dy == 6;
        if (onWall && (dx + dy).isEven) {
          w.set(ox + dx, oy + dy, 5, Blocks.stone);
        }
      }
    }
  }
  const corners = [(0, 0), (5, 0), (0, 5), (5, 5)];
  // Stages 6 and 7: corner towers up to z 3, then z 6. Stage 8: merlons.
  if (stage >= 6) {
    final top = stage >= 7 ? 6 : 3;
    for (final (dx, dy) in corners) {
      w.fill(ox + dx, oy + dy, 1, ox + dx + 1, oy + dy + 1, top, Blocks.stone);
    }
  }
  if (stage >= 8) {
    for (final (dx, dy) in corners) {
      w
        ..set(ox + dx, oy + dy, 7, Blocks.stone)
        ..set(ox + dx + 1, oy + dy + 1, 7, Blocks.stone);
    }
  }
  // Stages 9-11: keep, slate roof, roof peak. Stage 12: two flags.
  if (stage >= 9) w.fill(ox + 2, oy + 2, 1, ox + 4, oy + 4, 4, Blocks.cobble);
  if (stage >= 10) w.fill(ox + 2, oy + 2, 5, ox + 4, oy + 4, 5, Blocks.slate);
  if (stage >= 11) w.set(ox + 3, oy + 3, 6, Blocks.slate);
  if (stage >= 12) {
    _flag(w, ox, oy, 8);
    _flag(w, ox + 5, oy, 8);
  }
}

// A log pole three blocks high with a wool pennant on its +x side.
void _flag(VoxelWorld w, int x, int y, int z) {
  w
    ..fill(x, y, z, x, y, z + 2, Blocks.log)
    ..set(x + 1, y, z + 1, Blocks.wool)
    ..set(x + 1, y, z + 2, Blocks.wool);
}

/// A burnt-out building left by a failed session, on the plot at
/// ([plotOriginX], [plotOriginY]).
void buildRuin(VoxelWorld w, int plotOriginX, int plotOriginY) {
  final ox = plotOriginX + 1;
  final oy = plotOriginY + 1;
  for (final (dx, dy) in [
    (0, 0),
    (1, 0),
    (0, 1),
    (4, 0),
    (4, 1),
    (0, 3),
    (0, 4),
    (3, 4),
    (4, 4),
  ]) {
    w.set(ox + dx, oy + dy, 1, Blocks.cobble);
  }
  for (final (dx, dy) in [(0, 0), (0, 1), (4, 0)]) {
    w.set(ox + dx, oy + dy, 2, Blocks.plank);
  }
  w
    ..set(ox, oy, 3, Blocks.char)
    ..set(ox + 4, oy + 4, 2, Blocks.char)
    ..fill(ox + 1, oy + 2, 1, ox + 3, oy + 2, 1, Blocks.char)
    ..set(ox + 2, oy + 3, 1, Blocks.cobble);
}
