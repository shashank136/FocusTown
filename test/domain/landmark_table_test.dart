import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/domain/building_tier.dart';
import 'package:focus_town/domain/landmark.dart';
import 'package:focus_town/domain/town.dart';
import 'package:focus_town/domain/town_level.dart';

// The planned plots of each landmark (docs/spec.md, "The landmark list").
const Map<Landmark, int> _plots = {
  Landmark.christRedeemer: 1,
  Landmark.lighthouse: 4,
  Landmark.easterIsland: 4,
  Landmark.spaceNeedle: 4,
  Landmark.pagoda: 4,
  Landmark.petra: 6,
  Landmark.sphinx: 8,
  Landmark.chichenItza: 9,
  Landmark.statueOfLiberty: 9,
  Landmark.eiffel: 9,
  Landmark.colosseum: 16,
  Landmark.tajMahal: 20,
  Landmark.greatPyramid: 25,
};

// Minutes of each stage, and the level it unlocks at.
const Map<Landmark, (int, TownLevel)> _table = {
  Landmark.christRedeemer: (10, TownLevel.village),
  Landmark.lighthouse: (20, TownLevel.village),
  Landmark.easterIsland: (20, TownLevel.village),
  Landmark.spaceNeedle: (20, TownLevel.town),
  Landmark.pagoda: (20, TownLevel.town),
  Landmark.petra: (25, TownLevel.town),
  Landmark.sphinx: (30, TownLevel.town),
  Landmark.chichenItza: (35, TownLevel.city),
  Landmark.statueOfLiberty: (35, TownLevel.city),
  Landmark.eiffel: (35, TownLevel.city),
  Landmark.colosseum: (45, TownLevel.metropolis),
  Landmark.tajMahal: (50, TownLevel.metropolis),
  Landmark.greatPyramid: (55, TownLevel.metropolis),
};

void main() {
  test('every landmark has its time and level from the spec', () {
    expect(Landmark.values.toSet(), _table.keys.toSet());
    for (final e in _table.entries) {
      final l = e.key;
      expect(l.stages, 12, reason: l.title);
      expect(l.minutesPerStage, e.value.$1, reason: l.title);
      expect(l.totalMinutes, 12 * e.value.$1, reason: l.title);
      expect(l.unlockLevel, e.value.$2, reason: l.title);
    }
  });

  test('the biggest landmark takes 11 hours, the smallest 2', () {
    expect(Landmark.greatPyramid.totalMinutes, 660);
    expect(Landmark.christRedeemer.totalMinutes, 120);
  });

  test('a bigger landmark takes longer and unlocks no earlier', () {
    for (final a in Landmark.values) {
      for (final b in Landmark.values) {
        if (_plots[a]! >= _plots[b]!) continue;
        expect(
          a.totalMinutes,
          lessThanOrEqualTo(b.totalMinutes),
          reason: '${a.title} is smaller than ${b.title}',
        );
        expect(
          a.unlockLevel.minXp,
          lessThanOrEqualTo(b.unlockLevel.minXp),
          reason: '${a.title} is smaller than ${b.title}',
        );
      }
    }
  });

  test('the sizes get later levels: 3, 4, 3 and 3 landmarks each', () {
    int at(TownLevel l) =>
        Landmark.values.where((x) => x.unlockLevel == l).length;
    expect(at(TownLevel.village), 3);
    expect(at(TownLevel.town), 4);
    expect(at(TownLevel.city), 3);
    expect(at(TownLevel.metropolis), 3);
  });

  group('a landmark built or begun before the times changed', () {
    TownBuilding building(BuildingStatus status, int progress) => TownBuilding(
      id: 'landmark-pyramid',
      tier: BuildingTier.castle,
      status: status,
      plotIndex: 0,
      landmark: Landmark.greatPyramid,
      progress: progress,
    );

    test('a finished one is still finished (old total was 120 minutes)', () {
      final done = building(BuildingStatus.complete, 120);
      expect(done.stage, Landmark.greatPyramid.stages);
    });

    test('one in progress keeps its minutes, as a smaller share', () {
      final begun = building(BuildingStatus.building, 120);
      expect(begun.progress, 120);
      expect(begun.stage, 2); // 120 of the new 55-minute stages
    });
  });
}
