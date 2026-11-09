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
}
