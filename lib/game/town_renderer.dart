import 'dart:math' as math;
import 'dart:ui';

import 'package:focus_town/domain/building_tier.dart';
import 'package:focus_town/domain/town.dart';
import 'package:focus_town/game/camera/town_camera.dart';
import 'package:focus_town/game/effects/particles.dart';
import 'package:focus_town/game/render/block_painter.dart';
import 'package:focus_town/game/render/particle_painter.dart';
import 'package:focus_town/game/render/plot_outline_painter.dart';
import 'package:focus_town/game/render/static_layer_cache.dart';
import 'package:focus_town/game/render/worker_painter.dart';
import 'package:focus_town/game/workers/worker_layout.dart';
import 'package:focus_town/game/world/active_site.dart';
import 'package:focus_town/game/world/block_material.dart';
import 'package:focus_town/game/world/building_defs.dart';
import 'package:focus_town/game/world/plot_layout.dart';
import 'package:focus_town/game/world/town_world_builder.dart';
import 'package:focus_town/game/world/vec2.dart';
import 'package:focus_town/game/world/voxel_world.dart';

/// A finished building drawn as a see-through floating copy.
class ReadyPreview {
  /// Creates a preview of [tier] above [plot] at opacity [alpha].
  const new(this.tier, this.plot, this.alpha, {this.look = 0});

  /// Which building.
  final BuildingTier tier;

  /// Where it floats.
  final Plot plot;

  /// Which look of the tier.
  final int look;

  /// 0 to 1.
  final double alpha;
}

/// Draws the sky and the cached static town. Plain Dart, no Flame, so it can
/// be tested into a [PictureRecorder].
class TownRenderer {
  final StaticLayerCache _cache = StaticLayerCache();
  List<VisibleBlock>? _visible;
  BlockIndex? _index;
  List<PlacedWorker> _workers = const [];
  List<Particle> _particles = const [];
  double _particleAlpha = 1;
  ReadyPreview? _preview;
  Set<int> _outlines = const {};
  int? _selected;
  List<VisibleBlock> _previewBlocks = const [];
  (BuildingTier, int, int)? _previewKey;
  int _worldVersion = 0;
  TownState? _town;
  ActiveSite? _site;
  Set<int> _regionPlots = {for (var i = 0; i < 6; i++) i};
  TownCamera? _camera;
  bool _fitted = false;

  /// The camera, once the first frame has been drawn.
  TownCamera? get camera => _camera;

  /// How often the static layer was recorded (a spy for tests).
  int get recordCount => _cache.recordCount;

  /// The building under construction, if any.
  ActiveSite? get site => _site;

  /// How many blocks show a face (a spy for tests).
  int get visibleBlockCount => _visible?.length ?? 0;

  /// Rebuilds the world for [town]; the next paint re-records the layer.
  void setTown(TownState town) {
    _town = town;
    // The view starts on the first unlocked plots and wherever buildings are.
    _regionPlots = {
      for (var i = 0; i < town.plotsUnlocked && i < kPlots.length; i++) i,
      for (final b in town.buildings) b.plotIndex,
    };
    _rebuild();
  }

  /// Shows the building under construction at its current stage, or nothing
  /// for null. The static layer is re-recorded only when the tier or stage
  /// really changed, which is at most once per stage of a session.
  ///
  /// Design note: the site is built into the same world as the town (not a
  /// separate dynamic layer), so its depth order against neighbors is exactly
  /// right and the cost is a handful of re-records per session.
  void setSite(ActiveSite? site) {
    if (site == _site) return;
    _site = site;
    _rebuild();
  }

  void _rebuild() {
    final town = _town;
    if (town == null) return; // a site set early waits for the town
    final visible = buildTownWorld(town, site: _site).sortedVisible();
    _visible = visible;
    _index = BlockIndex(visible);
    _worldVersion++;
  }

  /// The workers currently drawn.
  List<PlacedWorker> get workers => _workers;

  /// The workers drawn on top of the town every frame (they never re-record
  /// the static layer).
  // ignore: use_setters_to_change_properties, a command, not a property
  void setWorkers(List<PlacedWorker> workers) => _workers = workers;

  /// The particles currently drawn.
  List<Particle> get particles => _particles;

  /// Draws [particles] over the workers, at opacity [alpha] (0 to 1).
  void setParticles(List<Particle> particles, double alpha) {
    _particles = particles;
    _particleAlpha = alpha;
  }

  /// The plots drawn with an outline (the choose-a-plot mode).
  Set<int> get plotOutlines => _outlines;

  /// The plot drawn filled, if any.
  int? get selectedPlot => _selected;

  /// Outlines the [free] plots and fills [selected]; an empty set hides them.
  /// Drawn over the cached town every frame, so it never re-records it.
  void setPlotOverlay(Set<int> free, int? selected) {
    _outlines = free;
    _selected = selected;
  }

  /// The floating "ready to place" building, if shown.
  ReadyPreview? get preview => _preview;

  /// Shows (or with null hides) the floating finished building.
  void setPreview(ReadyPreview? preview) {
    _preview = preview;
    if (preview == null) return;
    final key = (preview.tier, preview.plot.index, preview.look);
    if (key == _previewKey) return;
    _previewKey = key;
    final w = VoxelWorld();
    buildTier(
      w,
      preview.tier,
      preview.plot.originX,
      preview.plot.originY,
      stage: maxStage(preview.tier),
      look: preview.look,
    );
    _previewBlocks = w.sortedVisible();
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
    if (_outlines.isNotEmpty) {
      paintPlotOutlines(
        canvas,
        _outlines,
        _selected,
        tile: cam.tile,
        origin: cam.origin,
      );
    }
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
    final preview = _preview;
    if (preview != null) {
      // Lifted 2 blocks, drawn at the preview's opacity.
      canvas
        ..saveLayer(
          null,
          Paint()..color = Color.fromRGBO(0, 0, 0, preview.alpha.clamp(0, 1)),
        )
        ..translate(0, -2 * cam.tile);
      paintBlocks(
        canvas,
        _previewBlocks,
        tile: cam.tile,
        origin: cam.origin,
        viewSize: size,
      );
      canvas.restore();
    }
    if (_particles.isNotEmpty) {
      paintParticles(
        canvas,
        _particles,
        _particleAlpha,
        tile: cam.tile,
        origin: cam.origin,
      );
    }
  }

  /// The unlocked plots plus a 4-tile margin (tile coordinates).
  Rect get unlockedRegion {
    final plots = [for (final i in _regionPlots) kPlots[i]];
    return Rect.fromLTRB(
      plots.map((p) => p.originX).reduce(math.min) - 4.0,
      plots.map((p) => p.originY).reduce(math.min) - 4.0,
      plots.map((p) => p.originX + kPlotSize).reduce(math.max) + 4.0,
      plots.map((p) => p.originY + kPlotSize).reduce(math.max) + 4.0,
    );
  }
}
