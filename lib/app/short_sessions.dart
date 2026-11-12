import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Testing aid: when on, every new session lasts 1 minute, whatever was
/// chosen (the tier and the rules stay those of the chosen length). Switched
/// on from the debug screen; off again on every app start.
class ShortSessions extends Notifier<bool> {
  @override
  bool build() => false;

  /// Switches it on or off.
  void toggle() => state = !state;
}

/// See [ShortSessions].
final shortSessionsProvider = NotifierProvider<ShortSessions, bool>(
  ShortSessions.new,
);
