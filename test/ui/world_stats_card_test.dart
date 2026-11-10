import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/app/providers.dart';
import 'package:focus_town/data/database.dart';
import 'package:focus_town/domain/building_tier.dart';
import 'package:focus_town/domain/testing/fake_clock.dart';
import 'package:focus_town/game/world/building_defs.dart';
import 'package:focus_town/game/world/plot_layout.dart';
import 'package:focus_town/game/world/voxel_world.dart';
import 'package:focus_town/platform/testing/fake_notifier.dart';
import 'package:focus_town/ui/world_stats_card.dart';

late FakeClock _clock;

int _blocksOf(BuildingTier t, int plot) {
  final w = VoxelWorld();
  buildTier(
    w,
    t,
    kPlots[plot].originX,
    kPlots[plot].originY,
    stage: maxStage(t),
  );
  return w.blockCount;
}

Future<ProviderContainer> _pump(WidgetTester tester) async {
  _clock = FakeClock();
  final db = AppDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  final overrides = <Override>[
    clockProvider.overrideWithValue(_clock),
    databaseProvider.overrideWithValue(db),
    notifierProvider.overrideWithValue(FakeNotifier()),
  ];
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: const MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: WorldStatsCard())),
      ),
    ),
  );
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 30)),
  );
  await tester.pump();
  return ProviderScope.containerOf(tester.element(find.byType(WorldStatsCard)));
}

Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 30)),
  );
  await tester.pump();
}

void main() {
  testWidgets('the initial town lists its starter house', (tester) async {
    await _pump(tester);
    final n = _blocksOf(BuildingTier.house, 0);
    expect(find.text('house complete plot 0: $n blocks'), findsOneWidget);
    expect(find.textContaining('World:'), findsOneWidget);
    expect(find.textContaining(' blocks, '), findsOneWidget);
  });

  testWidgets('a completed hut adds a second line', (tester) async {
    final c = await _pump(tester);
    final controller = c.read(focusControllerProvider.notifier);
    await tester.runAsync(() => controller.start(10));
    _clock.advance(const Duration(minutes: 10));
    await tester.runAsync(controller.tick);
    await _settle(tester);
    expect(
      find.text(
        'hut complete plot 1: ${_blocksOf(BuildingTier.hut, 1)} blocks',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'house complete plot 0: ${_blocksOf(BuildingTier.house, 0)} blocks',
      ),
      findsOneWidget,
    );
  });

  testWidgets('an abandoned house shows as a ruin', (tester) async {
    final c = await _pump(tester);
    final controller = c.read(focusControllerProvider.notifier);
    await tester.runAsync(() => controller.start(25));
    await tester.runAsync(controller.abandon);
    await _settle(tester);
    expect(find.text('house ruin plot 1: 18 blocks'), findsOneWidget);
  });

  testWidgets('the world is not rebuilt on every redraw', (tester) async {
    final c = await _pump(tester);
    final town = c.read(focusControllerProvider).requireValue.town;
    final key = (town: town, active: null, stage: 0);
    final first = c.read(townWorldProvider(key));
    await tester.pump(const Duration(seconds: 1));
    expect(identical(c.read(townWorldProvider(key)), first), isTrue);
  });
}
