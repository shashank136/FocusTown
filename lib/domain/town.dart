// All fields are final; @immutable would need package:meta (not approved).
// ignore_for_file: avoid_equals_and_hash_code_on_mutable_classes

import 'package:focus_town/domain/building_look.dart';
import 'package:focus_town/domain/building_tier.dart';
import 'package:focus_town/domain/district.dart';
import 'package:focus_town/domain/landmark.dart';
import 'package:focus_town/domain/local_date.dart';
import 'package:focus_town/domain/parcel.dart';

/// Whether a placed building is standing or destroyed.
enum BuildingStatus {
  /// Finished building.
  complete,

  /// Destroyed by a failed session.
  ruin,

  /// A landmark under construction, built over several sessions.
  building,
}

/// A building (or ruin) occupying one plot.
class TownBuilding {
  /// Creates a building.
  const new({
    required this.id,
    required this.tier,
    required this.status,
    required this.plotIndex,
    this.look,
    this.landmark,
    this.progress = 0,
  });

  /// Unique id.
  final String id;

  /// Building size.
  final BuildingTier tier;

  /// Standing or ruin.
  final BuildingStatus status;

  /// Plot it sits on.
  final int plotIndex;

  /// The look the user chose, or null for a building from before looks were
  /// chosen (its id decides).
  final int? look;

  /// The landmark this is, or null for an ordinary building.
  final Landmark? landmark;

  /// Minutes of finished sessions built into a landmark so far.
  final int progress;

  /// The landmark's stage: how many stages its progress has reached.
  int get stage {
    final l = landmark;
    return l == null ? 0 : (progress ~/ l.minutesPerStage).clamp(0, l.stages);
  }

  /// The look it is drawn with.
  int get effectiveLook => look ?? lookIndex(id);

  @override
  bool operator ==(Object other) =>
      other is TownBuilding &&
      other.id == id &&
      other.tier == tier &&
      other.status == status &&
      other.plotIndex == plotIndex &&
      other.look == look &&
      other.landmark == landmark &&
      other.progress == progress;

  @override
  int get hashCode =>
      Object.hash(id, tier, status, plotIndex, look, landmark, progress);
}

/// A finished building waiting for a free plot. [id] is the session id.
class QueuedBuilding {
  /// Creates a queued building.
  const new({required this.id, required this.tier, this.look});

  /// Session id.
  final String id;

  /// Building size.
  final BuildingTier tier;

  /// The look the user chose, or null (its id decides).
  final int? look;

  /// The look it is drawn with.
  int get effectiveLook => look ?? lookIndex(id);

  @override
  bool operator ==(Object other) =>
      other is QueuedBuilding &&
      other.id == id &&
      other.tier == tier &&
      other.look == look;

  @override
  int get hashCode => Object.hash(id, tier, look);
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
    this.xp = 0,
    this.streakCount = 0,
    this.lastStreakDate,
    this.lastPlotGrantDate,
    this.emergencyPauses = 1,
    this.emergencyWeek,
    List<Parcel> parcels = const [],
    List<DistrictSide> districts = const [],
    this.districtProject,
  }) : buildings = List.unmodifiable(buildings),
       queue = List.unmodifiable(queue),
       parcels = List.unmodifiable(parcels),
       districts = List.unmodifiable(districts);

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

  /// Weekly emergency pauses left (0 or 1).
  final int emergencyPauses;

  /// Monday of the week the pause count was last refilled for.
  final LocalDate? emergencyWeek;

  /// Land claimed beyond the starting island, in claim order. Parcel `i` is
  /// plot `64 + i`.
  final List<Parcel> parcels;

  /// The districts finished, in the order they were built.
  final List<DistrictSide> districts;

  /// The district being built, or null.
  final DistrictProject? districtProject;

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

  /// Total focus minutes completed.
  final int xp;

  /// Consecutive focus days, as last recorded.
  final int streakCount;

  /// Day of the last completed session, if any.
  final LocalDate? lastStreakDate;

  /// Day a daily plot was last granted, if ever.
  final LocalDate? lastPlotGrantDate;

  /// Copy with changed fields.
  TownState copyWith({
    int? workers,
    int? plotsUnlocked,
    List<TownBuilding>? buildings,
    List<QueuedBuilding>? queue,
    bool? inRecoveryMode,
    int? xp,
    int? streakCount,
    LocalDate? lastStreakDate,
    LocalDate? lastPlotGrantDate,
    int? emergencyPauses,
    LocalDate? emergencyWeek,
    List<Parcel>? parcels,
    List<DistrictSide>? districts,
    DistrictProject? districtProject,
    bool clearDistrictProject = false,
  }) => TownState(
    workers: workers ?? this.workers,
    plotsUnlocked: plotsUnlocked ?? this.plotsUnlocked,
    buildings: buildings ?? this.buildings,
    queue: queue ?? this.queue,
    inRecoveryMode: inRecoveryMode ?? this.inRecoveryMode,
    xp: xp ?? this.xp,
    streakCount: streakCount ?? this.streakCount,
    lastStreakDate: lastStreakDate ?? this.lastStreakDate,
    lastPlotGrantDate: lastPlotGrantDate ?? this.lastPlotGrantDate,
    emergencyPauses: emergencyPauses ?? this.emergencyPauses,
    emergencyWeek: emergencyWeek ?? this.emergencyWeek,
    parcels: parcels ?? this.parcels,
    districts: districts ?? this.districts,
    districtProject: clearDistrictProject
        ? null
        : districtProject ?? this.districtProject,
  );

  @override
  bool operator ==(Object other) =>
      other is TownState &&
      other.workers == workers &&
      other.plotsUnlocked == plotsUnlocked &&
      _sameItems(other.buildings, buildings) &&
      _sameItems(other.queue, queue) &&
      other.inRecoveryMode == inRecoveryMode &&
      other.xp == xp &&
      other.streakCount == streakCount &&
      other.lastStreakDate == lastStreakDate &&
      other.lastPlotGrantDate == lastPlotGrantDate &&
      other.emergencyPauses == emergencyPauses &&
      other.emergencyWeek == emergencyWeek &&
      _sameItems(other.parcels, parcels) &&
      _sameItems(other.districts, districts) &&
      other.districtProject == districtProject;

  @override
  int get hashCode => Object.hash(
    workers,
    plotsUnlocked,
    Object.hashAll(buildings),
    Object.hashAll(queue),
    inRecoveryMode,
    xp,
    streakCount,
    lastStreakDate,
    lastPlotGrantDate,
    emergencyPauses,
    emergencyWeek,
    Object.hashAll(parcels),
    Object.hashAll(districts),
    districtProject,
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
