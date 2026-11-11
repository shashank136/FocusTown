import 'dart:math' as math;
import 'dart:ui';

import 'package:focus_town/domain/building_tier.dart';
import 'package:focus_town/game/render/block_painter.dart';
import 'package:focus_town/game/world/block_material.dart';
import 'package:focus_town/game/world/building_defs.dart';
import 'package:focus_town/game/world/plot_layout.dart';
import 'package:focus_town/game/world/vec2.dart';
import 'package:focus_town/game/world/voxel_world.dart';

/// A small picture of [tier]'s finished building on a patch of grass, drawn
/// with the town's own painter on a transparent background. The building's
/// outline fills about 80% of the [size] x [size] picture.
Future<Image> renderTierPreview(BuildingTier tier, {int size = 96}) {
  final world = VoxelWorld()
    ..fill(0, 0, 0, kPlotSize - 1, kPlotSize - 1, 0, Blocks.grass);
  buildTier(world, tier, 0, 0, stage: maxStage(tier));
  final blocks = world.sortedVisible();

  // Outline of the building (everything above the grass) at tile size 1.
  var minX = double.infinity;
  var maxX = -double.infinity;
  var minY = double.infinity;
  var maxY = -double.infinity;
  for (final b in blocks.where((b) => b.z >= 1)) {
    final left = (b.x - b.y - 1).toDouble();
    final right = (b.x - b.y + 1).toDouble();
    final top = (b.x + b.y) / 2 - b.z - 1;
    final bottom = (b.x + b.y) / 2 + 1 - b.z;
    minX = math.min(minX, left);
    maxX = math.max(maxX, right);
    minY = math.min(minY, top);
    maxY = math.max(maxY, bottom);
  }
  final tile = 0.8 * size / math.max(maxX - minX, maxY - minY);
  final origin = Vec2(
    size / 2 - (minX + maxX) / 2 * tile,
    size / 2 - (minY + maxY) / 2 * tile,
  );

  final recorder = PictureRecorder();
  paintBlocks(
    Canvas(recorder),
    blocks,
    tile: tile,
    origin: origin,
    viewSize: Size(size.toDouble(), size.toDouble()),
  );
  return recorder.endRecording().toImage(size, size);
}
