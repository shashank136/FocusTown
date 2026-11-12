import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/app/placement.dart';
import 'package:focus_town/app/providers.dart';
import 'package:focus_town/data/database.dart';
import 'package:focus_town/data/mappers.dart';
import 'package:focus_town/data/town_repository.dart';
import 'package:focus_town/domain/building_tier.dart';
import 'package:focus_town/domain/local_date.dart';
import 'package:focus_town/domain/testing/fake_clock.dart';
import 'package:focus_town/domain/tip.dart';
import 'package:focus_town/domain/town.dart';
import 'package:focus_town/game/frame_limiter.dart';
import 'package:focus_town/game/town_game.dart';
import 'package:focus_town/game/workers/worker_model.dart';
import 'package:focus_town/game/world/iso.dart';
import 'package:focus_town/game/world/plot_layout.dart';
import 'package:focus_town/platform/power_state.dart';
import 'package:focus_town/platform/testing/fake_notifier.dart';
import 'package:focus_town/ui/home_screen.dart';
import 'package:focus_town/ui/session_setup_sheet.dart';

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
  TownState? seed,
  bool onboarded = false,
  bool granted = false,
  Set<Tip> shown = const {},
  String? startupMessage,
}) async {
  _clock = FakeClock();
  _game = _SpyGame(clock: _clock);
  final db = AppDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  if (seed != null) {
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
          buildingsToRows(seed, now: _clock.nowWall()),
        ),
      );
    });
  }
  final notifier = FakeNotifier()..permissionGranted = granted;
  if (onboarded || shown.isNotEmpty) {
    final repo = TownRepository(db, _clock);
    await tester.runAsync(() async {
      await repo.loadOrCreate();
      if (onboarded) await repo.setOnboardingDone();
      for (final t in shown) {
        await repo.markTipShown(t);
      }
    });
  }
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        clockProvider.overrideWithValue(_clock),
        databaseProvider.overrideWithValue(db),
        notifierProvider.overrideWithValue(notifier),
        startupMessageProvider.overrideWithValue(startupMessage),
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

  testWidgets('a building with no free plot shows Ready to place, then not', (
    tester,
  ) async {
    final c = await _pump(
      tester,
      seed: TownState.initial().copyWith(
        buildings: [
          for (var i = 0; i < 6; i++)
            TownBuilding(
              id: 'b$i',
              tier: BuildingTier.hut,
              status: BuildingStatus.complete,
              plotIndex: i,
            ),
        ],
        lastPlotGrantDate: LocalDate.fromDateTime(_clock.nowWall()),
      ),
    );
    final controller = c.read(focusControllerProvider.notifier);
    expect(find.byKey(const ValueKey('ready-label')), findsNothing);
    await tester.runAsync(() => controller.start(10));
    _clock.advance(const Duration(minutes: 10));
    await tester.runAsync(controller.tick);
    await _settle(tester);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const ValueKey('ready-label')), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 2));
    expect(find.byKey(const ValueKey('ready-label')), findsNothing);
  });

  group('choose land', () {
    Future<ProviderContainer> choosing(WidgetTester tester) async {
      final c = await _pump(tester);
      c.read(placementProvider.notifier).beginLand();
      await tester.pump();
      // The camera glides out to the coast.
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      return c;
    }

    Offset parcelOnScreen(WidgetTester tester, int k) {
      final cam = _game.renderer.camera!;
      final plot = plotFor(kLandBase + k, const []);
      final c = plot.center;
      final v = project(c.x, c.y, 1, cam.tile, cam.origin);
      return tester.getTopLeft(find.byType(GameWidget<TownGame>)) +
          Offset(v.x, v.y);
    }

    testWidgets('the bar asks for land and the free parcels are outlined', (
      tester,
    ) async {
      await choosing(tester);
      expect(
        find.text('Choose land for your 25-minute session'),
        findsOneWidget,
      );
      expect(find.text('Make it a garden'), findsOneWidget);
      expect(_game.renderer.plotOutlines, {
        for (var i = 0; i < 32; i++) kLandBase + i,
      });
    });

    testWidgets('tapping a parcel selects it, Confirm claims it', (
      tester,
    ) async {
      final c = await choosing(tester);
      await tester.tapAt(parcelOnScreen(tester, 5));
      await tester.pump(const Duration(milliseconds: 400));
      expect(c.read(placementProvider)!.plot, kLandBase + 5);
      await tester.tap(find.text('Confirm'));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
      final land = c.read(focusControllerProvider).requireValue.active!.land;
      expect(land, isNotNull);
      expect(land!.garden, isFalse);
      expect(_game.renderer.plotOutlines, isEmpty);
    });

    testWidgets('the garden switch makes the land a garden', (tester) async {
      final c = await choosing(tester);
      await tester.tap(find.text('Make it a garden'));
      await tester.pump();
      expect(c.read(placementProvider)!.garden, isTrue);
    });
  });

  group('choose a plot', () {
    Offset plotCenterOnScreen(WidgetTester tester, int plot) {
      final cam = _game.renderer.camera!;
      final c = kPlots[plot].center;
      final v = project(c.x, c.y, 1, cam.tile, cam.origin);
      return tester.getTopLeft(find.byType(GameWidget<TownGame>)) +
          Offset(v.x, v.y);
    }

    Future<ProviderContainer> placing(WidgetTester tester) async {
      final c = await _pump(tester);
      c.read(placementProvider.notifier).begin(10);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      return c;
    }

    testWidgets('no bar without a pending placement', (tester) async {
      await _pump(tester);
      expect(find.text('Confirm'), findsNothing);
      expect(find.text('Cancel'), findsNothing);
    });

    testWidgets('a pending placement shows the bar with Confirm disabled', (
      tester,
    ) async {
      await placing(tester);
      expect(find.text('Choose a plot for your 10-minute build'), findsOne);
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Confirm'))
            .onPressed,
        isNull,
      );
      expect(_game.renderer.plotOutlines, {for (var i = 1; i < 64; i++) i});
    });

    testWidgets('tapping a free plot selects it and enables Confirm', (
      tester,
    ) async {
      final c = await placing(tester);
      await tester.tapAt(plotCenterOnScreen(tester, 3));
      await tester.pump(const Duration(milliseconds: 400));
      expect(c.read(placementProvider)!.plot, 3);
      expect(_game.renderer.selectedPlot, 3);
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Confirm'))
            .onPressed,
        isNotNull,
      );
    });

    testWidgets('tapping the starter plot selects nothing', (tester) async {
      final c = await placing(tester);
      await tester.tapAt(plotCenterOnScreen(tester, 0));
      await tester.pump(const Duration(milliseconds: 400));
      expect(c.read(placementProvider)!.plot, isNull);
    });

    testWidgets('Confirm starts the session on that plot', (tester) async {
      final c = await placing(tester);
      await tester.tapAt(plotCenterOnScreen(tester, 4));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('Confirm'));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
      final focus = c.read(focusControllerProvider).requireValue;
      expect(focus.active!.plotIndex, 4);
      expect(c.read(placementProvider), isNull);
      expect(find.text('Confirm'), findsNothing);
      expect(_game.renderer.plotOutlines, isEmpty);
    });

    testWidgets('Cancel starts nothing and hides the bar', (tester) async {
      final c = await placing(tester);
      await tester.tap(find.text('Cancel'));
      await tester.pump();
      expect(c.read(placementProvider), isNull);
      expect(c.read(focusControllerProvider).requireValue.active, isNull);
      expect(find.text('Confirm'), findsNothing);
    });
  });

  group('Start focus', () {
    testWidgets('the button shows without a session and opens the sheet', (
      tester,
    ) async {
      await _pump(tester);
      expect(find.text('Start focus'), findsOneWidget);
      await tester.tap(find.text('Start focus'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(SessionSetupSheet), findsOneWidget);
    });

    testWidgets('starting from the sheet hides the button', (tester) async {
      final c = await _pump(tester);
      await tester.tap(find.text('Start focus'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 60)),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Start'));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 60)),
      );
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      expect(c.read(focusControllerProvider).requireValue.active, isNotNull);
      expect(find.text('Start focus'), findsNothing);
      expect(find.byType(SessionSetupSheet), findsNothing);
    });

    testWidgets('the button is back after the session ends', (tester) async {
      final c = await _pump(tester);
      final controller = c.read(focusControllerProvider.notifier);
      await tester.runAsync(() => controller.start(10));
      await tester.pump();
      expect(find.text('Start focus'), findsNothing);
      _clock.advance(const Duration(minutes: 10));
      await tester.runAsync(controller.tick);
      await _settle(tester);
      expect(find.text('Start focus'), findsOneWidget);
    });

    testWidgets('the button hides while a plot is being chosen', (
      tester,
    ) async {
      final c = await _pump(tester);
      c.read(placementProvider.notifier).begin(10);
      await tester.pump();
      expect(find.text('Start focus'), findsNothing);
      c.read(placementProvider.notifier).cancel();
      await tester.pump();
      expect(find.text('Start focus'), findsOneWidget);
    });
  });

  group('the whole session loop', () {
    Future<void> pumpFor(WidgetTester tester, Duration d) async {
      await tester.pump(d);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 60)),
      );
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400)); // the dialog route
    }

    testWidgets('the HUD and, in a session, the panel are on screen', (
      tester,
    ) async {
      final c = await _pump(tester);
      expect(find.byKey(const ValueKey('hud-workers')), findsOneWidget);
      expect(find.text('Abandon'), findsNothing);
      await tester.runAsync(
        () => c.read(focusControllerProvider.notifier).start(25),
      );
      await pumpFor(tester, const Duration(milliseconds: 100));
      expect(find.text('Abandon'), findsOneWidget);
      expect(find.text('25:00'), findsOneWidget);
    });

    testWidgets('a session completes by itself, then the dialog, then Start', (
      tester,
    ) async {
      final c = await _pump(tester);
      await tester.runAsync(
        () => c.read(focusControllerProvider.notifier).start(25),
      );
      await pumpFor(tester, const Duration(milliseconds: 100));
      _clock.advance(const Duration(minutes: 25));
      await pumpFor(tester, const Duration(seconds: 1));
      expect(find.text('House built'), findsOneWidget);
      expect(find.text('+2 workers'), findsOneWidget);
      await tester.tap(find.text('Continue'));
      await pumpFor(tester, const Duration(milliseconds: 100));
      expect(find.text('House built'), findsNothing);
      expect(c.read(focusControllerProvider).requireValue.lastResult, isNull);
      expect(find.text('Start focus'), findsOneWidget);
      // The HUD now shows the 5 workers.
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('hud-workers'))).data,
        '5',
      );
    });

    testWidgets('the timer keeps running while the town is a still picture', (
      tester,
    ) async {
      final c = await _pump(tester);
      _game.guard.recordError('forced');
      await tester.runAsync(
        () => c.read(focusControllerProvider.notifier).start(25),
      );
      await pumpFor(tester, const Duration(milliseconds: 100));
      _clock.advance(const Duration(minutes: 25));
      await pumpFor(tester, const Duration(seconds: 1));
      expect(find.text('House built'), findsOneWidget);
    });

    testWidgets('leaving for 90 seconds fails the build with a dialog', (
      tester,
    ) async {
      final c = await _pump(tester);
      final controller = c.read(focusControllerProvider.notifier);
      await tester.runAsync(() => controller.start(25));
      await pumpFor(tester, const Duration(milliseconds: 100));
      await tester.runAsync(controller.onBackgroundedUnlocked);
      _clock.advance(const Duration(seconds: 90));
      await tester.runAsync(controller.onForegrounded);
      await pumpFor(tester, const Duration(milliseconds: 100));
      expect(find.text('Your builders stopped'), findsOneWidget);
      expect(find.text('Lost 2 workers'), findsOneWidget);
      await tester.tap(find.text('Continue'));
      await pumpFor(tester, const Duration(milliseconds: 100));
      expect(find.text('Your builders stopped'), findsNothing);
    });

    testWidgets('abandoning from the panel shows the abandoned dialog', (
      tester,
    ) async {
      final c = await _pump(tester);
      await tester.runAsync(
        () => c.read(focusControllerProvider.notifier).start(10),
      );
      await pumpFor(tester, const Duration(milliseconds: 100));
      await tester.tap(find.text('Abandon'));
      await pumpFor(tester, const Duration(milliseconds: 100));
      await tester.tap(find.widgetWithText(TextButton, 'Abandon').last);
      await pumpFor(tester, const Duration(milliseconds: 100));
      expect(find.text('You abandoned the build'), findsOneWidget);
    });

    testWidgets('a result is shown only once', (tester) async {
      final c = await _pump(tester);
      await tester.runAsync(
        () => c.read(focusControllerProvider.notifier).start(10),
      );
      _clock.advance(const Duration(minutes: 10));
      await pumpFor(tester, const Duration(seconds: 1));
      expect(find.text('Hut built'), findsOneWidget);
      await pumpFor(tester, const Duration(seconds: 2));
      expect(find.text('Hut built'), findsOneWidget);
    });
  });

  group('tips', () {
    Future<void> pumpFor(WidgetTester tester, Duration d) async {
      await tester.pump(d);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 60)),
      );
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
    }

    Future<void> finishHut(WidgetTester tester, ProviderContainer c) async {
      await tester.runAsync(
        () => c.read(focusControllerProvider.notifier).start(10),
      );
      await pumpFor(tester, const Duration(milliseconds: 100));
      _clock.advance(const Duration(minutes: 10));
      await pumpFor(tester, const Duration(seconds: 1));
    }

    const growth = 'Huts and houses add builders to your town.';

    testWidgets('the growth line shows on the first hut only', (tester) async {
      final c = await _pump(tester);
      await finishHut(tester, c);
      expect(find.text(growth), findsOneWidget);
      await tester.tap(find.text('Continue'));
      await pumpFor(tester, const Duration(milliseconds: 100));
      await finishHut(tester, c);
      expect(find.text('Hut built'), findsOneWidget);
      expect(find.text(growth), findsNothing);
    });

    testWidgets('no growth line once it was shown before', (tester) async {
      final c = await _pump(tester, shown: {Tip.growth});
      await finishHut(tester, c);
      expect(find.text('Hut built'), findsOneWidget);
      expect(find.text(growth), findsNothing);
    });

    testWidgets('the pass tip appears once, when the pass is spent', (
      tester,
    ) async {
      final c = await _pump(tester);
      final controller = c.read(focusControllerProvider.notifier);
      await tester.runAsync(() => controller.start(25));
      await pumpFor(tester, const Duration(milliseconds: 100));
      expect(find.textContaining('Emergency pass used'), findsNothing);
      await tester.runAsync(controller.onBackgroundedUnlocked);
      _clock.advance(const Duration(seconds: 30));
      await tester.runAsync(controller.onForegrounded);
      await pumpFor(tester, const Duration(milliseconds: 100));
      expect(find.textContaining('Emergency pass used'), findsOneWidget);
      expect(find.textContaining('Once a week'), findsOneWidget);
    });

    testWidgets('the pass tip stays away once shown', (tester) async {
      final c = await _pump(tester, shown: {Tip.pass});
      final controller = c.read(focusControllerProvider.notifier);
      await tester.runAsync(() => controller.start(25));
      await tester.runAsync(controller.onBackgroundedUnlocked);
      _clock.advance(const Duration(seconds: 30));
      await tester.runAsync(controller.onForegrounded);
      await pumpFor(tester, const Duration(milliseconds: 100));
      expect(find.textContaining('Emergency pass used'), findsNothing);
    });

    Future<void> loseEveryBuilder(
      WidgetTester tester,
      ProviderContainer c,
    ) async {
      final controller = c.read(focusControllerProvider.notifier);
      await tester.runAsync(() => controller.start(25));
      await pumpFor(tester, const Duration(milliseconds: 100));
      await tester.runAsync(controller.abandon);
      await pumpFor(tester, const Duration(milliseconds: 100));
    }

    final twoBuilders = TownState.initial().copyWith(workers: 2);
    const fullText = 'All your builders are gone.';
    const shortText =
        'Recovery mode again. Build huts to get back to 3 builders.';

    testWidgets('the first recovery explains the Last Builder in full', (
      tester,
    ) async {
      final c = await _pump(tester, seed: twoBuilders);
      await loseEveryBuilder(tester, c);
      expect(find.text('The Last Builder'), findsOneWidget);
      expect(find.textContaining(fullText), findsOneWidget);
      expect(find.text(shortText), findsNothing);
      await tester.tap(find.text('Continue'));
      await pumpFor(tester, const Duration(milliseconds: 100));
      expect(
        await tester.runAsync(() => c.read(townRepositoryProvider).shownTips()),
        contains(Tip.recovery),
      );
    });

    testWidgets('a later recovery gets the short line', (tester) async {
      final c = await _pump(tester, seed: twoBuilders, shown: {Tip.recovery});
      await loseEveryBuilder(tester, c);
      expect(find.text(shortText), findsOneWidget);
      expect(find.textContaining(fullText), findsNothing);
    });

    const note = 'Warnings are off.';

    testWidgets('the note shows after onboarding without permission', (
      tester,
    ) async {
      await _pump(tester, onboarded: true);
      expect(find.textContaining(note), findsOneWidget);
    });

    testWidgets('no note before onboarding or with permission', (tester) async {
      await _pump(tester);
      expect(find.textContaining(note), findsNothing);
    });

    testWidgets('no note when permission is granted', (tester) async {
      await _pump(tester, onboarded: true, granted: true);
      expect(find.textContaining(note), findsNothing);
    });

    testWidgets('dismissing the note hides it for good', (tester) async {
      final c = await _pump(tester, onboarded: true);
      await tester.tap(find.text('Dismiss'));
      await pumpFor(tester, const Duration(milliseconds: 100));
      expect(find.textContaining(note), findsNothing);
      expect(
        await tester.runAsync(() => c.read(townRepositoryProvider).shownTips()),
        contains(Tip.notificationNote),
      );
    });
  });

  group('repair a ruin', () {
    Offset plotOnScreen(WidgetTester tester, int plot) {
      final cam = _game.renderer.camera!;
      final c = kPlots[plot].center;
      final v = project(c.x, c.y, 1, cam.tile, cam.origin);
      return tester.getTopLeft(find.byType(GameWidget<TownGame>)) +
          Offset(v.x, v.y);
    }

    TownState withRuin() => TownState.initial().copyWith(
      buildings: [
        const TownBuilding(
          id: 'a',
          tier: BuildingTier.house,
          status: BuildingStatus.complete,
          plotIndex: 0,
        ),
        const TownBuilding(
          id: 'r',
          tier: BuildingTier.house,
          status: BuildingStatus.ruin,
          plotIndex: 2,
        ),
      ],
    );

    testWidgets('tapping a ruin offers a 10-minute repair', (tester) async {
      await _pump(tester, seed: withRuin());
      await tester.tapAt(plotOnScreen(tester, 2));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Repair this ruin?'), findsOneWidget);
      expect(find.text('Repair (10 min)'), findsOneWidget);
    });

    testWidgets('Repair starts the repair on that ruin', (tester) async {
      final c = await _pump(tester, seed: withRuin());
      await tester.tapAt(plotOnScreen(tester, 2));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('Repair (10 min)'));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump(const Duration(milliseconds: 400));
      final active = c.read(focusControllerProvider).requireValue.active;
      expect(active?.repairPlot, 2);
      expect(find.text('Repair this ruin?'), findsNothing);
    });

    testWidgets('Cancel starts nothing', (tester) async {
      final c = await _pump(tester, seed: withRuin());
      await tester.tapAt(plotOnScreen(tester, 2));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('Cancel'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(c.read(focusControllerProvider).requireValue.active, isNull);
    });

    testWidgets('tapping a standing building offers nothing', (tester) async {
      await _pump(tester, seed: withRuin());
      await tester.tapAt(plotOnScreen(tester, 0));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Repair this ruin?'), findsNothing);
    });
  });

  group('semantics', () {
    testWidgets('Start focus and every icon button have a label', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(tester);
      expect(find.bySemanticsLabel('Start focus'), findsOneWidget);
      final buttons = find.byType(IconButton);
      expect(buttons, findsWidgets);
      for (final b in buttons.evaluate()) {
        final node = tester.getSemantics(find.byWidget(b.widget));
        // A tooltip is read out as the button's name.
        expect(node.label + node.tooltip, isNotEmpty);
      }
      handle.dispose();
    });
  });

  group('startup message', () {
    const text = "We couldn't load your town and started a new one.";

    testWidgets('shows once when the town was started fresh', (tester) async {
      await _pump(tester, startupMessage: text);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text(text), findsOneWidget);
    });

    testWidgets('shows nothing on a normal start', (tester) async {
      await _pump(tester);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text(text), findsNothing);
    });
  });
}
