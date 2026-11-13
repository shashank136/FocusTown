import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/domain/landmark.dart';
import 'package:focus_town/domain/town_level.dart';
import 'package:focus_town/game/world/block_material.dart';
import 'package:focus_town/game/world/landmark_defs.dart';
import 'package:focus_town/game/world/voxel_world.dart';

const _ox = 20;
const _oy = 20;

VoxelWorld _build(Landmark l, int stage) {
  final w = VoxelWorld();
  buildLandmark(w, l, _ox, _oy, stage);
  return w;
}

BlockMaterial? _at(VoxelWorld w, int x, int y, int z) =>
    w.get(_ox + x, _oy + y, z);

void main() {
  test('their lengths and levels', () {
    for (final (l, minutes, level) in [
      (Landmark.easterIsland, 20, TownLevel.village),
      (Landmark.spaceNeedle, 30, TownLevel.town),
      (Landmark.chichenItza, 25, TownLevel.town),
      (Landmark.petra, 30, TownLevel.town),
      (Landmark.christRedeemer, 40, TownLevel.city),
    ]) {
      expect(l.stages, 12);
      expect(l.minutesPerStage, minutes);
      expect(l.unlockLevel, level);
    }
    expect(Landmark.chichenItza.title, 'Chichén Itzá');
    expect(Landmark.christRedeemer.title, 'Christ the Redeemer');
  });

  test('Chichén Itzá: stepped tiers with stairs, a temple with a door', () {
    final w = _build(Landmark.chichenItza, 8);
    expect(_at(w, 5, 1, 1), Blocks.plank); // the stair
    expect(_at(w, 3, 1, 1), Blocks.cobble); // the wall beside it
    expect(_at(w, 1, 1, 2), Blocks.cobble);
    expect(_at(w, 1, 1, 3), isNull); // the next tier is set back
    expect(_at(_build(Landmark.chichenItza, 9), 5, 7, 9), isNull); // the door
    expect(_at(_build(Landmark.chichenItza, 9), 4, 7, 9), Blocks.stone);
    expect(_at(_build(Landmark.chichenItza, 11), 5, 0, 1), Blocks.char);
  });

  test('Petra: the hall is cut out of the cliff from the start', () {
    for (var s = 1; s <= 12; s++) {
      expect(_at(_build(Landmark.petra, s), 4, 3, 2), isNull, reason: '$s');
    }
    expect(_at(_build(Landmark.petra, 1), 2, 3, 1), Blocks.rose);
    expect(_at(_build(Landmark.petra, 6), 3, 4, 3), Blocks.travertine);
    expect(_at(_build(Landmark.petra, 7), 5, 2, 2), Blocks.char);
    expect(_at(_build(Landmark.petra, 8), 5, 4, 5), Blocks.travertine);
  });

  test(
    'Christ the Redeemer: a flared robe, shoulders, arms, then the head',
    () {
      final robe = _build(Landmark.christRedeemer, 7);
      expect(
        _at(robe, 4, 4, 10),
        Blocks.marble,
      ); // the robe is wide at the feet
      expect(_at(robe, 4, 4, 11), isNull); // and narrow above
      expect(_at(_build(Landmark.christRedeemer, 8), 4, 5, 16), Blocks.marble);
      expect(_at(_build(Landmark.christRedeemer, 8), 2, 5, 16), isNull);
      expect(_at(_build(Landmark.christRedeemer, 9), 2, 5, 16), Blocks.marble);
      expect(_at(_build(Landmark.christRedeemer, 9), 0, 5, 14), Blocks.marble);
      expect(_at(_build(Landmark.christRedeemer, 9), 9, 5, 16), isNull);
      expect(_at(_build(Landmark.christRedeemer, 10), 9, 5, 16), Blocks.marble);
      expect(_at(_build(Landmark.christRedeemer, 10), 5, 5, 19), isNull);
      expect(_at(_build(Landmark.christRedeemer, 11), 5, 5, 19), Blocks.marble);
    },
  );

  test('Easter Island: a long head with a nose, deep eyes and a topknot', () {
    expect(_at(_build(Landmark.easterIsland, 6), 4, 4, 14), Blocks.stone);
    expect(_at(_build(Landmark.easterIsland, 6), 5, 7, 9), isNull);
    expect(_at(_build(Landmark.easterIsland, 7), 5, 7, 9), Blocks.stone);
    expect(_at(_build(Landmark.easterIsland, 8), 4, 7, 12), Blocks.stone);
    expect(_at(_build(Landmark.easterIsland, 9), 4, 7, 11), Blocks.char);
    expect(_at(_build(Landmark.easterIsland, 10), 5, 7, 7), Blocks.cobble);
    expect(_at(_build(Landmark.easterIsland, 11), 5, 5, 15), Blocks.roof);
    expect(_at(_build(Landmark.easterIsland, 12), 2, 6, 6), Blocks.stone);
  });

  test('Space Needle: legs, a waist, a shaft, a round saucer, a spire', () {
    expect(_at(_build(Landmark.spaceNeedle, 1), 3, 3, 3), Blocks.marble);
    expect(_at(_build(Landmark.spaceNeedle, 2), 4, 4, 5), Blocks.marble);
    expect(_at(_build(Landmark.spaceNeedle, 3), 5, 5, 8), Blocks.marble);
    expect(_at(_build(Landmark.spaceNeedle, 5), 5, 5, 15), Blocks.marble);
    expect(_at(_build(Landmark.spaceNeedle, 7), 5, 5, 17), Blocks.marble);
    expect(_at(_build(Landmark.spaceNeedle, 7), 0, 0, 17), isNull); // round
    expect(_at(_build(Landmark.spaceNeedle, 8), 2, 5, 18), Blocks.glass);
    expect(_at(_build(Landmark.spaceNeedle, 9), 2, 5, 19), Blocks.plank);
    expect(_at(_build(Landmark.spaceNeedle, 12), 5, 5, 26), Blocks.wool);
  });
}
