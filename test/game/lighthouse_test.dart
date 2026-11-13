import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/domain/landmark.dart';
import 'package:focus_town/domain/town_level.dart';
import 'package:focus_town/game/world/block_material.dart';
import 'package:focus_town/game/world/landmark_defs.dart';
import 'package:focus_town/game/world/voxel_world.dart';

const _ox = 20;
const _oy = 20;

VoxelWorld _lighthouse(int stage) {
  final w = VoxelWorld();
  buildLandmark(w, Landmark.lighthouse, _ox, _oy, stage);
  return w;
}

void main() {
  test('it is 12 stages of 15 minutes, 3 hours, unlocked at Village', () {
    expect(Landmark.lighthouse.title, 'Lighthouse of Alexandria');
    expect(Landmark.lighthouse.stages, 12);
    expect(Landmark.lighthouse.minutesPerStage, 15);
    expect(Landmark.lighthouse.totalMinutes, 180);
    expect(Landmark.lighthouse.unlockLevel, TownLevel.village);
  });

  test('a square base two levels per stage, then a narrower middle', () {
    expect(_lighthouse(4).has(_ox + 2, _oy + 2, 8), isTrue);
    expect(_lighthouse(4).has(_ox + 2, _oy + 2, 9), isFalse);
    // The middle starts with a ledge round the top of the base.
    expect(_lighthouse(5).has(_ox + 1, _oy + 1, 9), isTrue);
    expect(_lighthouse(5).has(_ox + 3, _oy + 3, 10), isTrue);
    expect(_lighthouse(8).has(_ox + 3, _oy + 3, 16), isTrue);
    // The upper part is narrower still.
    expect(_lighthouse(9).has(_ox + 4, _oy + 4, 17), isTrue);
    expect(_lighthouse(9).has(_ox + 3, _oy + 3, 17), isFalse);
  });

  test('the door in the base is open from the first stage', () {
    for (var s = 1; s <= 12; s++) {
      for (final x in [_ox + 5, _ox + 6]) {
        for (final z in [1, 2]) {
          expect(
            _lighthouse(s).has(x, _oy + 9, z),
            isFalse,
            reason: 'stage $s',
          );
        }
      }
    }
  });

  test('the lantern is glass and the fire comes last', () {
    expect(_lighthouse(11).get(_ox + 4, _oy + 4, 21), Blocks.glass);
    expect(_lighthouse(11).has(_ox + 5, _oy + 5, 24), isFalse);
    expect(_lighthouse(12).get(_ox + 5, _oy + 5, 24), Blocks.wool);
  });
}
