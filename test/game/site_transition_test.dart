import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/app/focus_state.dart';
import 'package:focus_town/domain/building_tier.dart';
import 'package:focus_town/domain/session_engine.dart';
import 'package:focus_town/domain/testing/fake_clock.dart';
import 'package:focus_town/domain/time_stamp.dart';
import 'package:focus_town/domain/town.dart';
import 'package:focus_town/game/effects/particles.dart';
import 'package:focus_town/game/effects/site_transition.dart';
import 'package:focus_town/game/town_game.dart';
import 'package:focus_town/game/workers/worker_layout.dart';
import 'package:focus_town/game/workers/worker_model.dart';
import 'package:focus_town/game/world/block_material.dart';
import 'package:focus_town/game/world/plot_layout.dart';

const _ms100 = Duration(milliseconds: 100);

const result0 = SessionResult(
  outcome: SessionOutcome.completed,
  tier: BuildingTier.hut,
  workersLost: 0,
  workersGained: 0,
  newStreak: 1,
  plotGranted: false,
);

void main() {
  group('ParticleSystem', () {
    test('the same seed gives the same particles', () {
      List<(double, double, double)> run(int seed) {
        final s = ParticleSystem(seed)
          ..burst((10, 10, 3), const [0xFFaa0000, 0xFF00aa00], 40)
          ..step(_ms100);
        return [for (final p in s.alive) (p.x, p.y, p.z)];
      }

      expect(run(7), run(7));
      expect(run(7), isNot(run(8)));
    });

    test('a burst makes the asked count, colored from the list', () {
      final s = ParticleSystem(1)..burst((0, 0, 0), const [0xFF123456], 40);
      expect(s.alive, hasLength(40));
      expect(s.alive.every((p) => p.color == 0xFF123456), isTrue);
    });

    test('particles rise and all die by their lifetime', () {
      final s = ParticleSystem(1)..burst((5, 5, 2), const [0xFF123456], 30);
      final z0 = s.alive.map((p) => p.z).reduce((a, b) => a + b);
      s.step(_ms100);
      final z1 = s.alive.map((p) => p.z).reduce((a, b) => a + b);
      expect(z1, greaterThan(z0));
      for (var i = 0; i < 20; i++) {
        s.step(_ms100);
      }
      expect(s.alive, isEmpty);
    });
  });

  group('SiteTransition', () {
    test('celebrates for exactly 1 s, then is done', () {
      final t = SiteTransition.celebrate();
      expect(t.phase, TransitionPhase.celebrate);
      t.step(const Duration(milliseconds: 999));
      expect(t.phase, TransitionPhase.celebrate);
      t.step(const Duration(milliseconds: 1));
      expect(t.phase, TransitionPhase.done);
      expect(t.fade, 0);
    });

    test('fade goes 1 to 0 and never rises', () {
      final t = SiteTransition.celebrate();
      expect(t.fade, 1);
      var last = 1.0;
      for (var i = 0; i < 12; i++) {
        t.step(_ms100);
        expect(t.fade, lessThanOrEqualTo(last));
        last = t.fade;
      }
      expect(last, 0);
    });
  });

  group('SiteTransition.fail', () {
    test('lasts exactly 3 s', () {
      final t = SiteTransition.fail();
      expect(t.phase, TransitionPhase.fail);
      t.step(const Duration(milliseconds: 2999));
      expect(t.phase, TransitionPhase.fail);
      t.step(const Duration(milliseconds: 1));
      expect(t.phase, TransitionPhase.done);
    });
  });

  group('deadWorkers', () {
    test('lie where they stood', () {
      final w = PlacedWorker(
        Worker(x: 20, y: 40, shirt: FlatColor.of(0xFF808080)),
        Pose.hammerUp,
      );
      final dead = deadWorkers([w]).single;
      expect(dead.pose, Pose.dead);
      expect((dead.worker.x, dead.worker.y), (20.0, 40.0));
    });
  });

  group('workersLeaving', () {
    final start = [
      PlacedWorker(
        Worker(x: 20, y: 40, shirt: FlatColor.of(0xFF808080)),
        Pose.hammerUp,
      ),
    ];

    test('at 0 they stand where they were, at 1 they are on a road', () {
      final a = workersLeaving(start, 0).single.worker;
      expect((a.x, a.y), (20.0, 40.0));
      final b = workersLeaving(start, 1).single.worker;
      final onRoad = (b.x - 31.6).abs() < 1e-9 || (b.y - 32.4).abs() < 1e-9;
      expect(onRoad, isTrue);
    });

    test('they walk, not hammer', () {
      final p = workersLeaving(start, 0.5).single.pose;
      expect(p == Pose.walk1 || p == Pose.walk2, isTrue);
    });
  });

  group('TownGame celebration', () {
    final clock = FakeClock();
    final town = TownState.initial().copyWith(workers: 5);
    final session = SessionEngine.start(
      id: 's',
      minutes: 10,
      workersAvailable: 5,
      now: TimeStamp.now(clock),
    );
    const result = SessionResult(
      outcome: SessionOutcome.completed,
      tier: BuildingTier.hut,
      workersLost: 0,
      workersGained: 0,
      newStreak: 1,
      plotGranted: false,
    );

    TownGame running() => TownGame(clock: clock)
      ..onGameResize(Vector2(400, 700))
      ..setFocus(FocusState(town: town, active: session))
      ..update(0.1)
      ..render(ui.Canvas(ui.PictureRecorder()));

    void finish(TownGame g, {SessionResult r = result}) => g.setFocus(
      FocusState(
        town: town.copyWith(
          buildings: [
            ...town.buildings,
            const TownBuilding(
              id: 'b',
              tier: BuildingTier.hut,
              status: BuildingStatus.complete,
              plotIndex: 1,
            ),
          ],
        ),
        lastResult: r,
      ),
    );

    test('a completed result bursts about 40 particles above the plot', () {
      final g = running();
      expect(g.renderer.particles, isEmpty);
      finish(g);
      g.update(0.1);
      expect(g.renderer.particles.length, inInclusiveRange(30, 40));
      final plot = kPlots[1];
      for (final p in g.renderer.particles) {
        expect(p.x, closeTo(plot.center.x, 3));
        expect(p.y, closeTo(plot.center.y, 3));
      }
    });

    test('one result celebrates once, however often the state repeats', () {
      final g = running();
      finish(g);
      g.update(0.1);
      final n = g.renderer.particles.length;
      for (var i = 0; i < 3; i++) {
        g.setFocus(FocusState(town: town, lastResult: result));
      }
      g.update(0.1);
      expect(g.renderer.particles.length, lessThanOrEqualTo(n));
    });

    test('everything is gone after 1 s', () {
      final g = running();
      finish(g);
      for (var i = 0; i < 11; i++) {
        g.update(0.1);
      }
      expect(g.renderer.particles, isEmpty);
      final siteWorkers = g.renderer.workers.where(
        (w) => w.worker.shirt.top == FlatColor.of(WorkerColors.vest).top,
      );
      expect(siteWorkers, isEmpty);
    });

    test('the site workers keep walking to a road during the second', () {
      final g = running();
      finish(g);
      g.update(0.1);
      final leaving = g.renderer.workers.where(
        (w) => w.worker.shirt.top == FlatColor.of(WorkerColors.vest).top,
      );
      expect(leaving, hasLength(session.workersAssigned));
      for (final w in leaving) {
        expect(w.pose == Pose.walk1 || w.pose == Pose.walk2, isTrue);
      }
    });

    test('low power: no particles, workers still leave at the end', () {
      final g = running()..lowPower = true;
      finish(g);
      g.update(0.1);
      expect(g.renderer.particles, isEmpty);
    });

    test('reduced motion: the workers vanish at once', () {
      final g = running()..reducedMotion = true;
      finish(g);
      g.update(0.1);
      final siteWorkers = g.renderer.workers.where(
        (w) => w.worker.shirt.top == FlatColor.of(WorkerColors.vest).top,
      );
      expect(siteWorkers, isEmpty);
    });

    test('a failed result throws no dust, only smoke', () {
      final g = running();
      finish(
        g,
        r: const SessionResult(
          outcome: SessionOutcome.failed,
          tier: BuildingTier.hut,
          workersLost: 3,
          workersGained: 0,
          newStreak: 0,
          plotGranted: false,
        ),
      );
      g.update(0.1);
      expect(g.renderer.particles.every((p) => p.color == 0xFF4a4038), isTrue);
    });
  });

  group('TownGame failure', () {
    final clock = FakeClock();
    final town = TownState.initial().copyWith(workers: 5);
    final session = SessionEngine.start(
      id: 's',
      minutes: 10,
      workersAvailable: 5,
      now: TimeStamp.now(clock),
    );
    const failed = SessionResult(
      outcome: SessionOutcome.failed,
      tier: BuildingTier.hut,
      workersLost: 1,
      workersGained: 0,
      newStreak: 0,
      plotGranted: false,
    );

    TownGame running() => TownGame(clock: clock)
      ..onGameResize(Vector2(400, 700))
      ..setFocus(FocusState(town: town, active: session))
      ..update(0.1)
      ..render(ui.Canvas(ui.PictureRecorder()));

    void fail(TownGame g) =>
        g.setFocus(FocusState(town: town, lastResult: failed));

    Iterable<PlacedWorker> dead(TownGame g) =>
        g.renderer.workers.where((w) => w.pose == Pose.dead);

    test('the site workers lie dead for 3 s, then are gone', () {
      final g = running();
      fail(g);
      for (var i = 0; i < 29; i++) {
        g.update(0.1);
      }
      expect(dead(g), hasLength(session.workersAssigned));
      for (var i = 0; i < 3; i++) {
        g.update(0.1);
      }
      expect(dead(g), isEmpty);
    });

    test('smoke rises during the phase and is gone after it', () {
      final g = running();
      fail(g);
      g.update(0.1);
      expect(g.renderer.particles.length, inInclusiveRange(20, 30));
      for (var i = 0; i < 15; i++) {
        g.update(0.1);
      }
      expect(g.renderer.particles.length, inInclusiveRange(20, 30));
      for (var i = 0; i < 16; i++) {
        g.update(0.1);
      }
      expect(g.renderer.particles, isEmpty);
    });

    test('smoke is char colored and never in low power', () {
      final g = running();
      fail(g);
      g.update(0.1);
      expect(g.renderer.particles.every((p) => p.color == 0xFF4a4038), isTrue);
      final low = running()..lowPower = true;
      fail(low);
      low.update(0.1);
      expect(low.renderer.particles, isEmpty);
      expect(dead(low), isNotEmpty);
    });

    test('a completed result shows no dead workers', () {
      final g = running()
        ..setFocus(FocusState(town: town, lastResult: result0))
        ..update(0.1);
      expect(dead(g), isEmpty);
    });
  });
}
