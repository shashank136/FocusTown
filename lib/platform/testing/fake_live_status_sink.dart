import 'package:focus_town/platform/live_status.dart';

/// Test double that records what the app asked for.
class FakeLiveStatusSink implements LiveStatusSink {
  /// Every status shown, in order.
  final List<LiveStatus> shown = [];

  /// How many times [end] was called.
  int ended = 0;

  /// When true, every call throws.
  bool failing = false;

  @override
  Future<void> show(LiveStatus status) async {
    if (failing) throw StateError('sink failed');
    shown.add(status);
  }

  @override
  Future<void> end() async {
    if (failing) throw StateError('sink failed');
    ended++;
  }
}
