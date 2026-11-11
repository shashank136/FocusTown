import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/domain/building_tier.dart';
import 'package:focus_town/domain/town.dart';
import 'package:focus_town/game/town_renderer.dart';
import 'package:focus_town/game/world/active_site.dart';
import 'package:focus_town/game/world/block_material.dart';
import 'package:focus_town/game/world/building_defs.dart';
import 'package:focus_town/game/world/plot_layout.dart';
import 'package:focus_town/game/world/town_world_builder.dart';
import 'package:focus_town/game/world/voxel_world.dart';

const _size = ui.Size(400, 700);

void _paint(TownRenderer r) => r.paint(ui.Canvas(ui.PictureRecorder()), _size);

TownRenderer _renderer() {
  final r = TownRenderer()..setTown(TownState.initial());
  _paint(r);
  return r;
}

void main() {
  group('ActiveSite', () {
    test('has value equality', () {
      expect(
        const ActiveSite(BuildingTier.hut, 2),
        const ActiveSite(BuildingTier.hut, 2),
      );
      expect(
        const ActiveSite(BuildingTier.hut, 2),
        isNot(const ActiveSite(BuildingTier.hut, 3)),
      );
      expect(
        const ActiveSite(BuildingTier.hut, 2).hashCode,
        const ActiveSite(BuildingTier.hut, 2).hashCode,
      );
    });
  });

  group('buildTownWorld with a site', () {
    test('draws exactly the given stage on the next free plot', () {
      final w = buildTownWorld(
        TownState.initial(),
        site: const ActiveSite(BuildingTier.house, 3),
      );
      final direct = VoxelWorld();
      final p = kPlots[1];
      buildTier(
        direct,
        BuildingTier.house,
        p.originX,
        p.originY,
        stage: 3,
        scaffold: true,
      );
      final inPlot = w.blocks
          .where(
            (b) =>
                b.z >= 1 &&
                b.x >= p.originX &&
                b.x < p.originX + 7 &&
                b.y >= p.originY &&
                b.y < p.originY + 7,
          )
          .length;
      expect(inPlot, direct.blockCount);
    });

    test('the final stage has no scaffold', () {
      final w = buildTownWorld(
        TownState.initial(),
        site: ActiveSite(BuildingTier.hut, maxStage(BuildingTier.hut)),
      );
      final p = kPlots[1];
      expect(w.has(p.originX, p.originY, 1), isFalse);
      expect(w.get(p.originX + 1 + 1, p.originY + 1 + 1, 5), Blocks.roof);
    });
  });

  group('a chosen plot', () {
    test('the site is built on it and the sites differ by plot', () {
      final on3 = buildTownWorld(
        TownState.initial(),
        site: const ActiveSite(BuildingTier.hut, 4, plotIndex: 3),
      );
      final p = kPlots[3];
      expect(on3.get(p.originX + 2, p.originY + 2, 5), Blocks.roof);
      final auto = buildTownWorld(
        TownState.initial(),
        site: const ActiveSite(BuildingTier.hut, 4),
      );
      final q = kPlots[1];
      expect(auto.get(q.originX + 2, q.originY + 2, 5), Blocks.roof);
      expect(auto.get(p.originX + 2, p.originY + 2, 5), isNot(Blocks.roof));
    });

    test('equality and the site plot helper use the chosen plot', () {
      expect(
        const ActiveSite(BuildingTier.hut, 2, plotIndex: 3),
        isNot(const ActiveSite(BuildingTier.hut, 2, plotIndex: 4)),
      );
      expect(activeSitePlot(TownState.initial(), 3).index, 3);
      expect(activeSitePlot(TownState.initial()).index, 1);
    });
  });

  group('TownRenderer.setSite', () {
    test('setting the same site twice does not re-record', () {
      final r = _renderer();
      expect(r.recordCount, 1);
      r.setSite(const ActiveSite(BuildingTier.hut, 1));
      _paint(r);
      expect(r.recordCount, 2);
      r.setSite(const ActiveSite(BuildingTier.hut, 1));
      _paint(r);
      expect(r.recordCount, 2);
    });

    test('a new stage re-records once', () {
      final r = _renderer()..setSite(const ActiveSite(BuildingTier.hut, 1));
      _paint(r);
      final before = r.recordCount;
      r.setSite(const ActiveSite(BuildingTier.hut, 2));
      _paint(r);
      _paint(r);
      expect(r.recordCount, before + 1);
    });

    test(
      'walking a hut through stages 1 to 4 records 4 times after the first',
      () {
        final r = _renderer();
        for (var s = 1; s <= 4; s++) {
          r.setSite(ActiveSite(BuildingTier.hut, s));
          _paint(r);
          _paint(r);
        }
        expect(r.recordCount, 1 + 4);
      },
    );

    test('clearing the site records once', () {
      final r = _renderer()..setSite(const ActiveSite(BuildingTier.house, 4));
      _paint(r);
      final before = r.recordCount;
      r.setSite(null);
      _paint(r);
      r.setSite(null);
      _paint(r);
      expect(r.recordCount, before + 1);
    });

    test('a site set before any town is applied once the town arrives', () {
      final r = TownRenderer()
        ..setSite(const ActiveSite(BuildingTier.hut, 2))
        ..setTown(TownState.initial());
      _paint(r);
      expect(r.recordCount, 1);
      expect(r.visibleBlockCount, greaterThan(0));
    });
  });
}
