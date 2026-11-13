import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/domain/building_tier.dart';
import 'package:focus_town/domain/landmark.dart';
import 'package:focus_town/domain/plot_grid.dart';
import 'package:focus_town/domain/session.dart';
import 'package:focus_town/domain/session_engine.dart';
import 'package:focus_town/domain/time_stamp.dart';
import 'package:focus_town/domain/town.dart';
import 'package:focus_town/domain/town_level.dart';
import 'package:focus_town/domain/town_rules.dart';

TimeStamp _at(int s) => TimeStamp(
  DateTime(2026, 11, 11, 9).add(Duration(seconds: s)),
  Duration(seconds: s),
);

int _plot(int gx, int gy) => plotAtCell(gx, gy, const [])!;

TownBuilding _project(int progress, {int plot = 0}) => TownBuilding(
  id: 'landmark-eiffel',
  tier: BuildingTier.castle,
  status: BuildingStatus.building,
  plotIndex: plot,
  landmark: Landmark.eiffel,
  progress: progress,
);

TownState _town([List<TownBuilding> buildings = const [], int xp = 300]) =>
    TownState(
      workers: 3,
      plotsUnlocked: 6,
      buildings: buildings,
      queue: const [],
      inRecoveryMode: false,
      xp: xp,
    );

Session _session(int minutes, {SessionState? state}) {
  final s = SessionEngine.startLandmark(
    id: 'l1',
    landmark: Landmark.eiffel,
    minutes: minutes,
    now: _at(0),
  );
  return state == null ? s : s.copyWith(state: state);
}

void main() {
  test('the Eiffel Tower has 12 stages of 20 minutes, 240 in all', () {
    expect(Landmark.eiffel.stages, 12);
    expect(Landmark.eiffel.minutesPerStage, 20);
    expect(Landmark.eiffel.totalMinutes, 240);
    expect(Landmark.eiffel.title, 'Eiffel Tower');
  });

  test('the Eiffel Tower unlocks at Village', () {
    expect(Landmark.eiffel.unlockLevel, TownLevel.village);
  });

  group('unlocking', () {
    test('a new landmark needs the level; a started one does not', () {
      expect(
        TownRules.canStartLandmark(_town(const [], 299), Landmark.eiffel),
        isFalse,
      );
      expect(TownRules.canStartLandmark(_town(), Landmark.eiffel), isTrue);
      final started = _town([_project(40)], 0);
      expect(TownRules.canStartLandmark(started, Landmark.eiffel), isTrue);
    });

    test('the state of a landmark for the screen', () {
      LandmarkState state(TownState t) =>
          TownRules.landmarkState(t, Landmark.eiffel);
      expect(state(_town(const [], 0)), LandmarkState.locked);
      expect(state(_town()), LandmarkState.ready);
      expect(state(_town([_project(40)])), LandmarkState.inProgress);
      expect(
        state(
          _town([
            const TownBuilding(
              id: 'landmark-eiffel',
              tier: BuildingTier.castle,
              status: BuildingStatus.complete,
              plotIndex: 0,
              landmark: Landmark.eiffel,
              progress: 240,
            ),
          ]),
        ),
        LandmarkState.built,
      );
      final crowded = _town([
        for (var gx = 0; gx < 8; gx++)
          for (var gy = 0; gy < 8; gy++)
            if ((gx + gy).isEven)
              TownBuilding(
                id: 'h$gx$gy',
                tier: BuildingTier.hut,
                status: BuildingStatus.complete,
                plotIndex: _plot(gx, gy),
              ),
      ]);
      expect(state(crowded), LandmarkState.noRoom);
    });
  });

  test('only one landmark is built at a time', () {
    final busy = _town([_project(40)]);
    expect(
      TownRules.landmarkState(busy, Landmark.greatPyramid),
      LandmarkState.busy,
    );
    expect(TownRules.canStartLandmark(busy, Landmark.greatPyramid), isFalse);
    // Once the first is finished the next can start.
    final done = _town([
      const TownBuilding(
        id: 'landmark-eiffel',
        tier: BuildingTier.castle,
        status: BuildingStatus.complete,
        plotIndex: 0,
        landmark: Landmark.eiffel,
        progress: 240,
      ),
    ]);
    expect(
      TownRules.landmarkState(done, Landmark.greatPyramid),
      LandmarkState.ready,
    );
    // A landmark that is still locked stays locked, not busy.
    expect(
      TownRules.landmarkState(_town([_project(40)], 0), Landmark.greatPyramid),
      LandmarkState.locked,
    );
  });

  test('a project is at the stage its minutes have reached, at most 12', () {
    expect(_project(0).stage, 0);
    expect(_project(19).stage, 0);
    expect(_project(20).stage, 1);
    expect(_project(125).stage, 6);
    expect(_project(240).stage, 12);
    expect(_project(500).stage, 12);
  });

  test('a project is part of the town state and compares by its progress', () {
    expect(_project(20), isNot(_project(40)));
    expect(_project(20), _project(20));
  });

  group('a session', () {
    test('risks no workers and carries its landmark', () {
      final s = _session(45);
      expect(s.isLandmark, isTrue);
      expect(s.landmark, Landmark.eiffel);
      expect(s.plannedMinutes, 45);
      expect(s.workersAssigned, 0);
    });

    test('the emergency pause cannot be armed on it', () {
      expect(TownRules.armEmergency(TownState.initial(), _session(45)), isNull);
    });
  });

  group('starting', () {
    test('needs a free 2 x 2 block, and not a second project', () {
      expect(TownRules.landmarkProject(_town(), Landmark.eiffel), isNull);
      expect(TownRules.canStartLandmark(_town(), Landmark.eiffel), isTrue);
      final busy = _town([_project(40, plot: _plot(0, 0))]);
      expect(TownRules.landmarkProject(busy, Landmark.eiffel), isNotNull);
      // A project in progress can always be worked on.
      expect(TownRules.canStartLandmark(busy, Landmark.eiffel), isTrue);
    });

    test('a finished landmark cannot be built again', () {
      final done = _town([
        TownBuilding(
          id: 'landmark-eiffel',
          tier: BuildingTier.castle,
          status: BuildingStatus.complete,
          plotIndex: _plot(0, 0),
          landmark: Landmark.eiffel,
          progress: 240,
        ),
      ]);
      expect(TownRules.canStartLandmark(done, Landmark.eiffel), isFalse);
    });

    test('with no free block it cannot start', () {
      final crowded = _town([
        for (var gx = 0; gx < 8; gx++)
          for (var gy = 0; gy < 8; gy++)
            if ((gx + gy).isEven)
              TownBuilding(
                id: 'h$gx$gy',
                tier: BuildingTier.hut,
                status: BuildingStatus.complete,
                plotIndex: _plot(gx, gy),
              ),
      ]);
      expect(TownRules.canStartLandmark(crowded, Landmark.eiffel), isFalse);
    });

    test('beginning takes a block and starts at no progress', () {
      final block = _plot(0, 0);
      final town = TownRules.beginLandmark(_town(), Landmark.eiffel, block)!;
      final p = TownRules.landmarkProject(town, Landmark.eiffel)!;
      expect(p.plotIndex, block);
      expect(p.progress, 0);
      expect(p.status, BuildingStatus.building);
      expect(TownRules.occupied(town), hasLength(4));
    });

    test('beginning on a block that is not free gives nothing', () {
      expect(
        TownRules.beginLandmark(_town(), Landmark.eiffel, _plot(3, 0)),
        isNull,
      );
    });
  });

  group('progress', () {
    test('a finished session adds its minutes', () {
      final town = _town([_project(40)]);
      final done = TownRules.applyLandmarkCompleted(
        town,
        _session(45, state: SessionState.completed),
      );
      expect(TownRules.landmarkProject(done, Landmark.eiffel)!.progress, 85);
    });

    test('the landmark is complete at 240 minutes, not before', () {
      final almost = _town([_project(200)]);
      final done = TownRules.applyLandmarkCompleted(
        almost,
        _session(60, state: SessionState.completed),
      );
      final b = done.buildings.single;
      expect(b.status, BuildingStatus.complete);
      expect(b.progress, 240);
      final short = TownRules.applyLandmarkCompleted(
        almost,
        _session(30, state: SessionState.completed),
      );
      expect(short.buildings.single.status, BuildingStatus.building);
    });

    test('a failed session costs one stage, never below nothing', () {
      final town = _town([_project(125)]);
      final hurt = TownRules.applyLandmarkFailed(
        town,
        _session(45, state: SessionState.failed),
      );
      expect(hurt.buildings.single.progress, 105);
      final nothing = TownRules.applyLandmarkFailed(
        _town([_project(10)]),
        _session(45, state: SessionState.failed),
      );
      expect(nothing.buildings.single.progress, 0);
    });
  });

  group('landmarkShowcase', () {
    test('shows every landmark finished, on separate blocks', () {
      const hut = TownBuilding(
        id: 'h',
        tier: BuildingTier.hut,
        status: BuildingStatus.complete,
        plotIndex: 0,
      );
      final town = TownState.initial().copyWith(buildings: [hut]);
      final show = TownRules.landmarkShowcase(town);
      final marks = show.buildings.where((b) => b.landmark != null).toList();
      expect(marks.map((b) => b.landmark), Landmark.values);
      expect(marks.every((b) => b.status == BuildingStatus.complete), isTrue);
      expect(marks.every((b) => b.stage == Landmark.values[0].stages), isTrue);
      final plots = {
        for (final b in marks)
          ...footprintOf(b.tier, b.plotIndex, town.parcels)!,
      };
      expect(plots.length, 4 * marks.length);
      // The real town is untouched.
      expect(town.buildings, [hut]);
    });
  });
}
