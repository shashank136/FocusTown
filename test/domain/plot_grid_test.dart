import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/domain/building_tier.dart';
import 'package:focus_town/domain/parcel.dart';
import 'package:focus_town/domain/plot_grid.dart';

void main() {
  test('the starting island has 64 distinct cells, nearest the road first', () {
    expect(kBaseCells, hasLength(64));
    expect(kBaseCells.toSet(), hasLength(64));
    // The four plots touching the crossing come first.
    expect(kBaseCells.take(4).toSet(), {(3, 3), (4, 3), (3, 4), (4, 4)});
  });

  test('plotCell and plotAtCell are inverse for every starting plot', () {
    for (var i = 0; i < 64; i++) {
      final (gx, gy) = plotCell(i, const [])!;
      expect(plotAtCell(gx, gy, const []), i);
    }
  });

  test('claimed parcels are the next plots, gardens are skipped', () {
    const parcels = [Parcel(-1, 3, garden: true), Parcel(8, 0), Parcel(-1, 4)];
    expect(plotCell(64, parcels), (8, 0));
    expect(plotCell(65, parcels), (-1, 4));
    expect(plotCell(66, parcels), isNull);
    expect(plotAtCell(8, 0, parcels), 64);
    expect(plotAtCell(-1, 3, parcels), isNull); // a garden is no plot
    expect(plotAtCell(9, 9, parcels), isNull);
  });

  group('footprint', () {
    test('every tier but the castle takes just its plot', () {
      for (final t in BuildingTier.values.where(
        (t) => t != BuildingTier.castle,
      )) {
        expect(footprintOf(t, 10, const []), [10]);
        expect(plotsOf(t), 1);
      }
    });

    test('a castle takes the 2 x 2 block, anchor first', () {
      final anchor = plotAtCell(0, 0, const [])!;
      final f = footprintOf(BuildingTier.castle, anchor, const [])!;
      expect(f, [
        anchor,
        plotAtCell(1, 0, const []),
        plotAtCell(0, 1, const []),
        plotAtCell(1, 1, const []),
      ]);
      expect(plotsOf(BuildingTier.castle), 4);
    });

    test('a castle may not cross the road or leave the island', () {
      expect(
        footprintOf(BuildingTier.castle, plotAtCell(3, 0, const [])!, const []),
        isNull,
      ); // columns 3 and 4 are split by the road
      expect(
        footprintOf(BuildingTier.castle, plotAtCell(0, 3, const [])!, const []),
        isNull,
      );
      expect(
        footprintOf(BuildingTier.castle, plotAtCell(7, 0, const [])!, const []),
        isNull,
      ); // no plot east of column 7
      expect(footprintOf(BuildingTier.castle, 999, const []), isNull);
    });

    test('claimed land can complete a block at the coast', () {
      const parcels = [Parcel(8, 0), Parcel(8, 1)];
      final anchor = plotAtCell(7, 0, parcels)!;
      expect(footprintOf(BuildingTier.castle, anchor, parcels), [
        anchor,
        64,
        plotAtCell(7, 1, parcels),
        65,
      ]);
    });
  });
}
