import 'dart:async';

import 'package:focus_town/app/focus_controller.dart';
import 'package:focus_town/domain/clock.dart';
import 'package:focus_town/domain/elapsed.dart';
import 'package:focus_town/domain/time_stamp.dart';
import 'package:focus_town/platform/lifecycle_events.dart';

/// How long a backgrounded event waits for a lock to follow it.
const kLockWindow = Duration(milliseconds: 500);

/// Routes lifecycle events to the [FocusController], one at a time.
class LifecycleRouter {
  /// Creates a router; call [start] to begin listening.
  new(this._source, this._controller, this._clock, {this.onEvent});

  final LifecycleSource _source;
  final FocusController _controller;
  final Clock _clock;

  /// Called for every event first (the event log uses it).
  final void Function(LifecycleEvent)? onEvent;

  StreamSubscription<LifecycleEvent>? _subscription;
  Future<void> _queue = Future<void>.value();
  bool _inCall = false;
  BackgroundedEvent? _pending;
  // The last lock. On the iPhone the lock comes just BEFORE the background
  // (the screen locks, then the app is sent away), so a background right after
  // a lock is part of that lock.
  LockedEvent? _lockedAt;

  /// Completes when every event received so far has been handled.
  Future<void> get idle => _queue;

  /// Forwards a held backgrounded event once the lock window has passed.
  Future<void> flushExpired() => _enqueue(() async {
    final pending = _pending;
    if (pending == null) return;
    if (elapsedBetween(pending.timestamp, TimeStamp.now(_clock)) <
        kLockWindow) {
      return;
    }
    _pending = null;
    await _controller.onBackgroundedUnlocked(at: pending.timestamp);
  });

  /// Starts listening to the source.
  void start() {
    _subscription = _source.events.listen((e) {
      unawaited(_enqueue(() => _handle(e)));
    });
  }

  /// Stops listening. The source belongs to its provider.
  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
    _pending = null;
  }

  // Runs [task] after everything queued before it, so events keep their order.
  Future<void> _enqueue(Future<void> Function() task) => _queue = _queue
      .then((_) => task())
      .catchError(
        // Report but keep the queue alive for later events.
        (Object error, StackTrace stack) =>
            Zone.current.handleUncaughtError(error, stack),
      );

  Future<void> _handle(LifecycleEvent e) async {
    onEvent?.call(e);
    final pending = _pending;
    if (pending != null) {
      switch (e) {
        case BackgroundedEvent():
          return; // keep the earlier timestamp
        case CallStartedEvent():
          _pending = null; // calls are allowed
        case LockedEvent() || ForegroundedEvent():
          _pending = null;
          // Within the window the switch was a lock or a blip: no penalty.
          if (!_withinWindow(pending, e)) await _forward(pending);
        case UnlockedEvent() || CallEndedEvent():
          if (!_withinWindow(pending, e)) {
            _pending = null;
            await _forward(pending);
          }
      }
    }
    switch (e) {
      case LockedEvent():
        _lockedAt = e;
        await _controller.onLocked(at: e.timestamp);
      case CallStartedEvent():
        _inCall = true;
        await _controller.onCallStarted(at: e.timestamp);
      case CallEndedEvent():
        _inCall = false;
      case BackgroundedEvent():
        final lock = _lockedAt;
        final partOfLock = lock != null && _withinWindow(lock, e);
        if (!_inCall && !partOfLock) _pending = e;
      case ForegroundedEvent():
        _lockedAt = null;
        await _controller.onForegrounded(at: e.timestamp);
      case UnlockedEvent():
        _lockedAt = null;
    }
  }

  bool _withinWindow(LifecycleEvent pending, LifecycleEvent next) =>
      elapsedBetween(pending.timestamp, next.timestamp) <= kLockWindow;

  Future<void> _forward(LifecycleEvent pending) =>
      _controller.onBackgroundedUnlocked(at: pending.timestamp);
}
