import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/domain/building_tier.dart';
import 'package:focus_town/domain/local_date.dart';
import 'package:focus_town/domain/town.dart';

void main() {
  group('initial', () {
    final t = TownState.initial();
    test('3 workers, 6 plots, no queue, no recovery', () {
      expect(t.workers, 3);
      expect(t.plotsUnlocked, 6);
      expect(t.queue, isEmpty);
      expect(t.inRecoveryMode, isFalse);
    });
    test('no progression yet: xp 0, streak 0, null dates', () {
      expect(t.xp, 0);
      expect(t.streakCount, 0);
      expect(t.lastStreakDate, isNull);
      expect(t.lastPlotGrantDate, isNull);
    });
    test('starter house complete on plot 0', () {
      expect(t.buildings, [
        const TownBuilding(
          id: 'starter',
          tier: BuildingTier.house,
          status: BuildingStatus.complete,
          plotIndex: 0,
        ),
      ]);
    });
  });

  group('copyWith changes only the named field', () {
    final base = TownState.initial();
    const ruin = TownBuilding(
      id: 'r',
      tier: BuildingTier.hut,
      status: BuildingStatus.ruin,
      plotIndex: 1,
    );
    const queued = QueuedBuilding(id: 'q', tier: BuildingTier.tower);

    test('workers', () {
      final c = base.copyWith(workers: 9);
      expect(c.workers, 9);
      expect(c.copyWith(workers: 3), base);
    });
    test('plotsUnlocked', () {
      final c = base.copyWith(plotsUnlocked: 7);
      expect(c.plotsUnlocked, 7);
      expect(c.copyWith(plotsUnlocked: 6), base);
    });
    test('buildings', () {
      final c = base.copyWith(buildings: [...base.buildings, ruin]);
      expect(c.buildings, hasLength(2));
      expect(c.copyWith(buildings: base.buildings), base);
    });
    test('queue', () {
      final c = base.copyWith(queue: [queued]);
      expect(c.queue, [queued]);
      expect(c.copyWith(queue: const []), base);
    });
    test('xp', () {
      final c = base.copyWith(xp: 40);
      expect(c.xp, 40);
      expect(c.copyWith(xp: 0), base);
    });
    test('streakCount', () {
      final c = base.copyWith(streakCount: 3);
      expect(c.streakCount, 3);
      expect(c.copyWith(streakCount: 0), base);
    });
    test('lastStreakDate', () {
      final c = base.copyWith(lastStreakDate: const LocalDate(2026, 5, 1));
      expect(c.lastStreakDate, const LocalDate(2026, 5, 1));
      expect(c.workers, base.workers);
    });
    test('lastPlotGrantDate', () {
      final c = base.copyWith(lastPlotGrantDate: const LocalDate(2026, 5, 1));
      expect(c.lastPlotGrantDate, const LocalDate(2026, 5, 1));
      expect(c.workers, base.workers);
    });
    test('other copyWith calls keep the progression fields', () {
      final p = base.copyWith(
        xp: 10,
        streakCount: 2,
        lastStreakDate: const LocalDate(2026, 5, 1),
        lastPlotGrantDate: const LocalDate(2026, 5, 1),
      );
      final c = p.copyWith(workers: 9);
      expect(c.xp, 10);
      expect(c.streakCount, 2);
      expect(c.lastStreakDate, const LocalDate(2026, 5, 1));
      expect(c.lastPlotGrantDate, const LocalDate(2026, 5, 1));
    });
    test('inRecoveryMode', () {
      final c = base.copyWith(inRecoveryMode: true);
      expect(c.inRecoveryMode, isTrue);
      expect(c.copyWith(inRecoveryMode: false), base);
    });
  });

  group('equality', () {
    test('equal states with separate lists are equal', () {
      final a = TownState.initial();
      final b = TownState.initial();
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });
    test('differing queue is unequal', () {
      final a = TownState.initial();
      final b = a.copyWith(
        queue: [const QueuedBuilding(id: 'q', tier: BuildingTier.hut)],
      );
      expect(a, isNot(b));
    });
    test('each progression field affects equality', () {
      final a = TownState.initial();
      expect(a, isNot(a.copyWith(xp: 1)));
      expect(a, isNot(a.copyWith(streakCount: 1)));
      expect(a, isNot(a.copyWith(lastStreakDate: const LocalDate(2026, 1, 1))));
      expect(
        a,
        isNot(a.copyWith(lastPlotGrantDate: const LocalDate(2026, 1, 1))),
      );
    });
    test('differing building field is unequal', () {
      const x = TownBuilding(
        id: 'a',
        tier: BuildingTier.hut,
        status: BuildingStatus.complete,
        plotIndex: 1,
      );
      expect(
        x,
        isNot(
          const TownBuilding(
            id: 'b',
            tier: BuildingTier.hut,
            status: BuildingStatus.complete,
            plotIndex: 1,
          ),
        ),
      );
      expect(
        x,
        isNot(
          const TownBuilding(
            id: 'a',
            tier: BuildingTier.house,
            status: BuildingStatus.complete,
            plotIndex: 1,
          ),
        ),
      );
      expect(
        x,
        isNot(
          const TownBuilding(
            id: 'a',
            tier: BuildingTier.hut,
            status: BuildingStatus.ruin,
            plotIndex: 1,
          ),
        ),
      );
      expect(
        x,
        isNot(
          const TownBuilding(
            id: 'a',
            tier: BuildingTier.hut,
            status: BuildingStatus.complete,
            plotIndex: 2,
          ),
        ),
      );
    });
  });

  test('lists cannot be mutated from outside', () {
    final t = TownState.initial();
    expect(t.buildings.clear, throwsUnsupportedError);
    expect(
      () => t.queue.add(const QueuedBuilding(id: 'q', tier: BuildingTier.hut)),
      throwsUnsupportedError,
    );
  });

  test('source list changes do not leak into the state', () {
    final src = <QueuedBuilding>[];
    final t = TownState.initial().copyWith(queue: src);
    src.add(const QueuedBuilding(id: 'q', tier: BuildingTier.hut));
    expect(t.queue, isEmpty);
  });
}
