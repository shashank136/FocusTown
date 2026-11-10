import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/domain/building_tier.dart';
import 'package:focus_town/game/world/block_material.dart';
import 'package:focus_town/game/world/building_defs.dart';
import 'package:focus_town/game/world/plot_layout.dart';
import 'package:focus_town/game/world/voxel_world.dart';

VoxelWorld _build(
  BuildingTier t,
  int stage, {
  bool scaffold = false,
  Plot? plot,
}) {
  final p = plot ?? kPlots.first;
  final w = VoxelWorld();
  buildTier(w, t, p.originX, p.originY, stage: stage, scaffold: scaffold);
  return w;
}

void main() {
  final plot0 = kPlots.first;
  final ox = plot0.originX + 1;
  final oy = plot0.originY + 1;

  group('maxStage', () {
    test('values per tier', () {
      expect(maxStage(BuildingTier.hut), 4);
      expect(maxStage(BuildingTier.house), 7);
      expect(maxStage(BuildingTier.workshop), 6);
      expect(maxStage(BuildingTier.tower), 8);
      expect(maxStage(BuildingTier.castle), 12);
    });
  });

  group('stageForProgress', () {
    test('0 gives stage 1 and 1.0 gives the max stage', () {
      for (final t in BuildingTier.values) {
        expect(stageForProgress(t, 0), 1);
        expect(stageForProgress(t, 1), maxStage(t));
      }
    });

    test('out of range progress is clamped', () {
      expect(stageForProgress(BuildingTier.hut, -3), 1);
      expect(stageForProgress(BuildingTier.hut, 7), 4);
    });

    test('house at 0.5 is stage 4', () {
      expect(stageForProgress(BuildingTier.house, 0.5), 4);
    });

    test('each hut stage starts exactly at (s - 1) / 4', () {
      for (var s = 2; s <= 4; s++) {
        final start = (s - 1) / 4;
        expect(stageForProgress(BuildingTier.hut, start), s);
        expect(stageForProgress(BuildingTier.hut, start - 0.001), s - 1);
      }
    });
  });

  group('hut', () {
    test('block count never decreases from stage 1 to 4', () {
      var last = 0;
      for (var s = 1; s <= 4; s++) {
        final n = _build(BuildingTier.hut, s).blockCount;
        expect(n, greaterThanOrEqualTo(last), reason: 'stage $s');
        last = n;
      }
      expect(_build(BuildingTier.hut, 1).blockCount, greaterThan(0));
    });

    test('stage 1 is a ring with a door gap and a log at the corner', () {
      final w = _build(BuildingTier.hut, 1);
      expect(w.get(ox, oy, 1), Blocks.log);
      expect(w.get(ox + 1, oy, 1), Blocks.plank);
      expect(w.has(ox + 1, oy + 2, 1), isFalse); // door
      expect(w.has(ox + 1, oy + 1, 1), isFalse); // hollow
    });

    test('stage 4 has the roof peak', () {
      final w = _build(BuildingTier.hut, 4);
      expect(w.get(ox + 1, oy + 1, 5), Blocks.roof);
      expect(w.has(ox + 1, oy + 2, 2), isFalse); // door stays open
    });

    test('stage 3 roof overhangs by one block', () {
      final w = _build(BuildingTier.hut, 3);
      expect(w.get(ox - 1, oy - 1, 3), Blocks.roof);
      expect(w.get(ox + 3, oy + 3, 3), Blocks.roof);
    });
  });

  group('house', () {
    test('block count never decreases from stage 1 to 7', () {
      var last = 0;
      for (var s = 1; s <= 7; s++) {
        final n = _build(BuildingTier.house, s).blockCount;
        expect(n, greaterThanOrEqualTo(last), reason: 'stage $s');
        last = n;
      }
    });

    test('stage 7 has the roof peak and a door gap', () {
      final w = _build(BuildingTier.house, 7);
      expect(w.get(ox + 2, oy + 2, 7), Blocks.roof);
      expect(w.has(ox + 2, oy + 4, 1), isFalse);
      expect(w.has(ox + 2, oy + 4, 2), isFalse);
    });

    test('stage 3 adds three glass windows', () {
      final w = _build(BuildingTier.house, 3);
      expect(w.get(ox + 4, oy + 2, 3), Blocks.glass);
      expect(w.get(ox + 3, oy + 4, 3), Blocks.glass);
      expect(w.get(ox + 1, oy + 4, 3), Blocks.glass);
    });

    test('stage 1 is a cobble ring', () {
      final w = _build(BuildingTier.house, 1);
      expect(w.get(ox, oy, 1), Blocks.cobble);
      expect(w.has(ox + 2, oy + 4, 1), isFalse); // door
    });
  });

  group('footprint and scaffold', () {
    void expectInside(VoxelWorld w, Plot p) {
      for (final b in w.blocks) {
        expect(b.x, inInclusiveRange(p.originX, p.originX + 6));
        expect(b.y, inInclusiveRange(p.originY, p.originY + 6));
      }
    }

    test(
      'hut and house stay inside the 7x7 plot with scaffold, plots 0 and 63',
      () {
        for (final p in [kPlots.first, kPlots.last]) {
          for (final t in [BuildingTier.hut, BuildingTier.house]) {
            for (var s = 1; s <= maxStage(t); s++) {
              expectInside(_build(t, s, scaffold: true, plot: p), p);
            }
          }
        }
      },
    );

    test('scaffold adds log posts at the four corners and rails', () {
      final w = _build(BuildingTier.hut, 1, scaffold: true);
      for (final (x, y) in [
        (ox - 1, oy - 1),
        (ox + 3, oy - 1),
        (ox - 1, oy + 3),
        (ox + 3, oy + 3),
      ]) {
        for (var z = 1; z <= 4; z++) {
          expect(w.get(x, y, z), Blocks.log, reason: '($x,$y,$z)');
        }
      }
      expect(w.get(ox + 1, oy + 3, 3), Blocks.plank); // rail along +y side
      expect(w.get(ox + 3, oy + 1, 3), Blocks.plank); // rail along +x side
    });

    test('no scaffold when it is off', () {
      final w = _build(BuildingTier.hut, 1);
      expect(w.has(ox - 1, oy - 1, 1), isFalse);
    });

    test('house scaffold is six blocks high', () {
      final w = _build(BuildingTier.house, 1, scaffold: true);
      expect(w.get(ox - 1, oy - 1, 6), Blocks.log);
      expect(w.has(ox - 1, oy - 1, 7), isFalse);
    });
  });

  test('workshop, tower and castle are not built yet', () {
    for (final t in [
      BuildingTier.workshop,
      BuildingTier.tower,
      BuildingTier.castle,
    ]) {
      expect(
        () => buildTier(VoxelWorld(), t, 3, 3, stage: 1),
        throwsUnimplementedError,
      );
    }
  }, skip: 'workshop and tower arrive in T-14.3, castle in T-14.4');
}
