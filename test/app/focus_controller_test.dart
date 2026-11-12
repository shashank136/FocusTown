import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/app/focus_controller.dart';
import 'package:focus_town/app/focus_state.dart';
import 'package:focus_town/app/providers.dart';
import 'package:focus_town/data/database.dart';
import 'package:focus_town/data/mappers.dart';
import 'package:focus_town/data/town_repository.dart';
import 'package:focus_town/domain/building_tier.dart';
import 'package:focus_town/domain/clock.dart';
import 'package:focus_town/domain/session.dart';
import 'package:focus_town/domain/testing/fake_clock.dart';
import 'package:focus_town/domain/time_stamp.dart';
import 'package:focus_town/domain/town.dart';
import 'package:focus_town/platform/testing/fake_notifier.dart';

const _result = SessionResult(
  outcome: SessionOutcome.completed,
  tier: BuildingTier.hut,
  workersLost: 0,
  workersGained: 1,
  newStreak: 1,
);

/// Starts with a result already set, so `clearResult` can be tested alone.
class _SeededController extends FocusController {
  @override
  Future<FocusState> build() async =>
      FocusState(town: TownState.initial(), lastResult: _result);
}

late AppDatabase _db;
late FakeClock _clock;

/// Repository whose session save always fails.
class _FailingRepository extends TownRepository {
  // ignore: use_super_parameters, super params are private so names differ
  new(AppDatabase db, Clock clock) : super(db, clock);

  @override
  Future<void> saveSessionStarted(TownState town, Session session) =>
      Future.error(StateError('disk full'));
}

ProviderContainer _container({List<Override> extra = const []}) {
  final db = _db;
  final c = ProviderContainer(
    overrides: [
      clockProvider.overrideWithValue(_clock),
      databaseProvider.overrideWithValue(db),
      notifierProvider.overrideWithValue(FakeNotifier()),
      ...extra,
    ],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  setUp(() {
    _clock = FakeClock();
    _db = AppDatabase(NativeDatabase.memory());
    addTearDown(_db.close);
  });

  group('FocusState', () {
    final session = Session(
      id: 's',
      plannedMinutes: 10,
      tier: BuildingTier.hut,
      workersAssigned: 1,
      state: SessionState.running,
      startedAt: TimeStamp(DateTime(2026), Duration.zero),
    );
    final full = FocusState(
      town: TownState.initial(),
      active: session,
      lastResult: _result,
    );

    test('copyWith keeps fields when nothing is passed', () {
      expect(full.copyWith(), full);
    });

    test('clearActive and clearLastResult null the fields', () {
      final cleared = full.copyWith(clearActive: true, clearLastResult: true);
      expect(cleared.active, isNull);
      expect(cleared.lastResult, isNull);
      expect(cleared.town, full.town);
    });

    test('value equality compares every field', () {
      expect(full.copyWith(clearActive: true), isNot(full));
      expect(full.copyWith(clearLastResult: true), isNot(full));
      expect(
        full.copyWith(town: TownState.initial().copyWith(xp: 1)),
        isNot(full),
      );
    });
  });

  group('FocusController', () {
    test('first read yields the initial town and no active session', () async {
      final c = _container();
      final state = await c.read(focusControllerProvider.future);
      expect(state.town, TownState.initial());
      expect(state.active, isNull);
      expect(state.lastResult, isNull);
    });

    test('clearResult clears a set result', () async {
      final c = _container(
        extra: [focusControllerProvider.overrideWith(_SeededController.new)],
      );
      expect(
        (await c.read(focusControllerProvider.future)).lastResult,
        _result,
      );
      c.read(focusControllerProvider.notifier).clearResult();
      final state = c.read(focusControllerProvider).requireValue;
      expect(state.lastResult, isNull);
      expect(state.town, TownState.initial());
    });

    group('start', () {
      test('10 minutes starts a persisted running session', () async {
        final c = _container();
        await c.read(focusControllerProvider.future);
        await c.read(focusControllerProvider.notifier).start(10);
        final active = c.read(focusControllerProvider).requireValue.active!;
        expect(active.state, SessionState.running);
        expect(active.workersAssigned, 1);
        expect(active.plannedMinutes, 10);
        expect(await c.read(townRepositoryProvider).activeSession(), active);
      });

      test('too few workers throws and persists nothing', () async {
        final c = _container();
        await c.read(focusControllerProvider.future);
        await expectLater(
          c.read(focusControllerProvider.notifier).start(120),
          throwsStateError,
        );
        expect(c.read(focusControllerProvider).requireValue.active, isNull);
        expect(await c.read(townRepositoryProvider).activeSession(), isNull);
      });

      test('starting while a session is active throws', () async {
        final c = _container();
        await c.read(focusControllerProvider.future);
        final controller = c.read(focusControllerProvider.notifier);
        await controller.start(10);
        await expectLater(controller.start(10), throwsStateError);
      });

      test('a failed save leaves no active session and rethrows', () async {
        final c = _container(
          extra: [
            townRepositoryProvider.overrideWith(
              (ref) => _FailingRepository(_db, ref.watch(clockProvider)),
            ),
          ],
        );
        await c.read(focusControllerProvider.future);
        await expectLater(
          c.read(focusControllerProvider.notifier).start(10),
          throwsStateError,
        );
        expect(c.read(focusControllerProvider).requireValue.active, isNull);
      });

      group('recovery town', () {
        late ProviderContainer c;
        setUp(() async {
          c = _container();
          final recovery = TownState.initial().copyWith(
            workers: 0,
            inRecoveryMode: true,
          );
          await c.read(townRepositoryProvider).loadOrCreate();
          await (_db.update(
            _db.towns,
          )..where((t) => t.id.equals(1))).write(townToRow(recovery));
        });

        test('can start 10 minutes with 0 workers assigned', () async {
          await c.read(focusControllerProvider.notifier).start(10);
          final active = c.read(focusControllerProvider).requireValue.active!;
          expect(active.workersAssigned, 0);
        });

        test('cannot start 25 minutes', () async {
          await expectLater(
            c.read(focusControllerProvider.notifier).start(25),
            throwsStateError,
          );
        });
      });
    });

    group('finish', () {
      /// Writes [town] as the stored town before the controller loads it.
      Future<void> seed(TownState town) async {
        await _db.transaction(() async {
          await _db
              .into(_db.towns)
              .insert(
                townToRow(town)
                    .copyWith(id: const Value(1), createdAt: const Value(0)),
              );
          await _db.batch(
            (b) => b.insertAll(
              _db.buildings,
              buildingsToRows(town, now: _clock.nowWall()),
            ),
          );
        });
      }

      Future<ProviderContainer> loaded() async {
        final c = _container();
        await c.read(focusControllerProvider.future);
        return c;
      }

      FocusState stateOf(ProviderContainer c) =>
          c.read(focusControllerProvider).requireValue;

      Future<void> runHut(ProviderContainer c) async {
        final controller = c.read(focusControllerProvider.notifier);
        await controller.start(10);
        _clock.advance(const Duration(minutes: 10));
        await controller.tick();
      }

      test(
        'completed hut: worker gained, placed, streak, plot granted',
        () async {
          final c = await loaded();
          await runHut(c);
          final s = stateOf(c);
          expect(s.town.workers, 4);
          expect(
            s.town.buildings.any(
              (b) => b.plotIndex == 1 && b.tier == BuildingTier.hut,
            ),
            isTrue,
          );
          expect(s.town.streakCount, 1);
          expect(s.active, isNull);
          expect(
            s.lastResult,
            const SessionResult(
              outcome: SessionOutcome.completed,
              tier: BuildingTier.hut,
              workersLost: 0,
              workersGained: 1,
              newStreak: 1,
              xpGained: 10,
              reason: OutcomeReason.completed,
            ),
          );
          expect(await c.read(townRepositoryProvider).activeSession(), isNull);
          expect(await c.read(townRepositoryProvider).loadOrCreate(), s.town);
        },
      );

      test('abandon loses workers and leaves a ruin', () async {
        final c = await loaded();
        final controller = c.read(focusControllerProvider.notifier);
        await controller.start(10);
        await controller.abandon();
        final s = stateOf(c);
        expect(s.town.workers, 2);
        expect(
          s.town.buildings.where((b) => b.status == BuildingStatus.ruin),
          hasLength(1),
        );
        expect(s.lastResult!.outcome, SessionOutcome.failed);
        expect(s.lastResult!.workersLost, 1);
        expect(s.active, isNull);
      });

      test('full town queues the completed building', () async {
        await seed(
          TownState.initial().copyWith(
            buildings: [
              for (var i = 0; i < 64; i++)
                TownBuilding(
                  id: 'b$i',
                  tier: BuildingTier.hut,
                  status: BuildingStatus.complete,
                  plotIndex: i,
                ),
            ],
          ),
        );
        final c = await loaded();
        await runHut(c);
        final s = stateOf(c);
        expect(s.lastResult!.outcome, SessionOutcome.queued);
        expect(s.town.queue, hasLength(1));
      });

      test('failed session with the last worker enters recovery', () async {
        await seed(TownState.initial().copyWith(workers: 1));
        final c = await loaded();
        final controller = c.read(focusControllerProvider.notifier);
        await controller.start(10);
        await controller.abandon();
        expect(stateOf(c).town.workers, 0);
        expect(stateOf(c).town.inRecoveryMode, isTrue);
      });

      group('in recovery', () {
        setUp(
          () => seed(
            TownState.initial().copyWith(workers: 0, inRecoveryMode: true),
          ),
        );

        test('abandoned recovery hut leaves workers at 0', () async {
          final c = await loaded();
          final controller = c.read(focusControllerProvider.notifier);
          await controller.start(10);
          await controller.abandon();
          expect(stateOf(c).town.workers, 0);
          expect(stateOf(c).town.inRecoveryMode, isTrue);
        });

        test('three completed huts end recovery with 3 workers', () async {
          final c = await loaded();
          for (var i = 0; i < 3; i++) {
            await runHut(c);
            c.read(focusControllerProvider.notifier).clearResult();
          }
          expect(stateOf(c).town.workers, 3);
          expect(stateOf(c).town.inRecoveryMode, isFalse);
        });
      });

      test('tick with nothing active does nothing', () async {
        final c = await loaded();
        final before = stateOf(c);
        await c.read(focusControllerProvider.notifier).tick();
        expect(stateOf(c), before);
      });

      test('tick before the planned time keeps the session running', () async {
        final c = await loaded();
        final controller = c.read(focusControllerProvider.notifier);
        await controller.start(10);
        _clock.advance(const Duration(minutes: 9));
        await controller.tick();
        expect(stateOf(c).active!.state, SessionState.running);
        expect(stateOf(c).lastResult, isNull);
      });
    });

    group('lifecycle', () {
      late ProviderContainer c;
      late FocusController controller;
      setUp(() async {
        c = _container();
        await c.read(focusControllerProvider.future);
        controller = c.read(focusControllerProvider.notifier);
      });

      FocusState stateOf() => c.read(focusControllerProvider).requireValue;
      Future<SessionRow> storedSession() =>
          _db.select(_db.sessions).getSingle();

      Future<void> awayFor(Duration d) async {
        await controller.onBackgroundedUnlocked();
        _clock.advance(d);
        await controller.onForegrounded();
      }

      test('leave and return after 5 s keeps running, no pass', () async {
        await controller.start(25);
        await awayFor(const Duration(seconds: 5));
        expect(stateOf().active!.state, SessionState.running);
        expect(stateOf().active!.passUsed, isFalse);
        expect((await storedSession()).state, 'running');
      });

      test('return after 30 s uses the pass and persists it', () async {
        await controller.start(25);
        await awayFor(const Duration(seconds: 30));
        expect(stateOf().active!.passUsed, isTrue);
        expect((await storedSession()).passUsed, isTrue);
      });

      test('return after 90 s fails the session', () async {
        await controller.start(25);
        await awayFor(const Duration(seconds: 90));
        final s = stateOf();
        expect(s.active, isNull);
        expect(s.lastResult!.outcome, SessionOutcome.failed);
        expect(s.town.workers, 1);
        expect(
          s.town.buildings.where((b) => b.status == BuildingStatus.ruin),
          hasLength(1),
        );
        expect((await storedSession()).state, 'failed');
      });

      test('a second 30 s away in the same session fails', () async {
        await controller.start(25);
        await awayFor(const Duration(seconds: 30));
        await awayFor(const Duration(seconds: 30));
        expect(stateOf().lastResult!.outcome, SessionOutcome.failed);
      });

      test('lock and call change and write nothing', () async {
        await controller.start(25);
        final before = stateOf();
        final row = await storedSession();
        await controller.onLocked();
        await controller.onCallStarted();
        expect(stateOf(), before);
        expect(await storedSession(), row);
      });

      test('events with no active session are no-ops', () async {
        final before = stateOf();
        await controller.onLocked();
        await controller.onCallStarted();
        await controller.onBackgroundedUnlocked();
        await controller.onForegrounded();
        expect(stateOf(), before);
        expect(await _db.select(_db.sessions).get(), isEmpty);
      });

      test('the at timestamp is used to measure time away', () async {
        await controller.start(25);
        _clock.advance(const Duration(seconds: 12));
        final at = TimeStamp(
          _clock.nowWall().subtract(const Duration(seconds: 12)),
          _clock.uptime() - const Duration(seconds: 12),
        );
        await controller.onBackgroundedUnlocked(at: at);
        expect(stateOf().active!.leftAt, at);
        await controller.onForegrounded();
        // 12 s measured from `at` needs the pass; from now it would be 0 s.
        expect(stateOf().active!.passUsed, isTrue);
      });

      test('away state is stored with leftAt', () async {
        await controller.start(25);
        await controller.onBackgroundedUnlocked();
        final stored = await c.read(townRepositoryProvider).activeSession();
        expect(stored!.state, SessionState.away);
        expect(stored.leftAt, stateOf().active!.leftAt);
      });
    });

    group('resume on launch', () {
      // A second container over the same database simulates a killed app.
      Future<FocusState> relaunch() =>
          _container().read(focusControllerProvider.future);

      Future<FocusController> first() {
        final c = _container();
        return c
            .read(focusControllerProvider.future)
            .then((_) => c.read(focusControllerProvider.notifier));
      }

      test('a running session survives and stays active', () async {
        final controller = await first();
        await controller.start(25);
        _clock.advance(const Duration(minutes: 4));
        final s = await relaunch();
        expect(s.active!.state, SessionState.running);
        expect(s.lastResult, isNull);
      });

      test('away for 90 s while killed fails the session', () async {
        final controller = await first();
        await controller.start(25);
        await controller.onBackgroundedUnlocked();
        _clock.advance(const Duration(seconds: 90));
        final s = await relaunch();
        expect(s.active, isNull);
        expect(s.lastResult!.outcome, SessionOutcome.failed);
        expect(s.town.workers, 1);
      });

      test('planned time passing while killed completes it', () async {
        final controller = await first();
        await controller.start(10);
        _clock.advance(const Duration(minutes: 11));
        final s = await relaunch();
        expect(s.active, isNull);
        expect(s.lastResult!.outcome, SessionOutcome.completed);
        expect(s.town.workers, 4);
      });

      test('away 30 s with the pass unused stays away', () async {
        final controller = await first();
        await controller.start(25);
        await controller.onBackgroundedUnlocked();
        _clock.advance(const Duration(seconds: 30));
        final s = await relaunch();
        expect(s.active!.state, SessionState.away);
        expect(s.lastResult, isNull);
      });

      test('a reboot while away falls back to wall time and fails', () async {
        // Uptime must be above zero so the reboot visibly resets it.
        _clock.advance(const Duration(hours: 1));
        final controller = await first();
        await controller.start(25);
        await controller.onBackgroundedUnlocked();
        _clock
          ..advance(const Duration(seconds: 100))
          ..simulateReboot();
        final s = await relaunch();
        expect(s.lastResult!.outcome, SessionOutcome.failed);
      });

      test(
        'wall clock moved forward while killed does not complete early',
        () async {
          final controller = await first();
          await controller.start(25);
          _clock
            ..advance(const Duration(minutes: 3))
            ..setWall(_clock.nowWall().add(const Duration(hours: 2)));
          final s = await relaunch();
          expect(s.active!.state, SessionState.running);
          expect(s.lastResult, isNull);
        },
      );
    });
  });
}
