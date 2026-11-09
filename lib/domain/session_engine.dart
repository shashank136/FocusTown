import 'package:focus_town/domain/building_tier.dart';
import 'package:focus_town/domain/elapsed.dart';
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

  /// Screen lock is harmless: [session] is returned unchanged.
  static Session onLocked(Session session, TimeStamp now) => session;

  /// An incoming call is harmless: [session] is returned unchanged.
  static Session onCallStarted(Session session, TimeStamp now) => session;

  /// Running becomes away; any other state is unchanged.
  static Session onBackgroundedUnlocked(Session session, TimeStamp now) =>
      session.state == SessionState.running
      ? session.copyWith(state: SessionState.away, leftAt: now)
      : session;

  /// Applies the away window and single pass when the user returns.
  static Session onForegrounded(Session session, TimeStamp now) {
    if (session.state != SessionState.away) return session;
    final away = elapsedBetween(session.leftAt!, now);
    final total = session.awayTotal + away;
    if (away <= kWarningWindow) {
      return session.copyWith(
        state: SessionState.running,
        clearLeftAt: true,
        awayTotal: total,
      );
    }
    if (away <= kWarningWindow + kPassWindow && !session.passUsed) {
      return session.copyWith(
        state: SessionState.running,
        clearLeftAt: true,
        awayTotal: total,
        passUsed: true,
      );
    }
    return session.copyWith(
      state: SessionState.failed,
      awayTotal: total,
      outcomeReason: OutcomeReason.leftTooLong,
    );
  }

  /// Active sessions fail as abandoned; finished ones are unchanged.
  static Session abandon(Session session, TimeStamp now) => session.isActive
      ? session.copyWith(
          state: SessionState.failed,
          outcomeReason: OutcomeReason.abandoned,
        )
      : session;
}
