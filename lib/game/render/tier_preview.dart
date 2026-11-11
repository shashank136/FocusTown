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
  // One scale for every tier, set by the biggest, so a bigger building
  // draws bigger.
  final biggest = BuildingTier.values
      .map((t) => _outline(t).$2)
      .reduce(math.max);
  final (blocks, _, box) = _outline(tier);
  final tile = 0.8 * size / biggest;
  final origin = Vec2(
    size / 2 - (box.$1 + box.$2) / 2 * tile,
    size / 2 - (box.$3 + box.$4) / 2 * tile,
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

// The sorted blocks of [tier]'s building, its longest side at tile size 1, and
// its outline as (minX, maxX, minY, maxY).
(List<VisibleBlock>, double, (double, double, double, double)) _outline(
  BuildingTier tier,
) {
  final world = VoxelWorld()
    ..fill(0, 0, 0, kPlotSize - 1, kPlotSize - 1, 0, Blocks.grass);
  buildTier(world, tier, 0, 0, stage: maxStage(tier));
  final blocks = world.sortedVisible();
  var minX = double.infinity;
  var maxX = -double.infinity;
  var minY = double.infinity;
  var maxY = -double.infinity;
  for (final b in blocks.where((b) => b.z >= 1)) {
    minX = math.min(minX, (b.x - b.y - 1).toDouble());
    maxX = math.max(maxX, (b.x - b.y + 1).toDouble());
    minY = math.min(minY, (b.x + b.y) / 2 - b.z - 1);
    maxY = math.max(maxY, (b.x + b.y) / 2 + 1 - b.z);
  }
  return (blocks, math.max(maxX - minX, maxY - minY), (minX, maxX, minY, maxY));
}
