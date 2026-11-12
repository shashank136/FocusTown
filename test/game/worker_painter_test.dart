// Golden images are made on macOS; CI skips this file (--exclude-tags golden).
@Tags(['golden'])
library;

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/domain/building_tier.dart';
import 'package:focus_town/game/render/block_painter.dart';
import 'package:focus_town/game/render/worker_painter.dart';
import 'package:focus_town/game/workers/worker_layout.dart';
import 'package:focus_town/game/workers/worker_model.dart';
import 'package:focus_town/game/world/block_material.dart';
import 'package:focus_town/game/world/building_defs.dart';
import 'package:focus_town/game/world/iso.dart';
import 'package:focus_town/game/world/plot_layout.dart';
import 'package:focus_town/game/world/vec2.dart';
import 'package:focus_town/game/world/voxel_world.dart';

const _size = Size(300, 300);
const _tile = 30.0;
const _origin = Vec2(150, 90);

// Ground 0..9 with a 3 high wall at x = 4, y = 2..6 (blocks z = 1..3).
List<VisibleBlock> _scene() {
  final w = VoxelWorld()
    ..fill(0, 0, 0, 9, 9, 0, Blocks.grass)
    ..fill(4, 2, 1, 4, 6, 3, Blocks.stone);
  return w.sortedVisible();
}

PlacedWorker _worker(double x, double y) => PlacedWorker(
  Worker(x: x, y: y, shirt: FlatColor.of(WorkerColors.vest)),
  Pose.idle,
);

void _draw(
  Canvas canvas,
  List<VisibleBlock> blocks,
  List<PlacedWorker> workers, {
  required bool occlude,
}) {
  canvas.drawColor(const Color(kSkyBottom), BlendMode.src);
  paintBlocks(canvas, blocks, tile: _tile, origin: _origin, viewSize: _size);
  paintWorkers(
    canvas,
    workers,
    tile: _tile,
    origin: _origin,
    viewSize: _size,
    index: occlude ? BlockIndex(blocks) : null,
  );
}

Future<Uint8List> _pixels(
  WidgetTester tester,
  void Function(Canvas canvas) draw,
) async {
  final bytes = await tester.runAsync(() async {
    final recorder = ui.PictureRecorder();
    draw(Canvas(recorder));
    final image = await recorder.endRecording().toImage(300, 300);
    return (await image.toByteData())!.buffer.asUint8List();
  });
  return bytes!;
}

int _pixelAt(Uint8List rgba, double x, double y) {
  final i = (y.round() * 300 + x.round()) * 4;
  return (rgba[i + 3] << 24) |
      (rgba[i] << 16) |
      (rgba[i + 1] << 8) |
      rgba[i + 2];
}

// Screen position of the middle of the helmet's top face.
Vec2 _helmetTop(PlacedWorker w) {
  final helmet = boxesFor(w.worker, w.pose)[3];
  return project(
    helmet.x + helmet.w / 2,
    helmet.y + helmet.d / 2,
    helmet.z + helmet.h,
    _tile,
    _origin,
  );
}

int get _helmetColor => FlatColor.of(WorkerColors.helmet).top;

Future<void> _pumpGolden(
  WidgetTester tester,
  void Function(Canvas canvas) draw,
) => tester.pumpWidget(
  Directionality(
    textDirection: TextDirection.ltr,
    child: Align(
      alignment: Alignment.topLeft,
      child: SizedBox.fromSize(
        size: _size,
        child: RepaintBoundary(child: CustomPaint(painter: _P(draw))),
      ),
    ),
  ),
);

class _P extends CustomPainter {
  new(this.draw);
  final void Function(Canvas canvas) draw;
  @override
  void paint(Canvas canvas, Size size) => draw(canvas);
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

void main() {
  group('BlockIndex.near', () {
    test('returns blocks within the radius only', () {
      final blocks = [
        VisibleBlock(5, 5, 0, Blocks.grass, 7),
        VisibleBlock(8, 5, 0, Blocks.grass, 7), // dx 3
        VisibleBlock(9, 5, 0, Blocks.grass, 7), // dx 4: out
        VisibleBlock(5, 2, 4, Blocks.grass, 7), // dy -3
        VisibleBlock(5, 1, 0, Blocks.grass, 7), // dy -4: out
      ];
      final near = BlockIndex(blocks).near(5.4, 5.6);
      expect(near.map((b) => (b.x, b.y)).toSet(), {(5, 5), (8, 5), (5, 2)});
    });

    test('keeps the draw order of the source list', () {
      final blocks = _scene();
      final near = BlockIndex(blocks).near(4.5, 4.5);
      final order = near.map(blocks.indexOf).toList();
      expect(order, [...order]..sort());
    });
  });

  group('sortWorkersByDepth', () {
    test('nearer workers come last', () {
      final far = _worker(2.5, 2.5);
      final near = _worker(6.5, 6.5);
      expect(sortWorkersByDepth([near, far]), [far, near]);
    });
  });

  testWidgets('a worker behind the wall is hidden by it', (tester) async {
    final blocks = _scene();
    final w = _worker(3.5, 4.5); // one block behind the wall
    final head = _helmetTop(w);
    final plain = await _pixels(
      tester,
      (c) => _draw(c, blocks, [w], occlude: false),
    );
    final occluded = await _pixels(
      tester,
      (c) => _draw(c, blocks, [w], occlude: true),
    );
    expect(_pixelAt(plain, head.x, head.y), _helmetColor); // drawn on top
    expect(_pixelAt(occluded, head.x, head.y), isNot(_helmetColor)); // hidden
  });

  testWidgets('a worker in front of the wall is fully visible', (tester) async {
    final blocks = _scene();
    final w = _worker(6.5, 4.5); // in front
    final head = _helmetTop(w);
    final occluded = await _pixels(
      tester,
      (c) => _draw(c, blocks, [w], occlude: true),
    );
    expect(_pixelAt(occluded, head.x, head.y), _helmetColor);
  });

  testWidgets('golden: worker behind the wall', (tester) async {
    final blocks = _scene();
    await _pumpGolden(
      tester,
      (c) => _draw(c, blocks, [_worker(3.5, 4.5)], occlude: true),
    );
    await expectLater(
      find.byType(RepaintBoundary).first,
      matchesGoldenFile('goldens/worker_behind_wall.png'),
    );
  });

  testWidgets('golden: worker in front of the wall', (tester) async {
    final blocks = _scene();
    await _pumpGolden(
      tester,
      (c) => _draw(c, blocks, [_worker(6.5, 4.5)], occlude: true),
    );
    await expectLater(
      find.byType(RepaintBoundary).first,
      matchesGoldenFile('goldens/worker_in_front.png'),
    );
  });

  testWidgets('golden: three workers at a house under construction', (
    tester,
  ) async {
    final w = VoxelWorld()..fill(0, 0, 0, 11, 11, 0, Blocks.grass);
    buildTier(w, BuildingTier.house, 2, 2, stage: 4, scaffold: true);
    final blocks = w.sortedVisible();
    final workers = siteWorkers(
      // plot origin (2, 2): the building starts at (3, 3)
      _plotAt(2, 2),
      BuildingTier.house,
      3,
      0,
    );
    await _pumpGolden(tester, (c) {
      c.drawColor(const Color(kSkyBottom), BlendMode.src);
      paintBlocks(
        c,
        blocks,
        tile: 22,
        origin: const Vec2(150, 40),
        viewSize: _size,
      );
      paintWorkers(
        c,
        workers,
        tile: 22,
        origin: const Vec2(150, 40),
        viewSize: _size,
        index: BlockIndex(blocks),
      );
    });
    await expectLater(
      find.byType(RepaintBoundary).first,
      matchesGoldenFile('goldens/workers_at_site.png'),
    );
  });
}

Plot _plotAt(int x, int y) => Plot(0, x, y);
