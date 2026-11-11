// All fields are final; @immutable would need package:meta (not approved).
// ignore_for_file: avoid_equals_and_hash_code_on_mutable_classes

import 'package:focus_town/domain/building_tier.dart';

/// The building under construction: what it is and which stage it is at.
class ActiveSite {
  /// Creates a site at [stage] (1 up to the tier's last stage).
  const new(this.tier, this.stage, {this.plotIndex});

  /// What is being built.
  final BuildingTier tier;

  /// The construction stage shown.
  final int stage;

  /// The plot the user chose, or null for the automatic one.
  final int? plotIndex;

  @override
  bool operator ==(Object other) =>
      other is ActiveSite &&
      other.tier == tier &&
      other.stage == stage &&
      other.plotIndex == plotIndex;

  @override
  int get hashCode => Object.hash(tier, stage, plotIndex);
}
