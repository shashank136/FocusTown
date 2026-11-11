import 'dart:ui';

import 'package:focus_town/game/render/block_painter.dart';
import 'package:focus_town/game/world/vec2.dart';
import 'package:focus_town/game/world/voxel_world.dart';

/// Draws the static town into a [Picture] once and replays it every frame.
///
/// The picture is re-recorded only when the world, the tile size or the view
/// size changes, or when the camera moved more than [_repanFraction] of the
/// view away from where it was recorded. The recording covers the view plus
/// [_repanFraction] on every side, so small pans show no gaps.
class StaticLayerCache {
  static const _repanFraction = 0.25;

  Picture? _picture;
  Vec2 _origin = const Vec2(0, 0);
  Size _viewSize = Size.zero;
  double _tile = 0;
  int _worldVersion = -1;

  /// How many times the picture was recorded (a spy for tests).
  int recordCount = 0;

  /// Re-records the picture if anything it depends on changed.
  void update({
    required int worldVersion,
    required List<VisibleBlock> blocks,
    required double tile,
    required Vec2 origin,
    required Size viewSize,
  }) {
    final stale =
        _picture == null ||
        worldVersion != _worldVersion ||
        tile != _tile ||
        viewSize != _viewSize ||
        (origin.x - _origin.x).abs() > _repanFraction * viewSize.width ||
        (origin.y - _origin.y).abs() > _repanFraction * viewSize.height;
    if (!stale) return;
    final padX = _repanFraction * viewSize.width;
    final padY = _repanFraction * viewSize.height;
    final recorder = PictureRecorder();
    // paintBlocks culls against 0..size from the picture's own corner, so the
    // origin is moved by the padding: the picture then covers the view plus
    // the padding on every side (not just to the right and below).
    paintBlocks(
      Canvas(recorder),
      blocks,
      tile: tile,
      origin: Vec2(origin.x + padX, origin.y + padY),
      viewSize: Size(viewSize.width * 1.5, viewSize.height * 1.5),
    );
    _picture?.dispose();
    _picture = recorder.endRecording();
    _origin = origin;
    _viewSize = viewSize;
    _tile = tile;
    _worldVersion = worldVersion;
    recordCount++;
  }

  /// Draws the recorded picture shifted to [currentOrigin].
  void paint(Canvas canvas, Vec2 currentOrigin) {
    final picture = _picture;
    if (picture == null) return;
    final padX = _repanFraction * _viewSize.width;
    final padY = _repanFraction * _viewSize.height;
    canvas
      ..save()
      ..translate(
        currentOrigin.x - _origin.x - padX,
        currentOrigin.y - _origin.y - padY,
      )
      ..drawPicture(picture)
      ..restore();
  }
}
