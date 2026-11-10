import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/game/world/block_material.dart';
import 'package:focus_town/game/world/plot_layout.dart';
import 'package:focus_town/game/world/scenery.dart';
import 'package:focus_town/game/world/voxel_world.dart';

VoxelWorld _scenery([int? seed]) {
  final w = VoxelWorld();
  if (seed == null) {
    buildScenery(w);
  } else {
    buildScenery(w, seed: seed);
  }
  return w;
}

List<(int, int)> _trunks(VoxelWorld w) =>
    [
      for (final b in w.blocks)
        if (b.z == 1 && b.material == Blocks.log) (b.x, b.y),
    ]..sort((a, b) {
      final x = a.$1.compareTo(b.$1);
      return x != 0 ? x : a.$2.compareTo(b.$2);
    });

Set<(int, int, int)> _cells(VoxelWorld w) => {
  for (final b in w.blocks) (b.x, b.y, b.z),
};

void main() {
  group('buildTree', () {
    test('has a 3 high trunk, a 3x3 canopy, a plus layer and a tip', () {
      final w = VoxelWorld();
      buildTree(w, 10, 10);
      for (var z = 1; z <= 3; z++) {
        expect(w.get(10, 10, z), Blocks.log);
      }
      for (var dx = -1; dx <= 1; dx++) {
        for (var dy = -1; dy <= 1; dy++) {
          expect(w.get(10 + dx, 10 + dy, 4), Blocks.leaves);
        }
      }
      expect(w.get(10, 10, 5), Blocks.leaves);
      expect(w.get(11, 10, 5), Blocks.leaves);
      expect(w.has(11, 11, 5), isFalse);
      expect(w.get(10, 10, 6), Blocks.leaves);
      expect(w.blockCount, 3 + 9 + 5 + 1);
    });
  });

  test('the pond is water in the top-right border strip', () {
    final w = VoxelWorld();
    buildPond(w);
    for (var x = 56; x <= 62; x++) {
      for (var y = 0; y <= 2; y++) {
        expect(w.get(x, y, 0), Blocks.water);
      }
    }
    expect(w.blockCount, 21);
  });

  group('buildScenery', () {
    test('the same seed gives identical blocks, another seed differs', () {
      expect(_cells(_scenery()), _cells(_scenery(7)));
      expect(_trunks(_scenery(7)), _trunks(_scenery(7)));
      expect(_trunks(_scenery(8)), isNot(_trunks(_scenery(7))));
    });

    test('plants 24 trees and the pond', () {
      final w = _scenery();
      expect(_trunks(w), hasLength(24));
      expect(w.get(60, 1, 0), Blocks.water);
    });

    test('no block is on a road or inside any plot', () {
      for (final b in _scenery().blocks) {
        expect(isRoad(b.x, b.y), isFalse, reason: 'road at (${b.x}, ${b.y})');
        expect(plotAt(b.x, b.y), isNull, reason: 'plot at (${b.x}, ${b.y})');
      }
    });

    test('all blocks are inside 0..63', () {
      for (final b in _scenery().blocks) {
        expect(b.x, inInclusiveRange(0, 63));
        expect(b.y, inInclusiveRange(0, 63));
      }
    });

    test('trees are on the border and at least 3 tiles apart', () {
      final t = _trunks(_scenery());
      for (final (x, y) in t) {
        final border = x <= 2 || x >= 61 || y <= 2 || y >= 61;
        expect(border, isTrue, reason: 'tree at ($x, $y)');
        expect(x >= 56 && y <= 2, isFalse, reason: 'tree in the pond');
      }
      for (var i = 0; i < t.length; i++) {
        for (var j = i + 1; j < t.length; j++) {
          final d = [
            (t[i].$1 - t[j].$1).abs(),
            (t[i].$2 - t[j].$2).abs(),
          ].reduce((a, b) => a > b ? a : b);
          expect(d, greaterThanOrEqualTo(3), reason: '${t[i]} and ${t[j]}');
        }
      }
    });
  });
}
