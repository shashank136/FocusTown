import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/domain/building_tier.dart';
import 'package:focus_town/domain/focus_stats.dart';
import 'package:focus_town/domain/local_date.dart';
import 'package:focus_town/domain/session.dart';
import 'package:focus_town/domain/time_stamp.dart';

// Wednesday 2026-11-11; its week starts on Monday 2026-11-09.
const _today = LocalDate(2026, 11, 11);

Session _s(
  LocalDate day,
  int minutes, {
  SessionState state = SessionState.completed,
}) => Session(
  id: '${day.toIso()}-$minutes-$state',
  plannedMinutes: minutes,
  tier: BuildingTier.hut,
  workersAssigned: 1,
  state: state,
  startedAt: TimeStamp(
    DateTime(day.year, day.month, day.day, 10),
    Duration.zero,
  ),
);

FocusStats _stats(List<Session> sessions) => FocusStats.from(sessions, _today);

void main() {
  test('no history gives zeros and no trend', () {
    final s = _stats([]);
    expect(s.isEmpty, isTrue);
    expect(s.minutesPerDay, List.filled(7, 0));
    expect(s.minutesPerWeek, List.filled(8, 0));
    expect(s.completionRate, 0);
    expect(s.averageMinutes, 0);
    expect(s.longestMinutes, 0);
    expect(s.currentStreak, 0);
    expect(s.longestStreak, 0);
    expect(s.weekChange, isNull);
  });

  test('one session today lands on the last day and the last week', () {
    final s = _stats([_s(_today, 25)]);
    expect(s.isEmpty, isFalse);
    expect(s.minutesPerDay, [0, 0, 0, 0, 0, 0, 25]);
    expect(s.minutesPerWeek, [0, 0, 0, 0, 0, 0, 0, 25]);
    expect(s.averageMinutes, 25);
    expect(s.longestMinutes, 25);
    expect(s.completionRate, 1);
    expect(s.currentStreak, 1);
  });

  test('a session on Sunday is last week, one on Monday is this week', () {
    final s = _stats([
      _s(const LocalDate(2026, 11, 8), 30),
      _s(const LocalDate(2026, 11, 9), 20),
    ]);
    expect(s.minutesPerWeek.sublist(6), [30, 20]);
  });

  test('failed sessions add no minutes and lower the rate', () {
    final s = _stats([
      _s(_today, 30),
      _s(_today, 40, state: SessionState.failed),
    ]);
    expect(s.minutesPerDay.last, 30);
    expect(s.completionRate, 0.5);
    expect(s.averageMinutes, 30);
  });

  test('average and longest cover completed sessions only', () {
    final s = _stats([_s(_today, 20), _s(_today.addDays(-1), 60)]);
    expect(s.averageMinutes, 40);
    expect(s.longestMinutes, 60);
  });

  test('streaks: current ends today or yesterday, longest is the best run', () {
    final s = _stats([
      _s(_today.addDays(-1), 25),
      _s(_today.addDays(-2), 25),
      _s(_today.addDays(-10), 25),
      _s(_today.addDays(-11), 25),
      _s(_today.addDays(-12), 25),
    ]);
    expect(s.currentStreak, 2);
    expect(s.longestStreak, 3);
    expect(_stats([_s(_today.addDays(-2), 25)]).currentStreak, 0);
  });

  test('the change compares the last 7 days with the 7 before', () {
    final s = _stats([_s(_today, 60), _s(_today.addDays(-7), 50)]);
    expect(s.weekChange, closeTo(0.2, 1e-9));
  });

  test('the change is null with nothing in the earlier 7 days', () {
    expect(_stats([_s(_today, 60)]).weekChange, isNull);
  });

  test('sessions dated after today (clock moved back) are ignored', () {
    final s = _stats([_s(_today.addDays(1), 90), _s(_today, 10)]);
    expect(s.minutesPerDay.last, 10);
    expect(s.longestMinutes, 10);
    expect(s.completionRate, 1);
  });

  test('sessions older than the charts count only in the totals', () {
    final s = _stats([_s(_today.addDays(-100), 45)]);
    expect(s.minutesPerDay, List.filled(7, 0));
    expect(s.minutesPerWeek, List.filled(8, 0));
    expect(s.longestMinutes, 45);
  });
}
