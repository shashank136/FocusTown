import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focus_town/app/providers.dart';
import 'package:focus_town/domain/building_tier.dart';
import 'package:focus_town/domain/elapsed.dart';
import 'package:focus_town/domain/time_stamp.dart';
import 'package:focus_town/ui/session_simulator_panel.dart';

/// Developer screen showing live wall time and uptime.
class DebugScreen extends ConsumerStatefulWidget {
  /// Creates the debug screen.
  const new({super.key});

  @override
  ConsumerState<DebugScreen> createState() => _DebugScreenState();
}

class _DebugScreenState extends ConsumerState<DebugScreen> {
  static final List<int> _durations = BuildingTier.validDurations();
  late final TimeStamp _start;
  Timer? _timer;
  int _minutes = 25;

  @override
  void initState() {
    super.initState();
    _start = TimeStamp.now(ref.read(clockProvider));
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  static String _hms(Duration d) {
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '${d.inHours}:$m:$s';
  }

  static String _ms(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final clock = ref.watch(clockProvider);
    final now = TimeStamp.now(clock);
    final tampered = wallClockTampered(_start, now);
    final tier = BuildingTier.forMinutes(_minutes);
    return Scaffold(
      appBar: AppBar(title: const Text('Focus Town debug')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Wall: ${clock.nowWall().toIso8601String()}'),
            Text('Uptime: ${_hms(clock.uptime())}'),
            Text('Elapsed since start: ${_ms(elapsedBetween(_start, now))}'),
            Text('Clock tampered: ${tampered ? 'yes' : 'no'}'),
            Slider(
              value: _durations.indexOf(_minutes).toDouble(),
              max: (_durations.length - 1).toDouble(),
              divisions: _durations.length - 1,
              onChanged: (v) =>
                  setState(() => _minutes = _durations[v.round()]),
            ),
            Text('Minutes: $_minutes'),
            Text('Tier: ${tier.name}'),
            Text('Workers at risk: ${tier.workersAtRisk}'),
            SessionSimulatorPanel(minutes: _minutes),
            const _StoredTownCard(),
          ],
        ),
      ),
    );
  }
}

/// What the database holds, loaded once through [storedTownProvider].
class _StoredTownCard extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stored = ref.watch(storedTownProvider);
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Stored town'),
          ...stored.when(
            data: (t) => [
              Text('Stored workers: ${t.workers}'),
              Text('Stored plots unlocked: ${t.plotsUnlocked}'),
              Text('Stored XP: ${t.xp}'),
              Text('Stored streak: ${t.streakCount}'),
              Text('Stored buildings: ${t.buildings.length + t.queue.length}'),
            ],
            loading: () => [const Text('Loading...')],
            error: (e, _) => [Text('Error: $e')],
          ),
        ],
      ),
    );
  }
}
