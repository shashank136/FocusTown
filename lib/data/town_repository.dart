import 'package:drift/drift.dart';
import 'package:focus_town/data/database.dart';
import 'package:focus_town/data/mappers.dart';
import 'package:focus_town/data/save_failed_exception.dart';
import 'package:focus_town/domain/beta_stats.dart';
import 'package:focus_town/domain/clock.dart';
import 'package:focus_town/domain/local_date.dart';
import 'package:focus_town/domain/session.dart';
import 'package:focus_town/domain/tip.dart';
import 'package:focus_town/domain/town.dart';

/// Reads and writes the town and sessions in the local database.
class TownRepository {
  /// Creates a repository over [_db], using [_clock] for timestamps.
  new(this._db, this._clock);

  final AppDatabase _db;
  final Clock _clock;

  static const _townId = 1;

  /// Returns the stored town, seeding the starting town on first run.
  Future<TownState> loadOrCreate() => _db.transaction(() async {
    var town = await _db.select(_db.towns).getSingleOrNull();
    if (town == null) {
      final now = _clock.nowWall();
      final seed = TownState.initial();
      await _db
          .into(_db.towns)
          .insert(
            townToRow(seed).copyWith(
              id: const Value(_townId),
              createdAt: Value(now.millisecondsSinceEpoch),
            ),
          );
      await _db.batch(
        (b) => b.insertAll(_db.buildings, buildingsToRows(seed, now: now)),
      );
      town = await _db.select(_db.towns).getSingle();
    }
    final buildings = await _db.select(_db.buildings).get();
    return townFromRows(town, buildings);
  });

  /// The duration the picker opens on (25 until the user chose another, or
  /// before any town exists).
  Future<int> lastDurationMinutes() async {
    final row = await _db.select(_db.towns).getSingleOrNull();
    return row?.lastDurationMinutes ?? 25;
  }

  /// Remembers [minutes] for the next time the picker opens.
  Future<void> saveLastDuration(int minutes) => _write(
    () => (_db.update(_db.towns)..where((t) => t.id.equals(_townId))).write(
      TownsCompanion(lastDurationMinutes: Value(minutes)),
    ),
  );

  /// On-device beta numbers, computed from the stored sessions.
  Future<BetaStats> betaStats() async {
    final sessions = await _db.select(_db.sessions).get();
    final town = await _db.select(_db.towns).getSingle();
    final firstOpen = DateTime.fromMillisecondsSinceEpoch(town.createdAt);
    final first = LocalDate.fromDateTime(firstOpen);
    final days = {
      for (final s in sessions)
        LocalDate.fromDateTime(
          DateTime.fromMillisecondsSinceEpoch(s.startedAtWall),
        ).toIso(),
    };
    final completed = sessions
        .where((s) => s.state == SessionState.completed.name)
        .length;
    final failed = sessions
        .where((s) => s.state == SessionState.failed.name)
        .length;
    return BetaStats(
      sessionsStarted: sessions.length,
      completed: completed,
      failed: failed,
      completionRate: completed + failed == 0
          ? 0
          : completed / (completed + failed),
      daysActive: days.length,
      firstOpen: firstOpen,
      returnedAfterDay7: days.any(
        (d) => first.daysBetween(LocalDate.parse(d)) >= 7,
      ),
    );
  }

  // Runs a write; on any failure tries once more, then gives up with a message
  // the user can read.
  Future<T> _write<T>(Future<T> Function() op) async {
    try {
      return await op();
    } on Object {
      try {
        return await op();
      } on Object {
        throw const SaveFailedException();
      }
    }
  }

  /// Whether the first-run onboarding was finished.
  Future<bool> isOnboardingDone() async {
    final row = await _db.select(_db.towns).getSingleOrNull();
    return row?.onboardingDone ?? false;
  }

  /// Remembers that onboarding is finished.
  Future<void> setOnboardingDone() => _write(
    () => (_db.update(_db.towns)..where((t) => t.id.equals(_townId))).write(
      const TownsCompanion(onboardingDone: Value(true)),
    ),
  );

  /// The tips already shown.
  Future<Set<Tip>> shownTips() async {
    final row = await _db.select(_db.towns).getSingleOrNull();
    if (row == null) return {};
    return {
      if (row.tipPassShown) Tip.pass,
      if (row.tipGrowthShown) Tip.growth,
      if (row.tipRecoveryShown) Tip.recovery,
      if (row.notificationNoteShown) Tip.notificationNote,
    };
  }

  /// Remembers that [tip] was shown.
  Future<void> markTipShown(Tip tip) => _write(
    () => (_db.update(_db.towns)..where((t) => t.id.equals(_townId))).write(
        switch (tip) {
          Tip.pass => const TownsCompanion(tipPassShown: Value(true)),
          Tip.growth => const TownsCompanion(tipGrowthShown: Value(true)),
          Tip.recovery => const TownsCompanion(tipRecoveryShown: Value(true)),
          Tip.notificationNote => const TownsCompanion(
            notificationNoteShown: Value(true),
          ),
        },
      ),
  );

  /// How many sessions were ever stored, the active one included.
  Future<int> sessionCount() {
    final count = _db.sessions.id.count();
    return (_db.selectOnly(
      _db.sessions,
    )..addColumns([count])).map((row) => row.read(count)!).getSingle();
  }

  /// The session that is running or away, if any.
  Future<Session?> activeSession() async {
    final active = [SessionState.running.name, SessionState.away.name];
    final row =
        await (_db.select(_db.sessions)
              ..where((s) => s.state.isIn(active))
              ..limit(1))
            .getSingleOrNull();
    return row == null ? null : sessionFromRow(row);
  }

  /// Stores a new running [session] and the [town] it was started from.
  Future<void> saveSessionStarted(TownState town, Session session) => _write(
    () => _db.transaction(() async {
      await _db.into(_db.sessions).insert(sessionToRow(session));
      await _writeTown(town);
    }),
  );

  /// Updates the stored row of an existing [session].
  Future<void> saveSessionUpdated(Session session) async {
    final changed = await _write(
      () => (_db.update(
        _db.sessions,
      )..where((s) => s.id.equals(session.id))).write(sessionToRow(session)),
    );
    if (changed == 0) throw StateError('No stored session ${session.id}');
  }

  /// Stores the finished [session] and the whole new [town] atomically.
  Future<void> saveSessionResolved(TownState town, Session session) => _write(
    () => _db.transaction(() async {
      await _db
          .into(_db.sessions)
          .insertOnConflictUpdate(
            sessionToRow(session, resolvedAt: _clock.nowWall()),
          );
      await _writeTown(town);
    }),
  );

  /// Overwrites the town row and replaces all building rows, keeping the
  /// `completedAt` of buildings that already exist.
  Future<void> _writeTown(TownState town) async {
    await (_db.update(
      _db.towns,
    )..where((t) => t.id.equals(_townId))).write(townToRow(town));
    final existing = {
      for (final b in await _db.select(_db.buildings).get())
        b.id: b.completedAt,
    };
    final rows = [
      for (final r in buildingsToRows(town, now: _clock.nowWall()))
        if (existing[r.id.value] case final at?)
          r.copyWith(completedAt: Value(at))
        else
          r,
    ];
    await _db.delete(_db.buildings).go();
    await _db.batch((b) => b.insertAll(_db.buildings, rows));
  }
}
