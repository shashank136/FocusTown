import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/domain/landmark.dart';
import 'package:focus_town/domain/plot_grid.dart';
import 'package:focus_town/game/world/block_material.dart';
import 'package:focus_town/game/world/landmark_defs.dart';
import 'package:focus_town/game/world/voxel_world.dart';

const _ox = 20;
const _oy = 20;
const Landmark _l = Landmark.christRedeemer;

VoxelWorld _build(int stage, {bool classic = false}) {
  final w = VoxelWorld();
  buildLandmark(w, _l, _ox, _oy, stage, classic: classic);
  return w;
}

BlockMaterial? _at(VoxelWorld w, int x, int y, int z) =>
    w.get(_ox + x, _oy + y, z);

void main() {
  test('it stands on one plot: a 5 x 5 inset inside the road', () {
    expect(_l.footprint, Footprint.one);
    for (final b in _build(_l.stages).blocks) {
      expect(b.x, inInclusiveRange(_ox, _ox + 4));
      expect(b.y, inInclusiveRange(_oy, _oy + 4));
    }
  });

  test('every stage adds blocks, from the hill to the head', () {
    var before = 0;
    for (var s = 1; s <= _l.stages; s++) {
      final now = _build(s).blockCount;
      expect(now, greaterThan(before), reason: 'stage $s');
      before = now;
    }
  });

  test('it grows from the ground up', () {
    int top(int stage) =>
        _build(stage).blocks.fold(0, (m, b) => b.z > m ? b.z : m);
    expect(top(1), lessThan(top(6)));
    expect(top(6), lessThan(top(12)));
    expect(top(12), 16);
  });

  test('the finished statue: a hill, a chapel, a robed figure, wide arms', () {
    final w = _build(_l.stages);
    // The hill: grass on the ground, rock above it, grass on the slope.
    expect(_at(w, 0, 0, 0), Blocks.grass);
    expect(_at(w, 0, 0, 1), Blocks.stone);
    // The chapel under the statue has a dark doorway.
    expect(_at(w, 2, 3, 4), Blocks.char);
    expect(_at(w, 2, 3, 5), Blocks.char);
    expect(_at(w, 1, 2, 4), Blocks.cobble);
    // The robe is white marble, the arms stretch the whole width of the plot.
    expect(_at(w, 2, 2, 7), Blocks.marble);
    for (var x = 0; x < 5; x++) {
      expect(_at(w, x, 2, 13), Blocks.marble, reason: 'arm at $x');
    }
    // The hands hang at the ends of the arms, and the head is on the top.
    expect(_at(w, 0, 2, 12), Blocks.marble);
    expect(_at(w, 4, 2, 12), Blocks.marble);
    expect(_at(w, 2, 2, 14), Blocks.marble);
    expect(_at(w, 2, 2, 16), Blocks.marble);
    expect(_at(w, 2, 2, 17), isNull);
  });

  test('the finished design has a fixed number of blocks', () {
    expect(_build(_l.stages).blockCount, 122);
  });

  test('the old 12 x 12 design is still there for the old block', () {
    final w = _build(_l.stages, classic: true);
    expect(w.blockCount, greaterThan(150));
    expect(
      w.blocks.any((b) => b.x > _ox + 5),
      isTrue,
      reason: 'it reaches beyond the new 5 x 5',
    );
    for (final b in w.blocks) {
      expect(b.x, inInclusiveRange(_ox, _ox + 11));
      expect(b.y, inInclusiveRange(_oy, _oy + 11));
    }
  });
}
