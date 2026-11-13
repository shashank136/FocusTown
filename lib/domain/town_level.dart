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
