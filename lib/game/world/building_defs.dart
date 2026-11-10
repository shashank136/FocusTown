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
/// [stage]; [scaffold] adds the builders' posts and rails around it.
void buildTier(
  VoxelWorld w,
  BuildingTier t,
  int plotOriginX,
  int plotOriginY, {
  required int stage,
  bool scaffold = false,
}) {
  final ox = plotOriginX + 1;
  final oy = plotOriginY + 1;
  switch (t) {
    case BuildingTier.hut:
      _hut(w, ox, oy, stage);
      if (scaffold) _scaffold(w, ox, oy, 3, 3, 4);
    case BuildingTier.house:
      _house(w, ox, oy, stage);
      if (scaffold) _scaffold(w, ox, oy, 5, 5, 6);
    case BuildingTier.workshop:
      _workshop(w, ox, oy, stage);
      if (scaffold) _scaffold(w, ox, oy, 5, 5, 4);
    case BuildingTier.tower:
      _tower(w, ox, oy, stage);
      if (scaffold) _scaffold(w, ox, oy, 3, 3, 9);
    case BuildingTier.castle:
      throw UnimplementedError('$t is not built yet');
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
