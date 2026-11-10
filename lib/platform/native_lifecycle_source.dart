import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:focus_town/domain/time_stamp.dart';
import 'package:focus_town/platform/lifecycle_events.dart';

/// Lifecycle events from the native side over an [EventChannel].
///
/// Each message is a map with `type`, `wallMs` and `uptimeMs`. Bad data is
/// skipped and reported, never thrown, so the stream keeps running.
class NativeLifecycleSource implements LifecycleSource {
  /// Creates the source. [onMalformed] hears about bad data (default: print).
  new({EventChannel? eventChannel, void Function(String message)? onMalformed})
    : _onMalformed = onMalformed ?? debugPrint {
    _subscription = (eventChannel ?? const EventChannel(channelName))
        .receiveBroadcastStream()
        .listen(
          _onData,
          onError: (Object error) =>
              _onMalformed('Lifecycle stream error: $error'),
        );
  }

  /// Name of the native event channel.
  static const channelName = 'focus/lifecycle/events';

  final void Function(String message) _onMalformed;
  final StreamController<LifecycleEvent> _controller =
      StreamController<LifecycleEvent>.broadcast();
  late final StreamSubscription<Object?> _subscription;

  @override
  Stream<LifecycleEvent> get events => _controller.stream;

  @override
  bool get isNative => true;

  void _onData(Object? data) {
    final event = _parse(data);
    if (event == null) {
      _onMalformed('Malformed lifecycle event: $data');
    } else {
      _controller.add(event);
    }
  }

  static LifecycleEvent? _parse(Object? data) {
    if (data is! Map) return null;
    final type = data['type'];
    final wall = data['wallMs'];
    final uptime = data['uptimeMs'];
    if (type is! String || wall is! int || uptime is! int) return null;
    final at = TimeStamp(
      DateTime.fromMillisecondsSinceEpoch(wall),
      Duration(milliseconds: uptime),
    );
    return switch (type) {
      'locked' => LockedEvent(at),
      'unlocked' => UnlockedEvent(at),
      'backgrounded' => BackgroundedEvent(at),
      'foregrounded' => ForegroundedEvent(at),
      'callStarted' => CallStartedEvent(at),
      'callEnded' => CallEndedEvent(at),
      _ => null,
    };
  }

  @override
  Future<void> dispose() async {
    await _subscription.cancel();
    await _controller.close();
  }
}
