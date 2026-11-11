import 'dart:async';

import 'package:flutter/services.dart';
import 'package:focus_town/domain/clock.dart';
import 'package:focus_town/platform/fallback_lifecycle_source.dart';
import 'package:focus_town/platform/lifecycle_events.dart';
import 'package:focus_town/platform/local_log.dart';
import 'package:focus_town/platform/native_lifecycle_source.dart';
import 'package:focus_town/platform/native_uptime_clock.dart';

/// The clock and lifecycle source the app should run with.
typedef PlatformBootstrap = ({Clock clock, LifecycleSource source});

/// Uses native code when the channel answers, otherwise the Flutter fallback.
Future<PlatformBootstrap> bootstrapPlatform({
  MethodChannel? channel,
  Duration timeout = const Duration(seconds: 1),
  LocalLog? log,
}) async {
  final method = channel ?? const MethodChannel('focus/lifecycle');
  try {
    final uptimeMs = await method
        .invokeMethod<Object?>('uptimeMs')
        .timeout(timeout);
    if (uptimeMs is int) {
      return (
        clock: NativeUptimeClock(Duration(milliseconds: uptimeMs)),
        source: NativeLifecycleSource(onMalformed: log?.write),
      );
    }
  } on MissingPluginException {
    // No native side (tests, unsupported platform): use the fallback.
  } on PlatformException {
    // Native side failed: use the fallback.
  } on TimeoutException {
    // Native side did not answer in time: use the fallback.
  }
  final clock = SystemClock();
  return (clock: clock, source: FallbackLifecycleSource(clock));
}
