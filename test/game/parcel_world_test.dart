import 'dart:ui' show Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/domain/building_tier.dart';
import 'package:focus_town/domain/parcel.dart';
import 'package:focus_town/domain/town.dart';
import 'package:focus_town/game/camera/town_camera.dart';
import 'package:focus_town/game/world/block_material.dart';
import 'package:focus_town/game/world/iso.dart';
import 'package:focus_town/game/world/plot_layout.dart';
import 'package:focus_town/game/world/town_world_builder.dart';
import 'package:focus_town/game/world/vec2.dart';
import 'package:focus_town/game/world/voxel_world.dart';

const _west = Parcel(-1, 3); // plot 64: tiles x -4..2, y 24..30

TownState _town({
  List<Parcel> parcels = const [_west],
  List<TownBuilding> buildings = const [],
}) => TownState(
  workers: 3,
  plotsUnlocked: 6,
  buildings: buildings,
  queue: const [],
  inRecoveryMode: false,
  parcels: parcels,
);

int _above(VoxelWorld w, Plot p) => w.blocks
    .where(
      (b) =>
          b.z >= 1 &&
          b.x >= p.originX &&
          b.x < p.originX + 7 &&
          b.y >= p.originY &&
          b.y < p.originY + 7,
    )
    .length;

void main() {
  test('a claimed parcel is land: grass on dirt, outside the old map', () {
    final w = buildTownWorld(_town());
    for (var x = -4; x <= 2; x++) {
      for (var y = 24; y <= 30; y++) {
        expect(w.get(x, y, 0), isNotNull, reason: '($x,$y)');
        expect(w.get(x, y, -1), Blocks.dirt, reason: '($x,$y)');
      }
    }
  });

  test('without parcels nothing exists outside the old map', () {
    final w = buildTownWorld(_town(parcels: const []));
    expect(w.blocks.every((b) => b.x >= 0 && b.y >= 0), isTrue);
  });

  test('a claimed parcel starts as forest', () {
    final w = buildTownWorld(_town());
    expect(_above(w, plotFor(64, const [_west])), greaterThan(0));
  });

  test('a building on a claimed parcel clears its trees and stands there', () {
    final empty = buildTownWorld(_town());
    final built = buildTownWorld(
      _town(
        buildings: const [
          TownBuilding(
            id: 'x',
            tier: BuildingTier.hut,
            status: BuildingStatus.complete,
            plotIndex: 64,
          ),
        ],
      ),
    );
    final plot = plotFor(64, const [_west]);
    expect(_above(built, plot), isNot(_above(empty, plot)));
    expect(built.has(plot.originX + 1, plot.originY + 1, 1), isTrue);
  });

  test('a chosen claimed plot is the build site', () {
    expect(activeSitePlot(_town(), 64).index, 64);
    expect(activeSitePlot(_town(), 64).originX, -4);
  });

  test('a tap finds a claimed parcel', () {
    expect(plotAtWith(const [_west], -1, 25)?.index, 64);
    expect(plotAtWith(const [_west], -9, 25), isNull);
    expect(plotAtWith(const [], -1, 25), isNull);
    expect(
      plotAtWith(const [_west], 10, 10)?.index,
      kPlots.indexOf(plotAt(10, 10)!),
    );
  });

  test('the camera can pan and zoom out over claimed land', () {
    const box = Rect.fromLTRB(-4, 0, 64, 64);
    final base = TownCamera(const Vec2(400, 700));
    final wide = TownCamera(const Vec2(400, 700), box: box);
    expect(wide.minTile, lessThan(base.minTile));
    // Tile (-4, 30), on the new land, can be brought to the screen centre.
    wide.focusOn(const Vec2(-2, 27));
    final at = project(-2, 27, 0, wide.tile, wide.origin);
    expect(at.x, closeTo(200, 1));
  });
}
