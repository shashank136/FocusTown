// All fields are final; @immutable would need package:meta (not approved).
// ignore_for_file: avoid_equals_and_hash_code_on_mutable_classes

import 'package:focus_town/domain/building_tier.dart';
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
    SessionState? state,
    TimeStamp? leftAt,
    bool clearLeftAt = false,
    Duration? awayTotal,
    bool? passUsed,
    OutcomeReason? outcomeReason,
  }) => Session(
    id: id,
    plannedMinutes: plannedMinutes,
    tier: tier,
    workersAssigned: workersAssigned,
    state: state ?? this.state,
    startedAt: startedAt,
    leftAt: clearLeftAt ? null : (leftAt ?? this.leftAt),
    awayTotal: awayTotal ?? this.awayTotal,
    passUsed: passUsed ?? this.passUsed,
    outcomeReason: outcomeReason ?? this.outcomeReason,
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
      other.outcomeReason == outcomeReason;

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
  );
}
