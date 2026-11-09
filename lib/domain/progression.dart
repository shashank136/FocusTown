import 'package:focus_town/domain/local_date.dart';
import 'package:focus_town/domain/session.dart';
import 'package:focus_town/domain/town.dart';

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

  /// Adds XP and updates the daily streak for a completed [session].
  ///
  /// [completedAtLocal] must be local time, so the calendar day is the user's.
  static TownState onSessionCompleted(
    TownState town,
    Session session,
    DateTime completedAtLocal,
  ) {
    final today = LocalDate.fromDateTime(completedAtLocal);
    final last = town.lastStreakDate;
    // Same day keeps the streak, the next day extends it, anything else
    // (first ever, a gap, or a date in the past) starts again at 1.
    final gap = last?.daysBetween(today);
    final streak = switch (gap) {
      0 => town.streakCount,
      1 => town.streakCount + 1,
      _ => 1,
    };
    return town.copyWith(
      xp: town.xp + session.plannedMinutes,
      streakCount: streak,
      lastStreakDate: today,
    );
  }
}
