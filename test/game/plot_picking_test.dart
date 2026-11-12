import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/app/focus_state.dart';
import 'package:focus_town/domain/town.dart';
import 'package:focus_town/game/town_game.dart';
import 'package:focus_town/game/world/iso.dart';
import 'package:focus_town/game/world/plot_layout.dart';
import 'package:focus_town/game/world/vec2.dart';

TownGame _game() => TownGame()
  ..onGameResize(Vector2(400, 700))
  ..setFocus(FocusState(town: TownState.initial()))
  ..update(0.1)
  ..render(ui.Canvas(ui.PictureRecorder()));

// Screen point of the middle of plot [i]'s ground (its top face is at z = 1).
Vec2 _center(TownGame g, int i) {
  final cam = g.renderer.camera!;
  final c = kPlots[i].center;
  return project(c.x, c.y, 1, cam.tile, cam.origin);
}

void main() {
  test('the middle of each unlocked plot picks that plot', () {
    final g = _game();
    for (var i = 0; i < 6; i++) {
      expect(g.plotAtScreen(_center(g, i)), i);
    }
  });

  test('a road or open land picks nothing', () {
    final g = _game();
    final cam = g.renderer.camera!;
    final road = project(31.5, 31.5, 1, cam.tile, cam.origin);
    expect(g.plotAtScreen(road), isNull);
    expect(g.plotAtScreen(const Vec2(-500, -500)), isNull);
  });

  test('picking follows the camera after a pan', () {
    final g = _game();
    final before = _center(g, 2);
    g.onPan(const Vec2(37, -21));
    final after = _center(g, 2);
    expect(after, isNot(before));
    expect(g.plotAtScreen(after), 2);
  });

  test('plot outlines change the picture and never re-record the town', () {
    final g = _game();
    final records = g.renderer.recordCount;
    g
      ..setPlacement({1, 2, 3}, 2)
      ..update(0.1)
      ..render(ui.Canvas(ui.PictureRecorder()));
    expect(g.renderer.recordCount, records);
    expect(g.renderer.plotOutlines, {1, 2, 3});
    expect(g.renderer.selectedPlot, 2);
    g
      ..setPlacement(const {}, null)
      ..update(0.1);
    expect(g.renderer.plotOutlines, isEmpty);
  });

  test('a castle selection is drawn over its whole 2 x 2 block', () {
    final g = _game()
      ..setPlacement({1, 2}, 2, span: 2)
      ..update(0.1)
      ..render(ui.Canvas(ui.PictureRecorder()));
    expect(g.renderer.selectedSpan, 2);
    g
      ..setPlacement({1, 2}, 2)
      ..update(0.1);
    expect(g.renderer.selectedSpan, 1);
  });
}
