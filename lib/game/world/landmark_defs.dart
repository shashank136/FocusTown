import 'package:focus_town/domain/landmark.dart';
import 'package:focus_town/game/world/block_material.dart';
import 'package:focus_town/game/world/voxel_world.dart';

/// Builds [landmark] up to [stage] (0 draws nothing, past the last stage is
/// the last) on the 12 x 12 tiles from ([ox], [oy]): the block of its 2 x 2
/// plots, one tile in from the edge (the outer tile is the road).
void buildLandmark(VoxelWorld w, Landmark landmark, int ox, int oy, int stage) {
  switch (landmark) {
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
