import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/domain/building_tier.dart';
import 'package:focus_town/domain/session.dart';
import 'package:focus_town/domain/time_stamp.dart';
import 'package:focus_town/domain/town.dart';
import 'package:focus_town/game/workers/worker_layout.dart';
import 'package:focus_town/game/workers/worker_model.dart';
import 'package:focus_town/game/world/plot_layout.dart';

Session _session(BuildingTier t, int assigned) => Session(
  id: 's',
  plannedMinutes: 10,
  tier: t,
  workersAssigned: assigned,
  state: SessionState.running,
  startedAt: TimeStamp(DateTime(2026), Duration.zero),
);

TownState _town(int workers, {bool recovery = false}) =>
    TownState.initial().copyWith(workers: workers, inRecoveryMode: recovery);

void main() {
  group('spareWorkerCount', () {
    test('3 workers and no session: 3 spare', () {
      expect(spareWorkerCount(_town(3), null), 3);
    });

    test('a castle with 8 of 10 workers leaves 2', () {
      expect(spareWorkerCount(_town(10), _session(BuildingTier.castle, 8)), 2);
    });

    test('at most 4 are shown', () {
      expect(spareWorkerCount(_town(30), null), 4);
    });

    test('never negative', () {
      expect(spareWorkerCount(_town(2), _session(BuildingTier.tower, 5)), 0);
    });

    test('recovery with no workers shows the Last Builder', () {
      expect(spareWorkerCount(_town(0, recovery: true), null), 1);
      expect(
        spareWorkerCount(
          _town(0, recovery: true),
          _session(BuildingTier.hut, 0),
        ),
        1,
      );
    });

    test('no workers outside recovery shows none', () {
      expect(spareWorkerCount(_town(0), null), 0);
    });
  });

  group('siteWorkers', () {
    final plot = kPlots[5];

    for (final count in [1, 3, 8]) {
      for (final tier in BuildingTier.values) {
        test('$count workers around a ${tier.name} stay near the plot', () {
          final w = siteWorkers(plot, tier, count, 0);
          expect(w, hasLength(count));
          // A castle stands on a 2 x 2 block: its walls are twice as long.
          final reach = tier == BuildingTier.castle ? 15 : 8;
          for (final p in w) {
            expect(
              p.worker.x,
              inInclusiveRange(plot.originX - 1, plot.originX + reach),
            );
            expect(
              p.worker.y,
              inInclusiveRange(plot.originY - 1, plot.originY + reach),
            );
          }
        });
      }
    }

    test('more than 8 are capped at 8', () {
      expect(siteWorkers(plot, BuildingTier.hut, 20, 0), hasLength(8));
      expect(siteWorkers(plot, BuildingTier.hut, 0, 0), isEmpty);
    });

    test('side A stands south of the building facing north, side B east', () {
      final w = siteWorkers(plot, BuildingTier.hut, 2, 0);
      // hut: origin = plot + 1, 3x3
      final ox = plot.originX + 1;
      final oy = plot.originY + 1;
      expect(w[0].worker.x, closeTo(ox + 0.8, 1e-9));
      expect(w[0].worker.y, closeTo(oy + 3 + 0.7, 1e-9));
      expect(w[0].worker.facing, (0, -1));
      expect(w[1].worker.x, closeTo(ox + 3 + 0.7, 1e-9));
      expect(w[1].worker.y, closeTo(oy + 0.8, 1e-9));
      expect(w[1].worker.facing, (-1, 0));
    });

    test('the castle uses the block origin itself', () {
      final w = siteWorkers(plot, BuildingTier.castle, 1, 0);
      expect(w[0].worker.y, closeTo(plot.originY + 14 + 0.7, 1e-9));
      expect(w[0].worker.x, closeTo(plot.originX + 0.8, 1e-9));
    });

    test(
      'poses alternate every half second and neighbors are out of phase',
      () {
        Pose pose(double t, int i) =>
            siteWorkers(plot, BuildingTier.house, 4, t)[i].pose;
        expect(pose(0, 0), Pose.hammerUp);
        expect(pose(0.5, 0), Pose.hammerDown);
        expect(pose(1, 0), Pose.hammerUp);
        // worker 0 and worker 2 are neighbors on side A: opposite phase
        expect(pose(0, 2), isNot(pose(0, 0)));
      },
    );

    test('reduced motion keeps everyone idle', () {
      for (final t in [0.0, 0.5, 1.3]) {
        for (final w in siteWorkers(
          plot,
          BuildingTier.hut,
          3,
          t,
          reducedMotion: true,
        )) {
          expect(w.pose, Pose.idle);
        }
      }
    });
  });

  group('spareWalkers', () {
    test('they stay on the roads between 3 and 59 over time', () {
      for (var t = 0.0; t < 200; t += 0.7) {
        for (final w in spareWalkers(4, t)) {
          expect(w.worker.x, inInclusiveRange(3, 59));
          expect(w.worker.y, inInclusiveRange(3, 59));
          final onVertical = (w.worker.x - 31.6).abs() < 1e-9;
          final onHorizontal = (w.worker.y - 32.4).abs() < 1e-9;
          expect(onVertical || onHorizontal, isTrue);
        }
      }
    });

    test('worker 0 walks the vertical road forward then back', () {
      double y(double t) => spareWalkers(1, t)[0].worker.y;
      expect(y(0), closeTo(3, 1e-9));
      expect(y(10), closeTo(3 + 15, 1e-9)); // 1.5 tiles per second
      expect(y(56 / 1.5), closeTo(59, 1e-6)); // far end
      expect(y(56 / 1.5 + 10), closeTo(59 - 15, 1e-6)); // coming back
      expect(spareWalkers(1, 10)[0].worker.facing, (0, 1));
      expect(spareWalkers(1, 56 / 1.5 + 10)[0].worker.facing, (0, -1));
    });

    test('odd workers use the horizontal road', () {
      final w = spareWalkers(2, 0)[1].worker;
      expect(w.y, closeTo(32.4, 1e-9));
      expect(w.x, closeTo(3 + 14, 1e-9)); // phase 14 tiles
    });

    test('they loop after a full ping-pong (112 tiles)', () {
      final a = spareWalkers(1, 5)[0].worker.y;
      final b = spareWalkers(1, 5 + 112 / 1.5)[0].worker.y;
      expect(b, closeTo(a, 1e-6));
    });

    test('walk poses alternate every quarter second', () {
      Pose pose(double t) => spareWalkers(1, t)[0].pose;
      expect(pose(0), Pose.walk1);
      expect(pose(0.25), Pose.walk2);
      expect(pose(0.5), Pose.walk1);
    });

    test('reduced motion: idle and fixed positions', () {
      final a = spareWalkers(3, 0, reducedMotion: true);
      final b = spareWalkers(3, 50, reducedMotion: true);
      for (var i = 0; i < 3; i++) {
        expect(a[i].pose, Pose.idle);
        expect((a[i].worker.x, a[i].worker.y), (b[i].worker.x, b[i].worker.y));
      }
    });

    test('count 0 gives nobody', () {
      expect(spareWalkers(0, 3), isEmpty);
    });
  });

  test(
    'castle builders spread along the two front walls of its 14 x 14 block',
    () {
      const plot = Plot(0, 10, 10, 2);
      final out = siteWorkers(plot, BuildingTier.castle, 8, 0);
      expect(out, hasLength(8));
      final front = out.where((w) => w.worker.facing == (0, -1)).toList();
      final xs = front.map((w) => w.worker.x);
      expect(
        xs.reduce((a, b) => a > b ? a : b) - xs.reduce((a, b) => a < b ? a : b),
        greaterThan(5),
      );
      for (final w in out) {
        expect(w.worker.x, inInclusiveRange(10, 25));
        expect(w.worker.y, inInclusiveRange(10, 25));
      }
    },
  );
}
