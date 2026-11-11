import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/game/render/block_painter.dart';
import 'package:focus_town/game/world/block_material.dart';
import 'package:focus_town/game/world/vec2.dart';
import 'package:focus_town/game/world/voxel_world.dart';

/// Paints [draw] on a sky-colored canvas.
class _Painter extends CustomPainter {
  new(this.draw);
  final void Function(Canvas canvas, Size size) draw;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawColor(const Color(kSkyBottom), BlendMode.src);
    draw(canvas, size);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

Future<void> _pumpPainted(
  WidgetTester tester,
  Size size,
  void Function(Canvas canvas, Size size) draw,
) => tester.pumpWidget(
  Directionality(
    textDirection: TextDirection.ltr,
    child: Align(
      alignment: Alignment.topLeft,
      child: SizedBox.fromSize(
        size: size,
        child: RepaintBoundary(
          child: CustomPaint(size: size, painter: _Painter(draw)),
        ),
      ),
    ),
  ),
);

Future<Uint8List> _pixels(
  WidgetTester tester,
  Size size,
  void Function(Canvas canvas, Size size) draw,
) async {
  final bytes = await tester.runAsync(() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    _Painter(draw).paint(canvas, size);
    final image = await recorder.endRecording().toImage(
      size.width.toInt(),
      size.height.toInt(),
    );
    final data = await image.toByteData();
    return data!.buffer.asUint8List();
  });
  return bytes!;
}

VisibleBlock _block(int x, int y, int z, BlockMaterial m, [int faces = 7]) =>
    VisibleBlock(x, y, z, m, faces);

List<VisibleBlock> _stack() => [
  _block(0, 0, 0, Blocks.stone),
  _block(1, 0, 0, Blocks.plank),
  _block(0, 1, 0, Blocks.cobble),
  _block(1, 1, 0, Blocks.roof),
  _block(0, 0, 1, Blocks.log),
  _block(1, 0, 1, Blocks.leaves),
  _block(0, 1, 1, Blocks.glass),
  _block(1, 1, 1, Blocks.wool),
];

void main() {
  const size200 = Size(200, 200);

  void drawBlocks(
    Canvas canvas,
    Size size,
    List<VisibleBlock> blocks,
    double tile,
    Vec2 origin,
  ) => paintBlocks(canvas, blocks, tile: tile, origin: origin, viewSize: size);

  testWidgets('culling skips a block far off screen', (tester) async {
    final empty = await _pixels(tester, size200, (c, s) {});
    final offscreen = await _pixels(
      tester,
      size200,
      (c, s) => drawBlocks(
        c,
        s,
        [_block(100, 0, 0, Blocks.grass)],
        40,
        const Vec2(100, 100),
      ),
    );
    final onscreen = await _pixels(
      tester,
      size200,
      (c, s) => drawBlocks(
        c,
        s,
        [_block(0, 0, 0, Blocks.grass)],
        40,
        const Vec2(100, 110),
      ),
    );
    expect(offscreen, empty);
    expect(onscreen, isNot(empty));
  });

  testWidgets('painting twice gives identical pixels', (tester) async {
    void draw(Canvas c, Size s) =>
        drawBlocks(c, s, _stack(), 24, const Vec2(100, 120));
    final a = await _pixels(tester, size200, draw);
    final b = await _pixels(tester, size200, draw);
    expect(a, b);
  });

  testWidgets('the texture variants change the pixels at tile >= 9', (
    tester,
  ) async {
    final big = await _pixels(
      tester,
      size200,
      (c, s) => drawBlocks(
        c,
        s,
        [_block(0, 0, 0, Blocks.grass)],
        24,
        const Vec2(100, 110),
      ),
    );
    final flat = await _pixels(
      tester,
      size200,
      (c, s) => drawBlocks(
        c,
        s,
        [_block(0, 0, 0, Blocks.grass)],
        8,
        const Vec2(100, 110),
      ),
    );
    expect(big, isNot(flat));
  });

  testWidgets('zoomed in far the texture is dropped: flat faces', (
    tester,
  ) async {
    // Colors that fill a real area (anti-aliased edges excluded).
    Future<int> faceColors(double tile) async {
      final px = await _pixels(
        tester,
        size200,
        (c, s) => drawBlocks(
          c,
          s,
          [_block(0, 0, 0, Blocks.grass)],
          tile,
          const Vec2(100, 110),
        ),
      );
      final counts = <int, int>{};
      for (var i = 0; i < px.length; i += 4) {
        final key = (px[i] << 16) | (px[i + 1] << 8) | px[i + 2];
        counts[key] = (counts[key] ?? 0) + 1;
      }
      const sky = (0xcd << 16) | (0xea << 8) | 0xf7;
      return counts.entries.where((e) => e.key != sky && e.value > 80).length;
    }

    expect(await faceColors(24), greaterThan(4)); // textured
    expect(await faceColors(40), lessThanOrEqualTo(3)); // top, left, right
  });

  testWidgets('a hidden face is not drawn', (tester) async {
    final all = await _pixels(
      tester,
      size200,
      (c, s) => drawBlocks(
        c,
        s,
        [_block(0, 0, 0, Blocks.grass)],
        40,
        const Vec2(100, 110),
      ),
    );
    final topOnly = await _pixels(
      tester,
      size200,
      (c, s) => drawBlocks(
        c,
        s,
        [_block(0, 0, 0, Blocks.grass, 1)],
        40,
        const Vec2(100, 110),
      ),
    );
    expect(topOnly, isNot(all));
  });

  testWidgets('paintBox draws three shaded faces', (tester) async {
    final empty = await _pixels(tester, size200, (c, s) {});
    final box = await _pixels(
      tester,
      size200,
      (c, s) => paintBox(
        c,
        x: 0,
        y: 0,
        z: 0,
        w: 1,
        d: 1,
        h: 2,
        color: FlatColor.of(0xff8a1f),
        tile: 30,
        origin: const Vec2(100, 130),
      ),
    );
    expect(box, isNot(empty));
  });

  testWidgets('golden: one grass block, tile 40', (tester) async {
    await _pumpPainted(
      tester,
      size200,
      (c, s) => drawBlocks(
        c,
        s,
        [_block(0, 0, 0, Blocks.grass)],
        40,
        const Vec2(100, 110),
      ),
    );
    await expectLater(
      find.byType(RepaintBoundary).first,
      matchesGoldenFile('goldens/block_single.png'),
    );
  });

  testWidgets('golden: 2x2x2 mixed stack, tile 24, textured', (tester) async {
    await _pumpPainted(
      tester,
      size200,
      (c, s) => drawBlocks(c, s, _stack(), 24, const Vec2(100, 130)),
    );
    await expectLater(
      find.byType(RepaintBoundary).first,
      matchesGoldenFile('goldens/block_stack_textured.png'),
    );
  });

  testWidgets('golden: 2x2x2 mixed stack, tile 6, untextured', (tester) async {
    await _pumpPainted(
      tester,
      size200,
      (c, s) => drawBlocks(c, s, _stack(), 6, const Vec2(100, 100)),
    );
    await expectLater(
      find.byType(RepaintBoundary).first,
      matchesGoldenFile('goldens/block_small_untextured.png'),
    );
  });
}
