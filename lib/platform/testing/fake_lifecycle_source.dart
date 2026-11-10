import 'dart:async';

import 'package:focus_town/platform/lifecycle_events.dart';

/// Test double: events are pushed with [emit].
class FakeLifecycleSource implements LifecycleSource {
  /// Creates a fake; [isNative] is what the source reports.
  new({this.isNative = false});

  final StreamController<LifecycleEvent> _controller =
      StreamController<LifecycleEvent>.broadcast();

  @override
  final bool isNative;

  @override
  Stream<LifecycleEvent> get events => _controller.stream;

  /// Delivers [e] to listeners.
  void emit(LifecycleEvent e) => _controller.add(e);

  @override
  Future<void> dispose() => _controller.close();
}
