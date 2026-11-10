import 'package:flutter/services.dart';

/// Reads whether the phone is in a battery saving mode (iOS Low Power Mode).
class PowerState {
  /// Creates a reader over the `focus/lifecycle` channel.
  new([MethodChannel? channel])
    : _channel = channel ?? const MethodChannel('focus/lifecycle');

  final MethodChannel _channel;

  /// True when low power mode is on. Any failure counts as off: the town just
  /// runs at the normal frame rate.
  Future<bool> isLowPower() async {
    try {
      final answer = await _channel.invokeMethod<Object?>('lowPowerMode');
      return answer is bool && answer;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }
}
