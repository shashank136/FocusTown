import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/app/focus_state.dart';
import 'package:focus_town/app/providers.dart';
import 'package:focus_town/data/database.dart';
import 'package:focus_town/data/save_failed_exception.dart';
import 'package:focus_town/data/town_repository.dart';
import 'package:focus_town/domain/clock.dart';
import 'package:focus_town/domain/session.dart';
import 'package:focus_town/domain/testing/fake_clock.dart';
import 'package:focus_town/domain/town.dart';
import 'package:focus_town/platform/testing/fake_notifier.dart';

/// A repository whose writes fail while [broken] is true.
class _Flaky extends TownRepository {
  // ignore: use_super_parameters, super params are private so names differ
  new(AppDatabase db, Clock clock) : super(db, clock);

  bool broken = false;

  @override
  Future<void> saveSessionStarted(TownState town, Session session) => broken
      ? Future.error(const SaveFailedException())
      : super.saveSessionStarted(town, session);

  @override
  Future<void> saveSessionUpdated(Session session) => broken
      ? Future.error(const SaveFailedException())
      : super.saveSessionUpdated(session);

  @override
  Future<void> saveSessionResolved(TownState town, Session session) => broken
      ? Future.error(const SaveFailedException())
      : super.saveSessionResolved(town, session);
}

late AppDatabase _db;
late FakeClock _clock;
late _Flaky _repo;

Future<ProviderContainer> _loaded() async {
  final c = ProviderContainer(
    overrides: [
      clockProvider.overrideWithValue(_clock),
      databaseProvider.overrideWithValue(_db),
      townRepositoryProvider.overrideWithValue(_repo),
      notifierProvider.overrideWithValue(FakeNotifier()),
    ],
  );
  addTearDown(c.dispose);
  await c.read(focusControllerProvider.future);
  return c;
}

void main() {
  setUp(() {
    _clock = FakeClock();
    _db = AppDatabase(NativeDatabase.memory());
    _repo = _Flaky(_db, _clock);
    addTearDown(_db.close);
  });

  test('a failed save starts nothing, here or in the database', () async {
    final c = await _loaded();
    _repo.broken = true;
    await expectLater(
      c.read(focusControllerProvider.notifier).start(25),
      throwsA(isA<SaveFailedException>()),
    );
    expect(c.read(focusControllerProvider).requireValue.active, isNull);
    _repo.broken = false;
    expect(await _repo.activeSession(), isNull);
  });

  test('a failed save at the end keeps the session, a tick retries', () async {
    final c = await _loaded();
    final controller = c.read(focusControllerProvider.notifier);
    await controller.start(10);
    _clock.advance(const Duration(minutes: 10));
    _repo.broken = true;
    await controller.tick(); // must not throw
    var state = c.read(focusControllerProvider).requireValue;
    expect(state.active, isNotNull);
    expect(state.lastResult, isNull);
    expect(state.town.buildings, hasLength(1));

    _repo.broken = false;
    await controller.tick();
    state = c.read(focusControllerProvider).requireValue;
    expect(state.active, isNull);
    expect(state.lastResult!.outcome, SessionOutcome.completed);
    expect(state.town.buildings, hasLength(2));
  });

  test('a failed save on abandon keeps the session running', () async {
    final c = await _loaded();
    final controller = c.read(focusControllerProvider.notifier);
    await controller.start(25);
    _repo.broken = true;
    await controller.abandon();
    expect(c.read(focusControllerProvider).requireValue.active, isNotNull);
  });

  test('a failed save of an event keeps the last good state', () async {
    final c = await _loaded();
    final controller = c.read(focusControllerProvider.notifier);
    await controller.start(25);
    _repo.broken = true;
    await controller.onBackgroundedUnlocked(); // must not throw
    expect(
      c.read(focusControllerProvider).requireValue.active!.state,
      SessionState.running,
    );
  });

  test('a finished session at launch stays active if saving fails', () async {
    final c = await _loaded();
    await c.read(focusControllerProvider.notifier).start(10);
    _clock.advance(const Duration(minutes: 10));
    _repo.broken = true;
    final again = ProviderContainer(
      overrides: [
        clockProvider.overrideWithValue(_clock),
        databaseProvider.overrideWithValue(_db),
        townRepositoryProvider.overrideWithValue(_repo),
        notifierProvider.overrideWithValue(FakeNotifier()),
      ],
    );
    addTearDown(again.dispose);
    final state = await again.read(focusControllerProvider.future);
    expect(state.active, isNotNull);
    expect(state.lastResult, isNull);
  });
}
