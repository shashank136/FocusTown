import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/app/focus_state.dart';
import 'package:focus_town/domain/building_tier.dart';
import 'package:focus_town/domain/session.dart';
import 'package:focus_town/domain/time_stamp.dart';
import 'package:focus_town/domain/town.dart';
import 'package:focus_town/game/town_game.dart';
import 'package:focus_town/game/workers/worker_model.dart';

Session _session(BuildingTier t, int assigned) => Session(
  id: 's',
  plannedMinutes: 10,
  tier: t,
  workersAssigned: assigned,
  state: SessionState.running,
  startedAt: TimeStamp(DateTime(2026), Duration.zero),
);

TownGame _game([FocusState? focus]) {
  final game = TownGame()
    ..onGameResize(Vector2(400, 700))
    ..setFocus(focus ?? FocusState(town: TownState.initial()));
  _tick(game); // the first frame always draws
  return game;
}

void _tick(TownGame g, {double dt = 1 / 60}) {
  g
    ..update(dt)
    ..render(ui.Canvas(ui.PictureRecorder()));
}

/// Fresh frames drawn over [seconds] of 60 Hz updates.
int _drawn(TownGame g, {int seconds = 1}) {
  final before = g.framesDrawn;
  for (var i = 0; i < 60 * seconds; i++) {
    _tick(g);
  }
  return g.framesDrawn - before;
}

void main() {
  group('frame cap', () {
    test('normal mode draws about 15 frames per second', () {
      expect(_drawn(_game()), inInclusiveRange(14, 16));
    });

    test('low power draws about 10', () {
      final g = _game()..lowPower = true;
      expect(_drawn(g), inInclusiveRange(9, 11));
      g.lowPower = false;
      expect(_drawn(g), inInclusiveRange(14, 16));
    });

    test('paused draws nothing and resuming draws again', () {
      final g = _game()..inBackground = true;
      expect(_drawn(g), 0);
      g.inBackground = false;
      expect(_drawn(g), inInclusiveRange(14, 16));
    });
  });

  group('workers', () {
    test('three spare walkers with no session', () {
      final g = _game();
      expect(g.renderer.workers, hasLength(3));
    });

    test('the assigned count follows the session, the rest walk', () {
      final town = TownState.initial().copyWith(workers: 5);
      final g = _game(
        FocusState(town: town, active: _session(BuildingTier.house, 2)),
      );
      // 2 on the site, 3 spare walkers
      expect(g.renderer.workers, hasLength(5));
      final hammering = g.renderer.workers.where(
        (w) => w.pose == Pose.hammerUp || w.pose == Pose.hammerDown,
      );
      expect(hammering, hasLength(2));
    });

    test('in recovery the Last Builder works the site alone', () {
      final town = TownState.initial().copyWith(
        workers: 0,
        inRecoveryMode: true,
      );
      final g = _game(
        FocusState(town: town, active: _session(BuildingTier.hut, 0)),
      );
      expect(g.renderer.workers, hasLength(1));
    });

    test('workers move between frames', () {
      final g = _game();
      final a = g.renderer.workers
          .map((w) => (w.worker.x, w.worker.y))
          .toList();
      _drawn(g);
      final b = g.renderer.workers
          .map((w) => (w.worker.x, w.worker.y))
          .toList();
      expect(b, isNot(a));
    });

    test('reduced motion: idle and standing still', () {
      final g = _game()..reducedMotion = true;
      _drawn(g);
      final a = g.renderer.workers
          .map((w) => (w.worker.x, w.worker.y))
          .toList();
      _drawn(g, seconds: 2);
      final b = g.renderer.workers
          .map((w) => (w.worker.x, w.worker.y))
          .toList();
      expect(b, a);
      expect(g.renderer.workers.every((w) => w.pose == Pose.idle), isTrue);
    });
  });

  group('fps readout', () {
    test('counts the frames drawn each second', () {
      final fps = ValueNotifier<double>(0);
      final g = TownGame(fps: fps)
        ..onGameResize(Vector2(400, 700))
        ..setFocus(FocusState(town: TownState.initial()));
      _drawn(g, seconds: 3);
      expect(fps.value, inInclusiveRange(13, 16));
    });
  });

  group('setFocus', () {
    test('an unchanged town and no session never re-records', () {
      final g = _game();
      final records = g.renderer.recordCount;
      g.setFocus(FocusState(town: TownState.initial()));
      _drawn(g, seconds: 2);
      expect(g.renderer.recordCount, records);
    });

    test('a session adds the site once, then frames re-record nothing', () {
      final g = _game();
      final records = g.renderer.recordCount;
      g.setFocus(
        FocusState(
          town: TownState.initial(),
          active: _session(BuildingTier.hut, 1),
        ),
      );
      _drawn(g);
      expect(g.renderer.recordCount, records + 1);
      _drawn(g, seconds: 2);
      expect(g.renderer.recordCount, records + 1);
    });
  });
}
