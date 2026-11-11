import 'package:focus_town/platform/local_log.dart';

/// Watches the town drawing: after a paint error, or five seconds under
/// 5 frames per second, the town is shown as a still picture for the rest of
/// the run. The session timer is not part of the game, so it keeps running.
class RenderGuard {
  /// Creates a guard that tells [_log] when it gives up on animation.
  new(this._log);

  static const _minFps = 5;
  static const _window = Duration(seconds: 5);

  final LocalLog? _log;
  Duration? _slowSince;

  /// True once the town should stay a still picture (until the app restarts).
  bool degraded = false;

  /// Reports [fps] for the second that ended at [at].
  void recordFps(double fps, Duration at) {
    if (degraded) return;
    if (fps >= _minFps) {
      _slowSince = null;
      return;
    }
    final since = _slowSince ??= at - const Duration(seconds: 1);
    if (at - since >= _window) _degrade('$fps fps for 5 seconds');
  }

  /// Reports that drawing failed with [error].
  void recordError(Object error) {
    if (!degraded) _degrade('error: $error');
  }

  void _degrade(String reason) {
    degraded = true;
    _log?.write('render degraded: $reason');
  }
}
