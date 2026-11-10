import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focus_town/app/providers.dart';
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
        _game.focusOnSite(activeSitePlot(focus.town));
      }
    }, fireImmediately: true);
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
    return Scaffold(
      body: Stack(
        children: [
          GameWidget(game: _game),
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
