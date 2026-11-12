import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/domain/building_tier.dart';
import 'package:focus_town/domain/parcel.dart';
import 'package:focus_town/domain/plot_grid.dart';
import 'package:focus_town/domain/town.dart';
import 'package:focus_town/game/world/plot_layout.dart';
import 'package:focus_town/game/world/road_network.dart';

TownState _town(
  List<TownBuilding> buildings, [
  List<Parcel> parcels = const [],
]) => TownState(
  workers: 3,
  plotsUnlocked: 6,
  buildings: buildings,
  queue: const [],
  inRecoveryMode: false,
  parcels: parcels,
);

TownBuilding _b(
  int plot,
  BuildingTier tier, [
  BuildingStatus status = BuildingStatus.complete,
]) => TownBuilding(id: 'b$plot', tier: tier, status: status, plotIndex: plot);

int _at(int gx, int gy) => plotAtCell(gx, gy, const [])!;

// Every road tile can be reached from the crossing by walking road tiles.
bool _connected(RoadNetwork r) {
  final seen = <(int, int)>{};
  final todo = [(31, 31)];
  while (todo.isNotEmpty) {
    final t = todo.removeLast();
    if (!r.isRoad(t.$1, t.$2) || !seen.add(t)) continue;
    todo
      ..add((t.$1 + 1, t.$2))
      ..add((t.$1 - 1, t.$2))
      ..add((t.$1, t.$2 + 1))
      ..add((t.$1, t.$2 - 1));
  }
  return seen.length == r.tiles.length;
}

bool _onPlotEdge(int x, int y, List<Parcel> parcels) {
  final plots = [
    for (var i = 0; i < kPlots.length + parcels.length; i++)
      if (i < kPlots.length || !parcels[i - kPlots.length].garden)
        plotFor(i, parcels),
  ];
  for (final p in plots) {
    final lx = x - p.originX;
    final ly = y - p.originY;
    if (lx < 0 || ly < 0 || lx > 6 || ly > 6) continue;
    if (lx == 0 || lx == 6 || ly == 0 || ly == 6) return true;
  }
  return false;
}

void main() {
  test('the two main roads are always roads', () {
    final r = RoadNetwork(_town(const []));
    for (var i = 0; i < 64; i++) {
      expect(r.isRoad(31, i), isTrue);
      expect(r.isRoad(32, i), isTrue);
      expect(r.isRoad(i, 31), isTrue);
      expect(r.isRoad(i, 32), isTrue);
    }
    expect(r.isRoad(10, 10), isFalse);
  });

  test('a building gets a road on the outer ring of its plot, not inside', () {
    final p = kPlots[_at(1, 1)];
    final r = RoadNetwork(_town([_b(_at(1, 1), BuildingTier.house)]));
    for (var i = 0; i < 7; i++) {
      expect(r.isRoad(p.originX + i, p.originY), isTrue);
      expect(r.isRoad(p.originX + i, p.originY + 6), isTrue);
      expect(r.isRoad(p.originX, p.originY + i), isTrue);
      expect(r.isRoad(p.originX + 6, p.originY + i), isTrue);
    }
    for (var x = 1; x <= 5; x++) {
      for (var y = 1; y <= 5; y++) {
        expect(r.isRoad(p.originX + x, p.originY + y), isFalse);
      }
    }
  });

  test('a castle gets one road around its whole 14 x 14 block', () {
    final p = kPlots[_at(0, 0)];
    final r = RoadNetwork(_town([_b(_at(0, 0), BuildingTier.castle)]));
    for (var i = 0; i < 14; i++) {
      expect(r.isRoad(p.originX + i, p.originY), isTrue);
      expect(r.isRoad(p.originX + i, p.originY + 13), isTrue);
      expect(r.isRoad(p.originX, p.originY + i), isTrue);
      expect(r.isRoad(p.originX + 13, p.originY + i), isTrue);
    }
    // The seam between its four plots is under the castle, not a road.
    expect(r.isRoad(p.originX + 6, p.originY + 6), isFalse);
    expect(r.isRoad(p.originX + 7, p.originY + 3), isFalse);
  });

  test('every road is connected to the main roads', () {
    final r = RoadNetwork(
      _town([
        _b(_at(0, 0), BuildingTier.castle),
        _b(_at(6, 6), BuildingTier.hut),
        _b(_at(0, 7), BuildingTier.house),
        _b(_at(7, 0), BuildingTier.tower),
      ]),
    );
    expect(_connected(r), isTrue);
  });

  test('a far building is joined by a road along plot edges only', () {
    final r = RoadNetwork(_town([_b(_at(0, 0), BuildingTier.hut)]));
    expect(_connected(r), isTrue);
    for (final (x, y) in r.tiles) {
      final main = (x >= 31 && x <= 32) || (y >= 31 && y <= 32);
      expect(main || _onPlotEdge(x, y, const []), isTrue, reason: '($x,$y)');
    }
    // It really needed a connector: the plot is far from the crossing.
    expect(r.tiles.length, greaterThan(2 * 64 * 2 - 4 + 24));
  });

  test('nothing is a road under a building', () {
    final buildings = [
      _b(_at(0, 0), BuildingTier.castle),
      _b(_at(4, 4), BuildingTier.workshop),
      _b(_at(2, 5), BuildingTier.tower),
    ];
    final r = RoadNetwork(_town(buildings));
    for (final b in buildings) {
      final p = plotForTier(b.plotIndex, b.tier, const []);
      for (var x = 1; x < p.size - 1; x++) {
        for (var y = 1; y < p.size - 1; y++) {
          expect(
            r.isRoad(p.originX + x, p.originY + y),
            isFalse,
            reason: '${b.tier.name} ($x,$y)',
          );
        }
      }
    }
  });

  test('a ruin and the building site get roads too', () {
    final ruin = kPlots[_at(5, 5)];
    final site = kPlots[_at(1, 6)];
    final r = RoadNetwork(
      _town([_b(_at(5, 5), BuildingTier.hut, BuildingStatus.ruin)]),
      site: site,
    );
    expect(r.isRoad(ruin.originX, ruin.originY), isTrue);
    expect(r.isRoad(site.originX, site.originY), isTrue);
    expect(_connected(r), isTrue);
  });

  test('empty forest has no road around it', () {
    final p = kPlots[_at(1, 1)];
    final r = RoadNetwork(_town([_b(_at(6, 6), BuildingTier.hut)]));
    expect(r.isRoad(p.originX + 3, p.originY + 3), isFalse);
    expect(r.isRoad(p.originX, p.originY + 3), isFalse);
  });

  test('claimed land at the coast is joined to the network', () {
    const parcels = [Parcel(-1, 3)];
    final plot = _town([_b(64, BuildingTier.hut)], parcels);
    final r = RoadNetwork(plot);
    expect(_connected(r), isTrue);
    final p = plotFor(64, parcels);
    expect(r.isRoad(p.originX, p.originY), isTrue);
  });

  group('routes', () {
    final town = _town([
      _b(_at(0, 0), BuildingTier.castle),
      _b(_at(6, 6), BuildingTier.hut),
      _b(_at(2, 5), BuildingTier.house),
    ]);

    test('each route runs over road tiles, one step at a time', () {
      final r = RoadNetwork(town);
      final routes = r.routes(8);
      expect(routes, hasLength(8));
      for (final route in routes) {
        expect(route.length, greaterThanOrEqualTo(10));
        for (var i = 0; i < route.length; i++) {
          expect(r.isRoad(route[i].$1, route[i].$2), isTrue);
          if (i > 0) {
            final d =
                (route[i].$1 - route[i - 1].$1).abs() +
                (route[i].$2 - route[i - 1].$2).abs();
            expect(d, 1);
          }
        }
      }
    });

    test('the routes are the same every time', () {
      expect(RoadNetwork(town).routes(6), RoadNetwork(town).routes(6));
    });

    test('the walkers do not all take the same road', () {
      final routes = RoadNetwork(town).routes(8);
      expect(routes.map((r) => r.first).toSet().length, greaterThan(4));
    });
  });
}
