import 'dart:math' as math;
import 'dart:ui';

import 'package:focus_town/domain/town.dart';
import 'package:focus_town/game/camera/town_camera.dart';
import 'package:focus_town/game/render/static_layer_cache.dart';
import 'package:focus_town/game/render/worker_painter.dart';
import 'package:focus_town/game/workers/worker_layout.dart';
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
  BlockIndex? _index;
  List<PlacedWorker> _workers = const [];
  int _worldVersion = 0;
  int _plotsUnlocked = 6;
  TownCamera? _camera;
  bool _fitted = false;

  /// The camera, once the first frame has been drawn.
  TownCamera? get camera => _camera;

  /// How often the static layer was recorded (a spy for tests).
  int get recordCount => _cache.recordCount;

  /// Rebuilds the world for [town]; the next paint re-records the layer.
  void setTown(TownState town) {
    final visible = buildTownWorld(town).sortedVisible();
    _visible = visible;
    _index = BlockIndex(visible);
    _plotsUnlocked = town.plotsUnlocked;
    _worldVersion++;
  }

  /// The workers drawn on top of the town every frame (they never re-record
  /// the static layer).
  // ignore: use_setters_to_change_properties, a command, not a property
  void setWorkers(List<PlacedWorker> workers) => _workers = workers;

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
    final view = Vec2(size.width, size.height);
    final cam = _camera ??= TownCamera(view);
    if (cam.viewSize != view) cam.resize(view);
    if (visible == null) return;
    if (!_fitted) {
      // First layout: show the unlocked plots, not the whole map.
      cam.fitToRegion(unlockedRegion);
      _fitted = true;
    }
    _cache
      ..update(
        worldVersion: _worldVersion,
        blocks: visible,
        tile: cam.tile,
        origin: cam.origin,
        viewSize: size,
      )
      ..paint(canvas, cam.origin);
    if (_workers.isNotEmpty) {
      paintWorkers(
        canvas,
        _workers,
        tile: cam.tile,
        origin: cam.origin,
        viewSize: size,
        index: _index,
      );
    }
  }

  /// The unlocked plots plus a 4-tile margin (tile coordinates).
  Rect get unlockedRegion {
    final plots = kPlots.take(_plotsUnlocked);
    return Rect.fromLTRB(
      plots.map((p) => p.originX).reduce(math.min) - 4.0,
      plots.map((p) => p.originY).reduce(math.min) - 4.0,
      plots.map((p) => p.originX + kPlotSize).reduce(math.max) + 4.0,
      plots.map((p) => p.originY + kPlotSize).reduce(math.max) + 4.0,
    );
  }
}
