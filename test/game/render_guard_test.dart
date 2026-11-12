import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/app/focus_state.dart';
import 'package:focus_town/domain/building_tier.dart';
import 'package:focus_town/domain/session.dart';
import 'package:focus_town/domain/testing/fake_clock.dart';
import 'package:focus_town/domain/time_stamp.dart';
import 'package:focus_town/domain/town.dart';
import 'package:focus_town/game/render_guard.dart';
import 'package:focus_town/game/town_game.dart';
import 'package:focus_town/game/town_renderer.dart';
import 'package:focus_town/platform/local_log.dart';

class _Exploding extends TownRenderer {
  bool explode = false;

  @override
  void paint(ui.Canvas canvas, ui.Size size) {
    if (explode) throw StateError('paint failed');
    super.paint(canvas, size);
  }
}

void _sample(RenderGuard g, double fps, int seconds, {int from = 0}) {
  for (var s = from + 1; s <= from + seconds; s++) {
    g.recordFps(fps, Duration(seconds: s));
  }
}

void main() {
  late LocalLog log;
  late RenderGuard guard;

  setUp(() {
    log = LocalLog(null, FakeClock());
    guard = RenderGuard(log);
  });

  group('frame rate', () {
    test('4 slow seconds are not enough, the fifth degrades', () {
      _sample(guard, 3, 4);
      expect(guard.degraded, isFalse);
      _sample(guard, 3, 1, from: 4);
      expect(guard.degraded, isTrue);
      expect(log.lines.single, contains('render degraded'));
    });

    test('a good second inside the window starts the count again', () {
      _sample(guard, 3, 4);
      _sample(guard, 20, 1, from: 4);
      _sample(guard, 3, 4, from: 5);
      expect(guard.degraded, isFalse);
    });

    test('healthy rates never degrade', () {
      _sample(guard, 15, 60);
      expect(guard.degraded, isFalse);
    });
  });

  test('an error degrades at once and logs once', () {
    guard
      ..recordError(StateError('x'))
      ..recordError(StateError('y'));
    expect(guard.degraded, isTrue);
    expect(log.lines, hasLength(1));
  });

  group('in the game', () {
    Session session() => Session(
      id: 's',
      plannedMinutes: 10,
      tier: BuildingTier.hut,
      workersAssigned: 1,
      state: SessionState.running,
      startedAt: TimeStamp(DateTime(2026), Duration.zero),
    );

    TownGame game(_Exploding r) => TownGame(renderer: r, guard: guard)
      ..onGameResize(Vector2(400, 700))
      ..setFocus(FocusState(town: TownState.initial(), active: session()));

    void tick(TownGame g) => g
      ..update(1 / 60)
      ..render(ui.Canvas(ui.PictureRecorder()));

    test('a paint error degrades and the game still renders', () {
      final r = _Exploding();
      final g = game(r);
      tick(g);
      r.explode = true;
      for (var i = 0; i < 30; i++) {
        tick(g);
      }
      expect(guard.degraded, isTrue);
    });

    test('a game nobody paints (a page on top of it) never degrades', () {
      final r = _Exploding();
      final g = game(r);
      tick(g);
      // Updates go on while a full-screen page hides the town: no render().
      for (var i = 0; i < 60 * 12; i++) {
        g.update(1 / 60);
      }
      expect(guard.degraded, isFalse);
    });

    test('a degraded game stops moving workers', () {
      final r = _Exploding();
      final g = game(r);
      for (var i = 0; i < 30; i++) {
        tick(g);
      }
      final before = r.workers;
      guard.recordError('forced');
      for (var i = 0; i < 60; i++) {
        tick(g);
      }
      expect(identical(r.workers, before), isTrue);
    });

    test('a degraded game stops drawing fresh frames', () {
      final r = _Exploding();
      final g = game(r);
      tick(g);
      guard.recordError('forced');
      final drawn = g.framesDrawn;
      for (var i = 0; i < 60; i++) {
        tick(g);
      }
      expect(g.framesDrawn, drawn);
    });
  });
}
