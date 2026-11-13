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
    expect(_has(_colosseum(1), 0, 5, 1), isFalse);
    expect(_has(_colosseum(2), 0, 5, 1), isTrue);
  });

  test('the wall is round: no corner cell, dark arches between pillars', () {
    final w = _colosseum(2);
    expect(_has(w, 0, 0, 1), isFalse); // the corner is cut
    expect(_has(w, 1, 1, 1), isFalse);
    expect(w.get(_ox + 0, _oy + 6, 1), Blocks.travertine); // a pillar
    expect(w.get(_ox + 0, _oy + 5, 1), Blocks.char); // an arch
  });

  test('a solid band closes each tier of arches', () {
    expect(_has(_colosseum(2), 0, 5, 2), isFalse);
    expect(_colosseum(3).get(_ox + 0, _oy + 5, 2), Blocks.travertine);
    expect(_colosseum(4).get(_ox + 0, _oy + 5, 3), Blocks.char); // tier 2
    expect(_colosseum(5).get(_ox + 0, _oy + 5, 4), Blocks.travertine);
    expect(_colosseum(7).get(_ox + 0, _oy + 5, 6), Blocks.travertine);
  });

  test('the attic on top has dark windows', () {
    expect(_has(_colosseum(7), 0, 6, 7), isFalse);
    expect(_colosseum(8).get(_ox + 0, _oy + 6, 7), Blocks.travertine);
    expect(_colosseum(8).get(_ox + 0, _oy + 5, 7), Blocks.char);
  });

  test('the front wall has fallen: only the lowest tier stands there', () {
    final w = _colosseum(12);
    expect(_has(w, 10, 9, 2), isTrue);
    expect(_has(w, 10, 9, 3), isFalse);
    expect(_has(w, 0, 5, 3), isTrue); // the back still stands
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
    expect(_has(_colosseum(8), 1, 4, 5), isFalse);
    expect(_has(_colosseum(9), 1, 4, 5), isTrue); // the top terrace
    expect(_has(_colosseum(9), 3, 3, 3), isFalse);
    expect(_has(_colosseum(10), 3, 3, 3), isTrue);
    expect(_has(_colosseum(10), 5, 5, 2), isFalse);
    expect(_has(_colosseum(11), 5, 5, 2), isTrue);
    for (final (x, y) in [(5, 0), (0, 5), (2, 1), (9, 1)]) {
      expect(_has(_colosseum(11), x, y, 9), isFalse);
      expect(_colosseum(12).get(_ox + x, _oy + y, 9), Blocks.wool);
    }
  });
}
