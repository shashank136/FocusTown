import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/domain/building_tier.dart';
import 'package:focus_town/domain/session.dart';
import 'package:focus_town/domain/time_stamp.dart';
import 'package:focus_town/domain/town.dart';
import 'package:focus_town/domain/town_rules.dart';

TownBuilding _b(int plot, {BuildingStatus s = BuildingStatus.complete}) =>
    TownBuilding(
      id: 'b$plot',
      tier: BuildingTier.hut,
      status: s,
      plotIndex: plot,
    );

TownState _town({
  int workers = 3,
  int plots = 6,
  List<TownBuilding> buildings = const [],
  bool recovery = false,
}) => TownState(
  workers: workers,
  plotsUnlocked: plots,
  buildings: buildings,
  queue: const [],
  inRecoveryMode: recovery,
);

Session _done(BuildingTier tier, {String id = 's1'}) => Session(
  id: id,
  plannedMinutes: tier.minMinutes,
  tier: tier,
  workersAssigned: tier.workersAtRisk,
  state: SessionState.completed,
  startedAt: TimeStamp(DateTime(2026), Duration.zero),
  outcomeReason: OutcomeReason.completed,
);

void main() {
  group('nextFreePlot', () {
    test('initial town gives plot 1', () {
      expect(TownRules.nextFreePlot(TownState.initial()), 1);
    });

    test('buildings on 0, 1, 3 give plot 2', () {
      final t = _town(buildings: [_b(0), _b(1), _b(3)]);
      expect(TownRules.nextFreePlot(t), 2);
    });

    test('all 6 plots used gives null', () {
      final t = _town(buildings: [for (var i = 0; i < 6; i++) _b(i)]);
      expect(TownRules.nextFreePlot(t), isNull);
    });

    test('a ruin on plot 0 still blocks it', () {
      final t = _town(buildings: [_b(0, s: BuildingStatus.ruin)]);
      expect(TownRules.nextFreePlot(t), 1);
    });

    test('7 unlocked with 6 used gives plot 6', () {
      final t = _town(plots: 7, buildings: [for (var i = 0; i < 6; i++) _b(i)]);
      expect(TownRules.nextFreePlot(t), 6);
    });

    test('an occupied plot beyond plotsUnlocked is ignored', () {
      final t = _town(plots: 1, buildings: [_b(0)]);
      expect(TownRules.nextFreePlot(t), isNull);
    });
  });

  group('canStart', () {
    const tiers = {10: 1, 25: 2, 45: 3, 65: 5, 95: 8};
    for (final e in tiers.entries) {
      for (final workers in [0, 1, 2, 3, 4, 5, 8]) {
        test('${e.key} min with $workers workers: ${workers >= e.value}', () {
          expect(
            TownRules.canStart(_town(workers: workers), e.key),
            workers >= e.value,
          );
        });
      }
    }

    test('invalid minutes are false, not an error', () {
      expect(TownRules.canStart(_town(workers: 8), 7), isFalse);
      expect(TownRules.canStart(_town(workers: 8), 130), isFalse);
    });

    test('recovery with 0 workers allows huts only', () {
      final t = _town(workers: 0, recovery: true);
      expect(TownRules.canStart(t, 10), isTrue);
      expect(TownRules.canStart(t, 20), isTrue);
      expect(TownRules.canStart(t, 25), isFalse);
    });

    test('recovery with 2 workers still refuses a house', () {
      expect(
        TownRules.canStart(_town(workers: 2, recovery: true), 25),
        isFalse,
      );
    });
  });

  group('applyCompleted', () {
    test('hut success: 4 workers, building on plot 1', () {
      final t = TownRules.applyCompleted(
        TownState.initial(),
        _done(BuildingTier.hut),
      );
      expect(t.workers, 4);
      expect(
        t.buildings.last,
        const TownBuilding(
          id: 's1',
          tier: BuildingTier.hut,
          status: BuildingStatus.complete,
          plotIndex: 1,
        ),
      );
      expect(t.buildings, hasLength(2));
    });

    test('house success: 5 workers', () {
      final t = TownRules.applyCompleted(
        TownState.initial(),
        _done(BuildingTier.house),
      );
      expect(t.workers, 5);
    });

    test('workshop, tower, castle success: workers unchanged', () {
      for (final tier in [
        BuildingTier.workshop,
        BuildingTier.tower,
        BuildingTier.castle,
      ]) {
        final t = TownRules.applyCompleted(TownState.initial(), _done(tier));
        expect(t.workers, 3, reason: '$tier');
        expect(t.buildings, hasLength(2), reason: '$tier');
      }
    });

    test('all plots full: queued, buildings unchanged', () {
      final full = _town(buildings: [for (var i = 0; i < 6; i++) _b(i)]);
      final t = TownRules.applyCompleted(full, _done(BuildingTier.tower));
      expect(t.queue, [
        const QueuedBuilding(id: 's1', tier: BuildingTier.tower),
      ]);
      expect(t.buildings, full.buildings);
    });

    test('recovery with 2 workers, hut success: 3 workers, exits recovery', () {
      final t = TownRules.applyCompleted(
        _town(workers: 2, recovery: true),
        _done(BuildingTier.hut),
      );
      expect(t.workers, 3);
      expect(t.inRecoveryMode, isFalse);
    });

    test('recovery with 0 workers, hut success: 1 worker, still recovery', () {
      final t = TownRules.applyCompleted(
        _town(workers: 0, recovery: true),
        _done(BuildingTier.hut),
      );
      expect(t.workers, 1);
      expect(t.inRecoveryMode, isTrue);
    });
  });

  group('placeQueued', () {
    const q1 = QueuedBuilding(id: 'q1', tier: BuildingTier.hut);
    const q2 = QueuedBuilding(id: 'q2', tier: BuildingTier.house);

    TownState full({List<QueuedBuilding> queue = const [], int plots = 6}) =>
        TownState(
          workers: 3,
          plotsUnlocked: plots,
          buildings: [for (var i = 0; i < 6; i++) _b(i)],
          queue: queue,
          inRecoveryMode: false,
        );

    test('raising plotsUnlocked to 7 places the queued building on plot 6', () {
      final t = TownRules.placeQueued(full(queue: [q1], plots: 7));
      expect(t.queue, isEmpty);
      expect(
        t.buildings.last,
        const TownBuilding(
          id: 'q1',
          tier: BuildingTier.hut,
          status: BuildingStatus.complete,
          plotIndex: 6,
        ),
      );
    });

    test('two queued, one free plot: oldest placed, one left', () {
      final t = TownRules.placeQueued(full(queue: [q1, q2], plots: 7));
      expect(t.buildings.last.id, 'q1');
      expect(t.queue, [q2]);
    });

    test('no free plot: unchanged', () {
      final s = full(queue: [q1]);
      expect(TownRules.placeQueued(s), s);
    });

    test('empty queue: unchanged', () {
      final s = TownState.initial();
      expect(TownRules.placeQueued(s), s);
    });
  });
}
