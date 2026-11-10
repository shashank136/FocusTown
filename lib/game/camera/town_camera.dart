import 'dart:math' as math;
import 'dart:ui' show Rect;

import 'package:focus_town/game/camera/camera_transition.dart';
import 'package:focus_town/game/world/iso.dart';
import 'package:focus_town/game/world/plot_layout.dart';
import 'package:focus_town/game/world/vec2.dart';

/// Largest tile size (zoomed in).
const kMaxTile = 64.0;

/// Where the isometric town sits on screen: its tile size and where tile
/// (0, 0) lands. Pure math, no UI. Every change keeps the map reachable.
class TownCamera {
  /// Creates a camera for a view of [viewSize], fitted to the whole map.
  new(this.viewSize) {
    fitToMap();
  }

  static const double _n = kMapSize * 1.0;

  /// Size of the view in pixels.
  Vec2 viewSize;

  /// Pixels per half block width; always in `[minTile, kMaxTile]`.
  double tile = 1;

  /// Where world tile (0, 0, 0) is drawn.
  Vec2 origin = const Vec2(0, 0);

  /// The tile size at which the whole map just fits.
  double get fitMapTile =>
      math.min(viewSize.x / (2 * _n + 6), viewSize.y / (_n + 18));

  /// Smallest tile size: a bit less than the whole-map fit.
  double get minTile => fitMapTile * 0.7;

  /// Shows the whole map.
  void fitToMap() {
    tile = _clampTile(fitMapTile);
    origin = Vec2(viewSize.x / 2, viewSize.y / 2 - _n * tile * 0.5 + 5 * tile);
    _clampOrigin();
  }

  /// Largest zoom that shows [worldRegion] (tile coordinates) with 8% padding.
  void fitToRegion(Rect worldRegion) {
    // Projected bounds of the four corners at tile size 1.
    final xs = <double>[];
    final ys = <double>[];
    for (final (x, y) in [
      (worldRegion.left, worldRegion.top),
      (worldRegion.right, worldRegion.top),
      (worldRegion.left, worldRegion.bottom),
      (worldRegion.right, worldRegion.bottom),
    ]) {
      xs.add(x - y);
      ys.add((x + y) / 2);
    }
    final minX = xs.reduce(math.min);
    final maxX = xs.reduce(math.max);
    final minY = ys.reduce(math.min);
    final maxY = ys.reduce(math.max);
    final fit = math.min(
      viewSize.x * 0.84 / (maxX - minX),
      viewSize.y * 0.84 / (maxY - minY),
    );
    tile = _clampTile(fit);
    origin = Vec2(
      viewSize.x / 2 - (minX + maxX) / 2 * tile,
      viewSize.y / 2 - (minY + maxY) / 2 * tile,
    );
    _clampOrigin();
  }

  /// Moves the picture by [delta] pixels.
  void panBy(Vec2 delta) {
    origin = Vec2(origin.x + delta.x, origin.y + delta.y);
    _clampOrigin();
  }

  /// Zooms by [factor] keeping the point under [focal] where it is.
  void zoomAt(Vec2 focal, double factor) {
    final newTile = _clampTile(tile * factor);
    final r = newTile / tile;
    origin = Vec2(
      focal.x - (focal.x - origin.x) * r,
      focal.y - (focal.y - origin.y) * r,
    );
    tile = newTile;
    _clampOrigin();
  }

  /// Centers the ground point ([worldPoint], in tile coordinates).
  void focusOn(Vec2 worldPoint) {
    origin = Vec2(
      viewSize.x / 2 - (worldPoint.x - worldPoint.y) * tile,
      viewSize.y / 2 - (worldPoint.x + worldPoint.y) * tile / 2,
    );
    _clampOrigin();
  }

  /// The ground point shown at the view center.
  Vec2 get centerWorld =>
      unprojectGround(viewSize.x / 2, viewSize.y / 2, tile, origin);

  /// The current [CameraPose].
  CameraPose get pose => CameraPose(centerWorld, tile);

  /// Looks at [center] with tile size [tile] (clamped).
  void setPose(Vec2 center, double tile) {
    this.tile = _clampTile(tile);
    focusOn(center);
  }

  /// Stores a new view size and re-clamps.
  void resize(Vec2 newSize) {
    viewSize = newSize;
    tile = _clampTile(tile);
    _clampOrigin();
  }

  double _clampTile(double t) => math.max(minTile, math.min(kMaxTile, t));

  // Keeps at least 30% of the map's projected box on screen on both axes.
  void _clampOrigin() {
    final w = viewSize.x;
    final h = viewSize.y;
    origin = Vec2(
      origin.x.clamp(-0.4 * _n * tile, w + 0.4 * _n * tile),
      origin.y.clamp(-0.7 * _n * tile, h - 0.3 * _n * tile),
    );
  }
}
