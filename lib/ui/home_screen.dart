import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focus_town/app/placement.dart';
import 'package:focus_town/app/providers.dart';
import 'package:focus_town/domain/town_rules.dart';
import 'package:focus_town/game/town_game.dart';
import 'package:focus_town/game/world/town_world_builder.dart';
import 'package:focus_town/game/world/vec2.dart';
import 'package:focus_town/ui/debug_screen.dart';

/// The town, full screen. Debug builds add a small bug button (top-left) that
/// opens the debug screen.
class HomeScreen extends ConsumerStatefulWidget {
  /// Creates the home screen. [game] is for tests; it defaults to a new game.
  const new({this.game, super.key});

  /// The game to draw with, or null to create one.
  final TownGame? game;

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  late final TownGame _game =
      widget.game ??
      TownGame(fps: ref.read(fpsProvider), clock: ref.read(clockProvider));

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Battery saver: fewer frames per second.
    ref.listenManual(lowPowerProvider, (prev, next) {
      _game.lowPower = next.value ?? false;
    }, fireImmediately: true);
    // The bridge: the game redraws only when the stored town itself changes,
    // not on every session event.
    ref.listenManual(focusControllerProvider, (prev, next) {
      final focus = next.value;
      if (focus == null) return;
      _game.setFocus(focus);
      // A session just became active (or was found running at launch): glide
      // the camera to its site.
      if (focus.active != null && prev?.value?.active == null) {
        _game.focusOnSite(activeSitePlot(focus.town, focus.active?.plotIndex));
      }
      _syncPlacement();
    }, fireImmediately: true);
    ref.listenManual(placementProvider, (prev, next) => _syncPlacement());
  }

  // Outlines on the free plots while the user is choosing one.
  void _syncPlacement() {
    final placement = ref.read(placementProvider);
    final town = ref.read(focusControllerProvider).value?.town;
    _game.setPlacement(
      placement == null || town == null
          ? const {}
          : {
              for (var i = 0; i < town.plotsUnlocked; i++)
                if (TownRules.isPlotFree(town, i)) i,
            },
      placement?.plot,
    );
  }

  void _pick(Offset at) {
    final plot = _game.plotAtScreen(Vec2(at.dx, at.dy));
    if (plot != null) ref.read(placementProvider.notifier).select(plot);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Nothing is drawn while the app is not in the foreground.
    _game.inBackground = state != AppLifecycleState.resumed;
  }

  @override
  Widget build(BuildContext context) {
    _game.reducedMotion = MediaQuery.of(context).disableAnimations;
    final placement = ref.watch(placementProvider);
    return Scaffold(
      body: Stack(
        children: [
          GameWidget(game: _game),
          // Choose-a-plot mode: taps pick a plot; pan and zoom still work.
          if (placement != null)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTapUp: (d) => _pick(d.localPosition),
              ),
            ),
          if (placement != null)
            SafeArea(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 56),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Choose a plot for your '
                            '${placement.minutes}-minute build',
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextButton(
                                onPressed: ref
                                    .read(placementProvider.notifier)
                                    .cancel,
                                child: const Text('Cancel'),
                              ),
                              const SizedBox(width: 8),
                              FilledButton(
                                onPressed: placement.plot == null
                                    ? null
                                    : () => unawaited(
                                        ref
                                            .read(placementProvider.notifier)
                                            .confirm(),
                                      ),
                                child: const Text('Confirm'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          // "Ready to place": follows the floating building while it shows.
          ValueListenableBuilder<Vec2?>(
            valueListenable: _game.readyLabel,
            builder: (context, at, _) => at == null
                ? const SizedBox.shrink()
                : Positioned(
                    left: at.x - 60,
                    top: at.y - 24,
                    width: 120,
                    child: const IgnorePointer(
                      child: Text(
                        'Ready to place',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          shadows: [Shadow(blurRadius: 4)],
                        ),
                      ),
                    ),
                  ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.bottomRight,
              child: IconButton(
                tooltip: 'Recenter town',
                icon: const Icon(Icons.my_location),
                color: Colors.black54,
                iconSize: 28,
                onPressed: _game.recenter,
              ),
            ),
          ),
          // Debug builds only: a small button, below the status bar.
          if (kDebugMode)
            SafeArea(
              child: Align(
                alignment: Alignment.topLeft,
                child: IconButton(
                  tooltip: 'Open debug screen',
                  icon: const Icon(Icons.bug_report_outlined),
                  color: Colors.black54,
                  iconSize: 28,
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const DebugScreen(),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
