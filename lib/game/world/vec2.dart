// All fields are final; @immutable would need package:meta (not approved).
// ignore_for_file: avoid_equals_and_hash_code_on_mutable_classes

/// An immutable 2D point or vector.
class Vec2 {
  /// Creates a vector.
  const new(this.x, this.y);

  /// Horizontal part.
  final double x;

  /// Vertical part.
  final double y;

  @override
  bool operator ==(Object other) =>
      other is Vec2 && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => 'Vec2($x, $y)';
}
