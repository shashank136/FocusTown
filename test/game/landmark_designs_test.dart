import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/domain/landmark.dart';
import 'package:focus_town/domain/plot_grid.dart';
import 'package:focus_town/game/world/block_material.dart';
import 'package:focus_town/game/world/landmark_defs.dart';
import 'package:focus_town/game/world/voxel_world.dart';

const _ox = 20;
const _oy = 20;

typedef _Spot = (int, int, int, BlockMaterial?);

// One entry per landmark: its footprint, the inset in tiles, the height of the
// highest block, the number of blocks, and some blocks that make it itself.
final List<
  ({Landmark landmark, Footprint size, int top, int count, List<_Spot> spots})
>
_designs = [
  (
    landmark: Landmark.spaceNeedle,
    size: Footprint.block,
    top: 37,
    count: 944,
    spots: [
      (4, 4, 1, Blocks.marble), // a leg at its foot
      (6, 6, 28, Blocks.flame), // the orange ring of the saucer
      (6, 6, 29, Blocks.glass), // the glass level
      (6, 6, 37, Blocks.roof), // the red beacon
      (6, 6, 38, null),
    ],
  ),
  (
    landmark: Landmark.pagoda,
    size: Footprint.block,
    top: 26,
    count: 820,
    spots: [
      (1, 1, 1, Blocks.stone), // the stone base
      (6, 9, 3, Blocks.char), // the door of the first tier
      (0, 0, 4, Blocks.leaves), // a tree in a corner of the courtyard
    ],
  ),
  (
    landmark: Landmark.petra,
    size: const Footprint(3, 2),
    top: 15,
    count: 1456,
    spots: [
      (0, 0, 1, Blocks.redRock), // the cliff
      (4, 3, 1, Blocks.rose), // a column of the Treasury
      (9, 3, 1, Blocks.char), // its doorway
      (9, 3, 12, Blocks.rose), // the round tholos
      (4, 4, 1, Blocks.travertine), // the steps down
    ],
  ),
  (
    landmark: Landmark.sphinx,
    size: const Footprint(4, 2),
    top: 11,
    count: 1068,
    spots: [
      (18, 6, 11, Blocks.gold), // the headdress
      (20, 5, 9, Blocks.char), // an eye
      (21, 6, 10, Blocks.gold), // the cobra on the brow
      (25, 6, 3, Blocks.travertine), // a pillar of the temple in front
    ],
  ),
  (
    landmark: Landmark.chichenItza,
    size: const Footprint(3, 3),
    top: 12,
    count: 1303,
    spots: [
      (9, 15, 1, Blocks.marble), // the stairway on the front
      (9, 11, 9, Blocks.char), // the door of the temple on top
      (1, 16, 0, Blocks.path), // the ball court
    ],
  ),
  (
    landmark: Landmark.statueOfLiberty,
    size: const Footprint(3, 3),
    top: 34,
    count: 1559,
    spots: [
      (0, 0, 0, Blocks.water), // the water round Fort Wood
      (9, 9, 5, Blocks.stone), // the pedestal
      (12, 9, 34, Blocks.flame), // the flame of the torch
      (5, 9, 16, Blocks.marble), // the tablet
    ],
  ),
  (
    landmark: Landmark.eiffel,
    size: const Footprint(3, 3),
    top: 44,
    count: 1152,
    spots: [
      (9, 9, 13, Blocks.bronze), // the first platform
      (9, 9, 44, Blocks.iron), // the tip of the antenna
      (9, 9, 45, null),
    ],
  ),
  (
    landmark: Landmark.colosseum,
    size: const Footprint(4, 4),
    top: 12,
    count: 3649,
    spots: [
      (13, 13, 0, Blocks.travertine), // the arena floor
      (13, 25, 1, Blocks.char), // a gate on the long axis
    ],
  ),
  (
    landmark: Landmark.tajMahal,
    size: const Footprint(5, 4),
    top: 18,
    count: 2718,
    spots: [
      (16, 13, 0, Blocks.water), // the channel of the garden
      (16, 5, 18, Blocks.gold), // the finial of the dome
      (8, 0, 14, Blocks.gold), // the top of a minaret
      (8, 25, 5, Blocks.roof), // the red gate
    ],
  ),
  (
    landmark: Landmark.greatPyramid,
    size: const Footprint(5, 5),
    top: 22,
    count: 6039,
    spots: [
      (10, 10, 22, Blocks.marble), // the white cap
      (12, 19, 8, Blocks.char), // the entrance
      (25, 1, 1, Blocks.sandstone), // a queen's pyramid
      (25, 29, 0, Blocks.dirt), // a boat pit
    ],
  ),
];

VoxelWorld _build(Landmark l, int stage, {bool classic = false}) {
  final w = VoxelWorld();
  buildLandmark(w, l, _ox, _oy, stage, classic: classic);
  return w;
}

void main() {
  for (final d in _designs) {
    final l = d.landmark;
    group(l.title, () {
      test('it stands on ${d.size.cols} x ${d.size.rows} plots', () {
        expect(l.footprint, d.size);
        final w = d.size.cols * 7 - 3;
        final deep = d.size.rows * 7 - 3;
        for (final b in _build(l, l.stages).blocks) {
          expect(b.x, inInclusiveRange(_ox, _ox + w));
          expect(b.y, inInclusiveRange(_oy, _oy + deep));
        }
      });

      test('every stage adds blocks and it grows from the ground up', () {
        var before = 0;
        for (var s = 1; s <= l.stages; s++) {
          final now = _build(l, s).blockCount;
          expect(now, greaterThan(before), reason: 'stage $s');
          before = now;
        }
        int top(int stage) =>
            _build(l, stage).blocks.fold(0, (m, b) => b.z > m ? b.z : m);
        expect(top(1), lessThan(top(6)));
        expect(top(12), d.top);
      });

      test('it has its features and a fixed number of blocks', () {
        final w = _build(l, l.stages);
        for (final (x, y, z, m) in d.spots) {
          expect(w.get(_ox + x, _oy + y, z), m, reason: '($x, $y, $z)');
        }
        expect(w.blockCount, d.count);
      });

      test('the old design is still there for the old block', () {
        final w = _build(l, l.stages, classic: true);
        expect(w.blockCount, greaterThan(150));
        for (final b in w.blocks) {
          expect(b.x, inInclusiveRange(_ox, _ox + 11));
          expect(b.y, inInclusiveRange(_oy, _oy + 11));
        }
      });
    });
  }
}
