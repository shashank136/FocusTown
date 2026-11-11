import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/data/database.dart';
import 'package:focus_town/data/db_recovery.dart';
import 'package:focus_town/domain/testing/fake_clock.dart';

late Directory _dir;

File _f(String name) => File('${_dir.path}/$name');

AppDatabase _real(File f) => AppDatabase(NativeDatabase(f));

Future<OpenResult> _open({int version = 4, AppDatabase Function(File)? open}) =>
    openDatabaseSafely(dir: _dir, schemaVersion: version, open: open ?? _real);

void main() {
  setUp(() => _dir = Directory.systemTemp.createTempSync('recovery'));
  tearDown(() => _dir.deleteSync(recursive: true));

  test('first launch opens fine and writes the version marker', () async {
    final r = await _open();
    expect(r.startedFresh, isFalse);
    expect(_f('schema_version.txt').readAsStringSync(), '4');
    expect(_f('focus_town.backup.sqlite').existsSync(), isFalse);
    await r.db.close();
  });

  test('a version bump backs the file up first', () async {
    await (await _open(version: 3)).db.close();
    final before = _f('focus_town.sqlite').readAsBytesSync();
    final r = await _open();
    expect(_f('focus_town.backup.sqlite').readAsBytesSync(), before);
    expect(_f('schema_version.txt').readAsStringSync(), '4');
    await r.db.close();
  });

  test('the backup is kept when the version has not changed', () async {
    await (await _open()).db.close();
    _f('focus_town.backup.sqlite').writeAsStringSync('old');
    await (await _open()).db.close();
    expect(_f('focus_town.backup.sqlite').readAsStringSync(), 'old');
  });

  test('a failed upgrade restores the backup and opens it', () async {
    await (await openDatabaseSafely(
      dir: _dir,
      schemaVersion: 3,
      open: _real,
      clock: FakeClock(start: DateTime(2020)),
    )).db.close();
    var calls = 0;
    final r = await _open(
      open: (f) {
        if (++calls == 1) {
          f.writeAsStringSync('half migrated');
          throw StateError('migration failed');
        }
        return _real(f);
      },
    );
    expect(r.startedFresh, isFalse);
    final town = await r.db.select(r.db.towns).getSingle();
    expect(town.createdAt, DateTime(2020).millisecondsSinceEpoch);
    await r.db.close();
  });

  test('with no backup the bad file is kept and a fresh town starts', () async {
    _f('focus_town.sqlite').writeAsStringSync('half migrated');
    _f('schema_version.txt').writeAsStringSync('4');
    final r = await _open();
    expect(r.startedFresh, isTrue);
    expect(_f('focus_town.corrupt.sqlite').readAsStringSync(), 'half migrated');
    await r.db.close();
  });

  test('random bytes with a backup that also fails start fresh', () async {
    await (await _open(version: 3)).db.close();
    _f('focus_town.backup.sqlite').writeAsBytesSync([1, 2, 3, 4]);
    _f('focus_town.sqlite').writeAsBytesSync([9, 9, 9, 9]);
    _f('schema_version.txt').writeAsStringSync('3');
    final r = await _open();
    expect(r.startedFresh, isTrue);
    expect(_f('schema_version.txt').readAsStringSync(), '4');
    await r.db.close();
  });
}
