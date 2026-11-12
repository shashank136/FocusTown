import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/domain/parcel.dart';
import 'package:focus_town/game/world/plot_layout.dart';

void main() {
  test('plots below 64 are the classic plots', () {
    expect(plotFor(10, const []), same(kPlots[10]));
    expect(plotFor(63, const [Parcel(-1, 3)]), same(kPlots[63]));
  });

  test('a claimed parcel is the next plot, on the grid beyond the island', () {
    final west = plotFor(64, const [Parcel(-1, 3)]);
    expect((west.index, west.originX, west.originY), (64, -4, 24));
    final east = plotFor(65, const [Parcel(-1, 3), Parcel(8, 0)]);
    expect((east.index, east.originX, east.originY), (65, 61, 3));
  });

  test('parcel positions across the road and out to the edges', () {
    expect(parcelOrigin(3), 24);
    expect(parcelOrigin(4), 33); // the road is skipped
    expect(parcelOrigin(-18), -123);
    expect(parcelOrigin(16), 117);
  });

  test('no claimable parcel leaves the 8-bit world', () {
    for (final p in claimableParcels(const [])) {
      final plot = plotFor(64, [p]);
      expect(plot.originX, inInclusiveRange(-128, 120));
      expect(plot.originY, inInclusiveRange(-128, 120));
    }
  });

  test('a garden is land but not a plot: later parcels take its number', () {
    const parcels = [Parcel(-1, 3, garden: true), Parcel(8, 0)];
    final first = plotFor(64, parcels);
    expect((first.originX, first.originY), (61, 3));
  });

  test('a virtual index stands for a parcel that can be claimed', () {
    final claimable = claimableParcels(const []);
    final plot = plotFor(kLandBase + 2, const []);
    expect(plot.originX, parcelOrigin(claimable[2].gx));
    expect(plot.originY, parcelOrigin(claimable[2].gy));
  });
}
