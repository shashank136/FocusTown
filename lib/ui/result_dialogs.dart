import 'package:flutter/material.dart';
import 'package:focus_town/app/focus_state.dart';
import 'package:focus_town/domain/session.dart';

String _capital(String s) => '${s[0].toUpperCase()}${s.substring(1)}';

String _plural(int n, String one, String many) => n == 1 ? one : many;

String _awayText(int seconds) =>
    seconds >= 60 ? '${seconds ~/ 60}m ${seconds % 60}s' : '${seconds}s';

/// Tells the user how the session ended; returns when they dismiss it.
Future<void> showResultDialog(BuildContext context, SessionResult r) =>
    showDialog<void>(
      context: context,
      builder: (context) {
        final (title, lines) = switch (r.outcome) {
          SessionOutcome.completed => _completed(r),
          SessionOutcome.queued => _queued(r),
          SessionOutcome.failed => _failed(r),
        };
        return AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final line in lines)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    line.$1,
                    style: line.$2 ? _heading(context) : null,
                  ),
                ),
            ],
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
(String, List<(String, bool)>) _completed(SessionResult r) => (
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
    if (r.plotGranted) ('New plot unlocked', false),
    if (r.leveledUpTo != null)
      ('Your town is now a ${_capital(r.leveledUpTo!.name)}', true),
    if (r.recoveryEnded) ('Your town is back on its feet.', true),
  ],
);

(String, List<(String, bool)>) _queued(SessionResult r) => (
  'Ready to place',
  [
    (
      'Your ${r.tier.name} is finished, but every plot is taken. It will be '
          'placed when the next plot unlocks.',
      false,
    ),
  ],
);

(String, List<(String, bool)>) _failed(SessionResult r) => (
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
    if (r.recoveryStarted) ...[
      ('The Last Builder', true),
      (
        'All your builders are gone. A wanderer arrives who cannot be lost. '
            'Build huts (10 to 20 minutes) until you have 3 builders.',
        false,
      ),
    ],
  ],
);
