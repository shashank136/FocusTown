import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/domain/landmark.dart';
import 'package:focus_town/domain/plot_grid.dart';
import 'package:focus_town/game/world/block_material.dart';
import 'package:focus_town/game/world/landmark_defs.dart';
import 'package:focus_town/game/world/voxel_world.dart';

const _ox = 20;
const _oy = 20;
const Landmark _l = Landmark.easterIsland;

VoxelWorld _build(int stage, {bool classic = false}) {
  final w = VoxelWorld();
  buildLandmark(w, _l, _ox, _oy, stage, classic: classic);
  return w;
}

BlockMaterial? _at(VoxelWorld w, int x, int y, int z) =>
    w.get(_ox + x, _oy + y, z);

void main() {
  test('it stands on a 2 x 2 block: 12 x 12 tiles inside the road', () {
    expect(_l.footprint, Footprint.block);
    for (final b in _build(_l.stages).blocks) {
      expect(b.x, inInclusiveRange(_ox, _ox + 11));
      expect(b.y, inInclusiveRange(_oy, _oy + 11));
    }
  });

  test('every stage adds blocks, from the platform to the topknot', () {
    var before = 0;
    for (var s = 1; s <= _l.stages; s++) {
      final now = _build(s).blockCount;
      expect(now, greaterThan(before), reason: 'stage $s');
      before = now;
    }
  });

  test('it grows from the ground up and the topknot is on top', () {
    int top(int stage) =>
        _build(stage).blocks.fold(0, (m, b) => b.z > m ? b.z : m);
    expect(top(1), lessThan(top(6)));
    expect(top(12), 20);
  });

  test('one statue on a stone platform with a ramp and a paved apron', () {
    final w = _build(_l.stages);
    expect(_at(w, 0, 0, 1), Blocks.cobble); // the ahu
    expect(_at(w, 5, 11, 0), Blocks.path); // the paved apron in front
    expect(_at(w, 5, 10, 1), Blocks.stone); // the sloping ramp of stones
  });

  test('a plain body with the hands on the belly and no legs', () {
    final w = _build(_l.stages);
    expect(_at(w, 3, 4, 3), Blocks.cobble); // the body, from the platform up
    expect(_at(w, 9, 8, 8), Blocks.cobble);
    expect(_at(w, 5, 9, 5), Blocks.stone); // the hands, in front
    expect(_at(w, 4, 8, 4), Blocks.char); // the line of an arm
  });

  test('a tall head with a heavy brow, deep eyes, a long nose and a chin', () {
    final w = _build(_l.stages);
    expect(_at(w, 3, 4, 9), Blocks.stone); // the head begins
    expect(_at(w, 9, 8, 17), Blocks.stone); // and ends nine blocks up
    expect(_at(w, 5, 9, 9), Blocks.stone); // the chin
    for (var x = 4; x <= 8; x++) {
      expect(_at(w, x, 8, 11), Blocks.char, reason: 'the mouth at $x');
    }
    expect(_at(w, 6, 10, 13), Blocks.stone); // the long nose juts out
    expect(_at(w, 4, 8, 14), Blocks.char); // an eye
    expect(_at(w, 8, 8, 15), Blocks.char); // the other eye
    expect(_at(w, 3, 9, 16), Blocks.cobble); // the brow
    expect(_at(w, 2, 7, 12), Blocks.stone); // an ear
  });

  test('the red topknot is the highest thing', () {
    final w = _build(_l.stages);
    expect(_at(w, 6, 6, 18), Blocks.roof);
    expect(_at(w, 6, 6, 20), Blocks.roof);
    expect(_at(w, 6, 6, 21), isNull);
  });

  test('the finished design has a fixed number of blocks', () {
    expect(_build(_l.stages).blockCount, 1046);
  });

  test('the old design is still there for the old block', () {
    final w = _build(_l.stages, classic: true);
    expect(w.blockCount, greaterThan(150));
    expect(w.get(_ox + 5, _oy + 5, 15), Blocks.roof); // the old topknot
  });
}
