import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focus_town/app/providers.dart';
import 'package:focus_town/game/town_game.dart';
import 'package:focus_town/ui/debug_screen.dart';

/// The town, full screen. In debug builds a long press in the top-left corner
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
      final town = next.value?.town;
      if (town != null && town != prev?.value?.town) _game.setTown(town);
    }, fireImmediately: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          GameWidget(game: _game),
          if (kDebugMode)
            Positioned(
              left: 0,
              top: 0,
              width: 56,
              height: 56,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onLongPress: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const DebugScreen()),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
