import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/domain/landmark.dart';
import 'package:focus_town/game/world/block_material.dart';
import 'package:focus_town/game/world/landmark_defs.dart';
import 'package:focus_town/game/world/voxel_world.dart';

const _ox = 20;
const _oy = 20;

VoxelWorld _pyramid(int stage) {
  final w = VoxelWorld();
  buildLandmark(w, Landmark.greatPyramid, _ox, _oy, stage);
  return w;
}

void main() {
  test('it is 12 stages of 10 minutes, 2 hours, unlocked at Village', () {
    expect(Landmark.greatPyramid.stages, 12);
    expect(Landmark.greatPyramid.minutesPerStage, 10);
    expect(Landmark.greatPyramid.totalMinutes, 120);
  });

  test('each stage is one more level, from a 12 wide base to the top', () {
    // Level z is as wide as the step it belongs to: 12, 12, 10, 10, 8 ...
    expect(_pyramid(1).has(_ox, _oy, 1), isTrue); // the base corner
    expect(_pyramid(1).has(_ox, _oy, 2), isFalse);
    expect(_pyramid(2).has(_ox, _oy, 2), isTrue); // still 12 wide at level 2
    expect(_pyramid(3).has(_ox, _oy, 3), isFalse); // level 3 is 10 wide
    expect(_pyramid(3).has(_ox + 1, _oy + 1, 3), isTrue);
    expect(_pyramid(11).has(_ox + 5, _oy + 5, 11), isTrue); // the point
    expect(_pyramid(11).has(_ox + 4, _oy + 5, 11), isFalse);
  });

  test('the entrance is open from the first stage', () {
    for (var s = 1; s <= 12; s++) {
      for (final x in [_ox + 5, _ox + 6]) {
        expect(_pyramid(s).has(x, _oy + 11, 1), isFalse, reason: 'stage $s');
        expect(_pyramid(s).has(x, _oy + 10, 1), isFalse, reason: 'stage $s');
      }
    }
  });

  test('the last stage adds a gold cap and two pillars at the entrance', () {
    expect(_pyramid(11).has(_ox + 5, _oy + 5, 12), isFalse);
    expect(_pyramid(12).get(_ox + 5, _oy + 5, 12), Blocks.wool);
    expect(_pyramid(11).has(_ox + 3, _oy + 11, 3), isFalse);
    expect(_pyramid(12).get(_ox + 3, _oy + 11, 4), Blocks.stone);
    expect(_pyramid(12).get(_ox + 8, _oy + 11, 4), Blocks.stone);
  });
}
