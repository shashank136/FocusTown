import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/app/providers.dart';
import 'package:focus_town/app/short_sessions.dart';
import 'package:focus_town/data/database.dart';
import 'package:focus_town/data/mappers.dart';
import 'package:focus_town/domain/building_tier.dart';
import 'package:focus_town/domain/landmark.dart';
import 'package:focus_town/domain/parcel.dart';
import 'package:focus_town/domain/testing/fake_clock.dart';
import 'package:focus_town/domain/town.dart';
import 'package:focus_town/platform/testing/fake_live_status_sink.dart';
import 'package:focus_town/platform/testing/fake_notifier.dart';
import 'package:focus_town/ui/debug_screen.dart';

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

  test('sessions have their normal length by default', () async {
    final c = _container();
    await c.read(focusControllerProvider.future);
    await c.read(focusControllerProvider.notifier).start(25);
    final s = c.read(focusControllerProvider).requireValue.active!;
    expect(s.plannedMinutes, 25);
  });

  test('with short test sessions on, every kind lasts 1 minute', () async {
    final c = _container();
    await c.read(focusControllerProvider.future);
    c.read(shortSessionsProvider.notifier).toggle();
    final n = c.read(focusControllerProvider.notifier);
    await n.start(60);
    var s = c.read(focusControllerProvider).requireValue.active!;
    expect(s.plannedMinutes, 1);
    expect(s.tier, BuildingTier.workshop); // still the tier that was chosen
    await n.abandon();
    _clock.advance(const Duration(minutes: 1));
    await n.startRepair(1);
    s = c.read(focusControllerProvider).requireValue.active!;
    expect(s.plannedMinutes, 1);
    await n.abandon();
    _clock.advance(const Duration(minutes: 1));
    await n.startLand(const Parcel(-1, 3));
    s = c.read(focusControllerProvider).requireValue.active!;
    expect(s.plannedMinutes, 1);
  });

  test(
    'a short land session really claims the parcel after a minute',
    () async {
      final c = _container();
      await c.read(focusControllerProvider.future);
      c.read(shortSessionsProvider.notifier).toggle();
      final n = c.read(focusControllerProvider.notifier);
      await n.startLand(const Parcel(-1, 3));
      _clock.advance(const Duration(seconds: 61));
      await n.tick();
      expect(c.read(focusControllerProvider).requireValue.town.parcels, [
        const Parcel(-1, 3),
      ]);
    },
  );

  testWidgets('the debug screen has the switch', (tester) async {
    final c = _container();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: const MaterialApp(home: DebugScreen()),
      ),
    );
    await tester.pump();
    final finder = find.text('Short test sessions (1 minute)');
    await tester.scrollUntilVisible(finder, 200);
    await tester.tap(finder);
    await tester.pump();
    expect(c.read(shortSessionsProvider), isTrue);
  });

  testWidgets('the debug screen can reset the Eiffel Tower', (tester) async {
    await _db
        .into(_db.towns)
        .insert(
          townToRow(TownState.initial().copyWith(xp: 300))
              .copyWith(id: const Value(1), createdAt: const Value(0)),
        );
    await _db.batch(
      (b) => b.insertAll(
        _db.buildings,
        buildingsToRows(TownState.initial(), now: _clock.nowWall()),
      ),
    );
    final c = _container();
    await c.read(focusControllerProvider.future);
    final n = c.read(focusControllerProvider.notifier);
    await n.startLandmark(Landmark.eiffel, 30);
    _clock.advance(const Duration(minutes: 31));
    await n.tick();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: const MaterialApp(home: DebugScreen()),
      ),
    );
    await tester.pump();
    final finder = find.text('Reset Eiffel Tower');
    await tester.scrollUntilVisible(finder, 200);
    await tester.tap(finder);
    await tester.pump();
    final town = c.read(focusControllerProvider).requireValue.town;
    expect(town.buildings.where((b) => b.landmark != null), isEmpty);
  });
}
