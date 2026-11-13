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

  test('a star-cut base, a cobble step, then the pedestal with a door', () {
    expect(_has(_statue(1), 3, 1, 1), isTrue);
    expect(_has(_statue(1), 1, 1, 1), isFalse); // the corner is cut
    expect(_has(_statue(1), 2, 3, 2), isFalse);
    expect(_has(_statue(2), 2, 3, 2), isTrue);
    expect(_has(_statue(3), 4, 4, 4), isTrue);
    expect(_has(_statue(3), 4, 4, 5), isFalse);
    expect(_has(_statue(4), 4, 4, 8), isTrue);
    expect(_has(_statue(4), 3, 3, 9), isFalse);
    expect(_has(_statue(5), 3, 3, 9), isTrue); // the ledge on top
  });

  test('the pedestal door is open from the stage it appears', () {
    for (var s = 3; s <= 12; s++) {
      for (final x in [5, 6]) {
        for (final z in [3, 4]) {
          expect(_has(_statue(s), x, 8, z), isFalse, reason: 'stage $s');
        }
      }
    }
  });

  test('the copper robe, torso and head rise one stage at a time', () {
    expect(_statue(6).get(_ox + 4, _oy + 4, 10), Blocks.copper);
    expect(_has(_statue(6), 5, 5, 13), isTrue);
    expect(_has(_statue(6), 5, 5, 14), isFalse);
    expect(_has(_statue(7), 5, 5, 17), isTrue);
    expect(_has(_statue(7), 5, 5, 18), isFalse);
    expect(_has(_statue(8), 5, 5, 19), isTrue);
  });

  test('a crown with rays, then the raised arm', () {
    expect(_has(_statue(8), 4, 5, 20), isFalse);
    expect(_statue(9).get(_ox + 4, _oy + 5, 20), Blocks.plank);
    expect(_has(_statue(9), 7, 4, 23), isFalse);
    expect(_statue(10).get(_ox + 7, _oy + 4, 23), Blocks.copper);
  });

  test('the torch and the tablet, then the flame', () {
    expect(_has(_statue(10), 7, 4, 24), isFalse);
    expect(_statue(11).get(_ox + 7, _oy + 4, 24), Blocks.plank);
    expect(_statue(11).get(_ox + 4, _oy + 7, 14), Blocks.plank);
    expect(_has(_statue(11), 7, 4, 25), isFalse);
    expect(_statue(12).get(_ox + 7, _oy + 4, 25), Blocks.wool);
    expect(_statue(12).get(_ox + 7, _oy + 4, 26), Blocks.wool);
  });
}
