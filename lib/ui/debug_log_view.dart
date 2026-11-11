import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focus_town/app/providers.dart';
import 'package:focus_town/domain/local_date.dart';

/// The on-device log, newest line first, with a button that copies it all.
class DebugLogView extends ConsumerWidget {
  /// Creates the view.
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lines = ref.watch(localLogProvider).lines;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Log (${lines.length})'),
            const Spacer(),
            TextButton(
              onPressed: () => unawaited(
                Clipboard.setData(ClipboardData(text: lines.join('\n'))),
              ),
              child: const Text('Copy log'),
            ),
          ],
        ),
        if (lines.isEmpty) const Text('Nothing logged.'),
        for (final line in lines.reversed)
          Text(line, style: const TextStyle(fontSize: 11)),
      ],
    );
  }
}

/// Beta numbers read from the database, for testers.
class BetaStatsCard extends ConsumerWidget {
  /// Creates the card.
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(betaStatsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Beta stats'),
        ...stats.when(
          data: (s) => [
            Text('Sessions started: ${s.sessionsStarted}'),
            Text('Completed: ${s.completed}'),
            Text('Failed: ${s.failed}'),
            Text('Completion rate: ${(s.completionRate * 100).round()}%'),
            Text('Days active: ${s.daysActive}'),
            Text('First open: ${LocalDate.fromDateTime(s.firstOpen).toIso()}'),
            Text('Returned after day 7: ${s.returnedAfterDay7 ? 'yes' : 'no'}'),
          ],
          loading: () => [const Text('Loading...')],
          error: (e, _) => [Text('Error: $e')],
        ),
      ],
    );
  }
}
