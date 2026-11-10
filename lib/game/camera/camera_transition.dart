// All fields are final; @immutable would need package:meta (not approved).
// ignore_for_file: avoid_equals_and_hash_code_on_mutable_classes

import 'package:focus_town/game/world/vec2.dart';

/// Where the camera looks: the ground point at the view center and the tile
/// size.
class CameraPose {
  /// Creates a pose.
  const new(this.center, this.tile);

  /// Ground point (tile coordinates) shown at the view center.
  final Vec2 center;

  /// Pixels per half block width.
  final double tile;

  @override
  bool operator ==(Object other) =>
      other is CameraPose && other.center == center && other.tile == tile;

  @override
  int get hashCode => Object.hash(center, tile);
}

/// A 400 ms glide from one [CameraPose] to another with an ease-out curve.
class CameraTransition {
  /// Starts a glide from [from] to [to].
  new({required this.from, required this.to});

  /// Total time of the glide.
  static const duration = Duration(milliseconds: 400);

  /// Where it starts.
  final CameraPose from;

  /// Where it ends.
  final CameraPose to;

  Duration _elapsed = Duration.zero;

  /// True once the whole [duration] has been stepped through.
  bool get isDone => _elapsed >= duration;

  /// Advances by [dt] and returns the pose now.
  CameraPose step(Duration dt) {
    _elapsed += dt;
    final t = (_elapsed.inMicroseconds / duration.inMicroseconds).clamp(
      0.0,
      1.0,
    );
    final e = 1 - (1 - t) * (1 - t) * (1 - t); // ease-out cubic
    double lerp(double a, double b) => a + (b - a) * e;
    return CameraPose(
      Vec2(lerp(from.center.x, to.center.x), lerp(from.center.y, to.center.y)),
      lerp(from.tile, to.tile),
    );
  }
}
