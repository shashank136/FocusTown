import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/data/database.dart';
import 'package:focus_town/data/mappers.dart';
import 'package:focus_town/data/town_repository.dart';
import 'package:focus_town/domain/building_tier.dart';
import 'package:focus_town/domain/session.dart';
import 'package:focus_town/domain/testing/fake_clock.dart';
import 'package:focus_town/domain/time_stamp.dart';
import 'package:focus_town/domain/town.dart';

void main() {
  late AppDatabase db;
  late FakeClock clock;
  late TownRepository repo;
  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    clock = FakeClock();
    repo = TownRepository(db, clock);
  });
  tearDown(() => db.close());

  Session session(String id, SessionState state) => Session(
    id: id,
    plannedMinutes: 25,
    tier: BuildingTier.house,
    workersAssigned: 2,
    state: state,
    startedAt: TimeStamp.now(clock),
  );

  Future<void> insert(Session s) =>
      db.into(db.sessions).insert(sessionToRow(s));

  group('loadOrCreate', () {
    test('first call seeds the initial town', () async {
      expect(await repo.loadOrCreate(), TownState.initial());
    });

    test('second call does not seed again', () async {
      await repo.loadOrCreate();
      await repo.loadOrCreate();
      expect(await db.select(db.towns).get(), hasLength(1));
      expect(await db.select(db.buildings).get(), hasLength(1));
    });

    test('seed row has id 1, clock createdAt, onboarding not done', () async {
      await repo.loadOrCreate();
      final row = await db.select(db.towns).getSingle();
      expect(row.id, 1);
      expect(row.createdAt, clock.nowWall().millisecondsSinceEpoch);
      expect(row.onboardingDone, isFalse);
      final b = await db.select(db.buildings).getSingle();
      expect(b.id, 'starter');
      expect(b.completedAt, clock.nowWall().millisecondsSinceEpoch);
    });

    test(
      'returns stored values, not a fresh seed, once a row exists',
      () async {
        await repo.loadOrCreate();
        await (db.update(db.towns)..where((t) => t.id.equals(1))).write(
          const TownsCompanion(workerCount: Value(7), xp: Value(40)),
        );
        final town = await repo.loadOrCreate();
        expect(town.workers, 7);
        expect(town.xp, 40);
      },
    );
  });

  group('activeSession', () {
    test('null with no sessions', () async {
      expect(await repo.activeSession(), isNull);
    });

    for (final state in [SessionState.running, SessionState.away]) {
      test('returns a ${state.name} session', () async {
        final s = session('a', state);
        await insert(s);
        expect(await repo.activeSession(), s);
      });
    }

    for (final state in [SessionState.completed, SessionState.failed]) {
      test('ignores a ${state.name} session', () async {
        await insert(session('a', state));
        expect(await repo.activeSession(), isNull);
      });
    }

    test('finds the active one among finished ones', () async {
      await insert(session('old', SessionState.completed));
      final live = session('live', SessionState.running);
      await insert(live);
      expect(await repo.activeSession(), live);
    });
  });
}
