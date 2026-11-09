// All fields are final; @immutable would need package:meta (not approved).
// ignore_for_file: avoid_equals_and_hash_code_on_mutable_classes

import 'package:focus_town/domain/clock.dart';

/// Wall time plus uptime at one moment.
class TimeStamp {
  /// Creates a stamp from explicit values.
  const new(this.wall, this.uptime);

  /// Captures the current wall time and uptime from [clock].
  // ignore: unnecessary_type_name_in_constructor, shorthand not valid for factories
  factory TimeStamp.now(Clock clock) =>
      TimeStamp(clock.nowWall(), clock.uptime());

  /// Wall-clock time.
  final DateTime wall;

  /// Monotonic uptime.
  final Duration uptime;

  @override
  bool operator ==(Object other) =>
      other is TimeStamp && other.wall == wall && other.uptime == uptime;

  @override
  int get hashCode => Object.hash(wall, uptime);
}
