import 'package:focus_town/domain/local_date.dart';
import 'package:focus_town/domain/session.dart';
import 'package:focus_town/domain/town_rules.dart';

/// The numbers behind the "Your focus" screen, from finished sessions.
///
/// Focus time is the planned minutes of completed sessions; failed ones add 0
/// but lower the completion rate. A session counts on the day it started
/// (shortcut: one that runs past midnight is not split, fine for a streak).
class FocusStats {
  /// Creates the stats from already counted values.
  const new({
    required this.minutesPerDay,
    required this.minutesPerWeek,
    required this.completionRate,
    required this.averageMinutes,
    required this.longestMinutes,
    required this.currentStreak,
    required this.longestStreak,
    required this.weekChange,
    required this.isEmpty,
  });

  /// Counts the finished [sessions] as of [today]. Sessions dated after today
  /// (a clock set back) are ignored.
  // ignore: unnecessary_type_name_in_constructor, shorthand not valid for factories
  factory FocusStats.from(List<Session> sessions, LocalDate today) {
    final finished = [
      for (final s in sessions)
        if (s.isFinished &&
            LocalDate.fromDateTime(s.startedAt.wall).compareTo(today) <= 0)
          s,
    ];
    final completed = finished
        .where((s) => s.state == SessionState.completed)
        .toList();
    final minutesOn = <LocalDate, int>{};
    for (final s in completed) {
      final day = LocalDate.fromDateTime(s.startedAt.wall);
      minutesOn[day] = (minutesOn[day] ?? 0) + s.plannedMinutes;
    }
    int sumDays(int fromAgo, int toAgo) => [
      for (var i = fromAgo; i >= toAgo; i--) minutesOn[today.addDays(-i)] ?? 0,
    ].fold(0, (a, b) => a + b);

    final thisWeek = TownRules.weekStart(today);
    int weekMinutes(LocalDate start) => minutesOn.entries
        .where((e) => TownRules.weekStart(e.key) == start)
        .fold(0, (a, e) => a + e.value);

    final last7 = sumDays(6, 0);
    final before = sumDays(13, 7);
    final days = minutesOn.keys.toList()..sort();
    var longest = 0;
    var run = 0;
    for (var i = 0; i < days.length; i++) {
      run = i > 0 && days[i - 1].daysBetween(days[i]) == 1 ? run + 1 : 1;
      if (run > longest) longest = run;
    }
    // The streak is alive while today or yesterday has a session.
    var current = 0;
    var day = minutesOn.containsKey(today) ? today : today.addDays(-1);
    while (minutesOn.containsKey(day)) {
      current++;
      day = day.addDays(-1);
    }

    return FocusStats(
      minutesPerDay: [for (var i = 6; i >= 0; i--) sumDays(i, i)],
      minutesPerWeek: [
        for (var i = 7; i >= 0; i--) weekMinutes(thisWeek.addDays(-7 * i)),
      ],
      completionRate: finished.isEmpty ? 0 : completed.length / finished.length,
      averageMinutes: completed.isEmpty
          ? 0
          : completed.fold(0, (a, s) => a + s.plannedMinutes) /
                completed.length,
      longestMinutes: completed.fold(
        0,
        (a, s) => s.plannedMinutes > a ? s.plannedMinutes : a,
      ),
      currentStreak: current,
      longestStreak: longest,
      weekChange: before == 0 ? null : (last7 - before) / before,
      isEmpty: finished.isEmpty,
    );
  }

  /// Focus minutes for each of the last 7 days, oldest first, today last.
  final List<int> minutesPerDay;

  /// Focus minutes for each of the last 8 weeks (Monday start), oldest first,
  /// the current week last.
  final List<int> minutesPerWeek;

  /// Completed sessions out of all finished ones, 0 to 1 (0 with none).
  final double completionRate;

  /// Average planned minutes of a completed session (0 with none).
  final double averageMinutes;

  /// Longest completed session in minutes.
  final int longestMinutes;

  /// Days in a row up to today (or yesterday) with a completed session.
  final int currentStreak;

  /// The longest run of such days ever.
  final int longestStreak;

  /// Last 7 days against the 7 before as a ratio (0.2 is 20% more), or null
  /// when the earlier 7 days have no focus time.
  final double? weekChange;

  /// True when there is no finished session at all.
  final bool isEmpty;
}
