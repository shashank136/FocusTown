import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/game/world/block_material.dart';
import 'package:focus_town/game/world/view_rotation.dart';
import 'package:focus_town/game/world/voxel_world.dart';

void main() {
  test('turns wrap around: five turns is one', () {
    expect(const ViewRotation(5), const ViewRotation(1));
    expect(const ViewRotation(-1), const ViewRotation(3));
    expect(ViewRotation.none.next.next.next.next, ViewRotation.none);
    expect(ViewRotation.none.previous, const ViewRotation(3));
  });

  test('a tile turns about the middle of the voxel range', () {
    expect(ViewRotation.none.tile(3, 5), (3, 5));
    expect(const ViewRotation(1).tile(3, 5), (-6, 3));
    expect(const ViewRotation(2).tile(3, 5), (-4, -6));
    expect(const ViewRotation(3).tile(3, 5), (5, -4));
  });

  test('every turn undoes itself, for any tile', () {
    for (var k = 0; k < 4; k++) {
      final r = ViewRotation(k);
      for (final (x, y) in [(0, 0), (3, 5), (-126, 100), (63, -64)]) {
        final (vx, vy) = r.tile(x, y);
        expect(r.untile(vx, vy), (x, y), reason: 'turn $k tile $x,$y');
      }
    }
  });

  test('a point turns the same way as its tile', () {
    for (var k = 0; k < 4; k++) {
      final r = ViewRotation(k);
      final (tx, ty) = r.tile(3, 5);
      final (px, py) = r.point(3.5, 5.5);
      expect((px, py), (tx + 0.5, ty + 0.5), reason: 'turn $k');
      expect(r.unpoint(px, py), (3.5, 5.5), reason: 'turn $k');
    }
  });

  test('a rectangle keeps its area, and swaps its sides on an odd turn', () {
    // A 7 x 7 plot and a 14 x 7 strip at tile (4, 24).
    expect(const ViewRotation(1).rect(4, 24, 7, 7), (-31, 4, 7, 7));
    expect(const ViewRotation(1).rect(4, 24, 14, 7), (-31, 4, 7, 14));
    expect(const ViewRotation(2).rect(4, 24, 14, 7), (-18, -31, 14, 7));
    expect(ViewRotation.none.rect(4, 24, 14, 7), (4, 24, 14, 7));
  });

  test('a rotated world has the same blocks, moved', () {
    final w = VoxelWorld()
      ..set(3, 5, 1, Blocks.stone)
      ..set(4, 5, 1, Blocks.log)
      ..set(-100, 90, 2, Blocks.roof);
    for (var k = 0; k < 4; k++) {
      final r = ViewRotation(k);
      final turned = r.rotateWorld(w);
      expect(turned.blockCount, 3);
      final (x, y) = r.tile(3, 5);
      expect(turned.get(x, y, 1), Blocks.stone);
      final (lx, ly) = r.tile(4, 5);
      expect(turned.get(lx, ly, 1), Blocks.log);
      final (rx, ry) = r.tile(-100, 90);
      expect(turned.get(rx, ry, 2), Blocks.roof);
    }
    // Four turns bring everything back.
    var back = w;
    for (var i = 0; i < 4; i++) {
      back = ViewRotation.none.next.rotateWorld(back);
    }
    expect(
      {for (final b in back.blocks) (b.x, b.y, b.z, b.material)},
      {for (final b in w.blocks) (b.x, b.y, b.z, b.material)},
    );
  });

  test('a rotated world faces the viewer: a lone block shows three faces', () {
    final w = VoxelWorld()..set(3, 5, 1, Blocks.stone);
    for (var k = 0; k < 4; k++) {
      final seen = ViewRotation(k).rotateWorld(w).sortedVisible();
      expect(seen.single.faces, kFaceTop | kFaceX | kFaceY);
    }
  });

  test('north points to a different corner of the screen at every turn', () {
    final corners = <(bool, bool)>{};
    for (var k = 0; k < 4; k++) {
      final (dx, dy) = ViewRotation(k).northOnScreen;
      corners.add((dx > 0, dy > 0));
    }
    expect(corners, hasLength(4));
    // Unturned, north is up and to the right.
    final (dx, dy) = ViewRotation.none.northOnScreen;
    expect(dx, greaterThan(0));
    expect(dy, lessThan(0));
  });

  test('the side that faces the viewer, by name', () {
    expect(ViewRotation.none.facing, 'south-east');
    expect(const ViewRotation(1).facing, 'north-east');
    expect(const ViewRotation(2).facing, 'north-west');
    expect(const ViewRotation(3).facing, 'south-west');
  });
}
