import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focus_town/app/providers.dart';
import 'package:focus_town/domain/elapsed.dart';
import 'package:focus_town/domain/time_stamp.dart';
import 'package:focus_town/ui/event_log_panel.dart';
import 'package:focus_town/ui/focus_debug_panel.dart';
import 'package:focus_town/ui/world_stats_card.dart';

/// Developer screen showing live wall time and uptime.
class DebugScreen extends ConsumerStatefulWidget {
  /// Creates the debug screen.
  const new({super.key});

  @override
  ConsumerState<DebugScreen> createState() => _DebugScreenState();
}

class _DebugScreenState extends ConsumerState<DebugScreen> {
  late final TimeStamp _start;
  Timer? _timer;
  bool _notificationsGranted = false;

  @override
  void initState() {
    super.initState();
    _start = TimeStamp.now(ref.read(clockProvider));
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
    unawaited(_refreshPermission());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refreshPermission() async {
    final granted = await ref.read(notifierProvider).hasPermission();
    if (mounted) setState(() => _notificationsGranted = granted);
  }

  Future<void> _requestPermission() async {
    await ref.read(notifierProvider).requestPermission();
    await _refreshPermission();
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
            const FocusDebugPanel(),
            const WorldStatsCard(),
            ValueListenableBuilder<double>(
              valueListenable: ref.watch(fpsProvider),
              builder: (_, fps, _) => Text('FPS: ${fps.round()}'),
            ),
            const _StoredTownCard(),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _requestPermission,
              child: const Text('Request notification permission'),
            ),
            Text(
              'Notifications: '
              '${_notificationsGranted ? 'granted' : 'denied'}',
            ),
            const SizedBox(height: 16),
            const EventLogPanel(),
          ],
        ),
      ),
    );
  }
}

/// What the database holds, from the controller state.
class _StoredTownCard extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stored = ref.watch(focusControllerProvider);
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Stored town'),
          ...stored.when(
            data: (f) {
              final t = f.town;
              return [
                Text('Stored workers: ${t.workers}'),
                Text('Stored plots unlocked: ${t.plotsUnlocked}'),
                Text('Stored XP: ${t.xp}'),
                Text('Stored streak: ${t.streakCount}'),
                Text(
                  'Stored buildings: ${t.buildings.length + t.queue.length}',
                ),
              ];
            },
            loading: () => [const Text('Loading...')],
            error: (e, _) => [Text('Error: $e')],
          ),
        ],
      ),
    );
  }
}
