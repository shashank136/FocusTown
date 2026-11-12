import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/domain/building_tier.dart';
import 'package:focus_town/domain/landmark.dart';
import 'package:focus_town/domain/plot_grid.dart';
import 'package:focus_town/domain/session.dart';
import 'package:focus_town/domain/time_stamp.dart';
import 'package:focus_town/domain/town.dart';
import 'package:focus_town/game/world/block_material.dart';
import 'package:focus_town/game/world/landmark_defs.dart';
import 'package:focus_town/game/world/plot_layout.dart';
import 'package:focus_town/game/world/town_world_builder.dart';
import 'package:focus_town/game/world/voxel_world.dart';

const _ox = 20;
const _oy = 20;

VoxelWorld _eiffel(int stage) {
  final w = VoxelWorld();
  buildLandmark(w, Landmark.eiffel, _ox, _oy, stage);
  return w;
}

Set<(int, int, int)> _cells(VoxelWorld w) => {
  for (final b in w.blocks) (b.x, b.y, b.z),
};

void main() {
  test('every stage adds something and never takes anything away', () {
    var before = <(int, int, int)>{};
    for (var s = 1; s <= Landmark.eiffel.stages; s++) {
      final now = _cells(_eiffel(s));
      expect(now.containsAll(before), isTrue, reason: 'stage $s');
      expect(now.length, greaterThan(before.length), reason: 'stage $s');
      before = now;
    }
  });

  test('stage 0 draws nothing and a stage past the end is the last', () {
    expect(_eiffel(0).blockCount, 0);
    expect(_cells(_eiffel(99)), _cells(_eiffel(12)));
  });

  test('it stays inside its 12 x 12 inset and is very tall', () {
    var top = 0;
    for (final b in _eiffel(12).blocks) {
      expect(b.x, inInclusiveRange(_ox, _ox + 11));
      expect(b.y, inInclusiveRange(_oy, _oy + 11));
      if (b.z > top) top = b.z;
    }
    expect(top, greaterThanOrEqualTo(24));
  });

  test('four legs stand at the corners and lean in', () {
    final w = _eiffel(3);
    for (final (dx, dy) in [(0, 0), (11, 0), (0, 11), (11, 11)]) {
      expect(w.has(_ox + dx, _oy + dy, 1), isTrue);
    }
    // Higher up the legs are nearer the middle.
    expect(w.has(_ox, _oy, 6), isFalse);
    expect(w.has(_ox + 2, _oy + 2, 6), isTrue);
  });

  test('a platform joins the legs at the first level', () {
    final w = _eiffel(3);
    expect(w.has(_ox + 5, _oy + 2, 6), isTrue); // on the ring
    expect(w.has(_ox + 5, _oy + 5, 6), isFalse); // open in the middle
  });

  test('the mast, spire and flag come last', () {
    expect(_eiffel(6).has(_ox + 5, _oy + 5, 13), isFalse);
    expect(_eiffel(7).has(_ox + 5, _oy + 5, 13), isTrue);
    expect(_eiffel(9).has(_ox + 5, _oy + 5, 19), isFalse);
    expect(_eiffel(10).has(_ox + 5, _oy + 5, 19), isTrue);
    expect(_eiffel(11).get(_ox + 5, _oy + 5, 23), Blocks.wool);
    expect(_eiffel(11).has(_ox + 5, _oy + 5, 24), isFalse);
    expect(_eiffel(12).get(_ox + 5, _oy + 5, 24), Blocks.log);
  });

  group('in the town', () {
    final block = plotAtCell(0, 0, const [])!;
    final plot = kPlots[block];

    TownState town(int progress, BuildingStatus status) => TownState(
      workers: 3,
      plotsUnlocked: 6,
      buildings: [
        TownBuilding(
          id: 'landmark-eiffel',
          tier: BuildingTier.castle,
          status: status,
          plotIndex: block,
          landmark: Landmark.eiffel,
          progress: progress,
        ),
      ],
      queue: const [],
      inRecoveryMode: false,
    );

    int top(VoxelWorld w) => w.blocks
        .where(
          (b) =>
              b.x >= plot.originX &&
              b.x < plot.originX + 14 &&
              b.y >= plot.originY &&
              b.y < plot.originY + 14,
        )
        .fold(0, (m, b) => b.z > m ? b.z : m);

    test('a project is drawn at the stage its progress has reached', () {
      final w = buildTownWorld(town(85, BuildingStatus.building));
      final direct = VoxelWorld();
      buildLandmark(
        direct,
        Landmark.eiffel,
        plot.originX + 1,
        plot.originY + 1,
        4,
      );
      expect(top(w), top(direct));
      expect(top(w), lessThan(24));
    });

    test('a finished landmark is drawn whole', () {
      final w = buildTownWorld(town(240, BuildingStatus.complete));
      expect(top(w), greaterThanOrEqualTo(24));
    });

    test('a landmark session shows the stage it has reached so far', () {
      final session = Session(
        id: 's',
        plannedMinutes: 60,
        tier: BuildingTier.hut,
        workersAssigned: 0,
        state: SessionState.running,
        startedAt: TimeStamp(DateTime(2026), Duration.zero),
        landmark: Landmark.eiffel,
        plotIndex: block,
      );
      final base = buildTownWorld(town(20, BuildingStatus.building));
      final live = buildTownWorld(
        town(20, BuildingStatus.building),
        active: session,
        progress: 0.5, // 30 of 60 minutes: 20 + 30 = 50 minutes = stage 2
      );
      expect(live.blockCount, greaterThan(base.blockCount));
    });
  });
}
