import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/app/placement.dart';
import 'package:focus_town/app/providers.dart';
import 'package:focus_town/data/database.dart';
import 'package:focus_town/domain/testing/fake_clock.dart';
import 'package:focus_town/platform/testing/fake_notifier.dart';

late AppDatabase _db;

Future<ProviderContainer> _loaded() async {
  final c = ProviderContainer(
    overrides: [
      clockProvider.overrideWithValue(FakeClock()),
      databaseProvider.overrideWithValue(_db),
      notifierProvider.overrideWithValue(FakeNotifier()),
    ],
  );
  addTearDown(c.dispose);
  await c.read(focusControllerProvider.future);
  return c;
}

void main() {
  setUp(() {
    _db = AppDatabase(NativeDatabase.memory());
    addTearDown(_db.close);
  });

  test('nothing is pending at first', () async {
    final c = await _loaded();
    expect(c.read(placementProvider), isNull);
  });

  test('begin keeps the minutes and no plot', () async {
    final c = await _loaded();
    c.read(placementProvider.notifier).begin(25);
    expect(c.read(placementProvider)!.minutes, 25);
    expect(c.read(placementProvider)!.plot, isNull);
  });

  test('select takes a free unlocked plot and ignores the others', () async {
    final c = await _loaded();
    final p = c.read(placementProvider.notifier)
      ..begin(10)
      ..select(3);
    expect(c.read(placementProvider)!.plot, 3);
    p.select(0); // the starter building
    expect(c.read(placementProvider)!.plot, 3);
    p.select(6); // locked
    expect(c.read(placementProvider)!.plot, 3);
    p.select(40); // locked
    expect(c.read(placementProvider)!.plot, 3);
  });

  test('select does nothing when no placement is pending', () async {
    final c = await _loaded();
    c.read(placementProvider.notifier).select(3);
    expect(c.read(placementProvider), isNull);
  });

  test('cancel clears and starts nothing', () async {
    final c = await _loaded();
    c.read(placementProvider.notifier)
      ..begin(10)
      ..select(2)
      ..cancel();
    expect(c.read(placementProvider), isNull);
    expect(c.read(focusControllerProvider).requireValue.active, isNull);
  });

  test('confirm starts the session on the plot and clears', () async {
    final c = await _loaded();
    c.read(placementProvider.notifier)
      ..begin(10)
      ..select(4);
    await c.read(placementProvider.notifier).confirm();
    expect(c.read(placementProvider), isNull);
    expect(c.read(focusControllerProvider).requireValue.active!.plotIndex, 4);
  });

  test('confirm without a plot does nothing', () async {
    final c = await _loaded();
    c.read(placementProvider.notifier).begin(10);
    await c.read(placementProvider.notifier).confirm();
    expect(c.read(placementProvider), isNotNull);
    expect(c.read(focusControllerProvider).requireValue.active, isNull);
  });

  test('begin is ignored while a session is running', () async {
    final c = await _loaded();
    await c.read(focusControllerProvider.notifier).start(10);
    c.read(placementProvider.notifier).begin(10);
    expect(c.read(placementProvider), isNull);
  });
}
