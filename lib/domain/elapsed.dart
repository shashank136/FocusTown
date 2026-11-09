import 'package:focus_town/domain/time_stamp.dart';

/// Time passed from [from] to [to], never negative.
///
/// Uptime is trusted. If uptime went backwards (reboot), wall time is used.
Duration elapsedBetween(TimeStamp from, TimeStamp to) {
  if (to.uptime >= from.uptime) return to.uptime - from.uptime;
  final wall = to.wall.difference(from.wall);
  return wall.isNegative ? Duration.zero : wall;
}
