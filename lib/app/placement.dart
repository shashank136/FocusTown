// All fields are final; @immutable would need package:meta (not approved).
// ignore_for_file: avoid_equals_and_hash_code_on_mutable_classes

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focus_town/app/providers.dart';
import 'package:focus_town/domain/building_tier.dart';
import 'package:focus_town/domain/landmark.dart';
import 'package:focus_town/domain/parcel.dart';
import 'package:focus_town/domain/town_rules.dart';
import 'package:focus_town/game/world/plot_layout.dart';

/// A build the user is about to start: how long, and which plot (if chosen).
/// With [land] it is a land session: [plot] is then a `kLandBase` index naming
/// a claimable parcel, and [garden] makes the new land open space.
class Placement {
  /// Creates a pending placement.
  const new(
    this.minutes, {
    this.plot,
    this.land = false,
    this.garden = false,
    this.look,
    this.landmark,
  });

  /// Planned minutes of the session to start.
  final int minutes;

  /// The chosen plot, or null while the user has not tapped one.
  final int? plot;

  /// Whether the user is choosing land to claim instead of a plot.
  final bool land;

  /// Whether the claimed land becomes a garden.
  final bool garden;

  /// The look of the building the user chose, or null.
  final int? look;

  /// The landmark the time goes into, or null for an ordinary building.
  final Landmark? landmark;

  /// The size of what is being placed: a landmark stands on a castle's block.
  BuildingTier get tier =>
      landmark != null ? BuildingTier.castle : BuildingTier.forMinutes(minutes);

  @override
  bool operator ==(Object other) =>
      other is Placement &&
      other.minutes == minutes &&
      other.plot == plot &&
      other.land == land &&
      other.garden == garden &&
      other.look == look &&
      other.landmark == landmark;

  @override
  int get hashCode => Object.hash(minutes, plot, land, garden, look, landmark);
}

/// The choose-a-plot step between "Start" and a running session.
class PlacementController extends Notifier<Placement?> {
  @override
  Placement? build() => null;

  /// Starts choosing a plot for a session of [minutes] building [look], or
  /// the block for [landmark]. Ignored while a session is running.
  void begin(int minutes, {int? look, Landmark? landmark}) {
    final focus = ref.read(focusControllerProvider).value;
    if (focus == null || focus.active != null) return;
    state = Placement(minutes, look: look, landmark: landmark);
  }

  /// Starts choosing land to claim. Ignored while a session is running.
  void beginLand() {
    final focus = ref.read(focusControllerProvider).value;
    if (focus == null || focus.active != null) return;
    state = Placement(
      TownRules.landMinutes(focus.town.parcels.length),
      land: true,
    );
  }

  /// Makes the land being claimed a garden, or a plot again.
  void toggleGarden() {
    final current = state;
    if (current == null || !current.land) return;
    state = Placement(
      current.minutes,
      plot: current.plot,
      land: true,
      garden: !current.garden,
    );
  }

  /// Selects plot [i] if it is free and unlocked (or, choosing land, if it
  /// names a claimable parcel); anything else is ignored.
  void select(int i) {
    final current = state;
    final focus = ref.read(focusControllerProvider).value;
    if (current == null || focus == null) return;
    if (current.land) {
      final n = claimableParcels(focus.town.parcels).length;
      if (i < kLandBase || i - kLandBase >= n) return;
    } else if (!TownRules.isPlotFree(focus.town, i, current.tier)) {
      return;
    }
    state = Placement(
      current.minutes,
      plot: i,
      land: current.land,
      garden: current.garden,
      look: current.look,
      landmark: current.landmark,
    );
  }

  /// Gives up without starting anything.
  void cancel() => state = null;

  /// Starts the session on the chosen plot, then clears. Does nothing before
  /// a plot is chosen.
  Future<void> confirm() async {
    final current = state;
    final plot = current?.plot;
    if (current == null || plot == null) return;
    final controller = ref.read(focusControllerProvider.notifier);
    if (current.land) {
      final town = ref.read(focusControllerProvider).requireValue.town;
      final p = claimableParcels(town.parcels)[plot - kLandBase];
      await controller.startLand(Parcel(p.gx, p.gy, garden: current.garden));
    } else if (current.landmark != null) {
      await controller.startLandmark(
        current.landmark!,
        current.minutes,
        plotIndex: plot,
      );
    } else {
      await controller.start(
        current.minutes,
        plotIndex: plot,
        look: current.look,
      );
    }
    state = null;
  }
}

/// The pending placement, or null when none.
final placementProvider = NotifierProvider<PlacementController, Placement?>(
  PlacementController.new,
);
