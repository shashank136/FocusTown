/// Building size, chosen by session length.
enum BuildingTier {
  /// 10-20 minutes.
  hut(
    minMinutes: 10,
    maxMinutes: 20,
    workersAtRisk: 1,
    workersAddedOnSuccess: 1,
  ),

  /// 21-40 minutes.
  house(
    minMinutes: 21,
    maxMinutes: 40,
    workersAtRisk: 2,
    workersAddedOnSuccess: 2,
  ),

  /// 41-60 minutes.
  workshop(
    minMinutes: 41,
    maxMinutes: 60,
    workersAtRisk: 3,
    workersAddedOnSuccess: 0,
  ),

  /// 61-90 minutes.
  tower(
    minMinutes: 61,
    maxMinutes: 90,
    workersAtRisk: 5,
    workersAddedOnSuccess: 0,
  ),

  /// 91-120 minutes.
  castle(
    minMinutes: 91,
    maxMinutes: 120,
    workersAtRisk: 8,
    workersAddedOnSuccess: 0,
  );

  new({
    required this.minMinutes,
    required this.maxMinutes,
    required this.workersAtRisk,
    required this.workersAddedOnSuccess,
  });

  /// Shortest session for this tier, in minutes.
  final int minMinutes;

  /// Longest session for this tier, in minutes.
  final int maxMinutes;

  /// Workers that die if the session fails.
  final int workersAtRisk;

  /// Workers gained when the session succeeds.
  final int workersAddedOnSuccess;

  /// Tier for [minutes]; throws [ArgumentError] unless 10-120 in steps of 5.
  static BuildingTier forMinutes(int minutes) {
    if (minutes < 10 || minutes > 120 || minutes % 5 != 0) {
      throw ArgumentError.value(minutes, 'minutes', 'must be 10-120, step 5');
    }
    return values.firstWhere((t) => minutes <= t.maxMinutes);
  }

  /// All valid session lengths: 10, 15, ..., 120.
  static List<int> validDurations() => [for (var m = 10; m <= 120; m += 5) m];

  /// Biggest tier affordable with [workers], or null if none.
  static BuildingTier? largestAffordable(int workers) {
    BuildingTier? best;
    for (final t in values) {
      if (t.workersAtRisk <= workers) best = t;
    }
    return best;
  }
}
