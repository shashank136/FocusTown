import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Testing aid: when on, the map shows every landmark finished on a cleared
/// island (see `TownRules.landmarkShowcase`). Nothing is saved; switched on
/// from the debug screen, off again on every app start.
class LandmarkShowcase extends Notifier<bool> {
  @override
  bool build() => false;

  /// Switches it on or off.
  void toggle() => state = !state;
}

/// See [LandmarkShowcase].
final landmarkShowcaseProvider = NotifierProvider<LandmarkShowcase, bool>(
  LandmarkShowcase.new,
);
