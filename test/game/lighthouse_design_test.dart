import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/domain/landmark.dart';
import 'package:focus_town/domain/plot_grid.dart';
import 'package:focus_town/game/world/block_material.dart';
import 'package:focus_town/game/world/landmark_defs.dart';
import 'package:focus_town/game/world/voxel_world.dart';

const _ox = 20;
const _oy = 20;
const Landmark _l = Landmark.lighthouse;

VoxelWorld _build(int stage) {
  final w = VoxelWorld();
  buildLandmark(w, _l, _ox, _oy, stage);
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

  test('every stage adds blocks, from the island to the fire', () {
    var before = 0;
    for (var s = 1; s <= _l.stages; s++) {
      final now = _build(s).blockCount;
      expect(now, greaterThan(before), reason: 'stage $s');
      before = now;
    }
  });

  test('it is a tall tower: 33 levels from the water to the beacon', () {
    int top(int stage) =>
        _build(stage).blocks.fold(0, (m, b) => b.z > m ? b.z : m);
    expect(top(1), lessThan(top(6)));
    expect(top(12), 32);
  });

  test('an island in the sea with steps up from the shore', () {
    final w = _build(_l.stages);
    expect(_at(w, 0, 0, 0), Blocks.water); // the corners are sea
    expect(_at(w, 6, 6, 0), Blocks.path); // the island
    expect(_at(w, 2, 2, 0), Blocks.travertine); // the sand of its shore
    // Steps lead up from the shore to the door.
    expect(_at(w, 6, 10, 2), Blocks.cobble);
    expect(_at(w, 6, 11, 1), Blocks.cobble);
    expect(_at(w, 6, 11, 2), isNull);
  });

  test('three tiers: a square base with a door, an octagon, a round top', () {
    final w = _build(_l.stages);
    // The square base, 7 wide, with a dark door in the middle of the front.
    expect(_at(w, 3, 3, 1), Blocks.stone);
    expect(_at(w, 9, 9, 13), isNotNull);
    expect(_at(w, 6, 9, 1), Blocks.char);
    expect(_at(w, 6, 9, 2), Blocks.char);
    // The octagon above it has its corners cut.
    expect(_at(w, 5, 4, 14), Blocks.marble);
    expect(_at(w, 4, 4, 14), isNull);
    expect(_at(w, 8, 8, 14), isNull);
    // The round top is a small disc.
    expect(_at(w, 5, 5, 23), Blocks.marble);
    expect(_at(w, 7, 5, 23), isNull);
  });

  test('the lantern burns on four pillars, with a gold figure above', () {
    final w = _build(_l.stages);
    expect(_at(w, 5, 5, 28), Blocks.cobble);
    expect(_at(w, 7, 7, 29), Blocks.cobble);
    expect(_at(w, 6, 6, 28), Blocks.flame);
    expect(_at(w, 6, 6, 29), Blocks.gold);
    expect(_at(w, 6, 6, 32), Blocks.gold);
    expect(_at(w, 6, 6, 33), isNull);
  });

  test('the finished design has a fixed number of blocks', () {
    expect(_build(_l.stages).blockCount, 636);
  });

  test('the old design is still there for the old block', () {
    final w = VoxelWorld();
    buildLandmark(w, _l, _ox, _oy, _l.stages, classic: true);
    expect(w.blockCount, greaterThan(150));
    expect(w.get(_ox + 5, _oy + 5, 24), Blocks.wool); // the old fire
  });
}
