import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/game/render/block_painter.dart';
import 'package:focus_town/game/world/block_material.dart';
import 'package:focus_town/game/world/vec2.dart';
import 'package:focus_town/game/world/voxel_world.dart';

// How far apart two ARGB colors are (sum of the channel differences).
int _distance(int a, int b) =>
    (((a >> 16) & 0xFF) - ((b >> 16) & 0xFF)).abs() +
    (((a >> 8) & 0xFF) - ((b >> 8) & 0xFF)).abs() +
    ((a & 0xFF) - (b & 0xFF)).abs();

// The faces of [m]: all shades of the green and all shades of the bloom.
({List<int> green, List<int> bloom}) _shades(BlockMaterial m) => (
  green: [...m.top.skip(1), ...m.sideX.skip(1), ...m.sideY.skip(1)],
  bloom: [...m.dotTop!.skip(1), ...m.dotSideX!.skip(1), ...m.dotSideY!.skip(1)],
);

void main() {
  group('a flower bush block', () {
    test('has green and bloom shades, and a blend for far away', () {
      for (final m in Blocks.bushes) {
        expect(m.dotTop, hasLength(5));
        expect(m.dotSideX, hasLength(5));
        expect(m.dotSideY, hasLength(5));
        // The flat color is neither the green nor the bloom: a mix of both.
        expect(m.top[0], isNot(m.top[1]));
        expect(m.top[0], isNot(m.dotTop![1]));
      }
      expect(Blocks.grass.dotTop, isNull); // an ordinary block has no dots
    });

    test('there are six colours of bush', () {
      expect(Blocks.bushes, hasLength(6));
      expect(Blocks.bushes.toSet(), hasLength(6));
    });

    test('every dot pattern is exactly half bloom and half green', () {
      final patterns = <int>{};
      for (var seed = 0; seed < 200; seed++) {
        final bits = dotPattern(seed);
        expect(bits, hasLength(16));
        expect(bits.where((b) => b).length, 8, reason: 'seed $seed');
        patterns.add(bits.fold(0, (v, b) => v * 2 + (b ? 1 : 0)));
      }
      expect(patterns.length, greaterThan(1)); // not the same on every face
    });
  });

  testWidgets('a bush block is drawn half green and half bloom', (
    tester,
  ) async {
    final world = VoxelWorld()..set(0, 0, 1, Blocks.bushPink);
    const size = ui.Size(200, 200);
    final bytes = (await tester.runAsync(() async {
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder)
        ..drawColor(const ui.Color(0xFFFFFFFF), ui.BlendMode.src);
      paintBlocks(
        canvas,
        world.sortedVisible(),
        tile: 40,
        origin: const Vec2(100, 100),
        viewSize: size,
      );
      final image = await recorder.endRecording().toImage(200, 200);
      return (await image.toByteData())!.buffer.asUint8List();
    }))!;
    final shades = _shades(Blocks.bushPink);
    var green = 0;
    var bloom = 0;
    for (var i = 0; i < bytes.length; i += 4) {
      final argb =
          0xFF000000 | (bytes[i] << 16) | (bytes[i + 1] << 8) | bytes[i + 2];
      if (argb == 0xFFFFFFFF) continue;
      final g = shades.green
          .map((c) => _distance(argb, c))
          .reduce((a, b) => a < b ? a : b);
      final p = shades.bloom
          .map((c) => _distance(argb, c))
          .reduce((a, b) => a < b ? a : b);
      if (g < p) {
        green++;
      } else {
        bloom++;
      }
    }
    final share = bloom / (green + bloom);
    expect(share, inInclusiveRange(0.42, 0.58));
  });
}
