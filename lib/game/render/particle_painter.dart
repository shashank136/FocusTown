import 'dart:ui';

import 'package:focus_town/game/effects/particles.dart';
import 'package:focus_town/game/render/block_painter.dart';
import 'package:focus_town/game/world/block_material.dart';
import 'package:focus_town/game/world/vec2.dart';

/// Draws [particles] as small cubes at opacity [alpha] (0 to 1).
void paintParticles(
  Canvas canvas,
  List<Particle> particles,
  double alpha, {
  required double tile,
  required Vec2 origin,
}) {
  canvas.saveLayer(
    null,
    Paint()..color = Color.fromRGBO(0, 0, 0, alpha.clamp(0.0, 1.0)),
  );
  for (final p in particles) {
    paintBox(
      canvas,
      x: p.x,
      y: p.y,
      z: p.z,
      w: 0.25,
      d: 0.25,
      h: 0.25,
      color: FlatColor.of(p.color),
      tile: tile,
      origin: origin,
    );
  }
  canvas.restore();
}
