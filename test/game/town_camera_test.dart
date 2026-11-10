import 'dart:math' as math;
import 'dart:ui' show Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/game/camera/town_camera.dart';
import 'package:focus_town/game/world/iso.dart';
import 'package:focus_town/game/world/plot_layout.dart';
import 'package:focus_town/game/world/vec2.dart';

const _view = Vec2(400, 700);

TownCamera _camera() => TownCamera(_view);

void main() {
  group('fitToMap', () {
    test('the whole map fits inside the view', () {
      final c = _camera();
      for (final (x, y) in [(0, 0), (64, 0), (0, 64), (64, 64)]) {
        final p = project(x.toDouble(), y.toDouble(), 0, c.tile, c.origin);
        expect(p.x, inInclusiveRange(0, _view.x));
        expect(p.y, inInclusiveRange(0, _view.y));
      }
    });

    test('tile is the documented fit and minTile is 70% of it', () {
      final c = _camera();
      expect(c.fitMapTile, closeTo(400 / 134, 1e-9));
      expect(c.tile, c.fitMapTile);
      expect(c.minTile, closeTo(c.fitMapTile * 0.7, 1e-12));
    });
  });

  group('zoomAt', () {
    test('keeps the world point under the focal point fixed', () {
      final c = _camera();
      const focal = Vec2(150, 420);
      final before = unprojectGround(focal.x, focal.y, c.tile, c.origin);
      c.zoomAt(focal, 1.6);
      expect(c.tile, closeTo(c.fitMapTile * 1.6, 1e-9));
      final after = unprojectGround(focal.x, focal.y, c.tile, c.origin);
      expect(after.x, closeTo(before.x, 1e-6));
      expect(after.y, closeTo(before.y, 1e-6));
    });

    test('zoom out stops at minTile', () {
      final c = _camera();
      for (var i = 0; i < 20; i++) {
        c.zoomAt(const Vec2(200, 350), 0.5);
      }
      expect(c.tile, c.minTile);
    });

    test('zoom in stops at 64', () {
      final c = _camera();
      for (var i = 0; i < 20; i++) {
        c.zoomAt(const Vec2(200, 350), 2);
      }
      expect(c.tile, kMaxTile);
      expect(kMaxTile, 64);
    });
  });

  group('panBy', () {
    test('moves the origin by the delta', () {
      final c = _camera();
      final o = c.origin;
      c.panBy(const Vec2(10, -6));
      expect(c.origin, Vec2(o.x + 10, o.y - 6));
    });

    test('huge pans in every direction keep 30% of the map on screen', () {
      for (final d in const [
        Vec2(1000000, 0),
        Vec2(-1000000, 0),
        Vec2(0, 1000000),
        Vec2(0, -1000000),
      ]) {
        for (final zoom in [1.0, 4.0]) {
          final c = _camera()
            ..zoomAt(const Vec2(200, 350), zoom)
            ..panBy(d);
          final n = kMapSize.toDouble();
          final mapW = 2 * n * c.tile;
          final mapH = n * c.tile;
          final overlapX =
              (c.origin.x + mapW / 2).clamp(0, _view.x) -
              (c.origin.x - mapW / 2).clamp(0, _view.x);
          final overlapY =
              (c.origin.y + mapH).clamp(0, _view.y) -
              c.origin.y.clamp(0, _view.y);
          // At high zoom the view is smaller than 30% of the map box.
          expect(
            overlapX,
            greaterThanOrEqualTo(math.min(0.3 * mapW, _view.x) - 1e-6),
            reason: '$d',
          );
          expect(
            overlapY,
            greaterThanOrEqualTo(math.min(0.3 * mapH, _view.y) - 1e-6),
            reason: '$d',
          );
        }
      }
    });
  });

  group('focusOn', () {
    test('puts the projected point at the view center', () {
      final c = _camera()
        ..zoomAt(const Vec2(200, 350), 3)
        ..focusOn(const Vec2(40, 24));
      final p = project(40, 24, 0, c.tile, c.origin);
      expect(p.x, closeTo(_view.x / 2, 1e-6));
      expect(p.y, closeTo(_view.y / 2, 1e-6));
    });
  });

  group('fitToRegion', () {
    test('plots 0 to 5 all fit and the tile is larger than the map fit', () {
      final c = _camera();
      final plots = kPlots.take(6).toList();
      final region = Rect.fromLTRB(
        plots.map((p) => p.originX).reduce((a, b) => a < b ? a : b) - 4.0,
        plots.map((p) => p.originY).reduce((a, b) => a < b ? a : b) - 4.0,
        plots.map((p) => p.originX + 7).reduce((a, b) => a > b ? a : b) + 4.0,
        plots.map((p) => p.originY + 7).reduce((a, b) => a > b ? a : b) + 4.0,
      );
      c.fitToRegion(region);
      expect(c.tile, greaterThan(c.fitMapTile));
      for (final p in plots) {
        for (final (dx, dy) in [(0, 0), (7, 0), (0, 7), (7, 7)]) {
          final s = project(
            (p.originX + dx).toDouble(),
            (p.originY + dy).toDouble(),
            0,
            c.tile,
            c.origin,
          );
          expect(s.x, inInclusiveRange(0, _view.x), reason: 'plot ${p.index}');
          expect(s.y, inInclusiveRange(0, _view.y), reason: 'plot ${p.index}');
        }
      }
    });

    test('a huge region falls back to a clamped tile', () {
      final c = _camera()
        ..fitToRegion(const Rect.fromLTRB(-500, -500, 500, 500));
      expect(c.tile, c.minTile);
    });
  });

  group('pose', () {
    test('centerWorld is the ground point at the view center', () {
      final c = _camera()..focusOn(const Vec2(20, 30));
      expect(c.centerWorld.x, closeTo(20, 1e-6));
      expect(c.centerWorld.y, closeTo(30, 1e-6));
    });

    test('setPose centers a point at a tile size', () {
      final c = _camera()..setPose(const Vec2(25, 25), 12);
      expect(c.tile, 12);
      expect(c.centerWorld.x, closeTo(25, 1e-6));
      expect(c.centerWorld.y, closeTo(25, 1e-6));
    });

    test('setPose clamps the tile', () {
      final c = _camera()..setPose(const Vec2(25, 25), 1000);
      expect(c.tile, kMaxTile);
    });
  });

  group('resize', () {
    test('re-clamps the origin and the tile to the new view', () {
      final c = _camera()
        ..panBy(const Vec2(1000000, 0))
        ..resize(const Vec2(200, 300));
      final maxX = 200 + 0.4 * kMapSize * c.tile;
      expect(c.origin.x, lessThanOrEqualTo(maxX + 1e-9));
      expect(c.tile, greaterThanOrEqualTo(c.minTile));
    });
  });
}
