import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:focus_town/domain/clock.dart';
import 'package:focus_town/domain/time_stamp.dart';
import 'package:focus_town/platform/lifecycle_events.dart';

/// Flutter-only source for use before native code exists.
///
/// Flutter cannot tell a lock from an app switch, so it maps leniently and
/// never punishes: paused counts as a lock, resumed as unlock plus return.
class FallbackLifecycleSource
    with WidgetsBindingObserver
    implements LifecycleSource {
  /// Creates the source and starts observing the app lifecycle.
  new(this._clock) {
    WidgetsBinding.instance.addObserver(this);
  }

  final Clock _clock;
  final StreamController<LifecycleEvent> _controller =
      StreamController<LifecycleEvent>.broadcast();

  @override
  Stream<LifecycleEvent> get events => _controller.stream;

  @override
  bool get isNative => false;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final now = TimeStamp.now(_clock);
    switch (state) {
      case AppLifecycleState.paused:
        _controller.add(LockedEvent(now));
      case AppLifecycleState.resumed:
        _controller
          ..add(UnlockedEvent(now))
          ..add(ForegroundedEvent(now));
      // Control Center and the notification shade only make the app inactive.
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        break;
    }
  }

  @override
  Future<void> dispose() {
    WidgetsBinding.instance.removeObserver(this);
    return _controller.close();
  }
}
