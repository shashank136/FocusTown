import 'package:drift/native.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/app/providers.dart';
import 'package:focus_town/data/database.dart';
import 'package:focus_town/domain/testing/fake_clock.dart';
import 'package:focus_town/domain/town.dart';
import 'package:focus_town/game/frame_limiter.dart';
import 'package:focus_town/game/town_game.dart';
import 'package:focus_town/game/workers/worker_model.dart';
import 'package:focus_town/game/world/plot_layout.dart';
import 'package:focus_town/platform/power_state.dart';
import 'package:focus_town/platform/testing/fake_notifier.dart';
import 'package:focus_town/ui/home_screen.dart';

/// A game that remembers every town it was given.
class _SpyGame extends TownGame {
  new({super.clock});

  final List<TownState> towns = [];
  final List<Plot> focused = [];
  int recentered = 0;

  @override
  void focusOnSite(Plot plot) {
    focused.add(plot);
    super.focusOnSite(plot);
  }

  @override
  void recenter() {
    recentered++;
    super.recenter();
  }

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

class _FakePower implements PowerState {
  new({required this.low});
  final bool low;

  @override
  Future<bool> isLowPower() async => low;
}

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  bool lowPower = false,
  bool reducedMotion = false,
}) async {
  _clock = FakeClock();
  _game = _SpyGame(clock: _clock);
  final db = AppDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        clockProvider.overrideWithValue(_clock),
        databaseProvider.overrideWithValue(db),
        notifierProvider.overrideWithValue(FakeNotifier()),
        powerStateProvider.overrideWithValue(_FakePower(low: lowPower)),
      ],
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(disableAnimations: reducedMotion),
          child: child!,
        ),
        home: HomeScreen(game: _game),
      ),
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

  testWidgets('starting a session focuses the camera on its plot once', (
    tester,
  ) async {
    final c = await _pump(tester);
    expect(_game.focused, isEmpty);
    final controller = c.read(focusControllerProvider.notifier);
    await tester.runAsync(() => controller.start(25));
    await _settle(tester);
    expect(_game.focused, [kPlots[1]]); // plot 0 holds the starter house
    await tester.runAsync(controller.onBackgroundedUnlocked);
    await _settle(tester);
    expect(_game.focused, [kPlots[1]]);
  });

  testWidgets('a session already running at launch focuses the camera', (
    tester,
  ) async {
    _clock = FakeClock();
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final overrides = [
      clockProvider.overrideWithValue(_clock),
      databaseProvider.overrideWithValue(db),
      notifierProvider.overrideWithValue(FakeNotifier()),
    ];
    // First launch starts a session, the second launch resumes it.
    final first = ProviderContainer(overrides: overrides);
    addTearDown(first.dispose);
    await tester.runAsync(() async {
      await first.read(focusControllerProvider.future);
      await first.read(focusControllerProvider.notifier).start(25);
    });
    _game = _SpyGame(clock: _clock);
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: MaterialApp(home: HomeScreen(game: _game)),
      ),
    );
    await _settle(tester);
    expect(_game.focused, [kPlots[1]]);
  });

  testWidgets('the recenter button calls recenter', (tester) async {
    await _pump(tester);
    expect(find.byTooltip('Recenter town'), findsOneWidget);
    await tester.tap(find.byTooltip('Recenter town'));
    await tester.pump();
    expect(_game.recentered, 1);
  });

  testWidgets('going to the background pauses the game, returning resumes', (
    tester,
  ) async {
    await _pump(tester);
    expect(_game.limiter.mode, FrameMode.normal);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(_game.inBackground, isTrue);
    expect(_game.limiter.mode, FrameMode.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(_game.inBackground, isFalse);
    expect(_game.limiter.mode, FrameMode.normal);
  });

  testWidgets('low power mode lowers the frame rate', (tester) async {
    await _pump(tester, lowPower: true);
    expect(_game.limiter.mode, FrameMode.lowPower);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(_game.limiter.mode, FrameMode.paused); // paused wins
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(_game.limiter.mode, FrameMode.lowPower);
  });

  testWidgets('reduced motion reaches the game', (tester) async {
    await _pump(tester, reducedMotion: true);
    expect(_game.reducedMotion, isTrue);
  });

  testWidgets('motion is on by default', (tester) async {
    await _pump(tester);
    expect(_game.reducedMotion, isFalse);
  });

  testWidgets('a running session puts hammering workers on the site', (
    tester,
  ) async {
    final c = await _pump(tester);
    await tester.runAsync(
      () => c.read(focusControllerProvider.notifier).start(25),
    );
    await _settle(tester);
    _game.update(0.1);
    final hammering = _game.renderer.workers.where(
      (w) => w.pose == Pose.hammerUp || w.pose == Pose.hammerDown,
    );
    expect(hammering, hasLength(2)); // a house risks 2 workers
  });
}
