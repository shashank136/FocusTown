/// Numbers a tester can read on the device. No analytics, nothing is sent.
class BetaStats {
  /// Creates the numbers.
  const new({
    required this.sessionsStarted,
    required this.completed,
    required this.failed,
    required this.completionRate,
    required this.daysActive,
    required this.firstOpen,
    required this.returnedAfterDay7,
  });

  /// Every session ever started.
  final int sessionsStarted;

  /// Sessions that finished well.
  final int completed;

  /// Sessions that were lost.
  final int failed;

  /// Completed out of finished sessions, 0 when none finished.
  final double completionRate;

  /// Different calendar days with at least one session.
  final int daysActive;

  /// When the town was first created.
  final DateTime firstOpen;

  /// Whether a session started 7 or more days after the first open.
  final bool returnedAfterDay7;
}
