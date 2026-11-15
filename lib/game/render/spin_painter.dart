import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:focus_town/game/world/block_material.dart';
import 'package:focus_town/game/world/vec2.dart';
import 'package:focus_town/game/world/voxel_world.dart';

// Face bits: the top, then the four sides by the way they face.
const _top = 1;
const _px = 2;
const _py = 4;
const _nx = 8;
const _ny = 16;

// The depth buckets of the back-to-front order: three to a tile.
const _bucketsPerTile = 3.0;
const _bucketOffset = 4096;
const _buckets = 8192;

// Room kept in the vertex buffers for boxes that are not blocks (workers and
// smoke).
const _extraVertices = 8192;

/// The blocks of a world in the form the live turning view draws them: every
/// block that shows a face from any side, lowest first, with flat colors.
class SpinBlocks {
  new _(this.count)
    : xs = Float32List(count),
      ys = Float32List(count),
      zs = Float32List(count),
      faces = Uint8List(count),
      topColor = Int32List(count),
      sideXColor = Int32List(count),
      sideYColor = Int32List(count),
      _rx = Float32List(count),
      _ry = Float32List(count),
      _key = Int32List(count),
      _seen = Int32List(count),
      _order = Int32List(count),
      _pos = Float32List((count * 18 + _extraVertices) * 2),
      _col = Int32List(count * 18 + _extraVertices);

  /// Collects the blocks of [world] that show a face.
  // ignore: unnecessary_type_name_in_constructor, shorthand not valid for factories
  factory SpinBlocks.of(VoxelWorld world) {
    final shown =
        <({int x, int y, int z, int faces, BlockMaterial material})>[];
    for (final b in world.blocks) {
      final f =
          (world.has(b.x, b.y, b.z + 1) ? 0 : _top) |
          (world.has(b.x + 1, b.y, b.z) ? 0 : _px) |
          (world.has(b.x, b.y + 1, b.z) ? 0 : _py) |
          (world.has(b.x - 1, b.y, b.z) ? 0 : _nx) |
          (world.has(b.x, b.y - 1, b.z) ? 0 : _ny);
      if (f != 0) {
        shown.add((x: b.x, y: b.y, z: b.z, faces: f, material: b.material));
      }
    }
    shown.sort((a, b) => a.z.compareTo(b.z));
    final out = SpinBlocks._(shown.length);
    for (var i = 0; i < shown.length; i++) {
      final b = shown[i];
      out.xs[i] = b.x.toDouble();
      out.ys[i] = b.y.toDouble();
      out.zs[i] = b.z.toDouble();
      out.faces[i] = b.faces;
      out.topColor[i] = b.material.top[0];
      out.sideXColor[i] = b.material.sideX[0];
      out.sideYColor[i] = b.material.sideY[0];
    }
    return out;
  }

  /// How many blocks.
  final int count;

  /// Block x coordinates, lowest block first.
  final Float32List xs;

  /// Block y coordinates.
  final Float32List ys;

  /// Block heights.
  final Float32List zs;

  /// Which faces of each block show.
  final Uint8List faces;

  /// Base color (ARGB) of the top of each block.
  final Int32List topColor;

  /// Base color of the +x side of each block.
  final Int32List sideXColor;

  /// Base color of the +y side of each block.
  final Int32List sideYColor;

  final Float32List _rx;
  final Float32List _ry;
  final Int32List _key;
  final Int32List _seen;
  final Int32List _order;
  final Float32List _pos;
  final Int32List _col;
}

/// A box that is not a block (a part of a worker, a puff of smoke), in the
/// same tile coordinates as the blocks, drawn with them while the island turns.
class SpinBox {
  /// Creates a box with its corner at ([x], [y], [z]).
  const new({
    required this.x,
    required this.y,
    required this.z,
    required this.w,
    required this.d,
    required this.h,
    required this.top,
    required this.sideX,
    required this.sideY,
    this.alpha = 1,
  });

  /// Corner.
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

  /// Color (ARGB) of the top.
  final int top;

  /// Color of the +x side.
  final int sideX;

  /// Color of the +y side.
  final int sideY;

  /// How solid it is, 0 to 1.
  final double alpha;
}

int _lerpColor(int a, int b, double w) {
  int ch(int shift) {
    final x = (a >> shift) & 0xFF;
    final y = (b >> shift) & 0xFF;
    return (x + (y - x) * w).round();
  }

  return 0xFF000000 | (ch(16) << 16) | (ch(8) << 8) | ch(0);
}

// The corners of a block's footprint, in the order the faces use them.
const List<double> _cornerU = [-0.5, 0.5, 0.5, -0.5];
const List<double> _cornerV = [-0.5, -0.5, 0.5, 0.5];
// Each side face: its two corners, the bit of its face, and its normal.
const List<int> _sideFrom = [0, 1, 2, 3];
const List<int> _sideTo = [1, 2, 3, 0];
const List<int> _sideBit = [_ny, _px, _py, _nx];
const List<double> _sideNormalX = [0.0, 1.0, 0.0, -1.0];
const List<double> _sideNormalY = [-1.0, 0.0, 1.0, 0.0];

/// Draws [blocks] as the island looks when turned by [angle] radians about the
/// ground point [center] (in the same tile coordinates as the blocks).
///
/// Every block is a top and the sides that face the viewer, in flat colors, put
/// in order back to front and handed to the GPU as one batch. A side that faces
/// the viewer along x takes the lit color, one that faces along y the dark one,
/// and in between a mix, so the light moves as the island turns.
void paintSpin(
  Canvas canvas,
  SpinBlocks blocks, {
  required double angle,
  required Vec2 center,
  required double tile,
  required Vec2 origin,
  required Size viewSize,
  List<SpinBox> boxes = const [],
}) {
  final b = blocks;
  final c = math.cos(angle);
  final s = math.sin(angle);
  final t = tile;
  final ox = origin.x;
  final oy = origin.y;
  final w = viewSize.width;
  final h = viewSize.height;

  // The blocks on screen, put in order back to front by counting.
  final counts = Int32List(_buckets + 1);
  var seen = 0;
  for (var i = 0; i < b.count; i++) {
    final dx = b.xs[i] + 0.5 - center.x;
    final dy = b.ys[i] + 0.5 - center.y;
    final rx = dx * c - dy * s;
    final ry = dx * s + dy * c;
    final z = b.zs[i];
    final px = center.x + rx;
    final py = center.y + ry;
    final sx = ox + (px - py) * t;
    final sy = oy + (px + py) * t * 0.5 - z * t;
    if (sx < -2 * t || sx > w + 2 * t || sy < -3 * t || sy > h + 2 * t) {
      continue;
    }
    final key = ((rx + ry + z) * _bucketsPerTile).floor() + _bucketOffset;
    final k = key < 0 ? 0 : (key >= _buckets ? _buckets - 1 : key);
    b._rx[seen] = rx;
    b._ry[seen] = ry;
    b._key[seen] = k;
    b._seen[seen] = i;
    counts[k + 1]++;
    seen++;
  }
  for (var i = 0; i < _buckets; i++) {
    counts[i + 1] += counts[i];
  }
  for (var j = 0; j < seen; j++) {
    b._order[counts[b._key[j]]++] = j;
  }

  // What does not change from block to block.
  final cornerX = [
    for (var k = 0; k < 4; k++) _cornerU[k] * c - _cornerV[k] * s,
  ];
  final cornerY = [
    for (var k = 0; k < 4; k++) _cornerU[k] * s + _cornerV[k] * c,
  ];
  final sideShown = List<bool>.filled(4, false);
  final sideLit = List<double>.filled(4, 0);
  for (var f = 0; f < 4; f++) {
    final nx = _sideNormalX[f] * c - _sideNormalY[f] * s;
    final ny = _sideNormalX[f] * s + _sideNormalY[f] * c;
    sideShown[f] = nx + ny > 1e-6;
    sideLit[f] = sideShown[f] ? (nx / (nx + ny)).clamp(0.0, 1.0) : 0;
  }

  final pos = b._pos;
  final col = b._col;
  var v = 0; // vertices written

  void quad(
    double x0,
    double y0,
    double x1,
    double y1,
    double x2,
    double y2,
    double x3,
    double y3,
    int color,
  ) {
    if (v + 6 > col.length) return;
    final p = v * 2;
    pos[p] = x0;
    pos[p + 1] = y0;
    pos[p + 2] = x1;
    pos[p + 3] = y1;
    pos[p + 4] = x2;
    pos[p + 5] = y2;
    pos[p + 6] = x0;
    pos[p + 7] = y0;
    pos[p + 8] = x2;
    pos[p + 9] = y2;
    pos[p + 10] = x3;
    pos[p + 11] = y3;
    col.fillRange(v, v + 6, color);
    v += 6;
  }

  // A box whose middle is at (px, py) once turned: the sides that face the
  // viewer, then the top. cx and cy are its corners from the middle.
  void box(
    double px,
    double py,
    double z,
    double height,
    List<double> cx,
    List<double> cy,
    int f,
    int topColor,
    int xColor,
    int yColor,
    int alpha,
  ) {
    double sx(int k) => ox + ((px + cx[k]) - (py + cy[k])) * t;
    double sy(int k, double zz) =>
        oy + ((px + cx[k]) + (py + cy[k])) * t * 0.5 - zz * t;
    int solid(int color) => (color & 0xFFFFFF) | (alpha << 24);
    for (var side = 0; side < 4; side++) {
      if (!sideShown[side] || f & _sideBit[side] == 0) continue;
      final a = _sideFrom[side];
      final d = _sideTo[side];
      quad(
        sx(a),
        sy(a, z + height),
        sx(d),
        sy(d, z + height),
        sx(d),
        sy(d, z),
        sx(a),
        sy(a, z),
        solid(_lerpColor(yColor, xColor, sideLit[side])),
      );
    }
    if (f & _top != 0) {
      quad(
        sx(0),
        sy(0, z + height),
        sx(1),
        sy(1, z + height),
        sx(2),
        sy(2, z + height),
        sx(3),
        sy(3, z + height),
        solid(topColor),
      );
    }
  }

  // The boxes that are not blocks, put in order by the same depth.
  final extras = <({int key, SpinBox box, double px, double py})>[];
  for (final e in boxes) {
    final dx = e.x + e.w / 2 - center.x;
    final dy = e.y + e.d / 2 - center.y;
    final rx = dx * c - dy * s;
    final ry = dx * s + dy * c;
    final key =
        ((rx + ry + e.z + e.h / 2 - 0.5) * _bucketsPerTile).floor() +
        _bucketOffset;
    extras.add((key: key, box: e, px: center.x + rx, py: center.y + ry));
  }
  extras.sort((a, b) => a.key.compareTo(b.key));
  var next = 0;
  void drawExtra(({int key, SpinBox box, double px, double py}) e) {
    final bx = e.box;
    final cx = [
      for (var k = 0; k < 4; k++)
        _cornerU[k] * bx.w * c - _cornerV[k] * bx.d * s,
    ];
    final cy = [
      for (var k = 0; k < 4; k++)
        _cornerU[k] * bx.w * s + _cornerV[k] * bx.d * c,
    ];
    box(
      e.px,
      e.py,
      bx.z,
      bx.h,
      cx,
      cy,
      _top | _px | _py | _nx | _ny,
      bx.top,
      bx.sideX,
      bx.sideY,
      (bx.alpha.clamp(0.0, 1.0) * 255).round(),
    );
  }

  for (var o = 0; o < seen; o++) {
    final j = b._order[o];
    final i = b._seen[j];
    // Boxes behind this block go first; those level with it go after it.
    while (next < extras.length && extras[next].key < b._key[j]) {
      drawExtra(extras[next++]);
    }
    box(
      center.x + b._rx[j],
      center.y + b._ry[j],
      b.zs[i],
      1,
      cornerX,
      cornerY,
      b.faces[i],
      b.topColor[i],
      b.sideXColor[i],
      b.sideYColor[i],
      255,
    );
  }
  while (next < extras.length) {
    drawExtra(extras[next++]);
  }
  if (v == 0) return;
  final vertices = Vertices.raw(
    VertexMode.triangles,
    Float32List.sublistView(pos, 0, v * 2),
    colors: Int32List.sublistView(col, 0, v),
  );
  canvas.drawVertices(vertices, BlendMode.dst, Paint());
  vertices.dispose();
}
