import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focus_town/app/providers.dart';
import 'package:focus_town/game/town_game.dart';
import 'package:focus_town/game/world/town_world_builder.dart';
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

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late final TownGame _game = widget.game ?? TownGame();

  @override
  void initState() {
    super.initState();
    // The bridge: the game redraws only when the stored town itself changes,
    // not on every session event.
    ref.listenManual(focusControllerProvider, (prev, next) {
      final focus = next.value;
      if (focus == null) return;
      if (focus.town != prev?.value?.town) _game.setTown(focus.town);
      // A session just became active (or was found running at launch): glide
      // the camera to its site.
      if (focus.active != null && prev?.value?.active == null) {
        _game.focusOnSite(activeSitePlot(focus.town));
      }
    }, fireImmediately: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          GameWidget(game: _game),
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
