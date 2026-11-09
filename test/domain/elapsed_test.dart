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

  test('TimeStamps differing only in uptime are unequal', () {
    final a = TimeStamp(DateTime(2026), const Duration(seconds: 1));
    final b = TimeStamp(DateTime(2026), const Duration(seconds: 2));
    expect(a, isNot(b));
  });

  group('elapsedBetween', () {
    test('equal uptime is 0 even when the wall clock moved', () {
      final from = TimeStamp(DateTime(2026), const Duration(minutes: 5));
      final to = TimeStamp(DateTime(2026, 1, 1, 3), const Duration(minutes: 5));
      expect(elapsedBetween(from, to), Duration.zero);
    });

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

  group('wallClockTampered', () {
    test('clean 30 minutes is not tampered', () {
      final from = TimeStamp.now(clock);
      clock.advance(const Duration(minutes: 30));
      expect(wallClockTampered(from, TimeStamp.now(clock)), isFalse);
    });

    test('wall +2 hours is tampered', () {
      final from = TimeStamp.now(clock);
      clock
        ..advance(const Duration(minutes: 30))
        ..setWall(clock.nowWall().add(const Duration(hours: 2)));
      expect(wallClockTampered(from, TimeStamp.now(clock)), isTrue);
    });

    test('wall -2 hours is tampered', () {
      final from = TimeStamp.now(clock);
      clock
        ..advance(const Duration(minutes: 30))
        ..setWall(clock.nowWall().subtract(const Duration(hours: 2)));
      expect(wallClockTampered(from, TimeStamp.now(clock)), isTrue);
    });

    test('difference of exactly 2 minutes is not tampered', () {
      final from = TimeStamp.now(clock);
      clock
        ..advance(const Duration(minutes: 30))
        ..setWall(clock.nowWall().add(const Duration(minutes: 2)));
      expect(wallClockTampered(from, TimeStamp.now(clock)), isFalse);
    });

    test('difference of 2 minutes 1 second is tampered', () {
      final from = TimeStamp.now(clock);
      clock
        ..advance(const Duration(minutes: 30))
        ..setWall(clock.nowWall().add(const Duration(minutes: 2, seconds: 1)));
      expect(wallClockTampered(from, TimeStamp.now(clock)), isTrue);
    });

    test('after a reboot is never tampered', () {
      clock.advance(const Duration(minutes: 20));
      final from = TimeStamp.now(clock);
      clock
        ..simulateReboot()
        ..setWall(from.wall.add(const Duration(days: 3)));
      expect(wallClockTampered(from, TimeStamp.now(clock)), isFalse);
    });
  });
}
