import 'package:focus_town/domain/building_tier.dart';
import 'package:focus_town/domain/footprint.dart';
import 'package:focus_town/domain/landmark.dart';
import 'package:focus_town/domain/parcel.dart';

export 'package:focus_town/domain/footprint.dart';

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
  final raw = rawPlotAtCell(gx, gy, parcels);
  if (raw == null) return null;
  // A square turned into a garden is no plot, but keeps its number so that the
  // plots after it do not move.
  final garden = parcels.any((p) => p.garden && p.gx == gx && p.gy == gy);
  return garden ? null : raw;
}

/// The plot number the cell ([gx], [gy]) has (or had, once it became a
/// garden), or null when it was never a plot.
int? rawPlotAtCell(int gx, int gy, List<Parcel> parcels) {
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

/// The footprint of a building of [tier], or of [landmark] when it is one.
Footprint footprintFor(BuildingTier tier, [Landmark? landmark]) =>
    landmark?.footprint ??
    (tier == BuildingTier.castle ? Footprint.block : Footprint.one);

// A run of [n] grid cells from [g] lies across the road of the starting
// island when it has cells on both sides of it (between columns or rows 3 and
// 4).
bool _crossesRoad(int g, int n) => g <= 3 && g + n - 1 >= 4;

/// The plots a building of [size] anchored on plot [anchor] covers, the anchor
/// (its top-left plot) first, or null when that cannot hold it: a plot is
/// missing (open sea, unclaimed land or a garden) or the block lies across the
/// road of the starting island. Whether the plots are free is not checked
/// here.
List<int>? footprintOf(Footprint size, int anchor, List<Parcel> parcels) {
  final cell = plotCell(anchor, parcels);
  if (cell == null) return null;
  if (size.area == 1) return [anchor];
  final (gx, gy) = cell;
  if (_crossesRoad(gx, size.cols) || _crossesRoad(gy, size.rows)) return null;
  final plots = <int>[];
  for (var y = 0; y < size.rows; y++) {
    for (var x = 0; x < size.cols; x++) {
      final plot = plotAtCell(gx + x, gy + y, parcels);
      if (plot == null) return null;
      plots.add(plot);
    }
  }
  return plots;
}
