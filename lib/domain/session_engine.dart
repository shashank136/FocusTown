import 'package:focus_town/domain/building_tier.dart';
import 'package:focus_town/domain/elapsed.dart';
import 'package:focus_town/domain/parcel.dart';
import 'package:focus_town/domain/session.dart';
import 'package:focus_town/domain/time_stamp.dart';

/// Away time up to this long is forgiven.
const kWarningWindow = Duration(seconds: 10);

/// Extra away time (beyond [kWarningWindow]) forgiven once per session.
const kPassWindow = Duration(seconds: 60);

/// The away time forgiven once when the weekly emergency pause is armed.
const kEmergencyWindow = Duration(minutes: 10);

/// Pure session rules: each function returns a new [Session].
class SessionEngine {
  new _();

  /// Starts a running session for [minutes].
  ///
  /// Throws [ArgumentError] for an invalid duration and [StateError] when
  /// [workersAvailable] is below the tier's workers at risk.
  ///
  /// [plotIndex] is the plot the user chose (null: the automatic one).
  ///
  /// With [recovery], only a hut is allowed, [workersAvailable] is ignored and
  /// no workers are put at risk.
  static Session start({
    required String id,
    required int minutes,
    required int workersAvailable,
    required TimeStamp now,
    bool recovery = false,
    int? plotIndex,
  }) {
    final tier = BuildingTier.forMinutes(minutes);
    if (recovery) {
      if (tier != BuildingTier.hut) {
        throw StateError('Recovery allows only a hut, got ${tier.name}');
      }
    } else if (workersAvailable < tier.workersAtRisk) {
      throw StateError(
        'Need ${tier.workersAtRisk} workers, have $workersAvailable',
      );
    }
    return Session(
      id: id,
      plannedMinutes: minutes,
      tier: tier,
      workersAssigned: recovery ? 0 : tier.workersAtRisk,
      state: SessionState.running,
      startedAt: now,
      plotIndex: plotIndex,
    );
  }

  /// A 10-minute session that clears the ruin on [plot]. Nothing is at risk:
  /// no workers are assigned, so a failed repair costs nothing.
  static Session startRepair({
    required String id,
    required int plot,
    required TimeStamp now,
  }) => Session(
    id: id,
    plannedMinutes: 10,
    tier: BuildingTier.hut,
    workersAssigned: 0,
    state: SessionState.running,
    startedAt: now,
    repairPlot: plot,
  );

  /// A session of [minutes] that claims [parcel] when it completes. Nothing is
  /// at risk: no workers are assigned, so a failed one costs nothing.
  static Session startLand({
    required String id,
    required Parcel parcel,
    required int minutes,
    required TimeStamp now,
  }) => Session(
    id: id,
    plannedMinutes: minutes,
    tier: BuildingTier.hut,
    workersAssigned: 0,
    state: SessionState.running,
    startedAt: now,
    land: parcel,
  );

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
    if (session.emergencyArmed) {
      // The pause covers this whole absence, then it is spent.
      return away <= kEmergencyWindow
          ? session.copyWith(
              state: SessionState.running,
              clearLeftAt: true,
              awayTotal: total,
              emergencyArmed: false,
              emergencyUsed: true,
            )
          : session.copyWith(
              state: SessionState.failed,
              awayTotal: total,
              outcomeReason: OutcomeReason.leftTooLong,
            );
    }
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

  /// Decides timeouts and completion from stored timestamps only.
  ///
  /// Call on every tick and app launch. Finished sessions are unchanged.
  ///
  /// Away: the limit is 10 s if the pass is spent, else 70 s (10 minutes when
  /// the emergency pause is armed). Past the limit
  /// the session completes if the planned time was reached inside the allowed
  /// window, otherwise it fails as `leftTooLong`, even if the app never came
  /// back. Within the limit it completes once the planned time passes, else
  /// stays away.
  ///
  /// Running: completes once the whole span from `startedAt` reaches the
  /// planned time, so allowed away time counts.
  static Session resolve(Session session, TimeStamp now) {
    if (session.isFinished) return session;
    Session complete(Session s) => s.copyWith(
      state: SessionState.completed,
      outcomeReason: OutcomeReason.completed,
    );
    if (session.state == SessionState.running) {
      return elapsedBetween(session.startedAt, now) >= session.planned
          ? complete(session)
          : session;
    }
    final left = session.leftAt!;
    final away = elapsedBetween(left, now);
    final limit = session.emergencyArmed
        ? kEmergencyWindow
        : session.passUsed
        ? kWarningWindow
        : kWarningWindow + kPassWindow;
    final withAway = session.copyWith(awayTotal: session.awayTotal + away);
    if (away > limit) {
      final reached =
          elapsedBetween(session.startedAt, left) + limit >= session.planned;
      return reached
          ? complete(withAway)
          : withAway.copyWith(
              state: SessionState.failed,
              outcomeReason: OutcomeReason.leftTooLong,
            );
    }
    return elapsedBetween(session.startedAt, now) >= session.planned
        ? complete(withAway)
        : session;
  }

  /// Fraction of the planned time done, from 0.0 to 1.0.
  static double progress(Session session, TimeStamp now) =>
      session.state == SessionState.completed
      ? 1
      : (elapsedBetween(session.startedAt, now).inMicroseconds /
                session.planned.inMicroseconds)
            .clamp(0, 1);
}
