import 'dart:ui';

import 'package:flame/game.dart';
import 'package:focus_town/domain/town.dart';
import 'package:focus_town/game/town_renderer.dart';

/// The Flame game that draws the town.
class TownGame extends FlameGame {
  /// Draws the sky and the town.
  final TownRenderer renderer = TownRenderer();

  /// Shows [town]; call on every change of the stored town.
  void setTown(TownState town) => renderer.setTown(town);

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    // The renderer is given the size every frame, so a resize needs no extra
    // handling: the static layer re-records when the size changes.
    renderer.paint(canvas, Size(size.x, size.y));
  }
}
