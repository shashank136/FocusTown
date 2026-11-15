import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/domain/building_tier.dart';
import 'package:focus_town/domain/landmark.dart';
import 'package:focus_town/domain/parcel.dart';
import 'package:focus_town/domain/plot_grid.dart';
import 'package:focus_town/domain/town.dart';
import 'package:focus_town/domain/town_rules.dart';

Footprint _big(Landmark l) => const Footprint(3, 3);
Footprint _huge(Landmark l) => const Footprint(5, 5);

// Land in columns 8 to 12 from row -1 (the corner above the strip) to row 7.
List<Parcel> _eastWithCorner() => [
  for (var gx = 8; gx <= 12; gx++)
    for (var gy = -1; gy <= 7; gy++) Parcel(gx, gy),
];

TownBuilding _landmark(
  int plot, {
  String id = 'L',
  Landmark landmark = Landmark.eiffel,
  BuildingStatus status = BuildingStatus.complete,
}) => TownBuilding(
  id: id,
  tier: BuildingTier.castle,
  status: status,
  plotIndex: plot,
  landmark: landmark,
);

TownBuilding _hut(int plot, [String id = 'h']) => TownBuilding(
  id: id,
  tier: BuildingTier.hut,
  status: BuildingStatus.complete,
  plotIndex: plot,
);

// The starting town without its starter house, with the given land.
TownState _town(
  List<TownBuilding> buildings, [
  List<Parcel> parcels = const [],
]) => TownState.initial().copyWith(buildings: buildings, parcels: parcels);

int _at(int gx, int gy, [List<Parcel> parcels = const []]) =>
    plotAtCell(gx, gy, parcels)!;

TownBuilding _byId(TownState t, String id) =>
    t.buildings.firstWhere((b) => b.id == id);

void main() {
  group('the footprint a building really covers', () {
    test('its new size when that area is free', () {
      final town = _town([_landmark(_at(0, 0))]);
      expect(
        TownRules.footprints(town, sizeOf: _big)['L'],
        const Footprint(3, 3),
      );
    });

    test('its old 2 x 2 when the new area is not free or not there', () {
      // A hut stands in the 3 x 3 from the corner (outside the old 2 x 2).
      final blocked = _town([_landmark(_at(0, 0)), _hut(_at(2, 2))]);
      expect(TownRules.footprints(blocked, sizeOf: _big)['L'], Footprint.block);
      // The island has no 5 x 5 anywhere.
      final nowhere = _town([_landmark(_at(0, 0))]);
      expect(
        TownRules.footprints(nowhere, sizeOf: _huge)['L'],
        Footprint.block,
      );
    });

    test("another landmark's own area stops a bigger one growing", () {
      // A's 3 x 3 would take the plot of B's old 2 x 2 at column 2.
      final town = _town([
        _landmark(_at(0, 0), id: 'A'),
        _landmark(_at(2, 0), id: 'B', landmark: Landmark.colosseum),
      ]);
      final f = TownRules.footprints(town, sizeOf: _big);
      expect(f['A'], Footprint.block);
      // B's 3 x 3 would lie across the road, so it stays as it is.
      expect(f['B'], Footprint.block);
    });

    test('a smaller new footprint gives the rest of the block back', () {
      final town = _town([_landmark(_at(0, 0))]);
      final f = TownRules.footprints(town, sizeOf: (_) => Footprint.one);
      expect(f['L'], Footprint.one);
    });

    test('a building that is not a landmark keeps the size of its tier', () {
      final town = _town([_hut(_at(0, 0))]);
      expect(TownRules.footprints(town, sizeOf: _big)['h'], Footprint.one);
    });
  });

  group('settleLandmarks', () {
    test('a landmark with room where it stands grows in place', () {
      final town = _town([_landmark(_at(0, 0))]);
      final settled = TownRules.settleLandmarks(town, sizeOf: _big);
      expect(_byId(settled, 'L').plotIndex, _at(0, 0));
    });

    test('it moves to the nearest free area when its own is taken', () {
      final town = _town([_landmark(_at(0, 0)), _hut(_at(2, 2))]);
      final settled = TownRules.settleLandmarks(town, sizeOf: _big);
      final moved = _byId(settled, 'L').plotIndex;
      expect(moved, isNot(_at(0, 0)));
      final area = footprintOf(const Footprint(3, 3), moved, const [])!;
      expect(area, hasLength(9));
      // Nothing else stands in it (the starter house and the hut).
      for (final b in town.buildings.where((b) => b.id != 'L')) {
        expect(area, isNot(contains(b.plotIndex)));
      }
      // And no free area is nearer to where it was.
      final from = plotCell(_at(0, 0), const [])!;
      int dist(int plot) {
        final c = plotCell(plot, const [])!;
        return (c.$1 - from.$1) * (c.$1 - from.$1) +
            (c.$2 - from.$2) * (c.$2 - from.$2);
      }

      final others = town.buildings.where((b) => b.id != 'L').toList();
      final taken = TownRules.occupied(_town(others));
      for (var i = 0; i < TownRules.plotCountOf(town); i++) {
        final a = footprintOf(const Footprint(3, 3), i, const []);
        if (a == null || a.any(taken.contains)) continue;
        expect(dist(i), greaterThanOrEqualTo(dist(moved)), reason: 'anchor $i');
      }
    });

    test('it stays where it is when there is no room', () {
      final town = _town([_landmark(_at(0, 0))]);
      final settled = TownRules.settleLandmarks(town, sizeOf: _huge);
      expect(_byId(settled, 'L').plotIndex, _at(0, 0));
      expect(settled, town);
    });

    test('it moves later, when room appears', () {
      final town = _town([_landmark(_at(0, 0))]);
      final first = TownRules.settleLandmarks(town, sizeOf: _huge);
      expect(first, town);
      final grown = first.copyWith(parcels: _eastWithCorner());
      final later = TownRules.settleLandmarks(grown, sizeOf: _huge);
      final moved = _byId(later, 'L').plotIndex;
      expect(moved, _at(8, -1, grown.parcels));
      expect(
        TownRules.footprints(later, sizeOf: _huge)['L'],
        const Footprint(5, 5),
      );
    });

    test('two landmarks never share a plot, or take a garden', () {
      final land = [..._eastWithCorner(), const Parcel(10, 1, garden: true)];
      final town = _town([
        _landmark(_at(0, 0, land), id: 'A'),
        _landmark(_at(0, 4, land), id: 'B', landmark: Landmark.colosseum),
        _hut(_at(2, 2, land)),
      ], land);
      final settled = TownRules.settleLandmarks(town, sizeOf: _big);
      final f = TownRules.footprints(settled, sizeOf: _big);
      final taken = <int>[];
      var total = 0;
      for (final b in settled.buildings) {
        final plots =
            footprintOf(f[b.id]!, b.plotIndex, settled.parcels) ??
            [b.plotIndex];
        taken.addAll(plots);
        total += plots.length;
      }
      expect(taken.toSet(), hasLength(total), reason: 'plots overlap');
      final garden = rawPlotAtCell(10, 1, settled.parcels)!;
      expect(taken, isNot(contains(garden)));
    });

    test('the landmark being worked on is left where it is', () {
      final town = _town([_landmark(_at(0, 0)), _hut(_at(2, 2))]);
      final settled = TownRules.settleLandmarks(
        town,
        sizeOf: _big,
        except: Landmark.eiffel,
      );
      expect(settled, town);
    });

    test('settling twice changes nothing more', () {
      final town = _town([_landmark(_at(0, 0)), _hut(_at(2, 2))]);
      final once = TownRules.settleLandmarks(town, sizeOf: _big);
      expect(TownRules.settleLandmarks(once, sizeOf: _big), once);
    });

    test('with the real sizes nothing moves yet', () {
      final town = _town([_landmark(_at(0, 0)), _hut(_at(2, 2))]);
      expect(TownRules.settleLandmarks(town), town);
    });
  });
}
