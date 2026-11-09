import 'package:focus_town/domain/clock.dart';

/// Controllable [Clock] for tests.
class FakeClock implements Clock {
  /// Creates a clock at [start] (default 2026-01-01 09:00) with zero uptime.
  new({DateTime? start}) : _wall = start ?? DateTime(2026, 1, 1, 9);

  DateTime _wall;
  Duration _uptime = Duration.zero;

  @override
  DateTime nowWall() => _wall;

  @override
  Duration uptime() => _uptime;

  /// Moves wall time and uptime forward by [d].
  void advance(Duration d) {
    _wall = _wall.add(d);
    _uptime += d;
  }

  /// Sets wall time only; uptime is unchanged.
  // ignore: use_setters_to_change_properties
  void setWall(DateTime t) => _wall = t;

  /// Resets uptime to zero; wall time is unchanged.
  void simulateReboot() => _uptime = Duration.zero;
}
