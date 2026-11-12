import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focus_town/app/providers.dart';
import 'package:focus_town/domain/elapsed.dart';
import 'package:focus_town/domain/local_date.dart';
import 'package:focus_town/domain/session.dart';
import 'package:focus_town/domain/session_engine.dart';
import 'package:focus_town/domain/time_stamp.dart';

/// The in-session view: countdown, tier, progress, a hint for the first few
/// sessions, and Abandon. Shows nothing without an active session.
class SessionPanel extends ConsumerStatefulWidget {
  /// Creates the panel.
  const new({super.key});

  @override
  ConsumerState<SessionPanel> createState() => _SessionPanelState();
}

class _SessionPanelState extends ConsumerState<SessionPanel> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // The time comes from the clock; this only asks for a redraw each second.
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(
      focusControllerProvider.select((f) => f.value?.active),
    );
    if (session == null) return const SizedBox.shrink();
    final now = TimeStamp.now(ref.watch(clockProvider));
    final left = session.planned - elapsedBetween(session.startedAt, now);
    final shown = left.isNegative ? Duration.zero : left;
    final progress = SessionEngine.progress(session, now);
    final count = ref.watch(sessionCountProvider).value ?? 99;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              container: true,
              label:
                  'Time left, ${shown.inMinutes} minutes '
                  '${shown.inSeconds.remainder(60)} seconds',
              excludeSemantics: true,
              child: Text(
                _format(shown),
                style: Theme.of(context).textTheme.displayMedium,
              ),
            ),
            Text(session.tier.name),
            const SizedBox(height: 8),
            Semantics(
              container: true,
              label: 'Build progress, ${(progress * 100).round()} percent',
              excludeSemantics: true,
              child: LinearProgressIndicator(value: progress),
            ),
            if (count <= 3) ...[
              const SizedBox(height: 8),
              const Text('Lock your phone and put it face down.'),
            ],
            if (!session.isRepair && !session.isLand && !session.emergencyUsed)
              _pauseControl(session),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => unawaited(_confirmAbandon(session)),
              child: const Text('Abandon', semanticsLabel: 'Abandon build'),
            ),
          ],
        ),
      ),
    );
  }

  // The weekly emergency pause: arm it before leaving.
  Widget _pauseControl(Session session) {
    final town = ref.watch(focusControllerProvider).value!.town;
    if (session.emergencyArmed) {
      return const Padding(
        padding: EdgeInsets.only(top: 8),
        child: Text('Emergency pause on: you may be away up to 10 minutes.'),
      );
    }
    final available = town.emergencyPauses > 0;
    final week = town.emergencyWeek;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          OutlinedButton(
            onPressed: available
                ? () => unawaited(
                    ref
                        .read(focusControllerProvider.notifier)
                        .armEmergencyPause(),
                  )
                : null,
            child: const Text('Emergency pause'),
          ),
          if (!available && week != null)
            Text('Next pause on ${_day(week.addDays(7))}'),
        ],
      ),
    );
  }

  Future<void> _confirmAbandon(Session session) async {
    final n = session.workersAssigned;
    final body = switch (n) {
      0 => 'The site becomes a ruin.',
      1 => 'Your builder will stop and the site becomes a ruin.',
      _ => 'Your $n builders will stop and the site becomes a ruin.',
    };
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Abandon this build?'),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep focusing'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Abandon'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      await ref.read(focusControllerProvider.notifier).abandon();
    }
  }
}

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String _day(LocalDate d) {
  final weekday = DateTime.utc(d.year, d.month, d.day).weekday;
  return '${_weekdays[weekday - 1]} ${d.day} ${_months[d.month - 1]}';
}

String _format(Duration d) {
  String two(int n) => n.toString().padLeft(2, '0');
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60);
  return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
}
