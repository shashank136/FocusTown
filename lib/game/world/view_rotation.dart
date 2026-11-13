// All fields are final; @immutable would need package:meta (not approved).
// ignore_for_file: avoid_equals_and_hash_code_on_mutable_classes

import 'package:focus_town/game/world/voxel_world.dart';

/// Which way the island is seen from: the view turns in steps of 90 degrees.
///
/// A turn maps a tile (x, y) to (-1 - y, x), a point (x, y) to (-y, x): a
/// turn about the middle of the voxel range (-128..127), so a rotated world
/// always fits. Turn 0 is the view the game began with, from the south-east
/// corner of the world (the viewer sees the +x and +y sides of every block).
class ViewRotation {
  /// Creates a view turned [turns] quarter turns (any integer; it wraps).
  const new(int turns) : turns = turns % 4;

  /// The view the game began with.
  static const none = ViewRotation(0);

  /// Quarter turns, 0 to 3.
  final int turns;

  /// The view one turn on.
  ViewRotation get next => ViewRotation(turns + 1);

  /// The view one turn back.
  ViewRotation get previous => ViewRotation(turns - 1);

  /// The view tile of the world tile ([x], [y]).
  (int, int) tile(int x, int y) {
    var tx = x;
    var ty = y;
    for (var i = 0; i < turns; i++) {
      (tx, ty) = (-1 - ty, tx);
    }
    return (tx, ty);
  }

  /// The world tile of the view tile ([x], [y]).
  (int, int) untile(int x, int y) {
    var tx = x;
    var ty = y;
    for (var i = 0; i < turns; i++) {
      (tx, ty) = (ty, -1 - tx);
    }
    return (tx, ty);
  }

  /// The view position of the world point ([x], [y]) (tile units).
  (double, double) point(double x, double y) {
    var px = x;
    var py = y;
    for (var i = 0; i < turns; i++) {
      (px, py) = (-py, px);
    }
    return (px, py);
  }

  /// The world point of the view position ([x], [y]).
  (double, double) unpoint(double x, double y) {
    var px = x;
    var py = y;
    for (var i = 0; i < turns; i++) {
      (px, py) = (py, -px);
    }
    return (px, py);
  }

  /// The view rectangle of the world rectangle at ([x], [y]), [w] wide in x
  /// and [h] tall in y: its top-left tile and its width and height.
  (int, int, int, int) rect(int x, int y, int w, int h) {
    final (ax, ay) = point(x.toDouble(), y.toDouble());
    final (bx, by) = point((x + w).toDouble(), (y + h).toDouble());
    return (
      (ax < bx ? ax : bx).round(),
      (ay < by ? ay : by).round(),
      (bx - ax).abs().round(),
      (by - ay).abs().round(),
    );
  }

  /// [world] seen from this view: every block moved with its tile.
  VoxelWorld rotateWorld(VoxelWorld world) {
    final out = VoxelWorld();
    for (final b in world.blocks) {
      final (x, y) = tile(b.x, b.y);
      out.set(x, y, b.z, b.material);
    }
    return out;
  }

  /// Where world north points on the screen, as a direction (right and down
  /// are positive).
  (double, double) get northOnScreen {
    final (vx, vy) = point(0, -1);
    return (vx - vy, (vx + vy) / 2);
  }

  /// The corner of the world that faces the viewer.
  String get facing {
    final (dx, dy) = unpoint(1, 1);
    return '${dy > 0 ? 'south' : 'north'}-${dx > 0 ? 'east' : 'west'}';
  }

  @override
  bool operator ==(Object other) =>
      other is ViewRotation && other.turns == turns;

  @override
  int get hashCode => turns.hashCode;

  @override
  String toString() => 'ViewRotation($turns)';
}
