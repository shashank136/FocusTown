// All fields are final; @immutable would need package:meta (not approved).
// ignore_for_file: avoid_equals_and_hash_code_on_mutable_classes

import 'package:focus_town/domain/building_tier.dart';
import 'package:focus_town/domain/session.dart';
import 'package:focus_town/domain/town.dart';

/// How a finished session ended up in the town.
enum SessionOutcome {
  /// Building placed on a plot.
  completed,

  /// Workers lost; the plot became a ruin.
  failed,

  /// Completed but waiting for a free plot.
  queued,
}

/// What the user should be told after a session finishes.
class SessionResult {
  /// Creates a result.
  const new({
    required this.outcome,
    required this.tier,
    required this.workersLost,
    required this.workersGained,
    required this.newStreak,
    required this.plotGranted,
  });

  /// How it ended.
  final SessionOutcome outcome;

  /// Building size of the session.
  final BuildingTier tier;

  /// Workers that died.
  final int workersLost;

  /// Workers that joined.
  final int workersGained;

  /// Streak after this session.
  final int newStreak;

  /// Whether this session earned the day's new plot.
  final bool plotGranted;

  @override
  bool operator ==(Object other) =>
      other is SessionResult &&
      other.outcome == outcome &&
      other.tier == tier &&
      other.workersLost == workersLost &&
      other.workersGained == workersGained &&
      other.newStreak == newStreak &&
      other.plotGranted == plotGranted;

  @override
  int get hashCode => Object.hash(
    outcome,
    tier,
    workersLost,
    workersGained,
    newStreak,
    plotGranted,
  );
}

/// Everything the UI needs: the town, the live session, the last result.
class FocusState {
  /// Creates a state.
  const new({required this.town, this.active, this.lastResult});

  /// The persisted town.
  final TownState town;

  /// The running or away session, if any.
  final Session? active;

  /// The result of the last finished session until dismissed.
  final SessionResult? lastResult;

  /// Copy with changed fields; the `clear` flags set a field to null.
  FocusState copyWith({
    TownState? town,
    Session? active,
    bool clearActive = false,
    SessionResult? lastResult,
    bool clearLastResult = false,
  }) => FocusState(
    town: town ?? this.town,
    active: clearActive ? null : (active ?? this.active),
    lastResult: clearLastResult ? null : (lastResult ?? this.lastResult),
  );

  @override
  bool operator ==(Object other) =>
      other is FocusState &&
      other.town == town &&
      other.active == active &&
      other.lastResult == lastResult;

  @override
  int get hashCode => Object.hash(town, active, lastResult);
}
