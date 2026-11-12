import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/app/focus_state.dart';
import 'package:focus_town/domain/building_tier.dart';
import 'package:focus_town/domain/progression.dart';
import 'package:focus_town/domain/session.dart';
import 'package:focus_town/ui/result_dialogs.dart';

SessionResult _completed({
  BuildingTier tier = BuildingTier.house,
  int gained = 2,
  int xp = 25,
  int streak = 3,
  TownLevel? level,
  bool recoveryEnded = false,
  SessionOutcome outcome = SessionOutcome.completed,
}) => SessionResult(
  outcome: outcome,
  tier: tier,
  workersLost: 0,
  workersGained: gained,
  newStreak: streak,
  xpGained: xp,
  reason: OutcomeReason.completed,
  leveledUpTo: level,
  recoveryEnded: recoveryEnded,
);

SessionResult _failed({
  OutcomeReason reason = OutcomeReason.leftTooLong,
  int lost = 2,
  int away = 90,
  bool recoveryStarted = false,
}) => SessionResult(
  outcome: SessionOutcome.failed,
  tier: BuildingTier.house,
  workersLost: lost,
  workersGained: 0,
  newStreak: 0,
  awaySeconds: away,
  reason: reason,
  recoveryStarted: recoveryStarted,
);

Future<void> _show(
  WidgetTester tester,
  SessionResult r, {
  bool growthTip = false,
  bool recoveryFull = true,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => showResultDialog(
              context,
              r,
              growthTip: growthTip,
              recoveryFull: recoveryFull,
            ),
            child: const Text('go'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('go'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

Iterable<String> _allText(WidgetTester tester) => [
  for (final t in tester.widgetList<Text>(find.byType(Text)))
    if (t.data != null) t.data!,
];

void main() {
  group('repair', () {
    SessionResult repair({SessionOutcome outcome = SessionOutcome.completed}) =>
        SessionResult(
          outcome: outcome,
          tier: BuildingTier.hut,
          workersLost: 0,
          workersGained: 0,
          newStreak: 2,
          xpGained: outcome == SessionOutcome.completed ? 10 : 0,
          reason: outcome == SessionOutcome.completed
              ? OutcomeReason.completed
              : OutcomeReason.leftTooLong,
          awaySeconds: 90,
          repair: true,
        );

    testWidgets('a cleared ruin shows XP and streak, no workers', (
      tester,
    ) async {
      await _show(tester, repair());
      expect(find.text('Ruin cleared'), findsOneWidget);
      expect(find.text('+10 XP'), findsOneWidget);
      expect(find.text('Streak: 2 days'), findsOneWidget);
      expect(find.textContaining('worker'), findsNothing);
    });

    testWidgets('a lost repair says nothing was lost', (tester) async {
      await _show(tester, repair(outcome: SessionOutcome.failed));
      expect(find.text('Repair stopped'), findsOneWidget);
      expect(
        find.text('The ruin is still there. Nothing was lost.'),
        findsOneWidget,
      );
      expect(find.textContaining('Lost'), findsNothing);
    });
  });

  group('land', () {
    SessionResult land({SessionOutcome outcome = SessionOutcome.completed}) =>
        SessionResult(
          outcome: outcome,
          tier: BuildingTier.hut,
          workersLost: 0,
          workersGained: 0,
          newStreak: 2,
          xpGained: outcome == SessionOutcome.completed ? 25 : 0,
          land: true,
        );

    testWidgets('claimed land says the island grew, with xp and no workers', (
      tester,
    ) async {
      await _show(tester, land());
      expect(find.text('Land claimed'), findsOneWidget);
      expect(find.text('Your island has grown.'), findsOneWidget);
      expect(find.text('+25 XP'), findsOneWidget);
      expect(find.textContaining('worker'), findsNothing);
    });

    testWidgets('a lost land session says nothing was lost', (tester) async {
      await _show(tester, land(outcome: SessionOutcome.failed));
      expect(find.text('Land session stopped'), findsOneWidget);
      expect(
        find.text('The land is still free. Nothing was lost.'),
        findsOneWidget,
      );
    });
  });

  group('completed', () {
    testWidgets('title, gains, xp and streak', (tester) async {
      await _show(tester, _completed());
      expect(find.text('House built'), findsOneWidget);
      expect(find.text('+2 workers'), findsOneWidget);
      expect(find.text('+25 XP'), findsOneWidget);
      expect(find.text('Streak: 3 days'), findsOneWidget);
    });

    testWidgets('a level-up is announced', (tester) async {
      await _show(tester, _completed(level: TownLevel.village));
      expect(find.text('Your town is now a Village'), findsOneWidget);
    });

    testWidgets('ending recovery says the town is back on its feet', (
      tester,
    ) async {
      await _show(
        tester,
        _completed(tier: BuildingTier.hut, gained: 1, recoveryEnded: true),
      );
      expect(find.text('Hut built'), findsOneWidget);
      expect(find.text('+1 worker'), findsOneWidget);
      expect(find.text('Your town is back on its feet.'), findsOneWidget);
    });

    testWidgets('zero lines are hidden', (tester) async {
      await _show(
        tester,
        _completed(tier: BuildingTier.workshop, gained: 0, xp: 0, streak: 0),
      );
      expect(find.textContaining('workers'), findsNothing);
      expect(find.textContaining('XP'), findsNothing);
      expect(find.textContaining('Streak'), findsNothing);
    });

    testWidgets('a streak of 1 is one day', (tester) async {
      await _show(tester, _completed(streak: 1));
      expect(find.text('Streak: 1 day'), findsOneWidget);
    });
  });

  testWidgets('queued: ready to place, with the reason', (tester) async {
    await _show(
      tester,
      _completed(
        tier: BuildingTier.tower,
        gained: 0,
        outcome: SessionOutcome.queued,
      ),
    );
    expect(find.text('Ready to place'), findsOneWidget);
    expect(
      find.text(
        'Your tower is finished, but there is no free space for it. Extend '
        'your land (Start focus, then Extend land) or repair a ruin, and it '
        'will be placed.',
      ),
      findsOneWidget,
    );
  });

  group('failed', () {
    testWidgets('away too long: workers lost and the time away', (
      tester,
    ) async {
      await _show(tester, _failed());
      expect(find.text('Your builders stopped'), findsOneWidget);
      expect(find.text('Lost 2 workers'), findsOneWidget);
      expect(find.text('You were away for 1m 30s'), findsOneWidget);
    });

    testWidgets('abandoned has its own title and no away line', (tester) async {
      await _show(tester, _failed(reason: OutcomeReason.abandoned, away: 0));
      expect(find.text('You abandoned the build'), findsOneWidget);
      expect(find.textContaining('away'), findsNothing);
    });

    testWidgets('one worker lost is singular, none is hidden', (tester) async {
      await _show(tester, _failed(lost: 1));
      expect(find.text('Lost 1 worker'), findsOneWidget);
      await tester.tap(find.text('Continue'));
      await tester.pump(const Duration(milliseconds: 300));
      await _show(tester, _failed(lost: 0));
      expect(find.textContaining('Lost'), findsNothing);
    });

    testWidgets('losing everyone introduces the Last Builder', (tester) async {
      await _show(tester, _failed(recoveryStarted: true));
      expect(find.text('The Last Builder'), findsOneWidget);
      expect(
        find.text(
          'All your builders are gone. A wanderer arrives who cannot be '
          'lost. Build huts (10 to 20 minutes) until you have 3 builders.',
        ),
        findsOneWidget,
      );
    });
  });

  testWidgets('Continue closes the dialog', (tester) async {
    await _show(tester, _completed());
    await tester.tap(find.text('Continue'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('tapping outside also closes it', (tester) async {
    await _show(tester, _completed());
    await tester.tapAt(const Offset(5, 5));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(AlertDialog), findsNothing);
  });

  final emoji = RegExp(
    r'[\u{1F000}-\u{1FAFF}\u{2600}-\u{27BF}]',
    unicode: true,
  );
  for (final (name, result) in [
    ('completed', _completed(level: TownLevel.city)),
    ('queued', _completed(outcome: SessionOutcome.queued)),
    ('failed', _failed(recoveryStarted: true)),
  ]) {
    testWidgets('no emoji in the $name dialog', (tester) async {
      await _show(tester, result);
      for (final text in _allText(tester)) {
        expect(emoji.hasMatch(text), isFalse, reason: text);
      }
    });
  }

  group('tips in the dialogs', () {
    const growth = 'Huts and houses add builders to your town.';
    const full =
        'All your builders are gone. A wanderer arrives who cannot '
        'be lost. Build huts (10 to 20 minutes) until you have 3 builders.';
    const short = 'Recovery mode again. Build huts to get back to 3 builders.';

    testWidgets('the growth line shows only when asked', (tester) async {
      await _show(tester, _completed());
      expect(_allText(tester), isNot(contains(growth)));
    });

    testWidgets('the growth line shows when asked', (tester) async {
      await _show(tester, _completed(), growthTip: true);
      expect(_allText(tester), contains(growth));
    });

    testWidgets('the full Last Builder text the first time', (tester) async {
      await _show(tester, _failed(recoveryStarted: true));
      expect(_allText(tester), contains(full));
      expect(_allText(tester), isNot(contains(short)));
    });

    testWidgets('a short recovery line afterwards', (tester) async {
      await _show(tester, _failed(recoveryStarted: true), recoveryFull: false);
      expect(_allText(tester), contains(short));
      expect(_allText(tester), isNot(contains(full)));
    });
  });
}
