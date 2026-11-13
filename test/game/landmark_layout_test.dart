import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/domain/landmark.dart';
import 'package:focus_town/game/world/landmark_defs.dart';
import 'package:focus_town/game/world/voxel_world.dart';

const _ox = 20;
const _oy = 20;

VoxelWorld _build(Landmark l, int stage) {
  final w = VoxelWorld();
  buildLandmark(w, l, _ox, _oy, stage);
  return w;
}

Set<(int, int, int)> _cells(VoxelWorld w) => {
  for (final b in w.blocks) (b.x, b.y, b.z),
};

void main() {
  for (final l in Landmark.values) {
    group(l.title, () {
      test('every stage adds something and never takes anything away', () {
        var before = <(int, int, int)>{};
        for (var s = 1; s <= l.stages; s++) {
          final now = _cells(_build(l, s));
          expect(now.containsAll(before), isTrue, reason: 'stage $s');
          expect(now.length, greaterThan(before.length), reason: 'stage $s');
          before = now;
        }
      });

      test('stage 0 draws nothing and a stage past the end is the last', () {
        expect(_build(l, 0).blockCount, 0);
        expect(_cells(_build(l, 99)), _cells(_build(l, l.stages)));
      });

      test('it stays inside its 12 x 12 inset', () {
        for (final b in _build(l, l.stages).blocks) {
          expect(b.x, inInclusiveRange(_ox, _ox + 11));
          expect(b.y, inInclusiveRange(_oy, _oy + 11));
          expect(b.z, greaterThanOrEqualTo(1));
        }
      });

      test('it has its own look', () {
        final mine = _cells(_build(l, l.stages));
        for (final other in Landmark.values.where((o) => o != l)) {
          expect(mine, isNot(_cells(_build(other, other.stages))));
        }
      });

      test('it is bigger than a house', () {
        expect(_build(l, l.stages).blockCount, greaterThan(150));
      });
    });
  }
}
