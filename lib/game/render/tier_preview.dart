import 'dart:math' as math;
import 'dart:ui';

import 'package:focus_town/domain/building_tier.dart';
import 'package:focus_town/domain/plot_grid.dart';
import 'package:focus_town/game/render/block_painter.dart';
import 'package:focus_town/game/world/block_material.dart';
import 'package:focus_town/game/world/building_defs.dart';
import 'package:focus_town/game/world/plot_layout.dart';
import 'package:focus_town/game/world/vec2.dart';
import 'package:focus_town/game/world/voxel_world.dart';

/// A small picture of [tier]'s finished building on a patch of grass, drawn
/// with the town's own painter on a transparent background. The building's
/// outline fills about 80% of the [size] x [size] picture. [look] picks the
/// classic (0) or the second look.
Future<Image> renderTierPreview(
  BuildingTier tier, {
  int size = 96,
  int look = 0,
}) {
  // One scale for every tier but the castle, set by the biggest of them, so a
  // bigger building draws bigger. The castle (14 x 14 tiles) would shrink the
  // rest to specks, so it gets its own scale and just fits the picture.
  final biggest = BuildingTier.values
      .where((t) => t != BuildingTier.castle)
      .map((t) => _outline(t, look).$2)
      .reduce(math.max);
  final (blocks, length, box) = _outline(tier, look);
  final tile =
      0.8 * size / (tier == BuildingTier.castle ? length : biggest * 1.15);
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
  int look,
) {
  // A castle stands on a 2 x 2 block of plots.
  final side = kPlotSize * (plotsOf(tier) == 4 ? 2 : 1);
  final world = VoxelWorld()
    ..fill(0, 0, 0, side - 1, side - 1, 0, Blocks.grass);
  buildTier(world, tier, 0, 0, stage: maxStage(tier), look: look);
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
