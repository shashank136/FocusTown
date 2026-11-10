import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:focus_town/domain/town.dart';
import 'package:focus_town/game/town_renderer.dart';
import 'package:focus_town/game/world/vec2.dart';

/// The Flame game that draws the town and lets the user pan and zoom it.
///
/// The gesture handlers are plain methods so tests need no real touches.
class TownGame extends FlameGame
    with
        ScaleDetector,
        ScrollDetector,
        // DoubleTapDetector is deprecated but shares the legacy gesture system
        // with the other two; the newer callbacks would add a second system.
        // ignore: deprecated_member_use
        DoubleTapDetector {
  /// Draws the sky and the town.
  final TownRenderer renderer = TownRenderer();

  double _lastScale = 1;
  Vec2? _doubleTapAt;

  /// Shows [town]; call on every change of the stored town.
  void setTown(TownState town) => renderer.setTown(town);

  /// One finger dragged by [delta] pixels.
  void onPan(Vec2 delta) => renderer.camera?.panBy(delta);

  /// Pinch around [focal]; [factor] is the change since the last update.
  void onPinch(Vec2 focal, double factor) =>
      renderer.camera?.zoomAt(focal, factor);

  /// Mouse wheel at [pos]; a negative [dy] (wheel up) zooms in.
  void onWheel(Vec2 pos, double dy) =>
      renderer.camera?.zoomAt(pos, math.exp(-dy * 0.002));

  /// Double tap at [pos]: zoom in 1.5x around it. (Not `onDoubleTap`: Flame's
  /// mixin already owns that name with another signature.)
  void onDoubleTapAt(Vec2 pos) => renderer.camera?.zoomAt(pos, 1.5);

  @override
  void onScaleStart(ScaleStartInfo info) => _lastScale = 1;

  @override
  void onScaleUpdate(ScaleUpdateInfo info) {
    final d = info.raw.focalPointDelta;
    onPan(Vec2(d.dx, d.dy));
    if (info.pointerCount > 1) {
      final scale = info.raw.scale;
      final p = info.eventPosition.widget;
      onPinch(Vec2(p.x, p.y), scale / _lastScale);
      _lastScale = scale;
    }
  }

  @override
  void onScroll(PointerScrollInfo info) {
    final p = info.eventPosition.widget;
    onWheel(Vec2(p.x, p.y), info.scrollDelta.global.y);
  }

  @override
  void onDoubleTapDown(TapDownInfo info) {
    final p = info.eventPosition.widget;
    _doubleTapAt = Vec2(p.x, p.y);
  }

  @override
  void onDoubleTap() {
    final at = _doubleTapAt;
    if (at != null) onDoubleTapAt(at);
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    // The renderer is given the size every frame, so a resize needs no extra
    // handling: the static layer re-records when the size changes.
    renderer.paint(canvas, Size(size.x, size.y));
  }
}
