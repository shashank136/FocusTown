import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/app/focus_state.dart';
import 'package:focus_town/domain/district.dart';
import 'package:focus_town/domain/session_engine.dart';
import 'package:focus_town/domain/testing/fake_clock.dart';
import 'package:focus_town/domain/time_stamp.dart';
import 'package:focus_town/domain/town.dart';
import 'package:focus_town/game/town_game.dart';
import 'package:focus_town/game/world/plot_layout.dart';
import 'package:focus_town/game/world/vec2.dart';

final TownState _town = TownState.initial().copyWith(workers: 10);

void _frames(TownGame g, [int n = 12]) {
  for (var i = 0; i < n; i++) {
    g
      ..update(0.1)
      ..render(ui.Canvas(ui.PictureRecorder()));
  }
}

({TownGame game, FocusState running}) _rig(FakeClock clock) {
  final session = SessionEngine.start(
    id: 's',
    minutes: 25,
    workersAvailable: 10,
    now: TimeStamp.now(clock),
  );
  final game = TownGame(clock: clock)
    ..onGameResize(Vector2(400, 700))
    ..setFocus(FocusState(town: _town));
  _frames(game);
  return (game: game, running: FocusState(town: _town, active: session));
}

void main() {
  test('the camera zooms back out when a session ends', () {
    final clock = FakeClock();
    final r = _rig(clock);
    final before = r.game.renderer.camera!.pose;
    r.game
      ..setFocus(r.running)
      ..focusOnSite(kPlots[3]);
    _frames(r.game);
    // Zoomed in on the building site.
    expect(r.game.renderer.camera!.tile, greaterThanOrEqualTo(14));
    r.game.setFocus(FocusState(town: _town));
    _frames(r.game);
    final after = r.game.renderer.camera!.pose;
    expect(after.tile, closeTo(before.tile, 0.01));
    expect(after.center.x, closeTo(before.center.x, 0.5));
    expect(after.center.y, closeTo(before.center.y, 0.5));
  });

  test('closing the district preview without starting brings it back', () {
    final r = _rig(FakeClock());
    final before = r.game.renderer.camera!.pose;
    r.game.setRowHighlight(districtRow(DistrictSide.east, 0, 0));
    _frames(r.game);
    expect(
      r.game.renderer.camera!.pose.tile,
      isNot(closeTo(before.tile, 0.01)),
    );
    r.game.setRowHighlight(const []);
    _frames(r.game);
    final after = r.game.renderer.camera!.pose;
    expect(after.tile, closeTo(before.tile, 0.01));
    expect(after.center.x, closeTo(before.center.x, 0.5));
  });

  test('starting from the preview keeps the camera on the site', () {
    final r = _rig(FakeClock());
    r.game.setRowHighlight(districtRow(DistrictSide.east, 0, 0));
    _frames(r.game);
    // The sheet closes (the preview clears) as the session starts.
    r.game
      ..setFocus(r.running)
      ..setRowHighlight(const [])
      ..focusOnSite(kPlots[3]);
    _frames(r.game);
    expect(r.game.renderer.camera!.tile, greaterThanOrEqualTo(14));
  });

  test('if you moved the camera yourself it stays where you put it', () {
    final r = _rig(FakeClock());
    r.game
      ..setFocus(r.running)
      ..focusOnSite(kPlots[3]);
    _frames(r.game);
    // You pinch out during the session, then it ends.
    r.game.onPinch(const Vec2(200, 350), 0.5);
    final yours = r.game.renderer.camera!.pose;
    r.game.setFocus(FocusState(town: _town));
    _frames(r.game);
    final after = r.game.renderer.camera!.pose;
    expect(after.tile, closeTo(yours.tile, 0.01));
    expect(after.center.x, closeTo(yours.center.x, 0.5));
  });
}
