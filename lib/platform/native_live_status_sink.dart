import 'package:flutter/services.dart';
import 'package:focus_town/platform/live_status.dart';

/// Sends the status to the iOS side, which runs the Live Activity. Without a
/// native side (tests, other platforms, Live Activities turned off) every
/// call quietly does nothing.
class NativeLiveStatusSink implements LiveStatusSink {
  /// Creates the sink; [channel] is replaceable for tests.
  new([MethodChannel? channel])
    : _channel = channel ?? const MethodChannel('focus/liveStatus');

  final MethodChannel _channel;

  @override
  Future<void> show(LiveStatus status) => _call('show', {
    'endsAtMs': status.endsAt.millisecondsSinceEpoch,
    'title': status.title,
    'away': status.away,
  });

  @override
  Future<void> end() => _call('end');

  Future<void> _call(String method, [Object? arguments]) async {
    try {
      await _channel.invokeMethod<void>(method, arguments);
    } on MissingPluginException {
      // No native side.
    } on PlatformException {
      // The status is a convenience; a native failure must not matter.
    }
  }
}
