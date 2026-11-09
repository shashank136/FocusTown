import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/domain/clock.dart';
import 'package:focus_town/domain/testing/fake_clock.dart';

void main() {
  group('FakeClock', () {
    test('advance moves wall and uptime by the same amount', () {
      final clock = FakeClock();
      final wall = clock.nowWall();
      clock.advance(const Duration(minutes: 5));
      expect(clock.nowWall(), wall.add(const Duration(minutes: 5)));
      expect(clock.uptime(), const Duration(minutes: 5));
    });

    test('setWall changes wall only', () {
      final clock = FakeClock()..advance(const Duration(seconds: 30));
      final target = DateTime(2030, 6, 1, 12);
      clock.setWall(target);
      expect(clock.nowWall(), target);
      expect(clock.uptime(), const Duration(seconds: 30));
    });

    test('simulateReboot zeroes uptime and keeps wall', () {
      final clock = FakeClock()..advance(const Duration(minutes: 10));
      final wall = clock.nowWall();
      clock.simulateReboot();
      expect(clock.uptime(), Duration.zero);
      expect(clock.nowWall(), wall);
      clock.advance(const Duration(seconds: 7));
      expect(clock.uptime(), const Duration(seconds: 7));
      expect(clock.nowWall(), wall.add(const Duration(seconds: 7)));
    });

    test('default start is 2026-01-01 09:00', () {
      expect(FakeClock().nowWall(), DateTime(2026, 1, 1, 9));
    });
  });

  test('SystemClock.uptime is non-negative and non-decreasing', () {
    final clock = SystemClock();
    final a = clock.uptime();
    final b = clock.uptime();
    expect(a, greaterThanOrEqualTo(Duration.zero));
    expect(b, greaterThanOrEqualTo(a));
  });
}
