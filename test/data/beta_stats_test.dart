import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/data/database.dart';
import 'package:focus_town/data/mappers.dart';
import 'package:focus_town/data/town_repository.dart';
import 'package:focus_town/domain/building_tier.dart';
import 'package:focus_town/domain/session.dart';
import 'package:focus_town/domain/testing/fake_clock.dart';
import 'package:focus_town/domain/time_stamp.dart';

final _first = DateTime(2026, 3, 1, 9);

void main() {
  late AppDatabase db;
  late TownRepository repo;
  var n = 0;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    repo = TownRepository(db, FakeClock(start: _first));
    await repo.loadOrCreate();
  });

  Future<void> add(SessionState state, DateTime at) => db
      .into(db.sessions)
      .insert(
        sessionToRow(
          Session(
            id: 's${n++}',
            plannedMinutes: 25,
            tier: BuildingTier.house,
            workersAssigned: 1,
            state: state,
            startedAt: TimeStamp(at, Duration.zero),
          ),
        ),
      );

  test('an empty database gives zeros and the first-open time', () async {
    final s = await repo.betaStats();
    expect(
      [s.sessionsStarted, s.completed, s.failed, s.daysActive],
      [0, 0, 0, 0],
    );
    expect(s.completionRate, 0);
    expect(s.firstOpen, _first);
    expect(s.returnedAfterDay7, isFalse);
  });

  test('3 completed and 1 failed make a rate of 0.75', () async {
    for (var i = 0; i < 3; i++) {
      await add(SessionState.completed, _first);
    }
    await add(SessionState.failed, _first);
    final s = await repo.betaStats();
    expect(s.sessionsStarted, 4);
    expect(s.completed, 3);
    expect(s.failed, 1);
    expect(s.completionRate, 0.75);
  });

  test('a running session counts as started but not finished', () async {
    await add(SessionState.running, _first);
    await add(SessionState.away, _first);
    await add(SessionState.completed, _first);
    final s = await repo.betaStats();
    expect(s.sessionsStarted, 3);
    expect(s.completionRate, 1);
  });

  test('days active counts distinct calendar days', () async {
    await add(SessionState.completed, _first);
    await add(SessionState.completed, _first.add(const Duration(hours: 3)));
    await add(SessionState.completed, DateTime(2026, 3, 2, 8));
    await add(SessionState.failed, DateTime(2026, 3, 5, 23));
    expect((await repo.betaStats()).daysActive, 3);
  });

  test('a session 7 days after the first open is a day-7 return', () async {
    await add(SessionState.completed, DateTime(2026, 3, 8, 7));
    expect((await repo.betaStats()).returnedAfterDay7, isTrue);
  });

  test('a session 6 days after the first open is not', () async {
    await add(SessionState.completed, DateTime(2026, 3, 7, 23));
    expect((await repo.betaStats()).returnedAfterDay7, isFalse);
  });
}
