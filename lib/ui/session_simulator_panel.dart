import 'package:flutter/material.dart';
import 'package:focus_town/domain/session.dart';
import 'package:focus_town/domain/session_engine.dart';
import 'package:focus_town/domain/testing/fake_clock.dart';
import 'package:focus_town/domain/time_stamp.dart';

/// Debug panel that drives a session with its own fake clock.
class SessionSimulatorPanel extends StatefulWidget {
  /// Creates the panel; [minutes] is the planned length used by Start.
  const new({required this.minutes, super.key});

  /// Planned session length, from the debug slider.
  final int minutes;

  @override
  State<SessionSimulatorPanel> createState() => _SessionSimulatorPanelState();
}

class _SessionSimulatorPanelState extends State<SessionSimulatorPanel> {
  final FakeClock _clock = FakeClock();
  Session? _session;

  TimeStamp get _now => TimeStamp.now(_clock);

  // Applies [event] to the live session, then resolves it.
  void _act(Session Function(Session s) event) {
    final s = _session;
    if (s == null) return;
    setState(() => _session = SessionEngine.resolve(event(s), _now));
  }

  void _start() => setState(() {
    _session = SessionEngine.resolve(
      SessionEngine.start(
        id: 'sim',
        minutes: widget.minutes,
        workersAvailable: 20,
        now: _now,
      ),
      _now,
    );
  });

  void _advance(Duration d) => _act((s) {
    _clock.advance(d);
    return s;
  });

  void _returnAfter(Duration d) => _act((s) {
    _clock.advance(d);
    return SessionEngine.onForegrounded(s, _now);
  });

  @override
  Widget build(BuildContext context) {
    final s = _session;
    final percent = s == null
        ? 0
        : (SessionEngine.progress(s, _now) * 100).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Session simulator'),
        Wrap(
          spacing: 8,
          children: [
            FilledButton(onPressed: _start, child: const Text('Start')),
            FilledButton(
              onPressed: () => _advance(const Duration(minutes: 1)),
              child: const Text('+1 min'),
            ),
            FilledButton(
              onPressed: () =>
                  _act((s) => SessionEngine.onBackgroundedUnlocked(s, _now)),
              child: const Text('Leave'),
            ),
            for (final n in [5, 30, 90])
              FilledButton(
                onPressed: () => _returnAfter(Duration(seconds: n)),
                child: Text('Return after ${n}s'),
              ),
            FilledButton(
              onPressed: () => _act((s) {
                _clock.advance(const Duration(minutes: 5));
                return SessionEngine.onLocked(s, _now);
              }),
              child: const Text('Lock'),
            ),
            FilledButton(
              onPressed: () => _act((s) => SessionEngine.abandon(s, _now)),
              child: const Text('Abandon'),
            ),
          ],
        ),
        Text('State: ${s?.state.name ?? '-'}'),
        Text('Progress: $percent%'),
        Text('Pass used: ${s?.passUsed ?? false}'),
        Text('Outcome: ${s?.outcomeReason?.name ?? '-'}'),
      ],
    );
  }
}
