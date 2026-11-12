import 'dart:io';

import 'package:focus_town/data/database.dart';
import 'package:focus_town/data/town_repository.dart';
import 'package:focus_town/domain/clock.dart';
import 'package:focus_town/platform/local_log.dart';

/// An opened database, and whether the old town had to be given up.
class OpenResult {
  /// Creates a result.
  const new(this.db, {required this.startedFresh, this.restored = false});

  /// The open database.
  final AppDatabase db;

  /// True when the saved town could not be opened or restored.
  final bool startedFresh;

  /// True when the town came back from the backup, which may be a little
  /// older than the last session.
  final bool restored;
}

// The database file and its write-ahead-log companions.
const _suffixes = ['', '-wal', '-shm'];

/// Opens the database in [dir] without ever losing the town to a failed
/// upgrade: it backs the file up before a schema change, restores the backup
/// if opening fails, and only then starts a fresh town (keeping the broken
/// file as `focus_town.corrupt.sqlite`).
Future<OpenResult> openDatabaseSafely({
  required Directory dir,
  required int schemaVersion,
  required AppDatabase Function(File) open,
  Clock? clock,
  LocalLog? log,
}) async {
  String p(String name) => '${dir.path}/$name';
  final dbFile = File(p('focus_town.sqlite'));
  final marker = File(p('schema_version.txt'));
  final backup = p('focus_town.backup.sqlite');
  final seen = marker.existsSync() ? marker.readAsStringSync().trim() : null;

  // Nothing has the file open yet, so a plain copy is a consistent snapshot.
  if (dbFile.existsSync() && seen != '$schemaVersion') {
    _copy(dbFile.path, backup);
    log?.write('db: backed up before schema $schemaVersion');
  }

  Future<AppDatabase?> attempt() async {
    AppDatabase? db;
    try {
      db = open(dbFile);
      await db.customSelect('SELECT 1').get();
      await TownRepository(db, clock ?? SystemClock()).loadOrCreate();
      marker.writeAsStringSync('$schemaVersion');
      await _refreshBackup(db, backup, log);
      return db;
    } on Object catch (e) {
      log?.write('db: open failed: $e');
      await db?.close().catchError((_) {});
      return null;
    }
  }

  final first = await attempt();
  if (first != null) return OpenResult(first, startedFresh: false);

  if (File(backup).existsSync()) {
    _keepBroken(dbFile.path, p('focus_town.corrupt.sqlite'));
    _copy(backup, dbFile.path);
    final restored = await attempt();
    if (restored != null) {
      log?.write('db: restored the backup');
      return OpenResult(restored, startedFresh: false, restored: true);
    }
  }

  _keepBroken(dbFile.path, p('focus_town.corrupt.sqlite'));
  log?.write('db: started a fresh town');
  final fresh = open(dbFile);
  await TownRepository(fresh, clock ?? SystemClock()).loadOrCreate();
  marker.writeAsStringSync('$schemaVersion');
  return OpenResult(fresh, startedFresh: true);
}

// Keeps the backup as recent as the last launch that opened cleanly, so a
// later failure never rolls the town back to the last schema change. `VACUUM
// INTO` writes one consistent file even while the database is open.
Future<void> _refreshBackup(
  AppDatabase db,
  String backup,
  LocalLog? log,
) async {
  final tmp = File('$backup.tmp');
  try {
    if (tmp.existsSync()) tmp.deleteSync();
    await db.customStatement('VACUUM INTO ?', [tmp.path]);
    for (final s in _suffixes) {
      final old = File('$backup$s');
      if (s.isNotEmpty && old.existsSync()) old.deleteSync();
    }
    tmp.renameSync(backup);
  } on Object catch (e) {
    log?.write('db: backup refresh failed: $e');
    if (tmp.existsSync()) tmp.deleteSync();
  }
}

void _copy(String from, String to) {
  for (final s in _suffixes) {
    final src = File('$from$s');
    final dst = File('$to$s');
    if (src.existsSync()) {
      src.copySync(dst.path);
    } else if (dst.existsSync()) {
      dst.deleteSync();
    }
  }
}

// Moves the database aside, so a later fix can still recover from it.
void _keepBroken(String from, String to) {
  for (final s in _suffixes) {
    final src = File('$from$s');
    if (!src.existsSync()) continue;
    final dst = File('$to$s');
    if (dst.existsSync()) dst.deleteSync();
    src.renameSync(dst.path);
  }
}
