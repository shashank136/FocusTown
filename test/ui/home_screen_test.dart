import 'package:drift/native.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/app/providers.dart';
import 'package:focus_town/data/database.dart';
import 'package:focus_town/domain/testing/fake_clock.dart';
import 'package:focus_town/domain/town.dart';
import 'package:focus_town/game/town_game.dart';
import 'package:focus_town/platform/testing/fake_notifier.dart';
import 'package:focus_town/ui/home_screen.dart';

/// A game that remembers every town it was given.
class _SpyGame extends TownGame {
  final List<TownState> towns = [];

  @override
  void setTown(TownState town) {
    towns.add(town);
    super.setTown(town);
  }
}

late FakeClock _clock;
late _SpyGame _game;

Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 30)),
  );
  await tester.pump();
}

Future<ProviderContainer> _pump(WidgetTester tester) async {
  _clock = FakeClock();
  _game = _SpyGame();
  final db = AppDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        clockProvider.overrideWithValue(_clock),
        databaseProvider.overrideWithValue(db),
        notifierProvider.overrideWithValue(FakeNotifier()),
      ],
      child: MaterialApp(home: HomeScreen(game: _game)),
    ),
  );
  await _settle(tester);
  return ProviderScope.containerOf(tester.element(find.byType(HomeScreen)));
}

void main() {
  testWidgets('shows the game full screen', (tester) async {
    await _pump(tester);
    expect(find.byType(GameWidget<TownGame>), findsOneWidget);
  });

  testWidgets('the initial stored town reaches the game', (tester) async {
    await _pump(tester);
    expect(_game.towns, isNotEmpty);
    expect(_game.towns.last, TownState.initial());
  });

  testWidgets('a completed hut reaches the game as a new town', (tester) async {
    final c = await _pump(tester);
    final controller = c.read(focusControllerProvider.notifier);
    await tester.runAsync(() => controller.start(10));
    _clock.advance(const Duration(minutes: 10));
    await tester.runAsync(controller.tick);
    await _settle(tester);
    expect(_game.towns.last.buildings, hasLength(2));
    expect(_game.towns.last.workers, 4);
  });

  testWidgets('session events that keep the town do not rebuild it', (
    tester,
  ) async {
    final c = await _pump(tester);
    final before = _game.towns.length;
    final controller = c.read(focusControllerProvider.notifier);
    await tester.runAsync(() => controller.start(25));
    await tester.runAsync(controller.onBackgroundedUnlocked);
    await _settle(tester);
    expect(_game.towns.length, before);
  });

  testWidgets('the debug button opens the debug screen', (tester) async {
    await _pump(tester);
    expect(find.byTooltip('Open debug screen'), findsOneWidget);
    await tester.tap(find.byTooltip('Open debug screen'));
    await tester.pump(); // starts the route
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Focus Town debug'), findsOneWidget);
  });

  testWidgets('tapping elsewhere does nothing', (tester) async {
    await _pump(tester);
    await tester.tapAt(const Offset(300, 300));
    await tester.longPressAt(const Offset(300, 300));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Focus Town debug'), findsNothing);
  });

  testWidgets('the debug button sits below the status bar', (tester) async {
    await _pump(tester);
    final box = tester.getRect(find.byTooltip('Open debug screen'));
    expect(box.left, lessThan(80));
    expect(box.width, greaterThanOrEqualTo(44)); // easy to hit
  });
}
