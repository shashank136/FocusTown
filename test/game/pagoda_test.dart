import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/domain/landmark.dart';
import 'package:focus_town/domain/town_level.dart';
import 'package:focus_town/game/world/block_material.dart';
import 'package:focus_town/game/world/landmark_defs.dart';
import 'package:focus_town/game/world/voxel_world.dart';

const _ox = 20;
const _oy = 20;

VoxelWorld _pagoda(int stage) {
  final w = VoxelWorld();
  buildLandmark(w, Landmark.pagoda, _ox, _oy, stage);
  return w;
}

void main() {
  test('it is 12 stages of 20 minutes, 4 hours, unlocked at Town', () {
    expect(Landmark.pagoda.title, 'Pagoda');
    expect(Landmark.pagoda.stages, 12);
    expect(Landmark.pagoda.minutesPerStage, 20);
    expect(Landmark.pagoda.totalMinutes, 240);
    expect(Landmark.pagoda.unlockLevel, TownLevel.town);
  });

  test('a tier is its walls, then its red roof, each a stage', () {
    expect(_pagoda(1).has(_ox + 2, _oy + 2, 1), isTrue); // tier 1 walls
    expect(_pagoda(1).has(_ox + 1, _oy + 1, 3), isFalse);
    expect(_pagoda(2).get(_ox + 1, _oy + 1, 3), Blocks.roof); // its roof
    expect(_pagoda(2).has(_ox + 3, _oy + 3, 4), isFalse);
    expect(_pagoda(3).has(_ox + 3, _oy + 3, 4), isTrue); // tier 2 walls
    expect(_pagoda(4).get(_ox + 2, _oy + 2, 6), Blocks.roof);
  });

  test('the tiers narrow as they rise', () {
    expect(_pagoda(6).get(_ox + 2, _oy + 2, 9), Blocks.roof); // tier 3 roof
    expect(_pagoda(7).has(_ox + 4, _oy + 4, 10), isTrue); // tier 4 walls
    expect(_pagoda(7).has(_ox + 3, _oy + 3, 10), isFalse);
    expect(_pagoda(8).get(_ox + 3, _oy + 3, 12), Blocks.roof);
    expect(_pagoda(10).get(_ox + 3, _oy + 3, 15), Blocks.roof);
  });

  test('the door is open from the first stage', () {
    for (var s = 1; s <= 12; s++) {
      for (final x in [_ox + 5, _ox + 6]) {
        for (final z in [1, 2]) {
          expect(_pagoda(s).has(x, _oy + 9, z), isFalse, reason: 'stage $s');
        }
      }
    }
  });

  test('the spire and the upturned eaves come last', () {
    expect(_pagoda(10).has(_ox + 5, _oy + 5, 16), isFalse);
    expect(_pagoda(11).has(_ox + 5, _oy + 5, 16), isTrue);
    expect(_pagoda(11).has(_ox + 5, _oy + 5, 19), isTrue);
    expect(_pagoda(11).has(_ox + 5, _oy + 5, 20), isFalse);
    expect(_pagoda(11).has(_ox + 1, _oy + 1, 4), isFalse);
    expect(_pagoda(12).get(_ox + 5, _oy + 5, 20), Blocks.wool);
    expect(_pagoda(12).get(_ox + 1, _oy + 1, 4), Blocks.wool);
  });
}
