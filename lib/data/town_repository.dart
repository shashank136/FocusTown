import 'package:drift/drift.dart';
import 'package:focus_town/data/database.dart';
import 'package:focus_town/data/mappers.dart';
import 'package:focus_town/domain/clock.dart';
import 'package:focus_town/domain/session.dart';
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
  Future<void> saveLastDuration(int minutes) =>
      (_db.update(_db.towns)..where((t) => t.id.equals(_townId))).write(
        TownsCompanion(lastDurationMinutes: Value(minutes)),
      );

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
  Future<void> saveSessionStarted(TownState town, Session session) =>
      _db.transaction(() async {
        await _db.into(_db.sessions).insert(sessionToRow(session));
        await _writeTown(town);
      });

  /// Updates the stored row of an existing [session].
  Future<void> saveSessionUpdated(Session session) async {
    final changed = await (_db.update(
      _db.sessions,
    )..where((s) => s.id.equals(session.id))).write(sessionToRow(session));
    if (changed == 0) throw StateError('No stored session ${session.id}');
  }

  /// Stores the finished [session] and the whole new [town] atomically.
  Future<void> saveSessionResolved(TownState town, Session session) =>
      _db.transaction(() async {
        await _db
            .into(_db.sessions)
            .insertOnConflictUpdate(
              sessionToRow(session, resolvedAt: _clock.nowWall()),
            );
        await _writeTown(town);
      });

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
