import 'dart:math' as math;

import 'package:focus_town/domain/building_tier.dart';
import 'package:focus_town/domain/parcel.dart';
import 'package:focus_town/domain/plot_grid.dart';
import 'package:focus_town/domain/town.dart';
import 'package:focus_town/domain/town_rules.dart';
import 'package:focus_town/game/world/vec2.dart';

/// Width and depth of the town map in tiles.
const kMapSize = 64;

/// Width and depth of one building plot in tiles.
const kPlotSize = 7;

/// A building plot, or the rectangle of plots a bigger building stands on.
/// Plot 0 is nearest the crossing.
class Plot {
  /// Creates a plot; [cols] and [rows] are how many plots wide (x) and deep
  /// (y) the building on it is (2 and 2 for a castle on a 2 x 2 block).
  const new(
    this.index,
    this.originX,
    this.originY, [
    this.cols = 1,
    this.rows = 1,
  ]);

  /// Number 0..63, nearest the crossing first.
  final int index;

  /// Tile of the west corner.
  final int originX;

  /// Tile of the north corner.
  final int originY;

  /// Plots wide (along x).
  final int cols;

  /// Plots deep (along y).
  final int rows;

  /// Width in tiles (along x).
  int get width => kPlotSize * cols;

  /// Depth in tiles (along y).
  int get depth => kPlotSize * rows;

  /// Middle of the plot (or block) in tile coordinates.
  Vec2 get center => Vec2(originX + width / 2, originY + depth / 2);
}

/// Whether tile ([x], [y]) is on one of the two crossing roads (31..32).
bool isRoad(int x, int y) => (x >= 31 && x <= 32) || (y >= 31 && y <= 32);

/// All 64 plots, nearest the crossing first (ties: smaller y, then x).
final List<Plot> kPlots = List<Plot>.unmodifiable([
  for (var i = 0; i < kBaseCells.length; i++)
    Plot(i, kBaseOrigins[kBaseCells[i].$1], kBaseOrigins[kBaseCells[i].$2]),
]);

/// The tile where the parcel column or row [g] starts: the classic origins for
/// 0..7, then plot-wide steps in both directions beyond them.
int parcelOrigin(int g) => g < 0
    ? kBaseOrigins.first + kPlotSize * g
    : g < kBaseOrigins.length
    ? kBaseOrigins[g]
    : kBaseOrigins.last + kPlotSize * (g - kBaseOrigins.length + 1);

/// The tiles of the island ground for a town with the claimed [parcels]: the
/// 64 x 64 map, grown so that it holds every claimed parcel with the same
/// 3-tile margin all round. The end of each range is one past the last tile.
({int x0, int y0, int x1, int y1}) islandGround(Iterable<Parcel> parcels) {
  final gx = [0, kBaseParcelsPerSide - 1, for (final p in parcels) p.gx];
  final gy = [0, kBaseParcelsPerSide - 1, for (final p in parcels) p.gy];
  return (
    x0: parcelOrigin(gx.reduce(math.min)) - 3,
    y0: parcelOrigin(gy.reduce(math.min)) - 3,
    x1: parcelOrigin(gx.reduce(math.max)) + kPlotSize + 3,
    y1: parcelOrigin(gy.reduce(math.max)) + kPlotSize + 3,
  );
}

/// Plot [index] of a town with the claimed [parcels]: the classic plots come
/// first (0..63), then one plot per claimed non-garden parcel in claim order.
Plot plotFor(int index, List<Parcel> parcels) {
  final Parcel p;
  if (index < kPlots.length) {
    return kPlots[index];
  } else {
    p = [
      for (final q in parcels)
        if (!q.garden) q,
    ][index - kPlots.length];
  }
  return Plot(index, parcelOrigin(p.gx), parcelOrigin(p.gy));
}

/// The plot a building of [size] anchored on plot [index] stands on: the
/// anchor plot grown to the whole rectangle when it fits there, else a single
/// plot.
Plot plotForFootprint(int index, Footprint size, List<Parcel> parcels) {
  final p = plotFor(index, parcels);
  return size.area > 1 && footprintOf(size, index, parcels) != null
      ? Plot(p.index, p.originX, p.originY, size.cols, size.rows)
      : p;
}

/// The plot a building of [tier] anchored on plot [index] stands on.
Plot plotForTier(int index, BuildingTier tier, List<Parcel> parcels) =>
    plotForFootprint(index, footprintFor(tier), parcels);

/// The plot [b] stands on in [town]: what it really covers, so a landmark's
/// rectangle (or its old 2 x 2 while its new area is not free).
Plot plotForBuilding(TownState town, TownBuilding b) => plotForFootprint(
  b.plotIndex,
  TownRules.footprintOfBuilding(town, b),
  town.parcels,
);

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
