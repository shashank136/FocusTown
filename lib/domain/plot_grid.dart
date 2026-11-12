import 'package:focus_town/domain/building_tier.dart';
import 'package:focus_town/domain/parcel.dart';

/// Tile where each starting plot column or row begins: four west/north of the
/// road (tiles 31 and 32), four east/south of it.
const kBaseOrigins = [3, 10, 17, 24, 33, 40, 47, 54];

double _distanceSquared(int gx, int gy) {
  final dx = kBaseOrigins[gx] + 3.5 - 32;
  final dy = kBaseOrigins[gy] + 3.5 - 32;
  return dx * dx + dy * dy;
}

/// The grid cell (column, row) of each starting plot, nearest the crossing
/// first (ties: smaller row, then column). Plot `i` of the island is cell `i`.
final List<(int, int)> kBaseCells = _sortedCells();

List<(int, int)> _sortedCells() {
  final cells =
      <(int, int)>[
        for (var gy = 0; gy < kBaseOrigins.length; gy++)
          for (var gx = 0; gx < kBaseOrigins.length; gx++) (gx, gy),
      ]..sort((a, b) {
        final d = _distanceSquared(
          a.$1,
          a.$2,
        ).compareTo(_distanceSquared(b.$1, b.$2));
        if (d != 0) return d;
        final byY = a.$2.compareTo(b.$2);
        return byY != 0 ? byY : a.$1.compareTo(b.$1);
      });
  return List.unmodifiable(cells);
}

/// The grid cell of plot [index] in a town with the claimed [parcels]: the
/// starting plots, then one per claimed non-garden parcel in claim order. Null
/// when there is no such plot.
(int, int)? plotCell(int index, List<Parcel> parcels) {
  if (index < 0) return null;
  if (index < kBaseCells.length) return kBaseCells[index];
  final plots = [
    for (final p in parcels)
      if (!p.garden) p,
  ];
  final k = index - kBaseCells.length;
  return k < plots.length ? (plots[k].gx, plots[k].gy) : null;
}

/// The plot at grid cell ([gx], [gy]), or null when the cell is not a plot
/// (open sea, unclaimed land, or a garden).
int? plotAtCell(int gx, int gy, List<Parcel> parcels) {
  final base = kBaseCells.indexOf((gx, gy));
  if (base >= 0) return base;
  var k = kBaseCells.length;
  for (final p in parcels) {
    if (p.garden) continue;
    if (p.gx == gx && p.gy == gy) return k;
    k++;
  }
  return null;
}

/// How many plots a building of [tier] takes: a castle stands on a 2 x 2
/// block, everything else on one plot.
int plotsOf(BuildingTier tier) => tier == BuildingTier.castle ? 4 : 1;

// Columns and rows 3 and 4 of the starting island are split by the road.
bool _crossesRoad(int g) => g == 3;

/// The plots a building of [tier] anchored on plot [anchor] covers, the anchor
/// (its top-left plot) first, or null when that cannot hold it: the block runs
/// off the plots of the island or across the road. Whether the plots are
/// free is not checked here.
List<int>? footprintOf(BuildingTier tier, int anchor, List<Parcel> parcels) {
  final cell = plotCell(anchor, parcels);
  if (cell == null) return null;
  if (plotsOf(tier) == 1) return [anchor];
  final (gx, gy) = cell;
  if (_crossesRoad(gx) || _crossesRoad(gy)) return null;
  final cells = [
    plotAtCell(gx + 1, gy, parcels),
    plotAtCell(gx, gy + 1, parcels),
    plotAtCell(gx + 1, gy + 1, parcels),
  ];
  return cells.contains(null) ? null : [anchor, ...cells.cast<int>()];
}
