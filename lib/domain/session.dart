// All fields are final; @immutable would need package:meta (not approved).
// ignore_for_file: avoid_equals_and_hash_code_on_mutable_classes

import 'package:focus_town/domain/building_tier.dart';
import 'package:focus_town/domain/district.dart';
import 'package:focus_town/domain/landmark.dart';
import 'package:focus_town/domain/parcel.dart';
import 'package:focus_town/domain/time_stamp.dart';

/// Lifecycle state of a focus session.
enum SessionState {
  /// App in foreground, timer counting.
  running,

  /// User left the app; the away window is ticking.
  away,

  /// Finished successfully.
  completed,

  /// Workers lost.
  failed,
}

/// Why a session ended.
enum OutcomeReason {
  /// Reached the planned time.
  completed,

  /// Away longer than allowed.
  leftTooLong,

  /// User gave up.
  abandoned,
}

/// One focus session. Immutable.
class Session {
  /// Creates a session.
  const new({
    required this.id,
    required this.plannedMinutes,
    required this.tier,
    required this.workersAssigned,
    required this.state,
    required this.startedAt,
    this.leftAt,
    this.awayTotal = Duration.zero,
    this.passUsed = false,
    this.outcomeReason,
    this.plotIndex,
    this.repairPlot,
    this.land,
    this.look,
    this.landmark,
    this.district,
    this.emergencyArmed = false,
    this.emergencyUsed = false,
  });

  /// Unique id.
  final String id;

  /// Planned length in minutes.
  final int plannedMinutes;

  /// Building tier being built.
  final BuildingTier tier;

  /// Workers put at risk.
  final int workersAssigned;

  /// Current state.
  final SessionState state;

  /// When the session started.
  final TimeStamp startedAt;

  /// When the user last left the app, if away.
  final TimeStamp? leftAt;

  /// Total allowed time spent away so far.
  final Duration awayTotal;

  /// Whether the single 60 s pass was used.
  final bool passUsed;

  /// Why the session ended, once finished.
  final OutcomeReason? outcomeReason;

  /// The plot the user chose to build on, or null for the automatic one.
  final int? plotIndex;

  /// The plot of the ruin this session repairs, or null for an ordinary
  /// build. A repair is 10 minutes with nothing at risk.
  final int? repairPlot;

  /// The parcel this session claims when it completes, for a land session.
  final Parcel? land;

  /// The look of the building this session builds, as the user chose it
  /// (null: its id decides).
  final int? look;

  /// The landmark this session works on, for a landmark session.
  final Landmark? landmark;

  /// The side of the island this session builds a district on, for a
  /// district session.
  final DistrictSide? district;

  /// The weekly emergency pause is switched on: the next absence may last up
  /// to 10 minutes.
  final bool emergencyArmed;

  /// The emergency pause was spent on an absence in this session.
  final bool emergencyUsed;

  /// Whether this session clears a ruin instead of building something.
  bool get isRepair => repairPlot != null;

  /// Whether this session builds on a [landmark].
  bool get isLandmark => landmark != null;

  /// Whether this session builds a [district].
  bool get isDistrict => district != null;

  /// Whether this session claims [land] instead of building.
  bool get isLand => land != null;

  /// Planned length as a [Duration].
  Duration get planned => Duration(minutes: plannedMinutes);

  /// True while running or away.
  bool get isActive =>
      state == SessionState.running || state == SessionState.away;

  /// True once completed or failed.
  bool get isFinished =>
      state == SessionState.completed || state == SessionState.failed;

  /// Copy with changed fields; [clearLeftAt] sets [leftAt] to null.
  Session copyWith({
    int? plannedMinutes,
    SessionState? state,
    TimeStamp? leftAt,
    bool clearLeftAt = false,
    Duration? awayTotal,
    bool? passUsed,
    OutcomeReason? outcomeReason,
    bool? emergencyArmed,
    bool? emergencyUsed,
  }) => Session(
    id: id,
    plannedMinutes: plannedMinutes ?? this.plannedMinutes,
    tier: tier,
    workersAssigned: workersAssigned,
    state: state ?? this.state,
    startedAt: startedAt,
    leftAt: clearLeftAt ? null : (leftAt ?? this.leftAt),
    awayTotal: awayTotal ?? this.awayTotal,
    passUsed: passUsed ?? this.passUsed,
    outcomeReason: outcomeReason ?? this.outcomeReason,
    plotIndex: plotIndex,
    repairPlot: repairPlot,
    land: land,
    look: look,
    landmark: landmark,
    district: district,
    emergencyArmed: emergencyArmed ?? this.emergencyArmed,
    emergencyUsed: emergencyUsed ?? this.emergencyUsed,
  );

  @override
  bool operator ==(Object other) =>
      other is Session &&
      other.id == id &&
      other.plannedMinutes == plannedMinutes &&
      other.tier == tier &&
      other.workersAssigned == workersAssigned &&
      other.state == state &&
      other.startedAt == startedAt &&
      other.leftAt == leftAt &&
      other.awayTotal == awayTotal &&
      other.passUsed == passUsed &&
      other.outcomeReason == outcomeReason &&
      other.plotIndex == plotIndex &&
      other.repairPlot == repairPlot &&
      other.land == land &&
      other.look == look &&
      other.landmark == landmark &&
      other.district == district &&
      other.emergencyArmed == emergencyArmed &&
      other.emergencyUsed == emergencyUsed;

  @override
  int get hashCode => Object.hash(
    id,
    plannedMinutes,
    tier,
    workersAssigned,
    state,
    startedAt,
    leftAt,
    awayTotal,
    passUsed,
    outcomeReason,
    plotIndex,
    repairPlot,
    land,
    look,
    landmark,
    district,
    emergencyArmed,
    emergencyUsed,
  );
}
