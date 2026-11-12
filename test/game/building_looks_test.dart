import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/domain/building_tier.dart';
import 'package:focus_town/game/world/building_defs.dart';
import 'package:focus_town/game/world/plot_layout.dart';
import 'package:focus_town/game/world/voxel_world.dart';

final Plot _plot = kPlots.first;

VoxelWorld _build(BuildingTier t, int stage, int look) {
  final w = VoxelWorld();
  buildTier(w, t, _plot.originX, _plot.originY, stage: stage, look: look);
  return w;
}

Set<(int, int, int)> _cells(VoxelWorld w) => {
  for (final b in w.blocks) (b.x, b.y, b.z),
};

void main() {
  for (final t in BuildingTier.values) {
    group('${t.name} second look', () {
      test('differs from the first look when finished', () {
        final a = _cells(_build(t, maxStage(t), 0));
        final b = _cells(_build(t, maxStage(t), 1));
        expect(b, isNot(a));
      });

      test('stays inside its plot', () {
        for (final c in _cells(_build(t, maxStage(t), 1))) {
          // A castle (pyramid) is 12 x 12 inside a 2 x 2 block of plots; the
          // outer tile is the road. Everything else stays inside its plot.
          final inset = t == BuildingTier.castle ? 1 : 0;
          final last = t == BuildingTier.castle ? 12 : 6;
          expect(
            c.$1,
            inInclusiveRange(_plot.originX + inset, _plot.originX + last),
          );
          expect(
            c.$2,
            inInclusiveRange(_plot.originY + inset, _plot.originY + last),
          );
        }
      });

      test(
        'only grows from stage to stage and finishes taller than it starts',
        () {
          var before = <(int, int, int)>{};
          for (var s = 1; s <= maxStage(t); s++) {
            final now = _cells(_build(t, s, 1));
            expect(now.containsAll(before), isTrue, reason: 'stage $s');
            before = now;
          }
          expect(before.length, greaterThan(_cells(_build(t, 1, 1)).length));
          expect(_cells(_build(t, 1, 1)), isNotEmpty);
        },
      );
    });
  }
}
