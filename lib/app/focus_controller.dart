import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focus_town/app/focus_state.dart';
import 'package:focus_town/app/providers.dart';
import 'package:focus_town/data/save_failed_exception.dart';
import 'package:focus_town/domain/elapsed.dart';
import 'package:focus_town/domain/local_date.dart';
import 'package:focus_town/domain/progression.dart';
import 'package:focus_town/domain/session.dart';
import 'package:focus_town/domain/session_engine.dart';
import 'package:focus_town/domain/time_stamp.dart';
import 'package:focus_town/domain/town.dart';
import 'package:focus_town/domain/town_rules.dart';

/// Owns the town and the live session; the UI only reads and calls this.
class FocusController extends AsyncNotifier<FocusState> {
  @override
  Future<FocusState> build() async {
    final repo = ref.watch(townRepositoryProvider);
    final base = FocusState(town: await repo.loadOrCreate());
    final stored = await repo.activeSession();
    if (stored == null) return base;
    // The app may have been killed: decide the outcome from timestamps now.
    final now = TimeStamp.now(ref.read(clockProvider));
    final resolved = SessionEngine.resolve(stored, now);
    if (resolved.isFinished) {
      return await _finish(base.copyWith(active: resolved), resolved, now);
    }
    if (resolved != stored) {
      try {
        await repo.saveSessionUpdated(resolved);
      } on SaveFailedException catch (e) {
        // The stored session is still active; the next event retries.
        _log('$e');
        return base.copyWith(active: stored);
      }
    }
    // Back in the app: warnings from before the kill no longer apply.
    if (resolved.state == SessionState.running) await _cancelWarnings();
    return base.copyWith(active: resolved);
  }

  /// Dismisses the last result.
  void clearResult() {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(clearLastResult: true));
  }

  /// Starts a session of [minutes] on [plotIndex] (a free unlocked plot), or
  /// on the next free plot when null; it exists only once it is saved.
  Future<void> start(int minutes, {int? plotIndex}) async {
    final current = await future;
    if (current.active != null) {
      throw StateError('A session is already active');
    }
    if (!TownRules.canStart(current.town, minutes)) {
      throw StateError('Cannot start $minutes minutes with this town');
    }
    if (plotIndex != null && !TownRules.isPlotFree(current.town, plotIndex)) {
      throw StateError('Plot $plotIndex is not free');
    }
    final now = TimeStamp.now(ref.read(clockProvider));
    final session = SessionEngine.start(
      id: 's${now.wall.microsecondsSinceEpoch}',
      minutes: minutes,
      workersAvailable: current.town.workers,
      recovery: current.town.inRecoveryMode,
      now: now,
      plotIndex: plotIndex ?? TownRules.nextFreePlot(current.town),
    );
    // The first session of a new week brings the emergency pause back.
    final town = _refilled(current.town, now);
    // Save first: a session that was not saved never starts.
    await ref.read(townRepositoryProvider).saveSessionStarted(town, session);
    state = AsyncData(current.copyWith(town: town, active: session));
  }

  TownState _refilled(TownState town, TimeStamp now) =>
      TownRules.refillEmergency(town, LocalDate.fromDateTime(now.wall));

  /// Switches on this week's emergency pause for the running session: the next
  /// absence may last 10 minutes. False when it is not allowed.
  Future<bool> armEmergencyPause() async {
    final current = await future;
    final active = current.active;
    if (active == null) return false;
    final armed = TownRules.armEmergency(current.town, active);
    if (armed == null) return false;
    final (town, session) = armed;
    await ref.read(townRepositoryProvider).saveEmergencyArmed(town, session);
    state = AsyncData(current.copyWith(town: town, active: session));
    return true;
  }

  /// Starts a 10-minute repair of the ruin on [plot]. Nothing is at risk.
  Future<void> startRepair(int plot) async {
    final current = await future;
    if (current.active != null) {
      throw StateError('A session is already active');
    }
    if (!TownRules.canRepair(current.town, plot)) {
      throw StateError('Plot $plot has no ruin to repair');
    }
    final now = TimeStamp.now(ref.read(clockProvider));
    final session = SessionEngine.startRepair(
      id: 's${now.wall.microsecondsSinceEpoch}',
      plot: plot,
      now: now,
    );
    final town = _refilled(current.town, now);
    await ref.read(townRepositoryProvider).saveSessionStarted(town, session);
    state = AsyncData(current.copyWith(town: town, active: session));
  }

  /// Resolves the active session from the clock; finishes it if due.
  Future<void> tick() async {
    final current = await future;
    final active = current.active;
    if (active == null) return;
    final now = TimeStamp.now(ref.read(clockProvider));
    final resolved = SessionEngine.resolve(active, now);
    if (resolved.isFinished) {
      state = AsyncData(await _finish(current, resolved, now));
    }
  }

  /// Gives up the active session, losing its workers.
  Future<void> abandon() async {
    final current = await future;
    final active = current.active;
    if (active == null) return;
    final now = TimeStamp.now(ref.read(clockProvider));
    state = AsyncData(
      await _finish(current, SessionEngine.abandon(active, now), now),
    );
  }

  /// Screen lock is allowed; nothing changes.
  Future<void> onLocked({TimeStamp? at}) =>
      _forward(SessionEngine.onLocked, at, cancelWarnings: true);

  /// A phone call is allowed; nothing changes.
  Future<void> onCallStarted({TimeStamp? at}) =>
      _forward(SessionEngine.onCallStarted, at);

  /// The user left the app with the phone unlocked.
  Future<void> onBackgroundedUnlocked({TimeStamp? at}) =>
      _forward(SessionEngine.onBackgroundedUnlocked, at);

  /// The user came back to the app.
  Future<void> onForegrounded({TimeStamp? at}) => _forward(
    SessionEngine.onForegrounded,
    at,
    resolveAfter: true,
    cancelWarnings: true,
  );

  // Applies an engine event to the active session, then saves or finishes.
  Future<void> _forward(
    Session Function(Session, TimeStamp) event,
    TimeStamp? at, {
    bool resolveAfter = false,
    bool cancelWarnings = false,
  }) async {
    final current = await future;
    final active = current.active;
    if (active == null) return;
    final clock = ref.read(clockProvider);
    final t = at ?? TimeStamp.now(clock);
    var updated = event(active, t);
    // Planned time may have passed while the user was away.
    if (resolveAfter) {
      updated = SessionEngine.resolve(updated, TimeStamp.now(clock));
    }
    if (updated.isFinished) {
      state = AsyncData(await _finish(current, updated, t));
      return;
    }
    // Locking or returning ends the away warnings.
    if (cancelWarnings) await _cancelWarnings();
    if (updated == active) return;
    try {
      await ref.read(townRepositoryProvider).saveSessionUpdated(updated);
    } on SaveFailedException catch (e) {
      _log('$e'); // keep the last good state; the next event retries
      return;
    }
    state = AsyncData(current.copyWith(active: updated));
    if (updated.state == SessionState.away &&
        active.state != SessionState.away) {
      await _safeNotify(
        () => ref
            .read(notifierProvider)
            .scheduleAwayWarnings(passAvailable: !updated.passUsed),
      );
    }
  }

  Future<void> _cancelWarnings() =>
      _safeNotify(() => ref.read(notifierProvider).cancelAwayWarnings());

  void _log(String message) => ref.read(localLogProvider).write(message);

  // Notification trouble must never change a session or the town.
  Future<void> _safeNotify(Future<void> Function() call) async {
    try {
      await call();
    } on Object catch (error) {
      _log('Notification failed: $error');
    }
  }

  /// Applies the town rules, saves everything atomically, builds the result.
  Future<FocusState> _finish(
    FocusState base,
    Session finished,
    TimeStamp now,
  ) async {
    final completed = finished.state == SessionState.completed;
    if (wallClockTampered(finished.startedAt, now)) {
      _log('clock tamper detected');
    }
    final repair = finished.isRepair;
    final town = switch ((repair, completed)) {
      (true, true) => Progression.onSessionCompleted(
        TownRules.applyRepairCompleted(base.town, finished),
        finished,
        now.wall,
      ),
      // A lost repair costs nothing.
      (true, false) => base.town,
      (false, true) => Progression.onSessionCompleted(
        TownRules.applyCompleted(base.town, finished),
        finished,
        now.wall,
      ),
      (false, false) => TownRules.applyFailed(base.town, finished),
    };
    try {
      await ref
          .read(townRepositoryProvider)
          .saveSessionResolved(town, finished);
    } on SaveFailedException catch (e) {
      // Nothing changed: the stored session is still active, so the next tick
      // or event finishes it once the database recovers.
      _log('$e');
      return base;
    }
    await _cancelWarnings();
    final queued = town.queue.any((q) => q.id == finished.id);
    final result = SessionResult(
      outcome: !completed
          ? SessionOutcome.failed
          : queued
          ? SessionOutcome.queued
          : SessionOutcome.completed,
      tier: finished.tier,
      workersLost: completed ? 0 : finished.workersAssigned,
      workersGained: completed && !repair
          ? finished.tier.workersAddedOnSuccess
          : 0,
      newStreak: Progression.currentStreak(
        town,
        LocalDate.fromDateTime(now.wall),
      ),
      plotGranted: town.plotsUnlocked > base.town.plotsUnlocked,
      xpGained: completed ? finished.plannedMinutes : 0,
      awaySeconds: finished.awayTotal.inSeconds,
      reason: finished.outcomeReason,
      leveledUpTo:
          Progression.levelFor(town.xp) != Progression.levelFor(base.town.xp)
          ? Progression.levelFor(town.xp)
          : null,
      recoveryStarted: !base.town.inRecoveryMode && town.inRecoveryMode,
      recoveryEnded: base.town.inRecoveryMode && !town.inRecoveryMode,
      repair: repair,
    );
    return FocusState(town: town, lastResult: result);
  }
}
