import 'dart:async';

import 'package:focus_town/app/focus_controller.dart';
import 'package:focus_town/domain/clock.dart';
import 'package:focus_town/platform/lifecycle_events.dart';

/// Routes lifecycle events to the [FocusController], one at a time.
class LifecycleRouter {
  /// Creates a router; call [start] to begin listening.
  new(this._source, this._controller, this._clock, {this.onEvent});

  final LifecycleSource _source;
  final FocusController _controller;
  // ignore: unused_field, used by the lock window in T-09.4
  final Clock _clock;

  /// Called for every event first (the event log uses it).
  final void Function(LifecycleEvent)? onEvent;

  StreamSubscription<LifecycleEvent>? _subscription;
  Future<void> _queue = Future<void>.value();
  bool _inCall = false;

  /// Completes when every event received so far has been handled.
  Future<void> get idle => _queue;

  /// Starts listening to the source.
  void start() {
    // Handle events one at a time, in arrival order.
    _subscription = _source.events.listen((e) {
      _queue = _queue
          .then((_) => _handle(e))
          .catchError(
            // Report but keep the queue alive for later events.
            (Object error, StackTrace stack) =>
                Zone.current.handleUncaughtError(error, stack),
          );
    });
  }

  /// Stops listening. The source belongs to its provider.
  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
  }

  Future<void> _handle(LifecycleEvent e) async {
    onEvent?.call(e);
    switch (e) {
      case LockedEvent():
        await _controller.onLocked(at: e.timestamp);
      case CallStartedEvent():
        _inCall = true;
        await _controller.onCallStarted(at: e.timestamp);
      case CallEndedEvent():
        _inCall = false;
      case BackgroundedEvent():
        if (!_inCall) await _controller.onBackgroundedUnlocked(at: e.timestamp);
      case ForegroundedEvent():
        await _controller.onForegrounded(at: e.timestamp);
      case UnlockedEvent():
        break;
    }
  }
}
