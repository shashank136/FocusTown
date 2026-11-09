import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/domain/building_tier.dart';
import 'package:focus_town/domain/local_date.dart';
import 'package:focus_town/domain/progression.dart';
import 'package:focus_town/domain/session.dart';
import 'package:focus_town/domain/time_stamp.dart';
import 'package:focus_town/domain/town.dart';
import 'package:focus_town/domain/town_rules.dart';

Session _session(int minutes, {SessionState state = SessionState.completed}) {
  final tier = BuildingTier.forMinutes(minutes);
  return Session(
    id: 's$minutes',
    plannedMinutes: minutes,
    tier: tier,
    workersAssigned: tier.workersAtRisk,
    state: state,
    startedAt: TimeStamp(DateTime(2026), Duration.zero),
  );
}

TownState _complete(TownState t, int minutes, DateTime at) =>
    Progression.onSessionCompleted(t, _session(minutes), at);

void main() {
  group('levelFor', () {
    final cases = {
      0: TownLevel.camp,
      299: TownLevel.camp,
      300: TownLevel.village,
      1499: TownLevel.village,
      1500: TownLevel.town,
      5999: TownLevel.town,
      6000: TownLevel.city,
      14999: TownLevel.city,
      15000: TownLevel.metropolis,
      100000: TownLevel.metropolis,
    };
    for (final e in cases.entries) {
      test('${e.key} xp is ${e.value.name}', () {
        expect(Progression.levelFor(e.key), e.value);
      });
    }
  });

  group('progressToNext', () {
    test('0 xp is 0.0', () => expect(Progression.progressToNext(0), 0.0));
    test('150 xp is 0.5', () => expect(Progression.progressToNext(150), 0.5));
    test('300 xp starts village at 0.0', () {
      expect(Progression.progressToNext(300), 0.0);
    });
    test('900 xp is 0.5 of village', () {
      expect(Progression.progressToNext(900), 0.5);
    });
    test('15000 xp is 1.0', () {
      expect(Progression.progressToNext(15000), 1.0);
    });
    test('beyond the top level stays 1.0', () {
      expect(Progression.progressToNext(99999), 1.0);
    });
    test('one xp short of a level is just under 1.0', () {
      expect(Progression.progressToNext(299), closeTo(299 / 300, 1e-9));
    });
  });

  group('onSessionCompleted: xp and streak', () {
    final day1 = DateTime(2026, 5, 1, 9);

    test('first ever completion: xp = minutes, streak 1, date today', () {
      final t = _complete(TownState.initial(), 25, day1);
      expect(t.xp, 25);
      expect(t.streakCount, 1);
      expect(t.lastStreakDate, const LocalDate(2026, 5, 1));
    });

    test('two sessions the same day: xp 35, streak 1', () {
      var t = _complete(TownState.initial(), 25, day1);
      t = _complete(t, 10, DateTime(2026, 5, 1, 21));
      expect(t.xp, 35);
      expect(t.streakCount, 1);
      expect(t.lastStreakDate, const LocalDate(2026, 5, 1));
    });

    test('consecutive days: streak 2', () {
      var t = _complete(TownState.initial(), 25, day1);
      t = _complete(t, 25, DateTime(2026, 5, 2, 9));
      expect(t.streakCount, 2);
      expect(t.lastStreakDate, const LocalDate(2026, 5, 2));
    });

    test('a gap day resets the streak to 1', () {
      var t = _complete(TownState.initial(), 25, day1);
      t = _complete(t, 25, DateTime(2026, 5, 2, 9));
      t = _complete(t, 25, DateTime(2026, 5, 4, 9));
      expect(t.streakCount, 1);
      expect(t.lastStreakDate, const LocalDate(2026, 5, 4));
    });

    test('month boundary Jan 31 to Feb 1: streak 2', () {
      var t = _complete(TownState.initial(), 25, DateTime(2026, 1, 31, 23));
      t = _complete(t, 25, DateTime(2026, 2, 1, 1));
      expect(t.streakCount, 2);
    });

    test('year boundary Dec 31 to Jan 1: streak 2', () {
      var t = _complete(TownState.initial(), 25, DateTime(2026, 12, 31, 23));
      t = _complete(t, 25, DateTime(2027, 1, 1, 1));
      expect(t.streakCount, 2);
    });

    test('a completion dated before lastStreakDate resets to 1', () {
      var t = _complete(TownState.initial(), 25, DateTime(2026, 5, 5, 9));
      t = _complete(t, 25, DateTime(2026, 5, 2, 9));
      expect(t.streakCount, 1);
      expect(t.lastStreakDate, const LocalDate(2026, 5, 2));
    });

    test('a failed session leaves xp, streak and dates untouched', () {
      final before = _complete(TownState.initial(), 25, day1);
      final failed = _session(25, state: SessionState.failed);
      final after = TownRules.applyFailed(before, failed);
      expect(after.xp, before.xp);
      expect(after.streakCount, before.streakCount);
      expect(after.lastStreakDate, before.lastStreakDate);
      expect(after.lastPlotGrantDate, before.lastPlotGrantDate);
    });
  });

  group('daily plot grant', () {
    test('two sessions the same day grant one plot: 6 to 7', () {
      var t = _complete(TownState.initial(), 25, DateTime(2026, 5, 1, 9));
      t = _complete(t, 10, DateTime(2026, 5, 1, 21));
      expect(t.plotsUnlocked, 7);
      expect(t.lastPlotGrantDate, const LocalDate(2026, 5, 1));
    });

    test('consecutive days: plots 8 and streak 2', () {
      var t = _complete(TownState.initial(), 25, DateTime(2026, 5, 1, 9));
      t = _complete(t, 25, DateTime(2026, 5, 2, 9));
      expect(t.plotsUnlocked, 8);
      expect(t.streakCount, 2);
    });

    test('a gap day resets the streak but still grants a plot', () {
      var t = _complete(TownState.initial(), 25, DateTime(2026, 5, 1, 9));
      t = _complete(t, 25, DateTime(2026, 5, 4, 9));
      expect(t.streakCount, 1);
      expect(t.plotsUnlocked, 8);
      expect(t.lastPlotGrantDate, const LocalDate(2026, 5, 4));
    });

    test('the queue drains when a daily plot arrives', () {
      const queued = QueuedBuilding(id: 'q1', tier: BuildingTier.hut);
      final full = TownState(
        workers: 3,
        plotsUnlocked: 6,
        buildings: [
          for (var i = 0; i < 6; i++)
            TownBuilding(
              id: 'b$i',
              tier: BuildingTier.hut,
              status: BuildingStatus.complete,
              plotIndex: i,
            ),
        ],
        queue: const [queued],
        inRecoveryMode: false,
      );
      final t = _complete(full, 25, DateTime(2026, 5, 1, 9));
      expect(t.queue, isEmpty);
      expect(t.plotsUnlocked, 7);
      expect(t.buildings.last.id, 'q1');
      expect(t.buildings.last.plotIndex, 6);
    });

    test('the queue drains even without a new grant', () {
      const queued = QueuedBuilding(id: 'q1', tier: BuildingTier.hut);
      final open = TownState.initial().copyWith(
        lastPlotGrantDate: const LocalDate(2026, 5, 1),
        queue: [queued],
      );
      final t = _complete(open, 25, DateTime(2026, 5, 1, 9));
      expect(t.plotsUnlocked, 6);
      expect(t.queue, isEmpty);
    });
  });

  group('currentStreak', () {
    TownState streak3(LocalDate last) =>
        TownState.initial().copyWith(streakCount: 3, lastStreakDate: last);
    const may1 = LocalDate(2026, 5, 1);

    test('fresh town is 0', () {
      expect(Progression.currentStreak(TownState.initial(), may1), 0);
    });
    test('same day shows the stored count', () {
      expect(Progression.currentStreak(streak3(may1), may1), 3);
    });
    test('next day still shows the stored count', () {
      expect(
        Progression.currentStreak(streak3(may1), const LocalDate(2026, 5, 2)),
        3,
      );
    });
    test('two days later is 0', () {
      expect(
        Progression.currentStreak(streak3(may1), const LocalDate(2026, 5, 3)),
        0,
      );
    });
    test('month boundary Jan 31 to Feb 1 keeps the streak', () {
      expect(
        Progression.currentStreak(
          streak3(const LocalDate(2026, 1, 31)),
          const LocalDate(2026, 2, 1),
        ),
        3,
      );
    });
    test('year boundary Dec 31 to Jan 2 gives 0', () {
      expect(
        Progression.currentStreak(
          streak3(const LocalDate(2026, 12, 31)),
          const LocalDate(2027, 1, 2),
        ),
        0,
      );
    });
  });
}
