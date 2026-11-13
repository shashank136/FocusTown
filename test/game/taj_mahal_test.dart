import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/domain/landmark.dart';
import 'package:focus_town/domain/town_level.dart';
import 'package:focus_town/game/world/block_material.dart';
import 'package:focus_town/game/world/landmark_defs.dart';
import 'package:focus_town/game/world/voxel_world.dart';

const _ox = 20;
const _oy = 20;

VoxelWorld _taj(int stage) {
  final w = VoxelWorld();
  buildLandmark(w, Landmark.tajMahal, _ox, _oy, stage);
  return w;
}

bool _has(VoxelWorld w, int x, int y, int z) => w.has(_ox + x, _oy + y, z);

void main() {
  test('it is 12 stages of 25 minutes, 5 hours, unlocked at Town', () {
    expect(Landmark.tajMahal.title, 'Taj Mahal');
    expect(Landmark.tajMahal.stages, 12);
    expect(Landmark.tajMahal.minutesPerStage, 25);
    expect(Landmark.tajMahal.totalMinutes, 300);
    expect(Landmark.tajMahal.unlockLevel, TownLevel.town);
  });

  test('a two-step platform, then the hall with its door', () {
    expect(_has(_taj(1), 1, 0, 1), isTrue);
    expect(_has(_taj(1), 2, 1, 2), isFalse);
    expect(_has(_taj(2), 2, 1, 2), isTrue);
    expect(_has(_taj(3), 3, 2, 3), isTrue); // the hall wall
    expect(_has(_taj(3), 5, 3, 3), isFalse); // hollow inside
    expect(_has(_taj(2), 3, 2, 3), isFalse);
    // Two levels a stage: z 3-4 at stage 3, z 5-6 at stage 4.
    expect(_has(_taj(3), 3, 2, 4), isTrue);
    expect(_has(_taj(3), 3, 2, 5), isFalse);
    expect(_has(_taj(4), 3, 2, 6), isTrue);
    expect(_has(_taj(4), 3, 2, 7), isFalse);
  });

  test('the door of the hall is open from the stage it appears', () {
    for (var s = 3; s <= 12; s++) {
      for (final x in [5, 6]) {
        for (final z in [3, 4]) {
          expect(_has(_taj(s), x, 5, z), isFalse, reason: 'stage $s');
        }
      }
    }
  });

  test('four minarets rise in two steps and are capped last', () {
    final corners = [(1, 0), (10, 0), (1, 7), (10, 7)];
    for (final (x, y) in corners) {
      expect(_has(_taj(5), x, y, 6), isTrue);
      expect(_has(_taj(5), x, y, 7), isFalse);
      expect(_has(_taj(6), x, y, 10), isTrue);
      expect(_has(_taj(11), x, y, 11), isFalse);
      expect(_taj(12).get(_ox + x, _oy + y, 11), Blocks.wool);
    }
  });

  test('the dome sits on the roofed hall in two steps', () {
    expect(_has(_taj(6), 4, 3, 7), isFalse);
    expect(_has(_taj(7), 4, 3, 7), isTrue); // the flat roof
    expect(_has(_taj(7), 4, 2, 8), isFalse);
    expect(_has(_taj(8), 4, 2, 9), isTrue);
    expect(_has(_taj(8), 5, 3, 11), isFalse);
    expect(_has(_taj(9), 5, 3, 11), isTrue);
  });

  test('the finial, then the pool in front', () {
    expect(_has(_taj(9), 5, 3, 13), isFalse);
    expect(_taj(10).get(_ox + 5, _oy + 3, 13), Blocks.log);
    expect(_taj(10).get(_ox + 5, _oy + 3, 14), Blocks.wool);
    expect(_has(_taj(10), 5, 9, 1), isFalse);
    expect(_taj(11).get(_ox + 5, _oy + 9, 1), Blocks.water);
  });
}
