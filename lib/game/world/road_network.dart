import 'package:focus_town/domain/plot_grid.dart';
import 'package:focus_town/domain/town.dart';
import 'package:focus_town/game/world/plot_layout.dart';

/// A tile (x, y).
typedef Tile = (int, int);

/// The roads of a town: the two main roads, a road along the outer tile ring
/// of every used plot or 2 x 2 block (buildings, ruins and the building
/// site), and the shortest connector along plot edges wherever a ring does not
/// already touch the network. Nothing is a road under a building. The player
/// never places roads.
class RoadNetwork {
  /// Builds the network of [town], with a road around the [site] plot too.
  new(TownState town, {Plot? site}) : tiles = _build(town, site);

  /// Every road tile.
  final Set<Tile> tiles;

  /// Whether tile ([x], [y]) is a road.
  bool isRoad(int x, int y) => tiles.contains((x, y));

  /// [count] walking routes, each a list of road tiles one step apart. A
  /// walker goes along its route and back again. The routes depend only on the
  /// network, so they are the same every time.
  List<List<Tile>> routes(int count) {
    final nodes = tiles.toList()
      ..sort(
        (a, b) => a.$2 != b.$2 ? a.$2.compareTo(b.$2) : a.$1.compareTo(b.$1),
      );
    final n = nodes.length;
    if (n < 2) return const [];
    final out = <List<Tile>>[];
    for (var i = 0; i < count; i++) {
      final from = nodes[((i + 1) * 40503) % n];
      var to = nodes[((i + 1) * 65537 + n ~/ 2) % n];
      for (var tries = 0; tries < 6; tries++) {
        if ((to.$1 - from.$1).abs() + (to.$2 - from.$2).abs() >= 12) break;
        to = nodes[(nodes.indexOf(to) + n ~/ 3) % n];
      }
      final route = _route(from, to);
      if (route.length >= 2) out.add(route);
    }
    return out;
  }

  // The cheapest walk from [from] to [to]: a step costs 1000, a turn 1 more,
  // so walkers keep to a straight line on a wide road.
  List<Tile> _route(Tile from, Tile to) {
    const dirs = [(1, 0), (-1, 0), (0, 1), (0, -1)];
    int key(Tile t, int d) => ((t.$1 + 512) * 2048 + (t.$2 + 512)) * 4 + d;
    final best = <int, int>{};
    final from_ = <int, int>{};
    final heap = _Heap();
    for (var d = 0; d < 4; d++) {
      best[key(from, d)] = 0;
      heap.push(0, (from, d));
    }
    int? goal;
    while (heap.isNotEmpty) {
      final (cost, (tile, dir)) = heap.pop();
      if (cost > (best[key(tile, dir)] ?? 1 << 40)) continue;
      if (tile == to) {
        goal = key(tile, dir);
        break;
      }
      for (var d = 0; d < 4; d++) {
        final next = (tile.$1 + dirs[d].$1, tile.$2 + dirs[d].$2);
        if (!tiles.contains(next)) continue;
        final c = cost + 1000 + (d == dir ? 0 : 1);
        final k = key(next, d);
        if (c < (best[k] ?? 1 << 40)) {
          best[k] = c;
          from_[k] = key(tile, dir);
          heap.push(c, (next, d));
        }
      }
    }
    if (goal == null) return const [];
    final path = <Tile>[];
    int? at = goal;
    while (at != null) {
      final tileKey = at ~/ 4;
      path.add((tileKey ~/ 2048 - 512, tileKey % 2048 - 512));
      at = from_[at];
    }
    return path.reversed.toList();
  }
}

// A small binary min-heap of (cost, value) pairs.
class _Heap {
  final List<(int, (Tile, int))> _items = [];

  bool get isNotEmpty => _items.isNotEmpty;

  void push(int cost, (Tile, int) value) {
    _items.add((cost, value));
    var i = _items.length - 1;
    while (i > 0) {
      final parent = (i - 1) ~/ 2;
      if (_items[parent].$1 <= _items[i].$1) break;
      final tmp = _items[parent];
      _items[parent] = _items[i];
      _items[i] = tmp;
      i = parent;
    }
  }

  (int, (Tile, int)) pop() {
    final top = _items.first;
    final last = _items.removeLast();
    if (_items.isNotEmpty) {
      _items[0] = last;
      var i = 0;
      while (true) {
        final l = 2 * i + 1;
        final r = l + 1;
        var m = i;
        if (l < _items.length && _items[l].$1 < _items[m].$1) m = l;
        if (r < _items.length && _items[r].$1 < _items[m].$1) m = r;
        if (m == i) break;
        final tmp = _items[m];
        _items[m] = _items[i];
        _items[i] = tmp;
        i = m;
      }
    }
    return top;
  }
}

bool _isMain(int x, int y) =>
    x >= 0 && y >= 0 && x < kMapSize && y < kMapSize && isRoad(x, y);

// The outer tile ring of [p]'s block.
Iterable<Tile> _ring(Plot p) sync* {
  final n = p.size;
  for (var i = 0; i < n; i++) {
    yield (p.originX + i, p.originY);
    yield (p.originX + i, p.originY + n - 1);
    if (i > 0 && i < n - 1) {
      yield (p.originX, p.originY + i);
      yield (p.originX + n - 1, p.originY + i);
    }
  }
}

Set<Tile> _build(TownState town, Plot? site) {
  final blocks = [
    for (final b in town.buildings)
      plotForTier(b.plotIndex, b.tier, town.parcels),
    ?site,
  ];
  final roads = <Tile>{
    for (var x = 0; x < kMapSize; x++)
      for (var y = 0; y < kMapSize; y++)
        if (_isMain(x, y)) (x, y),
    for (final p in blocks) ..._ring(p),
  };
  // Under a building: never a road.
  final blocked = <Tile>{
    for (final p in blocks)
      for (var x = 1; x < p.size - 1; x++)
        for (var y = 1; y < p.size - 1; y++) (p.originX + x, p.originY + y),
  };
  // Where a connector may run: the edge tiles of every plot, and the roads.
  final lattice = <Tile>{...roads};
  for (var i = 0; i < kPlots.length + town.parcels.length; i++) {
    if (i >= kPlots.length && town.parcels[i - kPlots.length].garden) continue;
    final cell = plotCell(i, town.parcels);
    if (cell == null) continue;
    lattice.addAll(_ring(plotFor(i, town.parcels)));
  }
  lattice.removeAll(blocked);

  Set<Tile> reachable() {
    final seen = <Tile>{};
    final todo = <Tile>[(31, 31)];
    while (todo.isNotEmpty) {
      final t = todo.removeLast();
      if (!roads.contains(t) || !seen.add(t)) continue;
      todo
        ..add((t.$1 + 1, t.$2))
        ..add((t.$1 - 1, t.$2))
        ..add((t.$1, t.$2 + 1))
        ..add((t.$1, t.$2 - 1));
    }
    return seen;
  }

  // Join every ring that does not touch the network: walk out over plot edges
  // from the connected roads until an unconnected road tile is met, and keep
  // that path.
  var connected = reachable();
  while (connected.length < roads.length) {
    final parent = <Tile, Tile?>{for (final t in connected) t: null};
    final queue = [...connected];
    Tile? hit;
    for (var head = 0; head < queue.length && hit == null; head++) {
      final t = queue[head];
      for (final next in [
        (t.$1 + 1, t.$2),
        (t.$1 - 1, t.$2),
        (t.$1, t.$2 + 1),
        (t.$1, t.$2 - 1),
      ]) {
        if (!lattice.contains(next) || parent.containsKey(next)) continue;
        parent[next] = t;
        if (roads.contains(next)) {
          hit = next;
          break;
        }
        queue.add(next);
      }
    }
    if (hit == null) break; // nothing can reach it; leave it alone
    for (Tile? t = hit; t != null; t = parent[t]) {
      roads.add(t);
    }
    connected = reachable();
  }
  return roads;
}
