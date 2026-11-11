import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/app/focus_state.dart';
import 'package:focus_town/app/providers.dart';
import 'package:focus_town/data/database.dart';
import 'package:focus_town/data/mappers.dart';
import 'package:focus_town/domain/progression.dart';
import 'package:focus_town/domain/session.dart';
import 'package:focus_town/domain/testing/fake_clock.dart';
import 'package:focus_town/domain/town.dart';
import 'package:focus_town/platform/testing/fake_notifier.dart';

late AppDatabase _db;
late FakeClock _clock;

Future<ProviderContainer> _loaded([TownState? seed]) async {
  if (seed != null) {
    await _db.transaction(() async {
      await _db
          .into(_db.towns)
          .insert(
            townToRow(seed)
                .copyWith(id: const Value(1), createdAt: const Value(0)),
          );
      await _db.batch(
        (b) => b.insertAll(
          _db.buildings,
          buildingsToRows(seed, now: _clock.nowWall()),
        ),
      );
    });
  }
  final c = ProviderContainer(
    overrides: [
      clockProvider.overrideWithValue(_clock),
      databaseProvider.overrideWithValue(_db),
      notifierProvider.overrideWithValue(FakeNotifier()),
    ],
  );
  addTearDown(c.dispose);
  await c.read(focusControllerProvider.future);
  return c;
}

SessionResult _result(ProviderContainer c) =>
    c.read(focusControllerProvider).requireValue.lastResult!;

Future<void> _run(ProviderContainer c, int minutes) async {
  final controller = c.read(focusControllerProvider.notifier);
  await controller.start(minutes);
  _clock.advance(Duration(minutes: minutes));
  await controller.tick();
}

void main() {
  setUp(() {
    _clock = FakeClock();
    _db = AppDatabase(NativeDatabase.memory());
    addTearDown(_db.close);
  });

  test('a completed 25 minute session earns 25 xp and no level-up', () async {
    final c = await _loaded();
    await _run(c, 25);
    expect(_result(c).xpGained, 25);
    expect(_result(c).leveledUpTo, isNull);
    expect(_result(c).reason, OutcomeReason.completed);
  });

  test('crossing 300 xp reports the new level', () async {
    final c = await _loaded(TownState.initial().copyWith(xp: 295));
    await _run(c, 10);
    expect(_result(c).leveledUpTo, TownLevel.village);
  });

  test('a failure earns nothing', () async {
    final c = await _loaded();
    await c.read(focusControllerProvider.notifier).start(10);
    await c.read(focusControllerProvider.notifier).abandon();
    expect(_result(c).xpGained, 0);
    expect(_result(c).leveledUpTo, isNull);
  });

  test('losing the last worker starts recovery', () async {
    final c = await _loaded(TownState.initial().copyWith(workers: 1));
    await c.read(focusControllerProvider.notifier).start(10);
    await c.read(focusControllerProvider.notifier).abandon();
    expect(_result(c).recoveryStarted, isTrue);
    expect(_result(c).recoveryEnded, isFalse);
  });

  test('finishing the hut that brings back 3 builders ends recovery', () async {
    final c = await _loaded(
      TownState.initial().copyWith(workers: 2, inRecoveryMode: true),
    );
    await _run(c, 10);
    expect(_result(c).recoveryEnded, isTrue);
    expect(_result(c).recoveryStarted, isFalse);
  });

  test('a normal result has neither recovery flag', () async {
    final c = await _loaded();
    await _run(c, 10);
    expect(_result(c).recoveryStarted, isFalse);
    expect(_result(c).recoveryEnded, isFalse);
  });

  test('abandoning says abandoned', () async {
    final c = await _loaded();
    await c.read(focusControllerProvider.notifier).start(10);
    await c.read(focusControllerProvider.notifier).abandon();
    expect(_result(c).reason, OutcomeReason.abandoned);
    expect(_result(c).awaySeconds, 0);
  });

  test('being away too long says leftTooLong with the time away', () async {
    final c = await _loaded();
    final controller = c.read(focusControllerProvider.notifier);
    await controller.start(25);
    await controller.onBackgroundedUnlocked();
    _clock.advance(const Duration(seconds: 90));
    await controller.onForegrounded();
    expect(_result(c).outcome, SessionOutcome.failed);
    expect(_result(c).reason, OutcomeReason.leftTooLong);
    expect(_result(c).awaySeconds, inInclusiveRange(89, 91));
  });
}
