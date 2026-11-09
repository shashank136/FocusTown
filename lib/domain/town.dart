// All fields are final; @immutable would need package:meta (not approved).
// ignore_for_file: avoid_equals_and_hash_code_on_mutable_classes

import 'package:focus_town/domain/building_tier.dart';

/// Whether a placed building is standing or destroyed.
enum BuildingStatus {
  /// Finished building.
  complete,

  /// Destroyed by a failed session.
  ruin,
}

/// A building (or ruin) occupying one plot.
class TownBuilding {
  /// Creates a building.
  const new({
    required this.id,
    required this.tier,
    required this.status,
    required this.plotIndex,
  });

  /// Unique id.
  final String id;

  /// Building size.
  final BuildingTier tier;

  /// Standing or ruin.
  final BuildingStatus status;

  /// Plot it sits on.
  final int plotIndex;

  @override
  bool operator ==(Object other) =>
      other is TownBuilding &&
      other.id == id &&
      other.tier == tier &&
      other.status == status &&
      other.plotIndex == plotIndex;

  @override
  int get hashCode => Object.hash(id, tier, status, plotIndex);
}

/// A finished building waiting for a free plot. [id] is the session id.
class QueuedBuilding {
  /// Creates a queued building.
  const new({required this.id, required this.tier});

  /// Session id.
  final String id;

  /// Building size.
  final BuildingTier tier;

  @override
  bool operator ==(Object other) =>
      other is QueuedBuilding && other.id == id && other.tier == tier;

  @override
  int get hashCode => Object.hash(id, tier);
}

/// The whole town. Immutable; lists are unmodifiable.
class TownState {
  /// Creates a town state.
  new({
    required this.workers,
    required this.plotsUnlocked,
    required List<TownBuilding> buildings,
    required List<QueuedBuilding> queue,
    required this.inRecoveryMode,
  }) : buildings = List.unmodifiable(buildings),
       queue = List.unmodifiable(queue);

  /// The starting town.
  // ignore: unnecessary_type_name_in_constructor, shorthand not valid for factories
  factory TownState.initial() => TownState(
    workers: 3,
    plotsUnlocked: 6,
    buildings: const [
      TownBuilding(
        id: 'starter',
        tier: BuildingTier.house,
        status: BuildingStatus.complete,
        plotIndex: 0,
      ),
    ],
    queue: const [],
    inRecoveryMode: false,
  );

  /// Living workers.
  final int workers;

  /// Plots available for building.
  final int plotsUnlocked;

  /// Placed buildings and ruins.
  final List<TownBuilding> buildings;

  /// Finished buildings waiting for a plot, oldest first.
  final List<QueuedBuilding> queue;

  /// True while the town has no workers left to risk.
  final bool inRecoveryMode;

  /// Copy with changed fields.
  TownState copyWith({
    int? workers,
    int? plotsUnlocked,
    List<TownBuilding>? buildings,
    List<QueuedBuilding>? queue,
    bool? inRecoveryMode,
  }) => TownState(
    workers: workers ?? this.workers,
    plotsUnlocked: plotsUnlocked ?? this.plotsUnlocked,
    buildings: buildings ?? this.buildings,
    queue: queue ?? this.queue,
    inRecoveryMode: inRecoveryMode ?? this.inRecoveryMode,
  );

  @override
  bool operator ==(Object other) =>
      other is TownState &&
      other.workers == workers &&
      other.plotsUnlocked == plotsUnlocked &&
      _sameItems(other.buildings, buildings) &&
      _sameItems(other.queue, queue) &&
      other.inRecoveryMode == inRecoveryMode;

  @override
  int get hashCode => Object.hash(
    workers,
    plotsUnlocked,
    Object.hashAll(buildings),
    Object.hashAll(queue),
    inRecoveryMode,
  );

  // Pure Dart: no collection package, so compare lists by hand.
  static bool _sameItems<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
