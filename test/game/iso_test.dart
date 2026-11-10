import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/game/world/iso.dart';
import 'package:focus_town/game/world/vec2.dart';

void main() {
  const origin = Vec2(100, 50);

  group('project with tile 10, origin (100, 50)', () {
    final cases = <String, (List<double>, Vec2)>{
      'origin': ([0, 0, 0], const Vec2(100, 50)),
      'x+1': ([1, 0, 0], const Vec2(110, 55)),
      'y+1': ([0, 1, 0], const Vec2(90, 55)),
      'z+1 goes up': ([0, 0, 1], const Vec2(100, 40)),
      '(2,3,4)': ([2, 3, 4], const Vec2(90, 35)),
    };
    for (final entry in cases.entries) {
      test(entry.key, () {
        final (p, expected) = entry.value;
        expect(project(p[0], p[1], p[2], 10, origin), expected);
      });
    }
  });

  group('unprojectGround', () {
    const samples = [
      (0.0, 0.0),
      (3.0, 2.0),
      (-4.0, 5.0),
      (2.5, -1.25),
      (-3.5, -6.75),
    ];
    for (final (x, y) in samples) {
      test('round trips ($x, $y)', () {
        final s = project(x, y, 0, 10, origin);
        final g = unprojectGround(s.x, s.y, 10, origin);
        expect(g.x, closeTo(x, 1e-9));
        expect(g.y, closeTo(y, 1e-9));
      });
    }

    test('a different tile and origin still round-trips', () {
      const o = Vec2(-30, 400);
      final s = project(7.5, -2, 0, 24, o);
      final g = unprojectGround(s.x, s.y, 24, o);
      expect(g.x, closeTo(7.5, 1e-9));
      expect(g.y, closeTo(-2, 1e-9));
    });
  });

  test('Vec2 has value equality', () {
    expect(const Vec2(1, 2), const Vec2(1, 2));
    expect(const Vec2(1, 2).hashCode, const Vec2(1, 2).hashCode);
    expect(const Vec2(1, 2), isNot(const Vec2(2, 1)));
  });
}
