import 'dart:math' as math;

/// Brightness offsets for the four texture variants of every face.
const kVariantOffsets = [-0.09, -0.03, 0.03, 0.08];

/// Sky gradient colors (ARGB).
const kSkyTop = 0xFF8cc9ea;

/// Sky gradient bottom color (ARGB).
const kSkyBottom = 0xFFcdeaf7;

/// [argb] with every channel scaled by `1 + f`, alpha forced to 255.
int shade(int argb, double f) {
  int channel(int shift) {
    final v = (argb >> shift) & 0xFF;
    return math.max(0, math.min(255, (v * (1 + f)).round()));
  }

  return 0xFF000000 | (channel(16) << 16) | (channel(8) << 8) | channel(0);
}

List<int> _faces(int hex, double base) => [
  shade(hex, base),
  for (final v in kVariantOffsets) shade(hex, base + v),
];

/// Face colors of one block type. Index 0 is the base, 1 to 4 the variants.
class BlockMaterial {
  const new _(this.top, this.sideX, this.sideY);

  /// Builds a material from a top and a side color (RGB hex).
  // ignore: unnecessary_type_name_in_constructor, shorthand not valid for factories
  factory BlockMaterial.of(int topHex, int sideHex) => BlockMaterial._(
    _faces(topHex, 0),
    _faces(sideHex, -0.06),
    _faces(sideHex, -0.26),
  );

  /// Top face colors.
  final List<int> top;

  /// Left side face colors.
  final List<int> sideX;

  /// Right side face colors (darker).
  final List<int> sideY;
}

/// The block types of the town.
abstract final class Blocks {
  /// Grass.
  static final grass = BlockMaterial.of(0x6aa84f, 0x866043);

  /// Dirt.
  static final dirt = BlockMaterial.of(0x8b6a47, 0x866043);

  /// Path.
  static final path = BlockMaterial.of(0xbba57c, 0x9b875f);

  /// Wooden planks.
  static final plank = BlockMaterial.of(0xc69c5d, 0xc69c5d);

  /// Log.
  static final log = BlockMaterial.of(0xa8875c, 0x6b4e31);

  /// Cobblestone.
  static final cobble = BlockMaterial.of(0x9d9d9d, 0x8e8e8e);

  /// Stone.
  static final stone = BlockMaterial.of(0xbcbfc5, 0xa7aab0);

  /// Red roof.
  static final roof = BlockMaterial.of(0xb04a3c, 0x9a3f33);

  /// Slate roof.
  static final slate = BlockMaterial.of(0x56708c, 0x4b6178);

  /// Glass.
  static final glass = BlockMaterial.of(0xcdeef7, 0xa9dcec);

  /// Leaves.
  static final leaves = BlockMaterial.of(0x4e9a3d, 0x3f8531);

  /// Water.
  static final water = BlockMaterial.of(0x3d84c6, 0x3574b0);

  /// Wool (red).
  static final wool = BlockMaterial.of(0xe0483e, 0xc63d34);

  /// Charred wood.
  static final char = BlockMaterial.of(0x4a4038, 0x3b332d);

  /// Weathered copper (the green of the Statue of Liberty).
  static final copper = BlockMaterial.of(0x6fc7ae, 0x4fa38c);

  /// Pale limestone (the Colosseum).
  static final travertine = BlockMaterial.of(0xe6d8ae, 0xcbb98c);
}

/// All 16 block types.
final List<BlockMaterial> allBlocks = [
  Blocks.grass,
  Blocks.dirt,
  Blocks.path,
  Blocks.plank,
  Blocks.log,
  Blocks.cobble,
  Blocks.stone,
  Blocks.roof,
  Blocks.slate,
  Blocks.glass,
  Blocks.leaves,
  Blocks.water,
  Blocks.wool,
  Blocks.char,
  Blocks.copper,
  Blocks.travertine,
];

/// One flat color shaded for the three visible faces (workers).
class FlatColor {
  const new _(this.top, this.sideX, this.sideY);

  /// Shades [hex] for top, left and right faces.
  // ignore: unnecessary_type_name_in_constructor, shorthand not valid for factories
  factory FlatColor.of(int hex) =>
      FlatColor._(shade(hex, 0.08), shade(hex, -0.07), shade(hex, -0.27));

  /// Top face color.
  final int top;

  /// Left face color.
  final int sideX;

  /// Right face color.
  final int sideY;
}

/// Worker colors (ARGB).
abstract final class WorkerColors {
  /// Trousers.
  static const pants = 0xFF3b4a6b;

  /// Safety vest.
  static const vest = 0xFFff8a1f;

  /// Skin.
  static const skin = 0xFFe2b48c;

  /// Helmet.
  static const helmet = 0xFFffd23f;

  /// Tool.
  static const tool = 0xFF6b6f78;

  /// Shirt.
  static const shirt = 0xFF3f9e7a;
}
