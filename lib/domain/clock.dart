/// Source of wall time and monotonic uptime for the domain layer.
abstract class Clock {
  /// Current wall-clock time.
  DateTime nowWall();

  /// Monotonic time since an arbitrary start, unaffected by wall changes.
  Duration uptime();
}

/// [Clock] backed by the system clock and a stopwatch started at construction.
class SystemClock implements Clock {
  final Stopwatch _stopwatch = Stopwatch()..start();

  @override
  DateTime nowWall() => DateTime.now();

  @override
  Duration uptime() => _stopwatch.elapsed;
}
