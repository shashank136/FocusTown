import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/game/world/plot_layout.dart';

double _dist2(Plot p) {
  final dx = p.center.x - 32;
  final dy = p.center.y - 32;
  return dx * dx + dy * dy;
}

void main() {
  test('there are 64 plots numbered 0..63 in order', () {
    expect(kPlots, hasLength(64));
    for (var i = 0; i < 64; i++) {
      expect(kPlots[i].index, i);
    }
  });

  test('distance from the crossing never decreases with the index', () {
    for (var i = 1; i < kPlots.length; i++) {
      expect(_dist2(kPlots[i]), greaterThanOrEqualTo(_dist2(kPlots[i - 1])));
    }
  });

  test('plots 0 to 3 are the four plots at the crossing corners', () {
    expect(kPlots.take(4).map((p) => (p.originX, p.originY)).toList(), [
      (24, 24),
      (33, 24),
      (24, 33),
      (33, 33),
    ]);
  });

  test('plot size is 7 and the center is the middle of the plot', () {
    final p = kPlots.first;
    expect(p.size, kPlotSize);
    expect(p.size, 7);
    expect((p.center.x, p.center.y), (27.5, 27.5));
  });

  test('no plot overlaps another plot or a road, all lie inside the map', () {
    final seen = <(int, int)>{};
    for (final p in kPlots) {
      expect(p.originX, greaterThanOrEqualTo(0));
      expect(p.originY, greaterThanOrEqualTo(0));
      expect(p.originX + p.size - 1, lessThan(kMapSize));
      expect(p.originY + p.size - 1, lessThan(kMapSize));
      for (var x = p.originX; x < p.originX + p.size; x++) {
        for (var y = p.originY; y < p.originY + p.size; y++) {
          expect(isRoad(x, y), isFalse, reason: 'plot ${p.index} on a road');
          expect(seen.add((x, y)), isTrue, reason: 'overlap at ($x, $y)');
        }
      }
    }
  });

  test('isRoad covers x or y in 31..32', () {
    expect(isRoad(31, 0), isTrue);
    expect(isRoad(32, 50), isTrue);
    expect(isRoad(5, 31), isTrue);
    expect(isRoad(5, 32), isTrue);
    expect(isRoad(30, 30), isFalse);
    expect(isRoad(33, 33), isFalse);
    expect(isRoad(30, 5), isFalse);
  });

  test('plotAt finds the plot from its corner tiles and is null elsewhere', () {
    for (final p in kPlots) {
      final last = p.size - 1;
      for (final (dx, dy) in [(0, 0), (last, 0), (0, last), (last, last)]) {
        expect(plotAt(p.originX + dx, p.originY + dy), p);
      }
    }
    expect(plotAt(31, 10), isNull);
    expect(plotAt(10, 32), isNull);
    expect(plotAt(0, 0), isNull);
    expect(plotAt(63, 63), isNull);
  });

  test('the layout is identical across two reads', () {
    expect(
      kPlots.map((p) => (p.index, p.originX, p.originY)).toList(),
      kPlots.map((p) => (p.index, p.originX, p.originY)).toList(),
    );
  });
}
