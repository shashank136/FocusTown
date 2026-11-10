import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/game/world/block_material.dart';
import 'package:focus_town/game/world/voxel_world.dart';

void main() {
  late VoxelWorld world;
  setUp(() => world = VoxelWorld());

  group('storage', () {
    test('set, get, has and remove', () {
      world.set(1, 2, 3, Blocks.grass);
      expect(world.get(1, 2, 3), Blocks.grass);
      expect(world.has(1, 2, 3), isTrue);
      expect(world.has(3, 2, 1), isFalse);
      expect(world.get(0, 0, 0), isNull);
      world.remove(1, 2, 3);
      expect(world.has(1, 2, 3), isFalse);
      expect(world.blockCount, 0);
    });

    test('negative z works', () {
      world.set(0, 0, -1, Blocks.dirt);
      expect(world.get(0, 0, -1), Blocks.dirt);
      expect(world.has(0, 0, 0), isFalse);
    });

    test('negative x and y work and do not collide', () {
      world
        ..set(-1, 0, 0, Blocks.stone)
        ..set(0, -1, 0, Blocks.log)
        ..set(0, 0, 0, Blocks.grass);
      expect(world.blockCount, 3);
      expect(world.get(-1, 0, 0), Blocks.stone);
      expect(world.get(0, -1, 0), Blocks.log);
    });

    test('overwriting keeps the count', () {
      world
        ..set(0, 0, 0, Blocks.grass)
        ..set(0, 0, 0, Blocks.dirt);
      expect(world.blockCount, 1);
      expect(world.get(0, 0, 0), Blocks.dirt);
    });

    test('clear empties the world', () {
      world
        ..set(0, 0, 0, Blocks.grass)
        ..clear();
      expect(world.blockCount, 0);
      expect(world.blocks, isEmpty);
    });

    test('blocks lists coordinates and materials', () {
      world.set(-2, 5, -1, Blocks.water);
      final b = world.blocks.single;
      expect((b.x, b.y, b.z), (-2, 5, -1));
      expect(b.material, Blocks.water);
    });

    test('coordinates outside -128..127 are rejected', () {
      expect(() => world.set(128, 0, 0, Blocks.grass), throwsA(anything));
      expect(() => world.set(0, -129, 0, Blocks.grass), throwsA(anything));
    });
  });

  group('fill', () {
    test('a 3x3x2 box adds 18 blocks', () {
      world.fill(0, 0, 0, 2, 2, 1, Blocks.stone);
      expect(world.blockCount, 18);
      expect(world.has(2, 2, 1), isTrue);
      expect(world.has(3, 2, 1), isFalse);
    });
  });

  group('ring', () {
    test('a 5x5 ring adds 16 blocks', () {
      world.ring(0, 0, 5, 5, 0, Blocks.log);
      expect(world.blockCount, 16);
      expect(world.has(2, 2, 0), isFalse);
    });

    test('a 3x3 ring adds 8 blocks', () {
      world.ring(0, 0, 3, 3, 0, Blocks.log);
      expect(world.blockCount, 8);
    });

    test('corner material is used for exactly the four corners', () {
      world.ring(0, 0, 5, 4, 2, Blocks.plank, corner: Blocks.log);
      final corners = world.blocks.where((b) => b.material == Blocks.log);
      expect(corners, hasLength(4));
      expect(corners.map((b) => (b.x, b.y)).toSet(), {
        (0, 0),
        (4, 0),
        (0, 3),
        (4, 3),
      });
      expect(world.blockCount, 14);
    });
  });

  group('visibility', () {
    test('a single block shows all three faces', () {
      world.set(0, 0, 0, Blocks.grass);
      expect(world.visibleFaces(0, 0, 0), kFaceTop | kFaceX | kFaceY);
      expect(world.visibleFaces(0, 0, 0), 7);
    });

    test('a block with neighbors on +x, +y and above is hidden', () {
      world
        ..set(0, 0, 0, Blocks.grass)
        ..set(1, 0, 0, Blocks.grass)
        ..set(0, 1, 0, Blocks.grass)
        ..set(0, 0, 1, Blocks.grass);
      expect(world.visibleFaces(0, 0, 0), 0);
      expect(
        world.sortedVisible().any((b) => b.x == 0 && b.y == 0 && b.z == 0),
        isFalse,
      );
    });

    test('stacking hides only the lower top face', () {
      world
        ..set(0, 0, 0, Blocks.grass)
        ..set(0, 0, 1, Blocks.grass);
      final f = world.visibleFaces(0, 0, 0);
      expect(f & kFaceTop, 0);
      expect(f & kFaceX, kFaceX);
      expect(f & kFaceY, kFaceY);
    });

    test('a block at x+1 hides only the +x face', () {
      world
        ..set(0, 0, 0, Blocks.grass)
        ..set(1, 0, 0, Blocks.grass);
      expect(world.visibleFaces(0, 0, 0), kFaceTop | kFaceY);
    });
  });

  group('sortedVisible', () {
    test('sorts by x + y + z ascending', () {
      world
        ..set(2, 2, 0, Blocks.grass)
        ..set(0, 0, 0, Blocks.grass)
        ..set(1, 1, 0, Blocks.grass);
      expect(world.sortedVisible().map((b) => (b.x, b.y, b.z)), [
        (0, 0, 0),
        (1, 1, 0),
        (2, 2, 0),
      ]);
    });

    test('equal depth breaks ties by z, then x, then y', () {
      world
        ..set(1, 0, 0, Blocks.grass)
        ..set(0, 1, 0, Blocks.grass)
        ..set(0, 0, 1, Blocks.grass);
      expect(world.sortedVisible().map((b) => (b.x, b.y, b.z)), [
        (0, 1, 0),
        (1, 0, 0),
        (0, 0, 1),
      ]);
    });

    test('a 5x5x1 fill has 25 visible blocks', () {
      world.fill(0, 0, 0, 4, 4, 0, Blocks.grass);
      expect(world.sortedVisible(), hasLength(25));
    });

    test('entries carry the material and visible faces', () {
      world.set(0, 0, 0, Blocks.roof);
      final b = world.sortedVisible().single;
      expect(b.material, Blocks.roof);
      expect(b.faces, 7);
    });

    test('the same input always gives the same order', () {
      void build(VoxelWorld w) {
        w
          ..fill(0, 0, 0, 3, 3, 1, Blocks.stone)
          ..set(5, 1, 0, Blocks.log)
          ..set(-2, 4, 2, Blocks.log);
      }

      final a = VoxelWorld();
      final b = VoxelWorld();
      build(a);
      build(b);
      expect(
        a.sortedVisible().map((v) => (v.x, v.y, v.z)).toList(),
        b.sortedVisible().map((v) => (v.x, v.y, v.z)).toList(),
      );
    });
  });
}
