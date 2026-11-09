import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/domain/elapsed.dart';
import 'package:focus_town/domain/testing/fake_clock.dart';
import 'package:focus_town/domain/time_stamp.dart';

void main() {
  late FakeClock clock;
  setUp(() => clock = FakeClock());

  test('TimeStamp.now captures wall and uptime', () {
    clock.advance(const Duration(minutes: 3));
    final t = TimeStamp.now(clock);
    expect(t.wall, clock.nowWall());
    expect(t.uptime, const Duration(minutes: 3));
  });

  test('TimeStamp has value equality', () {
    final a = TimeStamp(DateTime(2026), const Duration(seconds: 1));
    final b = TimeStamp(DateTime(2026), const Duration(seconds: 1));
    expect(a, b);
    expect(a.hashCode, b.hashCode);
  });

  group('elapsedBetween', () {
    test('normal passage uses uptime', () {
      final from = TimeStamp.now(clock);
      clock.advance(const Duration(minutes: 30));
      expect(
        elapsedBetween(from, TimeStamp.now(clock)),
        const Duration(minutes: 30),
      );
    });

    test('wall clock moved forward is ignored', () {
      final from = TimeStamp.now(clock);
      clock
        ..advance(const Duration(minutes: 30))
        ..setWall(clock.nowWall().add(const Duration(hours: 2)));
      expect(
        elapsedBetween(from, TimeStamp.now(clock)),
        const Duration(minutes: 30),
      );
    });

    test('wall clock moved backward is ignored', () {
      final from = TimeStamp.now(clock);
      clock
        ..advance(const Duration(minutes: 30))
        ..setWall(clock.nowWall().subtract(const Duration(hours: 5)));
      expect(
        elapsedBetween(from, TimeStamp.now(clock)),
        const Duration(minutes: 30),
      );
    });

    test('after reboot falls back to wall time', () {
      clock.advance(const Duration(minutes: 20));
      final from = TimeStamp.now(clock);
      clock
        ..advance(const Duration(minutes: 10))
        ..simulateReboot()
        ..advance(const Duration(minutes: 5));
      expect(
        elapsedBetween(from, TimeStamp.now(clock)),
        const Duration(minutes: 15),
      );
    });

    test('reboot with wall clock moved backward is zero, never negative', () {
      clock.advance(const Duration(minutes: 20));
      final from = TimeStamp.now(clock);
      clock
        ..simulateReboot()
        ..setWall(from.wall.subtract(const Duration(hours: 1)));
      expect(elapsedBetween(from, TimeStamp.now(clock)), Duration.zero);
    });
  });
}
