import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/domain/landmark.dart';
import 'package:focus_town/domain/town_level.dart';
import 'package:focus_town/game/world/block_material.dart';
import 'package:focus_town/game/world/landmark_defs.dart';
import 'package:focus_town/game/world/voxel_world.dart';

const _ox = 20;
const _oy = 20;

VoxelWorld _statue(int stage) {
  final w = VoxelWorld();
  buildLandmark(w, Landmark.statueOfLiberty, _ox, _oy, stage);
  return w;
}

bool _has(VoxelWorld w, int x, int y, int z) => w.has(_ox + x, _oy + y, z);

void main() {
  test('it is 12 stages of 30 minutes, 6 hours, unlocked at Town', () {
    expect(Landmark.statueOfLiberty.title, 'Statue of Liberty');
    expect(Landmark.statueOfLiberty.stages, 12);
    expect(Landmark.statueOfLiberty.minutesPerStage, 30);
    expect(Landmark.statueOfLiberty.totalMinutes, 360);
    expect(Landmark.statueOfLiberty.unlockLevel, TownLevel.town);
  });

  test('a two-step square base, then the pedestal with a door', () {
    expect(_has(_statue(1), 1, 1, 1), isTrue);
    expect(_has(_statue(1), 2, 2, 2), isFalse);
    expect(_has(_statue(2), 2, 2, 2), isTrue);
    expect(_has(_statue(3), 4, 4, 4), isTrue);
    expect(_has(_statue(3), 4, 4, 5), isFalse);
    expect(_has(_statue(4), 4, 4, 6), isTrue);
    expect(_has(_statue(4), 3, 3, 7), isFalse);
    expect(_has(_statue(5), 3, 3, 7), isTrue); // the ledge on top
  });

  test('the pedestal door is open from the stage it appears', () {
    for (var s = 3; s <= 12; s++) {
      for (final x in [5, 6]) {
        for (final z in [3, 4]) {
          expect(_has(_statue(s), x, 7, z), isFalse, reason: 'stage $s');
        }
      }
    }
  });

  test('the green robe, torso and head rise one stage at a time', () {
    expect(_statue(6).get(_ox + 5, _oy + 5, 11), Blocks.leaves);
    expect(_has(_statue(6), 5, 5, 12), isFalse);
    expect(_has(_statue(7), 5, 5, 14), isTrue);
    expect(_has(_statue(7), 5, 5, 15), isFalse);
    expect(_has(_statue(8), 5, 5, 16), isTrue);
  });

  test('a crown with rays, then the raised arm', () {
    expect(_has(_statue(8), 4, 5, 16), isFalse);
    expect(_statue(9).get(_ox + 4, _oy + 5, 16), Blocks.wool);
    expect(_has(_statue(9), 5, 5, 17), isTrue);
    expect(_has(_statue(9), 7, 5, 15), isFalse);
    expect(_statue(10).get(_ox + 7, _oy + 5, 18), Blocks.leaves);
  });

  test('the tablet and the torch handle, then the flame', () {
    expect(_has(_statue(10), 7, 5, 19), isFalse);
    expect(_statue(11).get(_ox + 7, _oy + 5, 19), Blocks.log);
    expect(_statue(11).get(_ox + 4, _oy + 6, 13), Blocks.plank);
    expect(_has(_statue(11), 7, 5, 20), isFalse);
    expect(_statue(12).get(_ox + 7, _oy + 5, 20), Blocks.wool);
    expect(_statue(12).get(_ox + 7, _oy + 5, 21), Blocks.wool);
  });
}
