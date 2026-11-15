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
