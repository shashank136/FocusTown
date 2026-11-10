import 'package:focus_town/game/world/block_material.dart';

/// What a worker is doing in one frame.
enum Pose {
  /// Standing, arms down.
  idle,

  /// Hammer raised.
  hammerUp,

  /// Hammer swung down.
  hammerDown,

  /// First step of a walk.
  walk1,

  /// Second step of a walk (a small bob).
  walk2,

  /// Lying flat after a failed session.
  dead,
}

/// A worker standing at ([x], [y]) on ground level, looking along [facing].
class Worker {
  /// Creates a worker.
  const new({
    required this.x,
    required this.y,
    required this.shirt,
    this.facing = (0, 1),
  });

  /// Position on the ground (tile coordinates, center of the feet).
  final double x;

  /// Position on the ground (tile coordinates, center of the feet).
  final double y;

  /// Direction faced: one of (±1, 0) or (0, ±1).
  final (int dx, int dy) facing;

  /// Shirt (or vest) color.
  final FlatColor shirt;
}

/// One box of a worker, in world coordinates.
class WorkerBox {
  /// Creates a box.
  const new({
    required this.x,
    required this.y,
    required this.z,
    required this.w,
    required this.d,
    required this.h,
    required this.color,
  });

  /// Corner, width (x), depth (y) and height (z).
  final double x;

  /// Corner.
  final double y;

  /// Corner (bottom).
  final double z;

  /// Width along x.
  final double w;

  /// Depth along y.
  final double d;

  /// Height.
  final double h;

  /// Face colors.
  final FlatColor color;

  /// Sum of the box center's coordinates: larger means nearer the viewer.
  double get depthKey => x + w / 2 + y + d / 2 + z + h / 2;
}

final FlatColor _pants = FlatColor.of(WorkerColors.pants);
final FlatColor _skin = FlatColor.of(WorkerColors.skin);
final FlatColor _helmet = FlatColor.of(WorkerColors.helmet);
final FlatColor _tool = FlatColor.of(WorkerColors.tool);

/// The boxes that draw [w] in pose [p]; the feet stand at `z = 1`.
List<WorkerBox> boxesFor(Worker w, Pose p) {
  final cx = w.x;
  final cy = w.y;
  if (p == Pose.dead) {
    return [
      WorkerBox(
        x: cx - 0.7,
        y: cy - 0.15,
        z: 1,
        w: 1.1,
        d: 0.3,
        h: 0.22,
        color: w.shirt,
      ),
      WorkerBox(
        x: cx + 0.4,
        y: cy - 0.16,
        z: 1,
        w: 0.32,
        d: 0.32,
        h: 0.3,
        color: _skin,
      ),
      WorkerBox(
        x: cx - 0.4,
        y: cy + 0.45,
        z: 1,
        w: 0.4,
        d: 0.4,
        h: 0.1,
        color: _helmet,
      ),
      WorkerBox(
        x: cx + 0.5,
        y: cy + 0.5,
        z: 1,
        w: 0.5,
        d: 0.1,
        h: 0.08,
        color: _tool,
      ),
    ];
  }
  final bob = p == Pose.hammerDown || p == Pose.walk2 ? 0.04 : 0.0;
  final (dx, dy) = w.facing;
  final (reach, armZ) = switch (p) {
    Pose.hammerUp => (0.26, 2.35),
    Pose.hammerDown => (0.42, 1.95),
    _ => (0.26, 1.3),
  };
  final ax = cx + dx * reach - 0.06 + (dy != 0 ? 0.2 : 0);
  final ay = cy + dy * reach - 0.06 + (dx != 0 ? 0.2 : 0);
  return [
    WorkerBox(
      x: cx - 0.18,
      y: cy - 0.12,
      z: 1,
      w: 0.36,
      d: 0.24,
      h: 0.6,
      color: _pants,
    ),
    WorkerBox(
      x: cx - 0.22,
      y: cy - 0.14,
      z: 1.6 + bob,
      w: 0.44,
      d: 0.28,
      h: 0.5,
      color: w.shirt,
    ),
    WorkerBox(
      x: cx - 0.17,
      y: cy - 0.17,
      z: 2.1 + bob,
      w: 0.34,
      d: 0.34,
      h: 0.34,
      color: _skin,
    ),
    WorkerBox(
      x: cx - 0.2,
      y: cy - 0.2,
      z: 2.44 + bob,
      w: 0.4,
      d: 0.4,
      h: 0.1,
      color: _helmet,
    ),
    WorkerBox(x: ax, y: ay, z: armZ, w: 0.12, d: 0.12, h: 0.36, color: w.shirt),
    if (p == Pose.hammerUp || p == Pose.hammerDown)
      WorkerBox(
        x: ax + dx * 0.12 - 0.05,
        y: ay + dy * 0.12 - 0.05,
        z: p == Pose.hammerUp ? armZ + 0.3 : armZ - 0.06,
        w: 0.22,
        d: 0.22,
        h: 0.12,
        color: _tool,
      ),
  ];
}
