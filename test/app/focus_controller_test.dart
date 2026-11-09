import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/app/focus_controller.dart';
import 'package:focus_town/app/focus_state.dart';
import 'package:focus_town/app/providers.dart';
import 'package:focus_town/data/database.dart';
import 'package:focus_town/domain/building_tier.dart';
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

ProviderContainer _container({List<Override> extra = const []}) {
  final db = AppDatabase(NativeDatabase.memory());
  addTearDown(db.close);
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
  });
}
