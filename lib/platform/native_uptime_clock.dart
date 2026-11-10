import 'package:focus_town/domain/clock.dart';

/// A [Clock] whose uptime starts at the native monotonic uptime.
///
/// The native value is read once at launch; later reads add a [Stopwatch],
/// so no channel call is needed per read.
class NativeUptimeClock implements Clock {
  /// Creates a clock whose uptime is [initial] now. [elapsed] is a test seam.
  new(this.initial, {Duration Function()? elapsed})
    : _elapsed = elapsed ?? _stopwatchSinceNow();

  /// Native uptime at construction.
  final Duration initial;
  final Duration Function() _elapsed;

  static Duration Function() _stopwatchSinceNow() {
    final stopwatch = Stopwatch()..start();
    return () => stopwatch.elapsed;
  }

  @override
  DateTime nowWall() => DateTime.now();

  @override
  Duration uptime() => initial + _elapsed();
}
