import 'package:focus_town/game/world/block_material.dart';

/// A sparse grid of blocks. Coordinates must be in -128..127.
class VoxelWorld {
  final Map<int, BlockMaterial> _blocks = {};

  static int _key(int x, int y, int z) {
    assert(
      x >= -128 && x <= 127 && y >= -128 && y <= 127 && z >= -128 && z <= 127,
      'coordinate out of range: ($x, $y, $z)',
    );
    return ((x + 128) << 16) | ((y + 128) << 8) | (z + 128);
  }

  /// Places [m] at ([x], [y], [z]), replacing any block there.
  void set(int x, int y, int z, BlockMaterial m) => _blocks[_key(x, y, z)] = m;

  /// The block at ([x], [y], [z]), if any.
  BlockMaterial? get(int x, int y, int z) => _blocks[_key(x, y, z)];

  /// Whether there is a block at ([x], [y], [z]).
  bool has(int x, int y, int z) => _blocks.containsKey(_key(x, y, z));

  /// Removes the block at ([x], [y], [z]).
  void remove(int x, int y, int z) => _blocks.remove(_key(x, y, z));

  /// Number of blocks.
  int get blockCount => _blocks.length;

  /// Removes every block.
  void clear() => _blocks.clear();

  /// Every block with its coordinates.
  Iterable<({int x, int y, int z, BlockMaterial material})> get blocks =>
      _blocks.entries.map(
        (e) => (
          x: (e.key >> 16) - 128,
          y: ((e.key >> 8) & 0xFF) - 128,
          z: (e.key & 0xFF) - 128,
          material: e.value,
        ),
      );

  /// Fills the inclusive box from ([x0], [y0], [z0]) to ([x1], [y1], [z1]).
  void fill(int x0, int y0, int z0, int x1, int y1, int z1, BlockMaterial m) {
    for (var x = x0; x <= x1; x++) {
      for (var y = y0; y <= y1; y++) {
        for (var z = z0; z <= z1; z++) {
          set(x, y, z, m);
        }
      }
    }
  }

  /// The outline of a [w] by [d] rectangle at height [z]; the four corners use
  /// [corner] when given.
  void ring(
    int x0,
    int y0,
    int w,
    int d,
    int z,
    BlockMaterial m, {
    BlockMaterial? corner,
  }) {
    for (var x = x0; x < x0 + w; x++) {
      for (var y = y0; y < y0 + d; y++) {
        final onEdgeX = x == x0 || x == x0 + w - 1;
        final onEdgeY = y == y0 || y == y0 + d - 1;
        if (!onEdgeX && !onEdgeY) continue;
        set(x, y, z, onEdgeX && onEdgeY ? corner ?? m : m);
      }
    }
  }
}
