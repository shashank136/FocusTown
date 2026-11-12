import 'package:focus_town/domain/local_date.dart';
import 'package:focus_town/domain/session.dart';
import 'package:focus_town/domain/town.dart';
import 'package:focus_town/domain/town_rules.dart';

/// Town size, from total XP (focus minutes).
enum TownLevel {
  /// Starting level.
  camp(0),

  /// 300 XP.
  village(300),

  /// 1500 XP.
  town(1500),

  /// 6000 XP.
  city(6000),

  /// 15000 XP, the top level.
  metropolis(15000);

  new(this.minXp);

  /// XP needed to reach this level.
  final int minXp;
}

/// Pure progression rules.
class Progression {
  new _();

  /// The level reached with [xp].
  static TownLevel levelFor(int xp) =>
      TownLevel.values.lastWhere((l) => xp >= l.minXp);

  /// Fraction 0.0-1.0 of the way from the current level to the next.
  static double progressToNext(int xp) {
    final level = levelFor(xp);
    if (level == TownLevel.metropolis) return 1;
    final next = TownLevel.values[level.index + 1];
    return ((xp - level.minXp) / (next.minXp - level.minXp)).clamp(0, 1);
  }

  /// Adds XP, updates the daily streak and drains the queue for a completed
  /// [session].
  ///
  /// [completedAtLocal] must be local time, so the calendar day is the user's.
  static TownState onSessionCompleted(
    TownState town,
    Session session,
    DateTime completedAtLocal,
  ) {
    final today = LocalDate.fromDateTime(completedAtLocal);
    final last = town.lastStreakDate;
    // Same day keeps the streak, the next day extends it, a gap (or the first
    // ever) starts again at 1. A date in the past, from a clock set back,
    // changes no date, so it cannot break or stretch the streak.
    final gap = last?.daysBetween(today);
    final past = gap != null && gap < 0;
    final streak = switch (gap) {
      0 => town.streakCount,
      1 => town.streakCount + 1,
      _ when past => town.streakCount,
      _ => 1,
    };
    final updated = town.copyWith(
      xp: town.xp + session.plannedMinutes,
      streakCount: streak,
      lastStreakDate: past ? last : today,
    );
    return TownRules.placeQueued(updated);
  }

  /// The streak to show on [today]: 0 once a day has been missed.
  static int currentStreak(TownState town, LocalDate today) {
    final last = town.lastStreakDate;
    if (last == null || last.daysBetween(today) > 1) return 0;
    return town.streakCount;
  }
}
