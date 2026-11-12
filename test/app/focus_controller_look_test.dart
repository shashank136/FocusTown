import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/app/placement.dart';
import 'package:focus_town/app/providers.dart';
import 'package:focus_town/data/database.dart';
import 'package:focus_town/domain/testing/fake_clock.dart';
import 'package:focus_town/platform/testing/fake_live_status_sink.dart';
import 'package:focus_town/platform/testing/fake_notifier.dart';

late AppDatabase _db;
late FakeClock _clock;

ProviderContainer _container() {
  final c = ProviderContainer(
    overrides: [
      clockProvider.overrideWithValue(_clock),
      databaseProvider.overrideWithValue(_db),
      notifierProvider.overrideWithValue(FakeNotifier()),
      liveStatusSinkProvider.overrideWithValue(FakeLiveStatusSink()),
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

  test('the chosen look is stored with the session and the building', () async {
    final c = _container();
    await c.read(focusControllerProvider.future);
    final n = c.read(focusControllerProvider.notifier);
    await n.start(25, look: 1);
    expect(c.read(focusControllerProvider).requireValue.active!.look, 1);
    _clock.advance(const Duration(minutes: 26));
    await n.tick();
    final building = c
        .read(focusControllerProvider)
        .requireValue
        .town
        .buildings
        .last;
    expect(building.look, 1);
    // It survives a restart.
    final again = _container();
    final saved = (await again.read(focusControllerProvider.future)).town;
    expect(saved.buildings.last.look, 1);
  });

  test('without a choice the look stays unset', () async {
    final c = _container();
    await c.read(focusControllerProvider.future);
    await c.read(focusControllerProvider.notifier).start(25);
    expect(c.read(focusControllerProvider).requireValue.active!.look, isNull);
  });

  test('the look follows the choose-a-plot step', () async {
    final c = _container();
    await c.read(focusControllerProvider.future);
    c.read(placementProvider.notifier)
      ..begin(25, look: 1)
      ..select(3);
    expect(c.read(placementProvider)!.look, 1);
    await c.read(placementProvider.notifier).confirm();
    expect(c.read(focusControllerProvider).requireValue.active!.look, 1);
  });
}
