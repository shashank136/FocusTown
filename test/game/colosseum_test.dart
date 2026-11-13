import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/domain/landmark.dart';
import 'package:focus_town/domain/town_level.dart';
import 'package:focus_town/game/world/block_material.dart';
import 'package:focus_town/game/world/landmark_defs.dart';
import 'package:focus_town/game/world/voxel_world.dart';

const _ox = 20;
const _oy = 20;

VoxelWorld _colosseum(int stage) {
  final w = VoxelWorld();
  buildLandmark(w, Landmark.colosseum, _ox, _oy, stage);
  return w;
}

bool _has(VoxelWorld w, int x, int y, int z) => w.has(_ox + x, _oy + y, z);

void main() {
  test('it is 12 stages of 40 minutes, 8 hours, unlocked at City', () {
    expect(Landmark.colosseum.title, 'Colosseum');
    expect(Landmark.colosseum.stages, 12);
    expect(Landmark.colosseum.minutesPerStage, 40);
    expect(Landmark.colosseum.totalMinutes, 480);
    expect(Landmark.colosseum.unlockLevel, TownLevel.city);
  });

  test('the arena floor comes first, the wall after it', () {
    expect(_has(_colosseum(1), 5, 5, 1), isTrue);
    expect(_has(_colosseum(1), 0, 2, 1), isFalse);
    expect(_has(_colosseum(2), 0, 2, 1), isTrue);
  });

  test(
    'the wall is a rounded ring: no corner cell, arches between pillars',
    () {
      final w = _colosseum(2);
      expect(_has(w, 0, 0, 1), isFalse); // the corner is cut
      expect(_has(w, 1, 0, 1), isFalse); // an arch (odd cell)
      expect(_has(w, 2, 0, 1), isTrue); // a pillar (even cell)
      expect(_has(w, 3, 0, 1), isFalse);
      expect(_has(w, 3, 0, 2), isFalse); // arches are two levels high
    },
  );

  test('a solid band closes each tier of arches', () {
    expect(_has(_colosseum(2), 3, 0, 3), isFalse);
    expect(_has(_colosseum(3), 3, 0, 3), isTrue);
    expect(_has(_colosseum(4), 3, 0, 5), isFalse);
    expect(_has(_colosseum(4), 2, 0, 4), isTrue); // tier 2 pillars
    expect(_has(_colosseum(5), 3, 0, 6), isTrue);
    expect(_has(_colosseum(7), 3, 0, 9), isTrue);
  });

  test('the attic on top has windows', () {
    expect(_has(_colosseum(7), 2, 0, 10), isFalse);
    expect(_colosseum(8).get(_ox + 2, _oy + 0, 10), Blocks.stone);
    expect(_colosseum(8).get(_ox + 3, _oy + 0, 10), Blocks.glass);
  });

  test('the main gate on the front is open from the start', () {
    for (var s = 1; s <= 12; s++) {
      for (final z in [1, 2]) {
        expect(_has(_colosseum(s), 5, 11, z), isFalse, reason: 'stage $s');
        expect(_has(_colosseum(s), 6, 11, z), isFalse, reason: 'stage $s');
      }
    }
  });

  test('seating terraces, a podium, then banners', () {
    expect(_has(_colosseum(8), 2, 2, 2), isFalse);
    expect(_has(_colosseum(9), 2, 2, 2), isTrue);
    expect(_has(_colosseum(9), 3, 3, 3), isFalse);
    expect(_has(_colosseum(10), 3, 3, 3), isTrue);
    expect(_has(_colosseum(10), 4, 4, 4), isTrue);
    expect(_has(_colosseum(10), 5, 5, 2), isFalse);
    expect(_has(_colosseum(11), 5, 5, 2), isTrue);
    for (final (x, y) in [(1, 0), (10, 0), (1, 11), (10, 11)]) {
      expect(_has(_colosseum(11), x, y, 12), isFalse);
      expect(_colosseum(12).get(_ox + x, _oy + y, 12), Blocks.wool);
    }
  });
}
