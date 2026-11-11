import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/data/database.dart';
import 'package:focus_town/data/mappers.dart';
import 'package:focus_town/data/town_repository.dart';
import 'package:focus_town/domain/building_tier.dart';
import 'package:focus_town/domain/local_date.dart';
import 'package:focus_town/domain/session.dart';
import 'package:focus_town/domain/testing/fake_clock.dart';
import 'package:focus_town/domain/time_stamp.dart';
import 'package:focus_town/domain/tip.dart';
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

  group('saveSessionStarted / saveSessionUpdated', () {
    late TownState town;
    setUp(() async => town = await repo.loadOrCreate());

    test('started session is the active session', () async {
      final s = session('a', SessionState.running);
      await repo.saveSessionStarted(town, s);
      expect(await repo.activeSession(), s);
    });

    test('started writes the town it was given', () async {
      await repo.saveSessionStarted(
        town.copyWith(xp: 10, workers: 2),
        session('a', SessionState.running),
      );
      final back = await repo.loadOrCreate();
      expect(back.xp, 10);
      expect(back.workers, 2);
    });

    test('rewriting the town keeps existing completedAt', () async {
      final before = (await db.select(db.buildings).getSingle()).completedAt;
      clock.advance(const Duration(days: 1));
      await repo.saveSessionStarted(town, session('a', SessionState.running));
      final after = (await db.select(db.buildings).getSingle()).completedAt;
      expect(after, before);
    });

    test('duplicate session id throws and leaves the town untouched', () async {
      await repo.saveSessionStarted(town, session('a', SessionState.running));
      await expectLater(
        repo.saveSessionStarted(
          town.copyWith(xp: 99),
          session('a', SessionState.running),
        ),
        throwsA(isA<Object>()),
      );
      expect((await repo.loadOrCreate()).xp, 0);
    });

    test('updated away session keeps leftAt', () async {
      final running = session('a', SessionState.running);
      await repo.saveSessionStarted(town, running);
      clock.advance(const Duration(minutes: 3));
      final away = running.copyWith(
        state: SessionState.away,
        leftAt: TimeStamp.now(clock),
      );
      await repo.saveSessionUpdated(away);
      final active = await repo.activeSession();
      expect(active, away);
      expect(active!.state, SessionState.away);
    });

    test('updating to completed clears the active session', () async {
      final running = session('a', SessionState.running);
      await repo.saveSessionStarted(town, running);
      await repo.saveSessionUpdated(
        running.copyWith(
          state: SessionState.completed,
          outcomeReason: OutcomeReason.completed,
        ),
      );
      expect(await repo.activeSession(), isNull);
    });

    test('updating an unknown session throws', () async {
      await expectLater(
        repo.saveSessionUpdated(session('nope', SessionState.away)),
        throwsStateError,
      );
    });
  });

  group('saveSessionResolved', () {
    late TownState town;
    late Session running;
    setUp(() async {
      town = await repo.loadOrCreate();
      running = session('a', SessionState.running);
      await repo.saveSessionStarted(town, running);
    });

    test(
      'completed save reloads as the new town; session not active',
      () async {
        clock.advance(const Duration(minutes: 25));
        final next = town.copyWith(
          workers: 4,
          plotsUnlocked: 7,
          xp: 25,
          streakCount: 1,
          lastStreakDate: LocalDate.parse('2026-01-01'),
          buildings: [
            ...town.buildings,
            const TownBuilding(
              id: 'a',
              tier: BuildingTier.house,
              status: BuildingStatus.complete,
              plotIndex: 1,
            ),
          ],
        );
        final done = running.copyWith(
          state: SessionState.completed,
          outcomeReason: OutcomeReason.completed,
        );
        await repo.saveSessionResolved(next, done);
        expect(await repo.loadOrCreate(), next);
        expect(await repo.activeSession(), isNull);
        final row = await db.select(db.sessions).getSingle();
        expect(row.state, 'completed');
        expect(row.resolvedAt, clock.nowWall().millisecondsSinceEpoch);
      },
    );

    test('failed save with a ruin round trips', () async {
      final next = town.copyWith(
        workers: 1,
        inRecoveryMode: true,
        buildings: [
          ...town.buildings,
          const TownBuilding(
            id: 'a',
            tier: BuildingTier.house,
            status: BuildingStatus.ruin,
            plotIndex: 2,
          ),
        ],
      );
      await repo.saveSessionResolved(
        next,
        running.copyWith(
          state: SessionState.failed,
          outcomeReason: OutcomeReason.leftTooLong,
        ),
      );
      expect(await repo.loadOrCreate(), next);
    });

    test('queued buildings keep their order across saves', () async {
      final done = running.copyWith(state: SessionState.completed);
      const first = QueuedBuilding(id: 'zz', tier: BuildingTier.hut);
      const second = QueuedBuilding(id: 'aa', tier: BuildingTier.hut);
      await repo.saveSessionResolved(town.copyWith(queue: [first]), done);
      clock.advance(const Duration(minutes: 5));
      await repo.saveSessionResolved(
        town.copyWith(queue: [first, second]),
        done,
      );
      expect((await repo.loadOrCreate()).queue, [first, second]);
    });

    test('createdAt and onboardingDone survive', () async {
      await (db.update(db.towns)..where((t) => t.id.equals(1))).write(
        const TownsCompanion(onboardingDone: Value(true)),
      );
      final created = (await db.select(db.towns).getSingle()).createdAt;
      clock.advance(const Duration(days: 2));
      await repo.saveSessionResolved(
        town.copyWith(xp: 5),
        running.copyWith(state: SessionState.completed),
      );
      final row = await db.select(db.towns).getSingle();
      expect(row.createdAt, created);
      expect(row.onboardingDone, isTrue);
      expect(row.xp, 5);
    });

    test('a failure rolls back town, buildings and session', () async {
      final towns = await db.select(db.towns).get();
      final buildings = await db.select(db.buildings).get();
      final sessions = await db.select(db.sessions).get();
      const dup = TownBuilding(
        id: 'dup',
        tier: BuildingTier.hut,
        status: BuildingStatus.complete,
        plotIndex: 1,
      );
      await expectLater(
        repo.saveSessionResolved(
          town.copyWith(xp: 99, buildings: [dup, dup]),
          running.copyWith(state: SessionState.failed),
        ),
        throwsA(isA<Object>()),
      );
      expect(await db.select(db.towns).get(), towns);
      expect(await db.select(db.buildings).get(), buildings);
      expect(await db.select(db.sessions).get(), sessions);
    });
  });

  group('last duration', () {
    test('a new town remembers 25 minutes', () async {
      await repo.loadOrCreate();
      expect(await repo.lastDurationMinutes(), 25);
    });

    test('saveLastDuration is read back', () async {
      await repo.loadOrCreate();
      await repo.saveLastDuration(40);
      expect(await repo.lastDurationMinutes(), 40);
    });

    test('it survives a started and a resolved session', () async {
      final town = await repo.loadOrCreate();
      await repo.saveLastDuration(40);
      final s = session('s1', SessionState.running);
      await repo.saveSessionStarted(town, s);
      await repo.saveSessionResolved(
        town.copyWith(xp: 10),
        s.copyWith(state: SessionState.completed),
      );
      expect(await repo.lastDurationMinutes(), 40);
    });

    test('without a stored town it is 25 and nothing is created', () async {
      expect(await repo.lastDurationMinutes(), 25);
      expect(await db.select(db.towns).get(), isEmpty);
    });
  });

  group('sessionCount', () {
    test('no sessions is 0', () async {
      expect(await repo.sessionCount(), 0);
    });

    test('counts every row, finished or active', () async {
      await insert(session('a', SessionState.completed));
      await insert(session('b', SessionState.failed));
      await insert(session('c', SessionState.running));
      expect(await repo.sessionCount(), 3);
    });
  });

  group('onboarding and tips', () {
    test('onboarding starts not done and setOnboardingDone persists', () async {
      await repo.loadOrCreate();
      expect(await repo.isOnboardingDone(), isFalse);
      await repo.setOnboardingDone();
      expect(await repo.isOnboardingDone(), isTrue);
    });

    test('no stored town means not done and nothing shown', () async {
      expect(await repo.isOnboardingDone(), isFalse);
      expect(await repo.shownTips(), isEmpty);
    });

    test('each tip is marked on its own', () async {
      await repo.loadOrCreate();
      expect(await repo.shownTips(), isEmpty);
      await repo.markTipShown(Tip.growth);
      expect(await repo.shownTips(), {Tip.growth});
      await repo.markTipShown(Tip.pass);
      await repo.markTipShown(Tip.recovery);
      await repo.markTipShown(Tip.notificationNote);
      expect(await repo.shownTips(), Tip.values.toSet());
    });

    test('a started and a resolved session keep flags', () async {
      final town = await repo.loadOrCreate();
      await repo.setOnboardingDone();
      await repo.markTipShown(Tip.pass);
      final s = session('s1', SessionState.running);
      await repo.saveSessionStarted(town, s);
      await repo.saveSessionResolved(
        town.copyWith(xp: 10),
        s.copyWith(state: SessionState.completed),
      );
      expect(await repo.isOnboardingDone(), isTrue);
      expect(await repo.shownTips(), {Tip.pass});
    });
  });
}
