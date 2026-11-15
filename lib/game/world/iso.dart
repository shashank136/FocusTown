import 'dart:math' as math;

import 'package:focus_town/game/world/vec2.dart';

/// Screen position of the world point ([x], [y], [z]).
///
/// [tile] is the width of half a block; [origin] is where (0, 0, 0) lands.
Vec2 project(double x, double y, double z, double tile, Vec2 origin) =>
    Vec2(origin.x + (x - y) * tile, origin.y + (x + y) * tile / 2 - z * tile);

/// World ground (z = 0) point under the screen position ([sx], [sy]).
Vec2 unprojectGround(double sx, double sy, double tile, Vec2 origin) {
  final a = (sx - origin.x) / tile; // x - y
  final b = (sy - origin.y) * 2 / tile; // x + y
  return Vec2((a + b) / 2, (b - a) / 2);
}

/// The ground point ([x], [y]) turned by [angle] radians about [pivot].
Vec2 turnAbout(double x, double y, Vec2 pivot, double angle) {
  final dx = x - pivot.x;
  final dy = y - pivot.y;
  final c = math.cos(angle);
  final s = math.sin(angle);
  return Vec2(pivot.x + dx * c - dy * s, pivot.y + dx * s + dy * c);
}
