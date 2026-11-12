import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/app/providers.dart';
import 'package:focus_town/domain/building_tier.dart';
import 'package:focus_town/domain/focus_stats.dart';
import 'package:focus_town/domain/local_date.dart';
import 'package:focus_town/domain/session.dart';
import 'package:focus_town/domain/testing/fake_clock.dart';
import 'package:focus_town/domain/time_stamp.dart';
import 'package:focus_town/ui/focus_trends_screen.dart';

// Wednesday.
const _today = LocalDate(2026, 11, 11);

Session _s(
  LocalDate day,
  int minutes, {
  SessionState state = SessionState.completed,
}) => Session(
  id: '${day.toIso()}-$minutes-${state.name}',
  plannedMinutes: minutes,
  tier: BuildingTier.hut,
  workersAssigned: 1,
  state: state,
  startedAt: TimeStamp(
    DateTime(day.year, day.month, day.day, 10),
    Duration.zero,
  ),
);

Future<void> _open(WidgetTester tester, List<Session> sessions) async {
  // Tall, so the lazy list builds every row.
  await tester.binding.setSurfaceSize(const Size(400, 1200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        clockProvider.overrideWithValue(
          FakeClock(start: DateTime(2026, 11, 11, 9)),
        ),
        focusStatsProvider.overrideWith(
          (ref) => FocusStats.from(sessions, _today),
        ),
      ],
      child: const MaterialApp(home: FocusTrendsScreen()),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('before the first session it says what to do', (tester) async {
    await _open(tester, []);
    expect(find.text('Your focus'), findsOneWidget);
    expect(find.textContaining('first session'), findsOneWidget);
    expect(find.text('Current streak'), findsNothing);
  });

  testWidgets('shows the numbers of a seeded history', (tester) async {
    await _open(tester, [
      _s(_today, 40),
      _s(_today.addDays(-1), 20),
      _s(_today, 10, state: SessionState.failed),
    ]);
    expect(find.text('2 days'), findsNWidgets(2)); // current and longest streak
    expect(find.text('67%'), findsOneWidget); // completion rate
    expect(find.text('30 min'), findsOneWidget); // average
    expect(find.text('40 min'), findsOneWidget); // longest
  });

  testWidgets('the sentence says more', (tester) async {
    await _open(tester, [_s(_today, 60), _s(_today.addDays(-7), 50)]);
    expect(find.textContaining('20% more'), findsOneWidget);
  });

  testWidgets('the sentence says less', (tester) async {
    await _open(tester, [_s(_today, 40), _s(_today.addDays(-7), 50)]);
    expect(find.textContaining('20% less'), findsOneWidget);
  });

  testWidgets('the sentence waits when there is nothing to compare', (
    tester,
  ) async {
    await _open(tester, [_s(_today, 40)]);
    expect(find.textContaining('compare'), findsOneWidget);
  });

  testWidgets('every bar has a label a screen reader can read', (tester) async {
    await _open(tester, [_s(_today, 25)]);
    expect(find.bySemanticsLabel('Wednesday: 25 minutes'), findsOneWidget);
    expect(find.bySemanticsLabel('Tuesday: 0 minutes'), findsOneWidget);
    expect(find.bySemanticsLabel('Week of 9/11: 25 minutes'), findsOneWidget);
  });
}
