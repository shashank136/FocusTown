import 'package:focus_town/domain/building_tier.dart';
import 'package:focus_town/domain/session.dart';
import 'package:focus_town/domain/time_stamp.dart';

/// Away time up to this long is forgiven.
const kWarningWindow = Duration(seconds: 10);

/// Extra away time (beyond [kWarningWindow]) forgiven once per session.
const kPassWindow = Duration(seconds: 60);

/// Pure session rules: each function returns a new [Session].
class SessionEngine {
  new _();

  /// Starts a running session for [minutes].
  ///
  /// Throws [ArgumentError] for an invalid duration and [StateError] when
  /// [workersAvailable] is below the tier's workers at risk.
  static Session start({
    required String id,
    required int minutes,
    required int workersAvailable,
    required TimeStamp now,
  }) {
    final tier = BuildingTier.forMinutes(minutes);
    if (workersAvailable < tier.workersAtRisk) {
      throw StateError(
        'Need ${tier.workersAtRisk} workers, have $workersAvailable',
      );
    }
    return Session(
      id: id,
      plannedMinutes: minutes,
      tier: tier,
      workersAssigned: tier.workersAtRisk,
      state: SessionState.running,
      startedAt: now,
    );
  }
}
