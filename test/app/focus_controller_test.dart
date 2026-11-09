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

const _result = SessionResult(
  outcome: SessionOutcome.completed,
  tier: BuildingTier.hut,
  workersLost: 0,
  workersGained: 1,
  newStreak: 1,
  plotGranted: true,
);

/// Starts with a result already set, so `clearResult` can be tested alone.
class _SeededController extends FocusController {
  @override
  Future<FocusState> build() async =>
      FocusState(town: TownState.initial(), lastResult: _result);
}

late AppDatabase _db;

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
      clockProvider.overrideWithValue(FakeClock()),
      databaseProvider.overrideWithValue(db),
      ...extra,
    ],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  setUp(() {
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
  });
}
