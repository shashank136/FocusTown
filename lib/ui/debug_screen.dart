import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focus_town/app/providers.dart';
import 'package:focus_town/domain/building_tier.dart';

/// Developer screen showing live wall time and uptime.
class DebugScreen extends ConsumerStatefulWidget {
  /// Creates the debug screen.
  const new({super.key});

  @override
  ConsumerState<DebugScreen> createState() => _DebugScreenState();
}

class _DebugScreenState extends ConsumerState<DebugScreen> {
  static final List<int> _durations = BuildingTier.validDurations();
  Timer? _timer;
  int _minutes = 25;

  @override
  void initState() {
    super.initState();
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

  @override
  Widget build(BuildContext context) {
    final clock = ref.watch(clockProvider);
    final tier = BuildingTier.forMinutes(_minutes);
    return Scaffold(
      appBar: AppBar(title: const Text('Focus Town debug')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Wall: ${clock.nowWall().toIso8601String()}'),
            Text('Uptime: ${_hms(clock.uptime())}'),
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
          ],
        ),
      ),
    );
  }
}
