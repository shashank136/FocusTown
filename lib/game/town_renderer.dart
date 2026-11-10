import 'dart:math' as math;
import 'dart:ui';

import 'package:focus_town/domain/town.dart';
import 'package:focus_town/game/render/static_layer_cache.dart';
import 'package:focus_town/game/world/block_material.dart';
import 'package:focus_town/game/world/plot_layout.dart';
import 'package:focus_town/game/world/town_world_builder.dart';
import 'package:focus_town/game/world/vec2.dart';
import 'package:focus_town/game/world/voxel_world.dart';

/// Draws the sky and the cached static town. Plain Dart, no Flame, so it can
/// be tested into a [PictureRecorder].
class TownRenderer {
  final StaticLayerCache _cache = StaticLayerCache();
  List<VisibleBlock>? _visible;
  int _worldVersion = 0;

  /// How often the static layer was recorded (a spy for tests).
  int get recordCount => _cache.recordCount;

  /// Rebuilds the world for [town]; the next paint re-records the layer.
  void setTown(TownState town) {
    _visible = buildTownWorld(town).sortedVisible();
    _worldVersion++;
  }

  /// Draws everything into [canvas], which is [size] big.
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = Gradient.linear(Offset.zero, Offset(0, size.height), [
          const Color(kSkyTop),
          const Color(kSkyBottom),
        ]),
    );
    final visible = _visible;
    if (visible == null) return;
    // The prototype's fit, for the 64-tile map. T-16.1 replaces it.
    const n = kMapSize;
    final tile = math.min(size.width / (2 * n + 6), size.height / (n + 18));
    final origin = Vec2(
      size.width / 2,
      size.height / 2 - n * tile * 0.5 + 5 * tile,
    );
    _cache
      ..update(
        worldVersion: _worldVersion,
        blocks: visible,
        tile: tile,
        origin: origin,
        viewSize: size,
      )
      ..paint(canvas, origin);
  }
}
