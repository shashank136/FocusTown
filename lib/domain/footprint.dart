// All fields are final; @immutable would need package:meta (not approved).
// ignore_for_file: avoid_equals_and_hash_code_on_mutable_classes

/// How many plots a building covers: [cols] wide (along x) and [rows] deep
/// (along y). A building takes one plot, a castle a 2 x 2 block, and a
/// landmark a rectangle of its own.
class Footprint {
  /// Creates a footprint.
  const new(this.cols, this.rows);

  /// One plot.
  static const one = Footprint(1, 1);

  /// A 2 x 2 block.
  static const block = Footprint(2, 2);

  /// Plots along x.
  final int cols;

  /// Plots along y.
  final int rows;

  /// How many plots it covers.
  int get area => cols * rows;

  @override
  bool operator ==(Object other) =>
      other is Footprint && other.cols == cols && other.rows == rows;

  @override
  int get hashCode => Object.hash(cols, rows);

  @override
  String toString() => 'Footprint($cols x $rows)';
}
