import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/game/render/block_painter.dart';
import 'package:focus_town/game/render/static_layer_cache.dart';
import 'package:focus_town/game/world/block_material.dart';
import 'package:focus_town/game/world/vec2.dart';
import 'package:focus_town/game/world/voxel_world.dart';

const _view = Size(200, 200);

List<VisibleBlock> _blocks() {
  final w = VoxelWorld()
    ..fill(-8, -8, 0, 8, 8, 0, Blocks.grass)
    ..fill(0, 0, 1, 2, 2, 2, Blocks.stone);
  return w.sortedVisible();
}

void _update(
  StaticLayerCache c, {
  int version = 1,
  double tile = 16,
  Vec2 origin = const Vec2(100, 100),
  Size view = _view,
}) => c.update(
  worldVersion: version,
  blocks: _blocks(),
  tile: tile,
  origin: origin,
  viewSize: view,
);

Future<Uint8List> _pixels(
  WidgetTester tester,
  void Function(ui.Canvas canvas) draw,
) async {
  final bytes = await tester.runAsync(() async {
    final recorder = ui.PictureRecorder();
    draw(ui.Canvas(recorder));
    final image = await recorder.endRecording().toImage(200, 200);
    return (await image.toByteData())!.buffer.asUint8List();
  });
  return bytes!;
}

void main() {
  test('the first update records once and identical updates do nothing', () {
    final c = StaticLayerCache();
    expect(c.recordCount, 0);
    _update(c);
    expect(c.recordCount, 1);
    _update(c);
    _update(c);
    expect(c.recordCount, 1);
  });

  test('a new world version re-records', () {
    final c = StaticLayerCache();
    _update(c);
    _update(c, version: 2);
    expect(c.recordCount, 2);
  });

  test('a tile change re-records', () {
    final c = StaticLayerCache();
    _update(c);
    _update(c, tile: 18);
    expect(c.recordCount, 2);
  });

  test('a view size change re-records', () {
    final c = StaticLayerCache();
    _update(c);
    _update(c, view: const Size(210, 200));
    expect(c.recordCount, 2);
  });

  test('a pan of 10% of the width does not re-record, 30% does', () {
    final c = StaticLayerCache();
    _update(c);
    _update(c, origin: const Vec2(120, 100));
    expect(c.recordCount, 1);
    _update(c, origin: const Vec2(160, 100));
    expect(c.recordCount, 2);
  });

  test('a vertical pan of 15% does not re-record, 30% does', () {
    final c = StaticLayerCache();
    _update(c);
    _update(c, origin: const Vec2(100, 130));
    expect(c.recordCount, 1);
    _update(c, origin: const Vec2(100, 160));
    expect(c.recordCount, 2);
  });

  test('a pan of exactly 25% does not re-record', () {
    final c = StaticLayerCache();
    _update(c);
    _update(c, origin: const Vec2(150, 100));
    expect(c.recordCount, 1);
  });

  testWidgets(
    'paint after a small pan equals a direct paint at the new origin',
    (tester) async {
      final c = StaticLayerCache();
      _update(c);
      _update(c, origin: const Vec2(120, 90)); // within the threshold
      expect(c.recordCount, 1);
      final cached = await _pixels(tester, (canvas) {
        c.paint(canvas, const Vec2(120, 90));
      });
      final direct = await _pixels(tester, (canvas) {
        paintBlocks(
          canvas,
          _blocks(),
          tile: 16,
          origin: const Vec2(120, 90),
          viewSize: _view,
        );
      });
      expect(cached, direct);
    },
  );

  testWidgets('a pan right shows the strip that came into view on the left', (
    tester,
  ) async {
    final c = StaticLayerCache();
    _update(c);
    _update(c, origin: const Vec2(145, 100)); // 22% right, still cached
    expect(c.recordCount, 1);
    final cached = await _pixels(tester, (canvas) {
      c.paint(canvas, const Vec2(145, 100));
    });
    final direct = await _pixels(tester, (canvas) {
      paintBlocks(
        canvas,
        _blocks(),
        tile: 16,
        origin: const Vec2(145, 100),
        viewSize: _view,
      );
    });
    expect(cached, direct);
  });

  testWidgets('a pan left, up and down also match a direct paint', (
    tester,
  ) async {
    for (final to in const [
      Vec2(55, 100),
      Vec2(100, 55),
      Vec2(100, 145),
      Vec2(145, 145),
      Vec2(55, 55),
    ]) {
      final c = StaticLayerCache();
      _update(c);
      _update(c, origin: to);
      expect(c.recordCount, 1);
      final cached = await _pixels(tester, (canvas) => c.paint(canvas, to));
      final direct = await _pixels(tester, (canvas) {
        paintBlocks(
          canvas,
          _blocks(),
          tile: 16,
          origin: to,
          viewSize: _view,
        );
      });
      expect(cached, direct, reason: '$to');
    }
  });

  testWidgets('paint without a pan equals a direct paint', (tester) async {
    final c = StaticLayerCache();
    _update(c);
    final cached = await _pixels(tester, (canvas) {
      c.paint(canvas, const Vec2(100, 100));
    });
    final direct = await _pixels(tester, (canvas) {
      paintBlocks(
        canvas,
        _blocks(),
        tile: 16,
        origin: const Vec2(100, 100),
        viewSize: _view,
      );
    });
    expect(cached, direct);
  });

  test('paint before any update draws nothing and does not throw', () {
    final c = StaticLayerCache();
    expect(
      () => c.paint(ui.Canvas(ui.PictureRecorder()), const Vec2(0, 0)),
      returnsNormally,
    );
  });
}
