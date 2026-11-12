import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/app/placement.dart';
import 'package:focus_town/app/providers.dart';
import 'package:focus_town/data/database.dart';
import 'package:focus_town/domain/parcel.dart';
import 'package:focus_town/domain/testing/fake_clock.dart';
import 'package:focus_town/game/world/plot_layout.dart';
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

  test('select takes any free plot and ignores the others', () async {
    final c = await _loaded();
    final p = c.read(placementProvider.notifier)
      ..begin(10)
      ..select(3);
    expect(c.read(placementProvider)!.plot, 3);
    p.select(0); // the starter building
    expect(c.read(placementProvider)!.plot, 3);
    p.select(64); // not on the island
    expect(c.read(placementProvider)!.plot, 3);
    p.select(40); // far away, still free
    expect(c.read(placementProvider)!.plot, 40);
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

  group('land', () {
    test(
      'beginLand uses the land minutes and picks only claimable land',
      () async {
        final c = await _loaded();
        final p = c.read(placementProvider.notifier)..beginLand();
        final placement = c.read(placementProvider)!;
        expect(placement.land, isTrue);
        expect(placement.minutes, 25);
        p.select(3); // a plot, not land
        expect(c.read(placementProvider)!.plot, isNull);
        p.select(kLandBase + 1);
        expect(c.read(placementProvider)!.plot, kLandBase + 1);
        p.select(kLandBase + 500); // not a claimable parcel
        expect(c.read(placementProvider)!.plot, kLandBase + 1);
      },
    );

    test('a plot placement does not accept land', () async {
      final c = await _loaded();
      c.read(placementProvider.notifier)
        ..begin(10)
        ..select(kLandBase);
      expect(c.read(placementProvider)!.plot, isNull);
    });

    test('confirm claims the chosen parcel, as a garden when asked', () async {
      final c = await _loaded();
      final claimable = claimableParcels(const []);
      c.read(placementProvider.notifier)
        ..beginLand()
        ..select(kLandBase + 2)
        ..toggleGarden();
      await c.read(placementProvider.notifier).confirm();
      expect(c.read(placementProvider), isNull);
      final land = c.read(focusControllerProvider).requireValue.active!.land!;
      expect((land.gx, land.gy), (claimable[2].gx, claimable[2].gy));
      expect(land.garden, isTrue);
    });

    test('beginLand is ignored while a session is running', () async {
      final c = await _loaded();
      await c.read(focusControllerProvider.notifier).start(10);
      c.read(placementProvider.notifier).beginLand();
      expect(c.read(placementProvider), isNull);
    });
  });
}
