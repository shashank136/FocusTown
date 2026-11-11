import 'dart:async';

import 'package:focus_town/domain/clock.dart';
import 'package:focus_town/platform/lifecycle_events.dart';
import 'package:focus_town/platform/local_log.dart';

/// Uses the native bridge, but watches the Flutter-only source: if Flutter
/// says the app went to the background and the bridge says nothing within
/// 2 seconds, the bridge is declared silent and the lenient fallback takes
/// over for the rest of the run.
class ResilientLifecycleSource implements LifecycleSource {
  /// Creates the source and starts listening to both.
  new(this._native, this._fallback, this._clock, this._log) {
    _subs
      ..add(_native.events.listen(_onNative))
      ..add(_fallback.events.listen(_onFallback));
  }

  static const _deadline = Duration(seconds: 2);

  final LifecycleSource _native;
  final LifecycleSource _fallback;
  final Clock _clock;
  final LocalLog _log;
  final List<StreamSubscription<LifecycleEvent>> _subs = [];
  final StreamController<LifecycleEvent> _controller =
      StreamController<LifecycleEvent>.broadcast();
  final List<Duration> _nativeAt = [];
  Duration? _pausedAt;
  bool _silent = false;

  @override
  Stream<LifecycleEvent> get events => _controller.stream;

  @override
  bool get isNative => !_silent;

  /// Decides whether the bridge has gone silent; the app calls this often.
  void check() {
    final paused = _pausedAt;
    if (_silent || paused == null) return;
    if (_nativeAt.any((t) => (t - paused).abs() <= _deadline)) {
      _pausedAt = null;
      return;
    }
    if (_clock.uptime() - paused < _deadline) return;
    _silent = true;
    _log.write('native lifecycle bridge silent: using the Flutter fallback');
  }

  void _onNative(LifecycleEvent e) {
    if (_silent) return;
    _nativeAt
      ..add(e.timestamp.uptime)
      ..removeWhere((t) => _clock.uptime() - t > const Duration(seconds: 30));
    check();
    _controller.add(e);
  }

  void _onFallback(LifecycleEvent e) {
    if (e is LockedEvent && !_silent) _pausedAt ??= e.timestamp.uptime;
    check();
    if (_silent) _controller.add(e);
  }

  @override
  Future<void> dispose() async {
    for (final s in _subs) {
      await s.cancel();
    }
    await _native.dispose();
    await _fallback.dispose();
    await _controller.close();
  }
}
