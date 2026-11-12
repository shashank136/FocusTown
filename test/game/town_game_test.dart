import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/app/focus_state.dart';
import 'package:focus_town/domain/building_tier.dart';
import 'package:focus_town/domain/parcel.dart';
import 'package:focus_town/domain/session.dart';
import 'package:focus_town/domain/time_stamp.dart';
import 'package:focus_town/domain/town.dart';
import 'package:focus_town/game/town_game.dart';
import 'package:focus_town/game/workers/worker_model.dart';
import 'package:focus_town/game/world/plot_layout.dart';
import 'package:focus_town/game/world/vec2.dart';

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

    test('a repair puts one worker at the ruin and builds nothing', () {
      final town = TownState.initial().copyWith(
        workers: 3,
        buildings: [
          const TownBuilding(
            id: 'a',
            tier: BuildingTier.house,
            status: BuildingStatus.complete,
            plotIndex: 0,
          ),
          const TownBuilding(
            id: 'r',
            tier: BuildingTier.house,
            status: BuildingStatus.ruin,
            plotIndex: 2,
          ),
        ],
      );
      final repair = Session(
        id: 'r1',
        plannedMinutes: 10,
        tier: BuildingTier.hut,
        workersAssigned: 0,
        state: SessionState.running,
        startedAt: TimeStamp(DateTime(2026), Duration.zero),
        repairPlot: 2,
      );
      final g = _game(FocusState(town: town, active: repair));
      expect(g.renderer.site, isNull);
      // One repairer and three spare walkers.
      expect(g.renderer.workers, hasLength(4));
      final plot = kPlots[2];
      final near = g.renderer.workers.where(
        (w) =>
            (w.worker.x - plot.center.x).abs() < 4 &&
            (w.worker.y - plot.center.y).abs() < 4,
      );
      expect(near, isNotEmpty);
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

  group('fps while covered', () {
    test('the readout keeps its last value while nothing is painted', () {
      final fps = ValueNotifier<double>(0);
      final g = TownGame(fps: fps)
        ..onGameResize(Vector2(400, 700))
        ..setFocus(FocusState(town: TownState.initial()));
      // Paint until a fresh reading arrives, so a new window starts right
      // after it.
      var changed = false;
      fps.addListener(() => changed = true);
      while (!changed) {
        _tick(g);
      }
      final shown = fps.value;
      expect(shown, greaterThan(5));
      // A page covers the town: updates go on, nothing is painted.
      for (var i = 0; i < 60 * 4; i++) {
        g.update(1 / 60);
      }
      expect(fps.value, shown);
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

  group('fps publishing', () {
    test('never changes the notifier while painting', () {
      // A listener that rebuilds widgets would assert "build during paint".
      var painting = false;
      var duringPaint = 0;
      final fps = ValueNotifier<double>(0)
        ..addListener(() {
          if (painting) duringPaint++;
        });
      final g = TownGame(fps: fps)
        ..onGameResize(Vector2(400, 700))
        ..setFocus(FocusState(town: TownState.initial()));
      for (var i = 0; i < 40; i++) {
        g.update(0.1);
        painting = true;
        g.render(ui.Canvas(ui.PictureRecorder()));
        painting = false;
      }
      expect(fps.value, greaterThan(0));
      expect(duringPaint, 0);
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

    test('finished land shows the whole island so the new land is seen', () {
      final g = _game();
      final cam = g.renderer.camera!;
      g.onPinch(const Vec2(200, 350), 3); // zoomed in on the town
      final zoomed = cam.tile;
      final session = Session(
        id: 'l',
        plannedMinutes: 25,
        tier: BuildingTier.hut,
        workersAssigned: 0,
        state: SessionState.running,
        startedAt: TimeStamp(DateTime(2026), Duration.zero),
        land: const Parcel(-1, 3),
      );
      g.setFocus(FocusState(town: TownState.initial(), active: session));
      _drawn(g);
      g
        ..setFocus(
          FocusState(
            town: TownState.initial().copyWith(parcels: const [Parcel(-1, 3)]),
            lastResult: const SessionResult(
              outcome: SessionOutcome.completed,
              tier: BuildingTier.hut,
              workersLost: 0,
              workersGained: 0,
              newStreak: 1,
              plotGranted: false,
              land: true,
            ),
          ),
        )
        ..update(1);
      expect(cam.tile, lessThan(zoomed));
      expect(cam.tile, closeTo(cam.fitMapTile, 1e-6));
    });

    test('claimed land redraws the town', () {
      final g = _game();
      final records = g.renderer.recordCount;
      g.setFocus(
        FocusState(
          town: TownState.initial().copyWith(parcels: const [Parcel(-1, 3)]),
        ),
      );
      _drawn(g);
      expect(g.renderer.recordCount, records + 1);
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
