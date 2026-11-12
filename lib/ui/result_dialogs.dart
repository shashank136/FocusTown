import 'package:flutter/material.dart';
import 'package:focus_town/app/focus_state.dart';
import 'package:focus_town/domain/session.dart';

String _capital(String s) => '${s[0].toUpperCase()}${s.substring(1)}';

String _plural(int n, String one, String many) => n == 1 ? one : many;

String _awayText(int seconds) =>
    seconds >= 60 ? '${seconds ~/ 60}m ${seconds % 60}s' : '${seconds}s';

/// Tells the user how the session ended; returns when they dismiss it.
/// [growthTip] adds the one-time line about builders; [recoveryFull] chooses
/// the long Last Builder text (the first time) over the short one.
Future<void> showResultDialog(
  BuildContext context,
  SessionResult r, {
  bool growthTip = false,
  bool recoveryFull = true,
}) => showDialog<void>(
  context: context,
  builder: (context) {
    final (title, lines) = switch (r.outcome) {
      _ when r.repair => _repair(r),
      _ when r.land => _land(r),
      SessionOutcome.completed => _completed(r, growthTip),
      SessionOutcome.queued => _queued(r),
      SessionOutcome.failed => _failed(r, recoveryFull),
    };
    return AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final line in lines)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(line.$1, style: line.$2 ? _heading(context) : null),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Continue'),
        ),
      ],
    );
  },
);

TextStyle? _heading(BuildContext context) =>
    Theme.of(context).textTheme.titleSmall;

// A line is (text, isHeading).
(String, List<(String, bool)>) _completed(SessionResult r, bool growthTip) => (
  '${_capital(r.tier.name)} built',
  [
    if (r.workersGained > 0)
      (
        '+${r.workersGained} ${_plural(r.workersGained, 'worker', 'workers')}',
        false,
      ),
    if (r.xpGained > 0) ('+${r.xpGained} XP', false),
    if (r.newStreak > 0)
      ('Streak: ${r.newStreak} ${_plural(r.newStreak, 'day', 'days')}', false),
    if (r.leveledUpTo != null)
      ('Your town is now a ${_capital(r.leveledUpTo!.name)}', true),
    if (r.recoveryEnded) ('Your town is back on its feet.', true),
    if (growthTip) ('Huts and houses add builders to your town.', false),
  ],
);

(String, List<(String, bool)>) _repair(SessionResult r) =>
    r.outcome == SessionOutcome.completed
    ? (
        'Ruin cleared',
        [
          ('This plot is free again: build something new here.', true),
          if (r.xpGained > 0) ('+${r.xpGained} XP', false),
          if (r.newStreak > 0)
            (
              'Streak: ${r.newStreak} ${_plural(r.newStreak, 'day', 'days')}',
              false,
            ),
          if (r.leveledUpTo != null)
            ('Your town is now a ${_capital(r.leveledUpTo!.name)}', true),
        ],
      )
    : (
        'Repair stopped',
        [
          ('The ruin is still there. Nothing was lost.', false),
          if (r.reason == OutcomeReason.leftTooLong)
            ('You were away for ${_awayText(r.awaySeconds)}', false),
        ],
      );

(String, List<(String, bool)>) _land(SessionResult r) =>
    r.outcome == SessionOutcome.completed
    ? (
        'Land claimed',
        [
          ('Your island has grown.', true),
          if (r.xpGained > 0) ('+${r.xpGained} XP', false),
          if (r.newStreak > 0)
            (
              'Streak: ${r.newStreak} ${_plural(r.newStreak, 'day', 'days')}',
              false,
            ),
          if (r.leveledUpTo != null)
            ('Your town is now a ${_capital(r.leveledUpTo!.name)}', true),
        ],
      )
    : (
        'Land session stopped',
        [
          ('The land is still free. Nothing was lost.', false),
          if (r.reason == OutcomeReason.leftTooLong)
            ('You were away for ${_awayText(r.awaySeconds)}', false),
        ],
      );

(String, List<(String, bool)>) _queued(SessionResult r) => (
  'Ready to place',
  [
    (
      'Your ${r.tier.name} is finished, but there is no free space for it. '
          'Extend your land (Start focus, then Extend land) or repair a ruin, '
          'and it will be placed.',
      false,
    ),
  ],
);

(String, List<(String, bool)>) _failed(SessionResult r, bool full) => (
  r.reason == OutcomeReason.abandoned
      ? 'You abandoned the build'
      : 'Your builders stopped',
  [
    if (r.workersLost > 0)
      (
        'Lost ${r.workersLost} '
            '${_plural(r.workersLost, 'worker', 'workers')}',
        false,
      ),
    if (r.reason == OutcomeReason.leftTooLong)
      ('You were away for ${_awayText(r.awaySeconds)}', false),
    if (r.recoveryStarted && full) ...[
      ('The Last Builder', true),
      (
        'All your builders are gone. A wanderer arrives who cannot be lost. '
            'Build huts (10 to 20 minutes) until you have 3 builders.',
        false,
      ),
    ],
    if (r.recoveryStarted && !full)
      ('Recovery mode again. Build huts to get back to 3 builders.', false),
  ],
);
