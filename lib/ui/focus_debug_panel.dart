import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focus_town/app/focus_controller.dart';
import 'package:focus_town/app/focus_state.dart';
import 'package:focus_town/app/placement.dart';
import 'package:focus_town/app/providers.dart';
import 'package:focus_town/domain/building_tier.dart';
import 'package:focus_town/domain/local_date.dart';
import 'package:focus_town/domain/progression.dart';
import 'package:focus_town/domain/session_engine.dart';
import 'package:focus_town/domain/time_stamp.dart';
import 'package:focus_town/domain/town.dart';
import 'package:focus_town/domain/town_rules.dart';

/// Debug panel that drives the real controller, database and clock.
class FocusDebugPanel extends ConsumerStatefulWidget {
  /// Creates the panel; [minutes] is the planned length used by Start.
  const new({required this.minutes, super.key});

  /// Planned session length, from the debug slider.
  final int minutes;

  @override
  ConsumerState<FocusDebugPanel> createState() => _FocusDebugPanelState();
}

class _FocusDebugPanelState extends ConsumerState<FocusDebugPanel> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Refreshes the display every second and ticks only while a session runs.
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {});
      if (ref.read(focusControllerProvider).value?.active != null) {
        unawaited(ref.read(focusControllerProvider.notifier).tick());
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  FocusController get _controller => ref.read(focusControllerProvider.notifier);

  void _showResult(SessionResult r) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Session ${r.outcome.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tier: ${r.tier.name}'),
              Text('Workers lost: ${r.workersLost}'),
              Text('Workers gained: ${r.workersGained}'),
              Text('New streak: ${r.newStreak}'),
              Text('Plot granted: ${r.plotGranted}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      _controller.clearResult();
    });
  }

  String? _blockedReason(TownState town) {
    if (TownRules.canStart(town, widget.minutes)) return null;
    if (town.inRecoveryMode) return 'Recovery mode: huts only';
    final need = BuildingTier.forMinutes(widget.minutes).workersAtRisk;
    return 'Needs $need workers, you have ${town.workers}';
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(focusControllerProvider, (prev, next) {
      final result = next.value?.lastResult;
      if (result != null && result != prev?.value?.lastResult) {
        _showResult(result);
      }
    });
    final focus = ref.watch(focusControllerProvider);
    return focus.when(
      loading: () => const Text('Loading...'),
      error: (e, _) => Text('Error: $e'),
      data: _content,
    );
  }

  Widget _content(FocusState focus) {
    final town = focus.town;
    final s = focus.active;
    final clock = ref.watch(clockProvider);
    final percent = s == null
        ? 0
        : (SessionEngine.progress(s, TimeStamp.now(clock)) * 100).round();
    final blocked = _blockedReason(town);
    final streak = Progression.currentStreak(
      town,
      LocalDate.fromDateTime(clock.nowWall()),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Session controller'),
        Wrap(
          spacing: 8,
          children: [
            FilledButton(
              onPressed: blocked == null && s == null
                  ? () => unawaited(_controller.start(widget.minutes))
                  : null,
              child: const Text('Start'),
            ),
            FilledButton(
              onPressed: blocked == null && s == null
                  ? () {
                      ref
                          .read(placementProvider.notifier)
                          .begin(widget.minutes);
                      Navigator.of(context).maybePop();
                    }
                  : null,
              child: const Text('Place…'),
            ),
            FilledButton(
              onPressed: () => unawaited(_controller.onBackgroundedUnlocked()),
              child: const Text('Leave'),
            ),
            FilledButton(
              onPressed: () => unawaited(_controller.onForegrounded()),
              child: const Text('Return'),
            ),
            FilledButton(
              onPressed: () => unawaited(_controller.onLocked()),
              child: const Text('Lock'),
            ),
            FilledButton(
              onPressed: () => unawaited(_controller.abandon()),
              child: const Text('Abandon'),
            ),
          ],
        ),
        if (blocked != null) Text(blocked),
        Text('State: ${s?.state.name ?? '-'}'),
        if (s != null) Text('Planned: ${s.plannedMinutes} min'),
        Text('Progress: $percent%'),
        Text('Pass used: ${s?.passUsed ?? false}'),
        Text('XP: ${town.xp}'),
        Text('Streak: $streak'),
        Text('Level: ${Progression.levelFor(town.xp).name}'),
        Text(
          'Level progress: '
          '${(Progression.progressToNext(town.xp) * 100).round()}%',
        ),
        Text('Workers: ${town.workers}'),
        Text('Plots: ${town.buildings.length}/${town.plotsUnlocked}'),
        Text('Queue: ${town.queue.length}'),
        Text('Recovery: ${town.inRecoveryMode}'),
        for (final b in town.buildings)
          Text('${b.tier.name} ${b.status.name} plot ${b.plotIndex}'),
      ],
    );
  }
}
