import 'package:focus_town/domain/parcel.dart';
import 'package:focus_town/game/world/vec2.dart';

/// Width and depth of the town map in tiles.
const kMapSize = 64;

/// Width and depth of one building plot in tiles.
const kPlotSize = 7;

// Plot origins on each axis: four west/north of the road, four east/south.
const _origins = [3, 10, 17, 24, 33, 40, 47, 54];

/// A square building plot. Plot 0 is nearest the crossing.
class Plot {
  /// Creates a plot.
  const new(this.index, this.originX, this.originY);

  /// Number 0..63, nearest the crossing first.
  final int index;

  /// Tile of the west corner.
  final int originX;

  /// Tile of the north corner.
  final int originY;

  /// Width and depth in tiles.
  int get size => kPlotSize;

  /// Middle of the plot in tile coordinates.
  Vec2 get center => Vec2(originX + 3.5, originY + 3.5);
}

/// Whether tile ([x], [y]) is on one of the two crossing roads (31..32).
bool isRoad(int x, int y) => (x >= 31 && x <= 32) || (y >= 31 && y <= 32);

double _distanceSquared(int ox, int oy) {
  final dx = ox + 3.5 - 32;
  final dy = oy + 3.5 - 32;
  return dx * dx + dy * dy;
}

/// All 64 plots, nearest the crossing first (ties: smaller y, then x).
final List<Plot> kPlots = () {
  final origins =
      [
        for (final y in _origins)
          for (final x in _origins) (x, y),
      ]..sort((a, b) {
        final d = _distanceSquared(
          a.$1,
          a.$2,
        ).compareTo(_distanceSquared(b.$1, b.$2));
        if (d != 0) return d;
        final byY = a.$2.compareTo(b.$2);
        return byY != 0 ? byY : a.$1.compareTo(b.$1);
      });
  return List<Plot>.unmodifiable([
    for (var i = 0; i < origins.length; i++)
      Plot(i, origins[i].$1, origins[i].$2),
  ]);
}();

/// The tile where the parcel column or row [g] starts: the classic origins for
/// 0..7, then plot-wide steps in both directions beyond them.
int parcelOrigin(int g) => g < 0
    ? _origins.first + kPlotSize * g
    : g < _origins.length
    ? _origins[g]
    : _origins.last + kPlotSize * (g - _origins.length + 1);

/// Plot indexes from here up stand for the parcels that can be claimed (index
/// `kLandBase + k` is the k-th of [claimableParcels]); they exist only while
/// the user chooses land.
const kLandBase = 1000;

/// Plot [index] of a town with the claimed [parcels]: the classic plots come
/// first (0..63), then one plot per claimed non-garden parcel in claim order.
Plot plotFor(int index, List<Parcel> parcels) {
  final Parcel p;
  if (index < kPlots.length) {
    return kPlots[index];
  } else if (index >= kLandBase) {
    p = claimableParcels(parcels)[index - kLandBase];
  } else {
    p = [
      for (final q in parcels)
        if (!q.garden) q,
    ][index - kPlots.length];
  }
  return Plot(index, parcelOrigin(p.gx), parcelOrigin(p.gy));
}

/// The plot covering tile ([x], [y]) in a town with the claimed [parcels], or
/// null for roads, scenery and unclaimed land.
Plot? plotAtWith(List<Parcel> parcels, int x, int y) {
  final base = plotAt(x, y);
  if (base != null) return base;
  for (var i = 0; i < parcels.where((p) => !p.garden).length; i++) {
    final p = plotFor(kPlots.length + i, parcels);
    if (x >= p.originX &&
        x < p.originX + kPlotSize &&
        y >= p.originY &&
        y < p.originY + kPlotSize) {
      return p;
    }
  }
  return null;
}

/// The tile box of the island: the starting map plus every claimed parcel.
({int left, int top, int right, int bottom}) islandBox(List<Parcel> parcels) {
  var left = 0;
  var top = 0;
  var right = kMapSize;
  var bottom = kMapSize;
  for (final p in parcels) {
    final ox = parcelOrigin(p.gx);
    final oy = parcelOrigin(p.gy);
    left = ox < left ? ox : left;
    top = oy < top ? oy : top;
    right = ox + kPlotSize > right ? ox + kPlotSize : right;
    bottom = oy + kPlotSize > bottom ? oy + kPlotSize : bottom;
  }
  return (left: left, top: top, right: right, bottom: bottom);
}

/// The plot covering tile ([x], [y]), or null for roads and scenery.
Plot? plotAt(int x, int y) {
  for (final p in kPlots) {
    if (x >= p.originX &&
        x < p.originX + kPlotSize &&
        y >= p.originY &&
        y < p.originY + kPlotSize) {
      return p;
    }
  }
  return null;
}
