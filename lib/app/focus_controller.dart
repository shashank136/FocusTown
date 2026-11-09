import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focus_town/app/focus_state.dart';
import 'package:focus_town/app/providers.dart';
import 'package:focus_town/domain/local_date.dart';
import 'package:focus_town/domain/progression.dart';
import 'package:focus_town/domain/session.dart';
import 'package:focus_town/domain/session_engine.dart';
import 'package:focus_town/domain/time_stamp.dart';
import 'package:focus_town/domain/town_rules.dart';

/// Owns the town and the live session; the UI only reads and calls this.
class FocusController extends AsyncNotifier<FocusState> {
  @override
  Future<FocusState> build() async {
    final town = await ref.watch(townRepositoryProvider).loadOrCreate();
    return FocusState(town: town);
  }

  /// Dismisses the last result.
  void clearResult() {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(clearLastResult: true));
  }

  /// Starts a session of [minutes]; it exists only once it is saved.
  Future<void> start(int minutes) async {
    final current = await future;
    if (current.active != null) {
      throw StateError('A session is already active');
    }
    if (!TownRules.canStart(current.town, minutes)) {
      throw StateError('Cannot start $minutes minutes with this town');
    }
    final now = TimeStamp.now(ref.read(clockProvider));
    final session = SessionEngine.start(
      id: 's${now.wall.microsecondsSinceEpoch}',
      minutes: minutes,
      workersAvailable: current.town.workers,
      recovery: current.town.inRecoveryMode,
      now: now,
    );
    // Save first: a session that was not saved never starts.
    await ref
        .read(townRepositoryProvider)
        .saveSessionStarted(current.town, session);
    state = AsyncData(current.copyWith(active: session));
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
      _forward(SessionEngine.onLocked, at);

  /// A phone call is allowed; nothing changes.
  Future<void> onCallStarted({TimeStamp? at}) =>
      _forward(SessionEngine.onCallStarted, at);

  /// The user left the app with the phone unlocked.
  Future<void> onBackgroundedUnlocked({TimeStamp? at}) =>
      _forward(SessionEngine.onBackgroundedUnlocked, at);

  /// The user came back to the app.
  Future<void> onForegrounded({TimeStamp? at}) =>
      _forward(SessionEngine.onForegrounded, at, resolveAfter: true);

  // Applies an engine event to the active session, then saves or finishes.
  Future<void> _forward(
    Session Function(Session, TimeStamp) event,
    TimeStamp? at, {
    bool resolveAfter = false,
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
    if (updated == active) return;
    if (updated.isFinished) {
      state = AsyncData(await _finish(current, updated, t));
      return;
    }
    await ref.read(townRepositoryProvider).saveSessionUpdated(updated);
    state = AsyncData(current.copyWith(active: updated));
  }

  /// Applies the town rules, saves everything atomically, builds the result.
  Future<FocusState> _finish(
    FocusState base,
    Session finished,
    TimeStamp now,
  ) async {
    final completed = finished.state == SessionState.completed;
    final town = completed
        ? Progression.onSessionCompleted(
            TownRules.applyCompleted(base.town, finished),
            finished,
            now.wall,
          )
        : TownRules.applyFailed(base.town, finished);
    await ref.read(townRepositoryProvider).saveSessionResolved(town, finished);
    final queued = town.queue.any((q) => q.id == finished.id);
    final result = SessionResult(
      outcome: !completed
          ? SessionOutcome.failed
          : queued
          ? SessionOutcome.queued
          : SessionOutcome.completed,
      tier: finished.tier,
      workersLost: completed ? 0 : finished.workersAssigned,
      workersGained: completed ? finished.tier.workersAddedOnSuccess : 0,
      newStreak: Progression.currentStreak(
        town,
        LocalDate.fromDateTime(now.wall),
      ),
      plotGranted: town.plotsUnlocked > base.town.plotsUnlocked,
    );
    return FocusState(town: town, lastResult: result);
  }
}
