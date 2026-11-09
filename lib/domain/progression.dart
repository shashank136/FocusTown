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
}
