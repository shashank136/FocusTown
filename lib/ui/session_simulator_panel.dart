import 'package:flutter/material.dart';
import 'package:focus_town/domain/building_tier.dart';
import 'package:focus_town/domain/session.dart';
import 'package:focus_town/domain/session_engine.dart';
import 'package:focus_town/domain/testing/fake_clock.dart';
import 'package:focus_town/domain/time_stamp.dart';
import 'package:focus_town/domain/town.dart';
import 'package:focus_town/domain/town_rules.dart';

/// Debug panel that drives sessions and a town with its own fake clock.
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
  TownState _town = TownState.initial();
  int _counter = 0;

  TimeStamp get _now => TimeStamp.now(_clock);

  // Stores [next]; the town changes once, when a session first finishes.
  void _set(Session next) {
    if (next.isFinished && !(_session?.isFinished ?? false)) {
      _town = next.state == SessionState.completed
          ? TownRules.applyCompleted(_town, next)
          : TownRules.applyFailed(_town, next);
    }
    _session = next;
  }

  // Applies [event] to the live session, then resolves it.
  void _act(Session Function(Session s) event) {
    final s = _session;
    if (s == null) return;
    setState(() => _set(SessionEngine.resolve(event(s), _now)));
  }

  void _start() => setState(() {
    _counter++;
    _set(
      SessionEngine.resolve(
        SessionEngine.start(
          id: 'sim$_counter',
          minutes: widget.minutes,
          workersAvailable: _town.workers,
          now: _now,
          recovery: _town.inRecoveryMode,
        ),
        _now,
      ),
    );
  });

  String? _blockedReason() {
    if (TownRules.canStart(_town, widget.minutes)) return null;
    if (_town.inRecoveryMode) return 'Recovery mode: huts only';
    final need = BuildingTier.forMinutes(widget.minutes).workersAtRisk;
    return 'Needs $need workers, you have ${_town.workers}';
  }

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
    final blocked = _blockedReason();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Session simulator'),
        Wrap(
          spacing: 8,
          children: [
            FilledButton(
              onPressed: blocked == null ? _start : null,
              child: const Text('Start'),
            ),
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
        if (blocked != null) Text(blocked),
        Text('State: ${s?.state.name ?? '-'}'),
        Text('Progress: $percent%'),
        Text('Pass used: ${s?.passUsed ?? false}'),
        Text('Outcome: ${s?.outcomeReason?.name ?? '-'}'),
        Text('Workers: ${_town.workers}'),
        Text('Plots: ${_town.buildings.length}/${_town.plotsUnlocked}'),
        Text('Queue: ${_town.queue.length}'),
        Text('Recovery: ${_town.inRecoveryMode}'),
        for (final b in _town.buildings)
          Text('${b.tier.name} ${b.status.name} plot ${b.plotIndex}'),
      ],
    );
  }
}
