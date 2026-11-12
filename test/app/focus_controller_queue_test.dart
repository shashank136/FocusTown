import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/app/providers.dart';
import 'package:focus_town/data/database.dart';
import 'package:focus_town/data/mappers.dart';
import 'package:focus_town/domain/building_tier.dart';
import 'package:focus_town/domain/testing/fake_clock.dart';
import 'package:focus_town/domain/town.dart';
import 'package:focus_town/platform/testing/fake_live_status_sink.dart';
import 'package:focus_town/platform/testing/fake_notifier.dart';

void main() {
  test('a waiting building is placed on launch once there is room', () async {
    final clock = FakeClock();
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final seed = TownState.initial().copyWith(
      queue: const [QueuedBuilding(id: 'q', tier: BuildingTier.castle)],
    );
    await db.transaction(() async {
      await db
          .into(db.towns)
          .insert(
            townToRow(seed)
                .copyWith(id: const Value(1), createdAt: const Value(0)),
          );
      await db.batch(
        (b) => b.insertAll(
          db.buildings,
          buildingsToRows(seed, now: clock.nowWall()),
        ),
      );
    });
    ProviderContainer container() {
      final c = ProviderContainer(
        overrides: [
          clockProvider.overrideWithValue(clock),
          databaseProvider.overrideWithValue(db),
          notifierProvider.overrideWithValue(FakeNotifier()),
          liveStatusSinkProvider.overrideWithValue(FakeLiveStatusSink()),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    final first = container();
    final town = (await first.read(focusControllerProvider.future)).town;
    expect(town.queue, isEmpty);
    expect(
      town.buildings.where((b) => b.tier == BuildingTier.castle),
      hasLength(1),
    );
    // It was saved, not just shown.
    final again = container();
    final saved = (await again.read(focusControllerProvider.future)).town;
    expect(saved.queue, isEmpty);
    expect(saved.buildings, town.buildings);
  });
}
