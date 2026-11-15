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
      _pos = Float32List(count * 36),
      _col = Int32List(count * 18);

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

  for (var o = 0; o < seen; o++) {
    final j = b._order[o];
    final i = b._seen[j];
    final px = center.x + b._rx[j];
    final py = center.y + b._ry[j];
    final z = b.zs[i];
    final f = b.faces[i];
    // Screen x and y of corner k of the footprint, at height zz.
    double sx(int k) => ox + ((px + cornerX[k]) - (py + cornerY[k])) * t;
    double sy(int k, double zz) =>
        oy + ((px + cornerX[k]) + (py + cornerY[k])) * t * 0.5 - zz * t;
    for (var side = 0; side < 4; side++) {
      if (!sideShown[side] || f & _sideBit[side] == 0) continue;
      final a = _sideFrom[side];
      final d = _sideTo[side];
      quad(
        sx(a),
        sy(a, z + 1),
        sx(d),
        sy(d, z + 1),
        sx(d),
        sy(d, z),
        sx(a),
        sy(a, z),
        _lerpColor(b.sideYColor[i], b.sideXColor[i], sideLit[side]),
      );
    }
    if (f & _top != 0) {
      quad(
        sx(0),
        sy(0, z + 1),
        sx(1),
        sy(1, z + 1),
        sx(2),
        sy(2, z + 1),
        sx(3),
        sy(3, z + 1),
        b.topColor[i],
      );
    }
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
