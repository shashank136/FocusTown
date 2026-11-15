import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/domain/building_tier.dart';
import 'package:focus_town/domain/district.dart';
import 'package:focus_town/domain/landmark.dart';
import 'package:focus_town/domain/parcel.dart';
import 'package:focus_town/domain/plot_grid.dart';
import 'package:focus_town/domain/town.dart';
import 'package:focus_town/domain/town_rules.dart';

// Land to the east of the starting island: columns 8 and up, rows 0 to 7.
List<Parcel> _east(int rows) => [
  for (var r = 0; r < rows; r++) ...districtRow(DistrictSide.east, 0, r),
];

// Land in columns 8 to 12 from row -1 (the corner above the strip) to row 7.
List<Parcel> _eastWithCorner() => [
  for (var gx = 8; gx <= 12; gx++)
    for (var gy = -1; gy <= 7; gy++) Parcel(gx, gy),
];

TownState _town([List<Parcel> parcels = const []]) =>
    TownState.initial().copyWith(parcels: parcels);

void main() {
  group('Footprint', () {
    test('is a width and a depth in plots, with an area', () {
      const f = Footprint(3, 2);
      expect(f.cols, 3);
      expect(f.rows, 2);
      expect(f.area, 6);
      expect(const Footprint(3, 2), const Footprint(3, 2));
      expect(const Footprint(3, 2), isNot(const Footprint(2, 3)));
    });

    test('a building takes one plot, a castle a 2 x 2 block', () {
      expect(footprintFor(BuildingTier.hut), Footprint.one);
      expect(footprintFor(BuildingTier.workshop), Footprint.one);
      expect(footprintFor(BuildingTier.castle), Footprint.block);
    });

    test('a landmark takes its own footprint, whatever the tier', () {
      for (final l in Landmark.values) {
        expect(footprintFor(BuildingTier.castle, l), l.footprint);
        expect(l.footprint.cols, greaterThanOrEqualTo(1));
        expect(l.footprint.rows, greaterThanOrEqualTo(1));
      }
    });
  });

  group('footprintOf a rectangle', () {
    test('plots in one piece, the anchor first', () {
      final anchor = plotAtCell(0, 0, const [])!;
      final plots = footprintOf(const Footprint(3, 2), anchor, const [])!;
      expect(plots, hasLength(6));
      expect(plots.first, anchor);
      expect(
        {for (final p in plots) plotCell(p, const [])!},
        {
          for (var x = 0; x < 3; x++)
            for (var y = 0; y < 2; y++) (x, y),
        },
      );
    });

    test('depth and width are not swapped: 2 wide and 3 deep differ', () {
      final anchor = plotAtCell(0, 0, const [])!;
      final plots = footprintOf(const Footprint(2, 3), anchor, const [])!;
      expect(
        {for (final p in plots) plotCell(p, const [])!},
        {
          for (var x = 0; x < 2; x++)
            for (var y = 0; y < 3; y++) (x, y),
        },
      );
    });

    test('never across the road of the starting island', () {
      // Columns 3 and 4 (and rows 3 and 4) are split by the road.
      expect(
        footprintOf(
          const Footprint(3, 2),
          plotAtCell(2, 0, const [])!,
          const [],
        ),
        isNull,
      );
      expect(
        footprintOf(
          const Footprint(2, 3),
          plotAtCell(0, 2, const [])!,
          const [],
        ),
        isNull,
      );
      expect(
        footprintOf(
          const Footprint(5, 4),
          plotAtCell(0, 0, const [])!,
          const [],
        ),
        isNull,
      );
      // A 4 x 4 fits exactly in a quarter.
      expect(
        footprintOf(
          const Footprint(4, 4),
          plotAtCell(0, 0, const [])!,
          const [],
        ),
        hasLength(16),
      );
      expect(
        footprintOf(
          const Footprint(4, 4),
          plotAtCell(4, 4, const [])!,
          const [],
        ),
        hasLength(16),
      );
    });

    test('a block of 5 x 5 needs land that is not split by the road', () {
      for (var gy = 0; gy < 8; gy++) {
        for (var gx = 0; gx < 8; gx++) {
          expect(
            footprintOf(
              const Footprint(5, 5),
              plotAtCell(gx, gy, const [])!,
              const [],
            ),
            isNull,
            reason: '($gx,$gy)',
          );
        }
      }
      final land = _eastWithCorner();
      // Rows 0 to 4 of the east strip lie across the road at rows 3 and 4.
      expect(
        footprintOf(const Footprint(5, 5), plotAtCell(8, 0, land)!, land),
        isNull,
      );
      // Rows -1 to 3 do not, so the corner makes a 5 x 5 possible.
      final plots = footprintOf(
        const Footprint(5, 5),
        plotAtCell(8, -1, land)!,
        land,
      )!;
      expect(plots, hasLength(25));
      expect(plots.first, plotAtCell(8, -1, land));
      // A 5 x 4 fits in the strip itself: rows 0 to 3.
      expect(
        footprintOf(const Footprint(5, 4), plotAtCell(8, 0, land)!, land),
        hasLength(20),
      );
    });

    test('a missing parcel or a garden breaks it', () {
      final land = _east(3); // columns 8 to 10 only
      final anchor = plotAtCell(8, 0, land)!;
      expect(footprintOf(const Footprint(4, 2), anchor, land), isNull);
      final withGarden = [...land, const Parcel(9, 1, garden: true)];
      // The garden square is no plot, so a block over it is not possible.
      expect(
        footprintOf(
          const Footprint(3, 2),
          plotAtCell(8, 0, withGarden)!,
          withGarden,
        ),
        isNull,
      );
    });
  });

  group('rules with a footprint', () {
    test('a free area is found for a 3 x 2, not across the road', () {
      final town = _town();
      final i = TownRules.nextFreePlot(town, const Footprint(3, 2));
      expect(i, isNotNull);
      final plots = footprintOf(const Footprint(3, 2), i!, const [])!;
      expect(plots, hasLength(6));
    });

    test('a 5 x 5 has no room on the starting island or in a bare strip', () {
      expect(TownRules.nextFreePlot(_town(), const Footprint(5, 5)), isNull);
      expect(
        TownRules.nextFreePlot(_town(_east(8)), const Footprint(5, 5)),
        isNull,
      );
      expect(
        TownRules.nextFreePlot(_town(_eastWithCorner()), const Footprint(5, 5)),
        isNotNull,
      );
    });

    test('a building in the way takes the area away', () {
      final land = _eastWithCorner();
      final anchor = plotAtCell(8, -1, land)!;
      final town = _town(land).copyWith(
        buildings: [
          TownBuilding(
            id: 'h',
            tier: BuildingTier.hut,
            status: BuildingStatus.complete,
            plotIndex: plotAtCell(10, 2, land)!,
          ),
        ],
      );
      expect(
        TownRules.isPlotFree(town, anchor, const Footprint(5, 5)),
        isFalse,
      );
      expect(
        TownRules.isPlotFree(_town(land), anchor, const Footprint(5, 5)),
        isTrue,
      );
    });

    test('a building is as many plots as its footprint', () {
      final land = _east(5);
      final anchor = plotAtCell(8, 0, land)!;
      final b = TownBuilding(
        id: 'c',
        tier: BuildingTier.castle,
        status: BuildingStatus.complete,
        plotIndex: anchor,
        landmark: Landmark.petra,
      );
      final taken = TownRules.occupied(_town(land).copyWith(buildings: [b]));
      expect(taken.length, Landmark.petra.footprint.area);
    });
  });
}
