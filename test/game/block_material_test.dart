import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/game/world/block_material.dart';

void main() {
  group('shade', () {
    test('f = 0 keeps the color and forces alpha 255', () {
      expect(shade(0x6aa84f, 0), 0xFF6aa84f);
      expect(shade(0x006aa84f, 0), 0xFF6aa84f);
    });

    test('f = -1 gives black', () {
      expect(shade(0xFFFFFF, -1), 0xFF000000);
    });

    test('clamps channels at 255', () {
      expect(shade(0x6aa84f, 10), 0xFFFFFFFF);
    });

    test('rounds each channel', () {
      // 0x10 = 16; 16 * 1.5 = 24 = 0x18
      expect(shade(0x101010, 0.5), 0xFF181818);
    });
  });

  group('BlockMaterial', () {
    test('every list has 5 entries', () {
      for (final m in allBlocks) {
        expect(m.top, hasLength(5));
        expect(m.sideX, hasLength(5));
        expect(m.sideY, hasLength(5));
      }
    });

    test('grass top base is the plain color', () {
      expect(Blocks.grass.top[0], 0xFF6aa84f);
    });

    test('grass side bases use -0.06 and -0.26', () {
      expect(Blocks.grass.sideX[0], shade(0x866043, -0.06));
      expect(Blocks.grass.sideY[0], shade(0x866043, -0.26));
    });

    test('variant 1 of grass top is shade -0.09', () {
      expect(Blocks.grass.top[1], shade(0x6aa84f, -0.09));
    });

    test('side variants add the offsets to the side base factor', () {
      expect(Blocks.grass.sideX[2], shade(0x866043, -0.06 + -0.03));
      expect(Blocks.grass.sideY[4], shade(0x866043, -0.26 + 0.08));
    });

    test('variant offsets are the documented four', () {
      expect(kVariantOffsets, [-0.09, -0.03, 0.03, 0.08]);
    });

    test('all 14 materials exist', () {
      expect(allBlocks, hasLength(18));
    });

    test('plank uses the same color on top and sides', () {
      expect(Blocks.plank.top[0], 0xFFc69c5d);
      expect(Blocks.plank.sideX[0], shade(0xc69c5d, -0.06));
    });
  });

  group('FlatColor and WorkerColors', () {
    test('FlatColor shades top, sideX and sideY', () {
      final c = FlatColor.of(0xff8a1f);
      expect(c.top, shade(0xff8a1f, 0.08));
      expect(c.sideX, shade(0xff8a1f, -0.07));
      expect(c.sideY, shade(0xff8a1f, -0.27));
    });

    test('worker colors match the prototype', () {
      expect(WorkerColors.vest, 0xFFff8a1f);
      expect(WorkerColors.pants, 0xFF3b4a6b);
      expect(WorkerColors.skin, 0xFFe2b48c);
      expect(WorkerColors.helmet, 0xFFffd23f);
      expect(WorkerColors.tool, 0xFF6b6f78);
      expect(WorkerColors.shirt, 0xFF3f9e7a);
    });
  });

  test('sky gradient colors', () {
    expect(kSkyTop, 0xFF8cc9ea);
    expect(kSkyBottom, 0xFFcdeaf7);
  });
}
