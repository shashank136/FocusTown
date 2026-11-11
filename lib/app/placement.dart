// All fields are final; @immutable would need package:meta (not approved).
// ignore_for_file: avoid_equals_and_hash_code_on_mutable_classes

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focus_town/app/providers.dart';
import 'package:focus_town/domain/town_rules.dart';

/// A build the user is about to start: how long, and which plot (if chosen).
class Placement {
  /// Creates a pending placement.
  const new(this.minutes, [this.plot]);

  /// Planned minutes of the session to start.
  final int minutes;

  /// The chosen plot, or null while the user has not tapped one.
  final int? plot;

  @override
  bool operator ==(Object other) =>
      other is Placement && other.minutes == minutes && other.plot == plot;

  @override
  int get hashCode => Object.hash(minutes, plot);
}

/// The choose-a-plot step between "Start" and a running session.
class PlacementController extends Notifier<Placement?> {
  @override
  Placement? build() => null;

  /// Starts choosing a plot for a session of [minutes]. Ignored while a
  /// session is running.
  void begin(int minutes) {
    final focus = ref.read(focusControllerProvider).value;
    if (focus == null || focus.active != null) return;
    state = Placement(minutes);
  }

  /// Selects plot [i] if it is free and unlocked; anything else is ignored.
  void select(int i) {
    final current = state;
    final focus = ref.read(focusControllerProvider).value;
    if (current == null || focus == null) return;
    if (!TownRules.isPlotFree(focus.town, i)) return;
    state = Placement(current.minutes, i);
  }

  /// Gives up without starting anything.
  void cancel() => state = null;

  /// Starts the session on the chosen plot, then clears. Does nothing before
  /// a plot is chosen.
  Future<void> confirm() async {
    final current = state;
    final plot = current?.plot;
    if (current == null || plot == null) return;
    await ref
        .read(focusControllerProvider.notifier)
        .start(current.minutes, plotIndex: plot);
    state = null;
  }
}

/// The pending placement, or null when none.
final placementProvider = NotifierProvider<PlacementController, Placement?>(
  PlacementController.new,
);
