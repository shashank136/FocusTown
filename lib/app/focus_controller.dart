import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focus_town/app/focus_state.dart';
import 'package:focus_town/app/providers.dart';
import 'package:focus_town/app/short_sessions.dart';
import 'package:focus_town/data/save_failed_exception.dart';
import 'package:focus_town/domain/building_tier.dart';
import 'package:focus_town/domain/elapsed.dart';
import 'package:focus_town/domain/landmark.dart';
import 'package:focus_town/domain/local_date.dart';
import 'package:focus_town/domain/parcel.dart';
import 'package:focus_town/domain/progression.dart';
import 'package:focus_town/domain/session.dart';
import 'package:focus_town/domain/session_engine.dart';
import 'package:focus_town/domain/time_stamp.dart';
import 'package:focus_town/domain/town.dart';
import 'package:focus_town/domain/town_rules.dart';
import 'package:focus_town/platform/live_status.dart';

/// Owns the town and the live session; the UI only reads and calls this.
class FocusController extends AsyncNotifier<FocusState> {
  // What the lock screen shows now, so it is only told about changes.
  LiveStatus? _live;

  @override
  Future<FocusState> build() async {
    listenSelf((_, next) => unawaited(_syncLiveStatus(next.value?.active)));
    final repo = ref.watch(townRepositoryProvider);
    var town = await repo.loadOrCreate();
    // Buildings that waited for room (the island grew, or the plots became
    // free) are placed now.
    final placed = TownRules.placeQueued(town);
    if (placed != town) {
      try {
        await repo.saveTown(placed);
        town = placed;
      } on SaveFailedException catch (e) {
        _log('$e'); // they stay in the queue; the next launch retries
      }
    }
    final base = FocusState(town: town);
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

  // True while a start, repair or pause is being saved, so a double tap
  // cannot create a second session.
  bool _busy = false;

  Future<T?> _once<T>(Future<T> Function() body) async {
    if (_busy) return null;
    _busy = true;
    try {
      return await body();
    } finally {
      _busy = false;
    }
  }

  /// Starts a session of [minutes] on [plotIndex] (a free plot), or on the
  /// next free plot when null, building the chosen [look]; it exists only
  /// once it is saved.
  Future<void> start(int minutes, {int? plotIndex, int? look}) => _once(
    () async {
      final current = await future;
      if (current.active != null) {
        throw StateError('A session is already active');
      }
      if (!TownRules.canStart(current.town, minutes)) {
        throw StateError('Cannot start $minutes minutes with this town');
      }
      final tier = BuildingTier.forMinutes(minutes);
      if (plotIndex != null &&
          !TownRules.isPlotFree(current.town, plotIndex, tier)) {
        throw StateError('Plot $plotIndex is not free for a ${tier.name}');
      }
      final now = TimeStamp.now(ref.read(clockProvider));
      final built = SessionEngine.start(
        id: 's${now.wall.microsecondsSinceEpoch}',
        minutes: minutes,
        workersAvailable: current.town.workers,
        recovery: current.town.inRecoveryMode,
        now: now,
        plotIndex: plotIndex ?? TownRules.nextFreePlot(current.town, tier),
        look: look,
      );
      final session = _testLength(built);
      // The first session of a new week brings the emergency pause back.
      final town = _refilled(current.town, now);
      // Save first: a session that was not saved never starts.
      await ref.read(townRepositoryProvider).saveSessionStarted(town, session);
      state = AsyncData(current.copyWith(town: town, active: session));
    },
  );

  // Testing aid: new sessions last 1 minute while the switch is on.
  Session _testLength(Session s) =>
      ref.read(shortSessionsProvider) ? s.copyWith(plannedMinutes: 1) : s;

  TownState _refilled(TownState town, TimeStamp now) =>
      TownRules.refillEmergency(town, LocalDate.fromDateTime(now.wall));

  /// Switches on this week's emergency pause for the running session: the next
  /// absence may last 10 minutes. False when it is not allowed.
  Future<bool> armEmergencyPause() async =>
      await _once(() async {
        final current = await future;
        final active = current.active;
        if (active == null) return false;
        final armed = TownRules.armEmergency(current.town, active);
        if (armed == null) return false;
        final (town, session) = armed;
        await ref
            .read(townRepositoryProvider)
            .saveEmergencyArmed(town, session);
        state = AsyncData(current.copyWith(town: town, active: session));
        return true;
      }) ??
      false;

  /// Starts a 10-minute repair of the ruin on [plot]. Nothing is at risk.
  Future<void> startRepair(int plot) => _once(() async {
    final current = await future;
    if (current.active != null) {
      throw StateError('A session is already active');
    }
    if (!TownRules.canRepair(current.town, plot)) {
      throw StateError('Plot $plot has no ruin to repair');
    }
    final now = TimeStamp.now(ref.read(clockProvider));
    final built = SessionEngine.startRepair(
      id: 's${now.wall.microsecondsSinceEpoch}',
      plot: plot,
      now: now,
    );
    final session = _testLength(built);
    final town = _refilled(current.town, now);
    await ref.read(townRepositoryProvider).saveSessionStarted(town, session);
    state = AsyncData(current.copyWith(town: town, active: session));
  });

  /// Starts a session of [minutes] (10 to 120) that works on [landmark]. The
  /// first one takes a free 2 x 2 block (the chosen [plotIndex], or the next
  /// free one); the others continue the project. Nothing is at risk but its
  /// progress.
  Future<void> startLandmark(
    Landmark landmark,
    int minutes, {
    int? plotIndex,
  }) => _once(() async {
    final current = await future;
    if (current.active != null) {
      throw StateError('A session is already active');
    }
    if (!BuildingTier.validDurations().contains(minutes)) {
      throw StateError('$minutes minutes is not a valid length');
    }
    var town = current.town;
    if (TownRules.landmarkProject(town, landmark) == null) {
      if (!TownRules.canStartLandmark(town, landmark)) {
        throw StateError('${landmark.title} cannot be started');
      }
      final anchor =
          plotIndex ?? TownRules.nextFreePlot(town, BuildingTier.castle)!;
      town =
          TownRules.beginLandmark(town, landmark, anchor) ??
          (throw StateError('Plot $anchor is not a free 2 x 2 block'));
    }
    final project = TownRules.landmarkProject(town, landmark)!;
    final now = TimeStamp.now(ref.read(clockProvider));
    final built = SessionEngine.startLandmark(
      id: 's${now.wall.microsecondsSinceEpoch}',
      landmark: landmark,
      minutes: minutes,
      plotIndex: project.plotIndex,
      now: now,
    );
    final session = _testLength(built);
    town = _refilled(town, now);
    await ref.read(townRepositoryProvider).saveSessionStarted(town, session);
    state = AsyncData(current.copyWith(town: town, active: session));
  });

  /// Starts a land session that claims [parcel] when it completes. Nothing is
  /// at risk: if it fails, nothing changes.
  Future<void> startLand(Parcel parcel) => _once(() async {
    final current = await future;
    if (current.active != null) {
      throw StateError('A session is already active');
    }
    if (!TownRules.canClaim(current.town, parcel)) {
      throw StateError('$parcel cannot be claimed');
    }
    final now = TimeStamp.now(ref.read(clockProvider));
    final built = SessionEngine.startLand(
      id: 's${now.wall.microsecondsSinceEpoch}',
      parcel: parcel,
      minutes: TownRules.landMinutes(current.town.parcels.length),
      now: now,
    );
    final session = _testLength(built);
    final town = _refilled(current.town, now);
    await ref.read(townRepositoryProvider).saveSessionStarted(town, session);
    state = AsyncData(current.copyWith(town: town, active: session));
  });

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
      // The repository reports a missing row as a StateError (a bug elsewhere);
      // an event must never be lost to an uncaught error in the router queue.
      // ignore: avoid_catching_errors
    } on StateError catch (e) {
      _log('$e');
      return;
    }
    state = AsyncData(current.copyWith(active: updated));
    if (updated.state == SessionState.away &&
        active.state != SessionState.away) {
      await _safeNotify(
        () => ref
            .read(notifierProvider)
            .scheduleAwayWarnings(
              passAvailable: !updated.passUsed,
              emergency: updated.emergencyArmed,
            ),
      );
    }
  }

  // Keeps the lock screen status in step with the active session.
  Future<void> _syncLiveStatus(Session? active) async {
    final sink = ref.read(liveStatusSinkProvider);
    if (active == null) {
      if (_live == null) return;
      _live = null;
      await _safeLive(sink.end);
      return;
    }
    final status = LiveStatus(
      endsAt: active.startedAt.wall.add(active.planned),
      title: active.isRepair
          ? 'repair'
          : active.isLand
          ? 'land'
          : active.tier.name,
      away: active.state == SessionState.away,
    );
    if (status == _live) return;
    _live = status;
    await _safeLive(() => sink.show(status));
  }

  // The lock screen status is a convenience: its trouble is only logged.
  Future<void> _safeLive(Future<void> Function() call) async {
    try {
      await call();
    } on Object catch (error) {
      _log('Live status failed: $error');
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
    final land = finished.isLand;
    final landmark = finished.landmark;
    // The day counts from when the session ended, not from when the app
    // noticed (it may have been closed past midnight).
    final plannedEnd = finished.startedAt.wall.add(finished.planned);
    final doneAt = completed && plannedEnd.isBefore(now.wall)
        ? plannedEnd
        : now.wall;
    final settled = switch ((repair, completed)) {
      _ when landmark != null && completed => Progression.onSessionCompleted(
        TownRules.applyLandmarkCompleted(base.town, finished),
        finished,
        doneAt,
      ),
      // A failed landmark session damages it by one stage; nothing else.
      _ when landmark != null => TownRules.applyLandmarkFailed(
        base.town,
        finished,
      ),
      // Land: the claim comes first, so the day's plot has room to arrive.
      _ when land && completed => Progression.onSessionCompleted(
        TownRules.applyLandCompleted(base.town, finished),
        finished,
        doneAt,
      ),
      // A lost land session costs nothing.
      _ when land => base.town,
      (true, true) => Progression.onSessionCompleted(
        TownRules.applyRepairCompleted(base.town, finished),
        finished,
        doneAt,
      ),
      // A lost repair costs nothing.
      (true, false) => base.town,
      (false, true) => Progression.onSessionCompleted(
        TownRules.applyCompleted(base.town, finished),
        finished,
        doneAt,
      ),
      (false, false) => TownRules.applyFailed(base.town, finished),
    };
    final town = TownRules.refundEmergency(settled, finished);
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
      workersGained: completed && !repair && !land && landmark == null
          ? finished.tier.workersAddedOnSuccess
          : 0,
      newStreak: Progression.currentStreak(
        town,
        LocalDate.fromDateTime(now.wall),
      ),
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
      land: land,
      landmark: landmark,
      landmarkStage: landmark == null
          ? 0
          : (TownRules.landmarkProject(town, landmark)?.stage ??
                landmark.stages),
      landmarkFinished:
          landmark != null &&
          completed &&
          TownRules.landmarkProject(town, landmark) == null,
    );
    return FocusState(town: town, lastResult: result);
  }
}
