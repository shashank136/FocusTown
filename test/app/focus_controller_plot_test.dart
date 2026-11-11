import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/app/focus_state.dart';
import 'package:focus_town/app/providers.dart';
import 'package:focus_town/data/database.dart';
import 'package:focus_town/domain/building_tier.dart';
import 'package:focus_town/domain/testing/fake_clock.dart';
import 'package:focus_town/domain/town.dart';
import 'package:focus_town/platform/testing/fake_notifier.dart';

late AppDatabase _db;
late FakeClock _clock;

ProviderContainer _container() {
  final c = ProviderContainer(
    overrides: [
      clockProvider.overrideWithValue(_clock),
      databaseProvider.overrideWithValue(_db),
      notifierProvider.overrideWithValue(FakeNotifier()),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

Future<ProviderContainer> _loaded() async {
  final c = _container();
  await c.read(focusControllerProvider.future);
  return c;
}

FocusState _state(ProviderContainer c) =>
    c.read(focusControllerProvider).requireValue;

void main() {
  setUp(() {
    _clock = FakeClock();
    _db = AppDatabase(NativeDatabase.memory());
    addTearDown(_db.close);
  });

  test('start stores the automatic plot when none is chosen', () async {
    final c = await _loaded();
    await c.read(focusControllerProvider.notifier).start(10);
    expect(_state(c).active!.plotIndex, 1);
  });

  test('start stores the chosen free plot', () async {
    final c = await _loaded();
    await c.read(focusControllerProvider.notifier).start(10, plotIndex: 3);
    expect(_state(c).active!.plotIndex, 3);
  });

  test(
    'a taken, locked or unknown plot is refused and nothing starts',
    () async {
      final c = await _loaded();
      final controller = c.read(focusControllerProvider.notifier);
      for (final bad in [0, -1, 64]) {
        await expectLater(
          controller.start(10, plotIndex: bad),
          throwsStateError,
          reason: 'plot $bad',
        );
      }
      expect(_state(c).active, isNull);
    },
  );

  test('a plot far from the middle can be chosen', () async {
    final c = await _loaded();
    await c.read(focusControllerProvider.notifier).start(10, plotIndex: 40);
    expect(_state(c).active!.plotIndex, 40);
  });

  test('a relaunch resumes on the chosen plot', () async {
    final first = await _loaded();
    await first.read(focusControllerProvider.notifier).start(10, plotIndex: 4);
    final second = await _loaded();
    expect(_state(second).active!.plotIndex, 4);
  });

  test('a completed hut lands on the chosen plot', () async {
    final c = await _loaded();
    final controller = c.read(focusControllerProvider.notifier);
    await controller.start(10, plotIndex: 5);
    _clock.advance(const Duration(minutes: 10));
    await controller.tick();
    final placed = _state(c).town.buildings.where((b) => b.plotIndex == 5);
    expect(placed.single.status, BuildingStatus.complete);
    expect(placed.single.tier, BuildingTier.hut);
  });

  test('an abandoned session leaves its ruin on the chosen plot', () async {
    final c = await _loaded();
    final controller = c.read(focusControllerProvider.notifier);
    await controller.start(10, plotIndex: 2);
    await controller.abandon();
    final ruin = _state(c).town.buildings.where((b) => b.plotIndex == 2);
    expect(ruin.single.status, BuildingStatus.ruin);
  });
}
