import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/domain/building_tier.dart';
import 'package:focus_town/game/world/block_material.dart';
import 'package:focus_town/game/world/building_defs.dart';
import 'package:focus_town/game/world/plot_layout.dart';
import 'package:focus_town/game/world/voxel_world.dart';

/// Pinned: blocks in the finished 14 x 14 castle (computed from the shape).
const kCastleBlocks = 675;

extension on VoxelWorld {
  void buildRuinAt(Plot p) => buildRuin(this, p.originX, p.originY);
}

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

  group('workshop', () {
    test('block count never decreases and the final count is 71', () {
      var last = 0;
      for (var s = 1; s <= 6; s++) {
        final n = _build(BuildingTier.workshop, s).blockCount;
        expect(n, greaterThanOrEqualTo(last), reason: 'stage $s');
        last = n;
      }
      expect(last, 71); // 3 rings of 16, minus 4 door, 25 slate, 2 chimney
    });

    test('the 2-wide door gap is open at stage 1', () {
      final w = _build(BuildingTier.workshop, 1);
      expect(w.has(ox + 1, oy + 4, 1), isFalse);
      expect(w.has(ox + 2, oy + 4, 1), isFalse);
      expect(w.has(ox, oy + 4, 1), isTrue);
    });

    test('stage 4 adds two glass windows, stage 5 a slate roof', () {
      final w4 = _build(BuildingTier.workshop, 4);
      expect(w4.get(ox + 4, oy + 1, 2), Blocks.glass);
      expect(w4.get(ox + 4, oy + 2, 2), Blocks.glass);
      expect(_build(BuildingTier.workshop, 3).has(ox + 4, oy + 1, 2), isTrue);
      expect(
        _build(BuildingTier.workshop, 3).get(ox + 4, oy + 1, 2),
        Blocks.cobble,
      );
      expect(_build(BuildingTier.workshop, 5).get(ox, oy, 4), Blocks.slate);
    });

    test('stage 6 adds the chimney', () {
      final w = _build(BuildingTier.workshop, 6);
      expect(w.get(ox + 3, oy + 1, 5), Blocks.cobble);
      expect(w.get(ox + 3, oy + 1, 6), Blocks.cobble);
      expect(_build(BuildingTier.workshop, 5).has(ox + 3, oy + 1, 5), isFalse);
    });
  });

  group('tower', () {
    test('block count never decreases and the final count is 90', () {
      var last = 0;
      for (var s = 1; s <= 8; s++) {
        final n = _build(BuildingTier.tower, s).blockCount;
        expect(n, greaterThanOrEqualTo(last), reason: 'stage $s');
        last = n;
      }
      expect(last, 90); // 81 stone minus 2 door, 4 battlements, 3 pole, 4 flag
    });

    test('the flag exists only at stage 8', () {
      expect(
        _build(BuildingTier.tower, 8).get(ox + 3, oy + 1, 12),
        Blocks.wool,
      );
      expect(_build(BuildingTier.tower, 7).has(ox + 3, oy + 1, 12), isFalse);
      expect(_build(BuildingTier.tower, 7).get(ox + 1, oy + 1, 12), Blocks.log);
      expect(_build(BuildingTier.tower, 6).has(ox + 1, oy + 1, 11), isFalse);
    });

    test('battlements appear at stage 6', () {
      final w = _build(BuildingTier.tower, 6);
      for (final (dx, dy) in [(0, 0), (2, 0), (0, 2), (2, 2)]) {
        expect(w.get(ox + dx, oy + dy, 10), Blocks.stone);
      }
      expect(w.has(ox + 1, oy + 1, 10), isFalse);
    });

    test('door gap and windows come with their layers', () {
      expect(_build(BuildingTier.tower, 1).has(ox + 1, oy + 2, 1), isFalse);
      expect(_build(BuildingTier.tower, 1).has(ox + 1, oy + 2, 2), isFalse);
      expect(_build(BuildingTier.tower, 2).has(ox + 1, oy + 2, 3), isTrue);
      expect(
        _build(BuildingTier.tower, 3).get(ox + 2, oy + 1, 5),
        Blocks.glass,
      );
      expect(_build(BuildingTier.tower, 2).has(ox + 2, oy + 1, 5), isFalse);
      expect(
        _build(BuildingTier.tower, 4).get(ox + 1, oy + 2, 7),
        Blocks.glass,
      );
    });
  });

  test(
    'workshop and tower fit the plot, scaffold on at the stage before max',
    () {
      for (final p in [kPlots.first, kPlots.last]) {
        for (final t in [BuildingTier.workshop, BuildingTier.tower]) {
          for (final scaffold in [true, false]) {
            final s = scaffold ? maxStage(t) - 1 : maxStage(t);
            final w = _build(t, s, scaffold: scaffold, plot: p);
            for (final b in w.blocks) {
              expect(b.x, inInclusiveRange(p.originX, p.originX + 6));
              expect(b.y, inInclusiveRange(p.originY, p.originY + 6));
            }
          }
        }
      }
    },
  );

  test('workshop and tower no longer throw', () {
    for (final t in [BuildingTier.workshop, BuildingTier.tower]) {
      expect(() => buildTier(VoxelWorld(), t, 3, 3, stage: 1), returnsNormally);
    }
  });

  group('castle', () {
    // The castle stands on a 2 x 2 block of plots (14 x 14 tiles) but is only
    // 12 x 12: one tile in from the block's edge, which is left for the road.
    final cx = plot0.originX + 1;
    final cy = plot0.originY + 1;

    test('block count never decreases across 12 stages', () {
      var last = 0;
      for (var s = 1; s <= 12; s++) {
        final n = _build(BuildingTier.castle, s).blockCount;
        expect(n, greaterThanOrEqualTo(last), reason: 'stage $s');
        last = n;
      }
      expect(last, kCastleBlocks);
    });

    test('every stage fits inside the block, one tile in from its edge', () {
      for (final p in [kPlots.first, kPlots.last]) {
        for (var s = 1; s <= 12; s++) {
          for (final b in _build(BuildingTier.castle, s, plot: p).blocks) {
            expect(b.x, inInclusiveRange(p.originX + 1, p.originX + 12));
            expect(b.y, inInclusiveRange(p.originY + 1, p.originY + 12));
          }
        }
      }
    });

    test('the gate gap is open from stage 1 at z 1..3, with a lintel', () {
      for (var s = 1; s <= 12; s++) {
        final w = _build(BuildingTier.castle, s);
        for (var x = cx + 4; x <= cx + 7; x++) {
          for (var z = 1; z <= math.min(s, 3); z++) {
            expect(w.has(x, cy + 11, z), isFalse, reason: 'stage $s ($x, $z)');
          }
        }
      }
      expect(_build(BuildingTier.castle, 4).has(cx + 5, cy + 11, 4), isTrue);
    });

    test('stages add their parts in order', () {
      expect(_build(BuildingTier.castle, 4).has(cx, cy, 5), isFalse);
      expect(_build(BuildingTier.castle, 5).has(cx, cy, 5), isTrue); // merlon
      expect(_build(BuildingTier.castle, 5).has(cx + 1, cy, 5), isFalse);
      expect(_build(BuildingTier.castle, 5).has(cx + 1, cy + 1, 1), isFalse);
      expect(_build(BuildingTier.castle, 6).has(cx + 1, cy + 1, 4), isTrue);
      expect(_build(BuildingTier.castle, 6).has(cx + 1, cy + 1, 5), isFalse);
      expect(_build(BuildingTier.castle, 7).has(cx + 1, cy + 1, 8), isTrue);
      expect(_build(BuildingTier.castle, 7).has(cx, cy, 9), isFalse);
      expect(_build(BuildingTier.castle, 8).has(cx, cy, 9), isTrue);
      expect(_build(BuildingTier.castle, 8).has(cx + 5, cy + 5, 1), isFalse);
      expect(
        _build(BuildingTier.castle, 9).get(cx + 5, cy + 5, 5),
        Blocks.cobble,
      );
      expect(_build(BuildingTier.castle, 9).has(cx + 5, cy + 5, 6), isFalse);
      expect(
        _build(BuildingTier.castle, 10).get(cx + 5, cy + 5, 6),
        Blocks.slate,
      );
      expect(_build(BuildingTier.castle, 10).has(cx + 5, cy + 5, 7), isFalse);
      expect(
        _build(BuildingTier.castle, 11).get(cx + 5, cy + 5, 8),
        Blocks.slate,
      );
      expect(_build(BuildingTier.castle, 11).has(cx, cy, 10), isFalse);
      expect(_build(BuildingTier.castle, 12).get(cx, cy, 10), Blocks.log);
      expect(_build(BuildingTier.castle, 12).get(cx + 1, cy, 11), Blocks.wool);
    });

    test('the castle ignores the scaffold flag', () {
      final a = _build(BuildingTier.castle, 12, scaffold: true);
      final b = _build(BuildingTier.castle, 12);
      expect(a.blockCount, b.blockCount);
      expect(
        a.blocks.map((e) => (e.x, e.y, e.z)).toSet(),
        b.blocks.map((e) => (e.x, e.y, e.z)).toSet(),
      );
    });
  });

  group('ruin', () {
    VoxelWorld ruin([Plot? plot]) {
      final p = plot ?? kPlots.first;
      return VoxelWorld()..buildRuinAt(p);
    }

    test('only cobble, plank and char blocks', () {
      final allowed = {Blocks.cobble, Blocks.plank, Blocks.char};
      for (final b in ruin().blocks) {
        expect(allowed, contains(b.material));
      }
    });

    test('fits the footprint and has a stable block count', () {
      for (final p in [kPlots.first, kPlots.last]) {
        final w = ruin(p);
        expect(w.blockCount, ruin(p).blockCount);
        for (final b in w.blocks) {
          expect(b.x, inInclusiveRange(p.originX, p.originX + 6));
          expect(b.y, inInclusiveRange(p.originY, p.originY + 6));
        }
      }
      expect(ruin().blockCount, 9 + 3 + 2 + 3 + 1);
    });

    test('has the prototype pieces', () {
      final w = ruin();
      expect(w.get(ox, oy, 1), Blocks.cobble);
      expect(w.get(ox, oy, 2), Blocks.plank);
      expect(w.get(ox, oy, 3), Blocks.char);
      expect(w.get(ox + 4, oy + 4, 2), Blocks.char);
      expect(w.get(ox + 2, oy + 2, 1), Blocks.char);
      expect(w.get(ox + 2, oy + 3, 1), Blocks.cobble);
    });
  });
}
