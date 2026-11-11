import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/domain/town.dart';
import 'package:focus_town/game/town_game.dart';
import 'package:focus_town/game/world/iso.dart';
import 'package:focus_town/game/world/plot_layout.dart';
import 'package:focus_town/game/world/vec2.dart';

TownGame _game() {
  final game = TownGame()
    ..onGameResize(Vector2(400, 700))
    ..setTown(TownState.initial());
  _frame(game);
  return game;
}

void _frame(TownGame game) => game.render(ui.Canvas(ui.PictureRecorder()));

void main() {
  test(
    'the first layout fits the unlocked plots, closer than the whole map',
    () {
      final game = _game();
      final cam = game.renderer.camera!;
      expect(cam.tile, greaterThan(cam.fitMapTile));
      expect(game.renderer.recordCount, 1);
    },
  );

  test('onPan moves the origin by the delta', () {
    final game = _game();
    final cam = game.renderer.camera!;
    final before = cam.origin;
    game.onPan(const Vec2(12, -7));
    expect(cam.origin, Vec2(before.x + 12, before.y - 7));
  });

  test('onPinch with factor 1.2 raises the tile by 20%', () {
    final game = _game();
    final cam = game.renderer.camera!;
    final before = cam.tile;
    game.onPinch(const Vec2(200, 350), 1.2);
    expect(cam.tile, closeTo(before * 1.2, 1e-9));
  });

  test('onWheel up zooms in and down zooms out', () {
    final game = _game();
    final cam = game.renderer.camera!;
    final start = cam.tile;
    game.onWheel(const Vec2(200, 350), -100);
    expect(cam.tile, greaterThan(start));
    final zoomedIn = cam.tile;
    game.onWheel(const Vec2(200, 350), 100);
    expect(cam.tile, lessThan(zoomedIn));
  });

  test('onDoubleTapAt zooms 1.5x and keeps the tapped point fixed', () {
    final game = _game();
    final cam = game.renderer.camera!;
    const tap = Vec2(130, 300);
    final start = cam.tile;
    final before = unprojectGround(tap.x, tap.y, cam.tile, cam.origin);
    game.onDoubleTapAt(tap);
    expect(cam.tile, closeTo(start * 1.5, 1e-9));
    final after = unprojectGround(tap.x, tap.y, cam.tile, cam.origin);
    expect(after.x, closeTo(before.x, 1e-6));
    expect(after.y, closeTo(before.y, 1e-6));
  });

  test('a 10% pan only translates, a zoom re-records the static layer', () {
    final game = _game();
    expect(game.renderer.recordCount, 1);
    game.onPan(const Vec2(40, 0)); // 10% of the 400 px width
    _frame(game);
    expect(game.renderer.recordCount, 1);
    game.onPinch(const Vec2(200, 350), 1.3);
    _frame(game);
    expect(game.renderer.recordCount, 2);
  });

  test('gestures before the first frame do nothing and do not throw', () {
    final game = TownGame();
    expect(() => game.onPan(const Vec2(1, 1)), returnsNormally);
    expect(() => game.onPinch(const Vec2(1, 1), 2), returnsNormally);
    expect(() => game.onWheel(const Vec2(1, 1), 5), returnsNormally);
    expect(() => game.onDoubleTapAt(const Vec2(1, 1)), returnsNormally);
  });

  group('focus and recenter', () {
    test('focusOnSite glides to the plot center at tile >= 14', () {
      final game = _game();
      final cam = game.renderer.camera!;
      final plot = kPlots[3];
      game
        ..focusOnSite(plot)
        ..update(0.5); // longer than the 400 ms glide
      expect(cam.centerWorld.x, closeTo(plot.center.x, 1e-6));
      expect(cam.centerWorld.y, closeTo(plot.center.y, 1e-6));
      expect(cam.tile, greaterThanOrEqualTo(14));
    });

    test('the glide moves a little each frame', () {
      final game = _game();
      final cam = game.renderer.camera!;
      final start = cam.centerWorld;
      game
        ..focusOnSite(kPlots[5])
        ..update(0.05);
      final mid = cam.centerWorld;
      expect(mid, isNot(start));
      game.update(0.05);
      expect(cam.centerWorld, isNot(mid));
    });

    test('a user pan cancels the glide', () {
      final game = _game();
      final cam = game.renderer.camera!;
      game
        ..focusOnSite(kPlots[5])
        ..update(0.05)
        ..onPan(const Vec2(1, 0));
      final after = cam.origin;
      game.update(0.3);
      expect(cam.origin, after);
    });

    test('recenter glides back to the unlocked plots', () {
      final game = _game();
      final cam = game.renderer.camera!;
      final fitted = cam.tile;
      game.onPinch(const Vec2(200, 350), 3);
      expect(cam.tile, greaterThan(fitted));
      game
        ..recenter()
        ..update(0.5);
      expect(cam.tile, closeTo(fitted, 1e-6));
    });

    test(
      'focusOnSite before the first frame starts once the camera exists',
      () {
        final game = TownGame()
          ..onGameResize(Vector2(400, 700))
          ..setTown(TownState.initial())
          ..focusOnSite(kPlots[2]);
        _frame(game); // creates the camera
        game.update(0.5);
        expect(
          game.renderer.camera!.centerWorld.x,
          closeTo(kPlots[2].center.x, 1e-6),
        );
      },
    );
  });

  group('reduced motion', () {
    test('the camera jumps to its target in a single frame', () {
      final game = _game()
        ..reducedMotion = true
        ..onPan(const Vec2(300, 300));
      final cam = game.renderer.camera!;
      final home = cam.origin;
      game
        ..recenter()
        ..update(1 / 60);
      expect(cam.origin.x, isNot(home.x + 300));
      game.update(1 / 60);
      final settled = cam.origin;
      game.update(1 / 60);
      expect(cam.origin, settled);
      expect(settled.x, isNot(home.x));
    });

    test('a normal camera is still gliding after one frame', () {
      final game = _game()..onPan(const Vec2(300, 300));
      final cam = game.renderer.camera!;
      game
        ..recenter()
        ..update(1 / 60);
      final first = cam.origin;
      game.update(1 / 60);
      expect(cam.origin, isNot(first));
    });
  });
}
