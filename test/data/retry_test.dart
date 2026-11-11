import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/data/database.dart';
import 'package:focus_town/data/save_failed_exception.dart';
import 'package:focus_town/data/town_repository.dart';
import 'package:focus_town/domain/building_tier.dart';
import 'package:focus_town/domain/session.dart';
import 'package:focus_town/domain/testing/fake_clock.dart';
import 'package:focus_town/domain/time_stamp.dart';
import 'package:focus_town/domain/tip.dart';

/// Fails the next [failures] write statements.
class FailingWrites extends QueryInterceptor {
  int failures = 0;

  Future<T> _maybe<T>(Future<T> Function() run) {
    if (failures > 0) {
      failures--;
      throw StateError('disk is full');
    }
    return run();
  }

  @override
  Future<int> runInsert(
    QueryExecutor e,
    String statement,
    List<Object?> args,
  ) => _maybe(() => super.runInsert(e, statement, args));

  @override
  Future<int> runUpdate(
    QueryExecutor e,
    String statement,
    List<Object?> args,
  ) => _maybe(() => super.runUpdate(e, statement, args));

  @override
  Future<void> runCustom(
    QueryExecutor e,
    String statement,
    List<Object?> args,
  ) => _maybe(() => super.runCustom(e, statement, args));
}

void main() {
  late FailingWrites fail;
  late AppDatabase db;
  late FakeClock clock;
  late TownRepository repo;
  setUp(() {
    fail = FailingWrites();
    db = AppDatabase(NativeDatabase.memory().interceptWith(fail));
    clock = FakeClock();
    repo = TownRepository(db, clock);
  });
  tearDown(() => db.close());

  Session session() => Session(
    id: 's1',
    plannedMinutes: 25,
    tier: BuildingTier.house,
    workersAssigned: 2,
    state: SessionState.running,
    startedAt: TimeStamp.now(clock),
  );

  test('one failed write is retried and nobody notices', () async {
    final town = await repo.loadOrCreate();
    fail.failures = 1;
    await repo.saveSessionStarted(town, session());
    expect((await repo.activeSession())!.id, 's1');
  });

  test('two failed writes throw SaveFailedException', () async {
    final town = await repo.loadOrCreate();
    fail.failures = 2;
    await expectLater(
      repo.saveSessionStarted(town, session()),
      throwsA(isA<SaveFailedException>()),
    );
    expect(await repo.activeSession(), isNull);
  });

  test('the message is the one the user reads', () {
    expect(
      const SaveFailedException().toString(),
      "Couldn't save your session. Try again.",
    );
  });

  test('every write method retries once', () async {
    final town = await repo.loadOrCreate();
    final s = session();
    await repo.saveSessionStarted(town, s);
    fail.failures = 1;
    await repo.saveSessionUpdated(s.copyWith(state: SessionState.away));
    fail.failures = 1;
    await repo.saveSessionResolved(
      town.copyWith(xp: 5),
      s.copyWith(state: SessionState.completed),
    );
    fail.failures = 1;
    await repo.saveLastDuration(40);
    fail.failures = 1;
    await repo.setOnboardingDone();
    fail.failures = 1;
    await repo.markTipShown(Tip.pass);
    expect(await repo.lastDurationMinutes(), 40);
    expect(await repo.isOnboardingDone(), isTrue);
    expect(await repo.shownTips(), {Tip.pass});
  });

  test('a missing session is still a StateError, not a save failure', () {
    expect(
      repo.saveSessionUpdated(session()),
      throwsA(isA<StateError>()),
    );
  });
}
