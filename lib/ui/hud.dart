import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focus_town/app/providers.dart';
import 'package:focus_town/domain/local_date.dart';
import 'package:focus_town/domain/progression.dart';
import 'package:focus_town/domain/town_rules.dart';
import 'package:focus_town/ui/debug_screen.dart';
import 'package:focus_town/ui/focus_trends_screen.dart';

/// Streak, town level with progress, workers, plots and the queue badge.
class Hud extends ConsumerWidget {
  /// Creates the HUD.
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final town = ref.watch(focusControllerProvider).value?.town;
    if (town == null) return const SizedBox.shrink();
    final today = LocalDate.fromDateTime(ref.watch(clockProvider).nowWall());
    final streak = Progression.currentStreak(town, today);
    final level = Progression.levelFor(town.xp).name;
    final placed = TownRules.occupied(town).length;
    return Material(
      color: Colors.black38,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: DefaultTextStyle.merge(
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
          child: IconTheme.merge(
            data: const IconThemeData(color: Colors.white),
            // Large text shrinks the bar instead of overflowing it.
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // The streak opens "Your focus".
                  _OpenFocus(
                    label: 'Streak, $streak ${streak == 1 ? 'day' : 'days'}',
                    child: Text('$streak', key: const ValueKey('hud-streak')),
                  ),
                  const SizedBox(width: 12),
                  _LevelBadge(
                    level: '${level[0].toUpperCase()}${level.substring(1)}',
                    progress: Progression.progressToNext(town.xp),
                  ),
                  const SizedBox(width: 12),
                  _Stat(
                    Icons.engineering,
                    'Workers, ${town.workers}',
                    Text('${town.workers}', key: const ValueKey('hud-workers')),
                  ),
                  const SizedBox(width: 12),
                  _Stat(
                    Icons.grid_view,
                    'Plots, $placed of ${TownRules.plotCountOf(town)} used',
                    Text(
                      '$placed/${TownRules.plotCountOf(town)}',
                      key: const ValueKey('hud-plots'),
                    ),
                  ),
                  if (town.queue.isNotEmpty) ...[
                    const SizedBox(width: 12),
                    _QueueNote(town.queue.length),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "N waiting": finished buildings that have no free space yet. Tapping it
/// says why and what to do.
class _QueueNote extends StatelessWidget {
  const new(this.count);

  final int count;

  void _explain(BuildContext context) => unawaited(
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Waiting for space'),
        content: Text(
          '$count finished ${count == 1 ? 'building has' : 'buildings have'} '
          'no free space yet. Extend your land (Start focus, then Extend '
          'land) or repair a ruin, and ${count == 1 ? 'it is' : 'they are'} '
          'placed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '$count ${count == 1 ? 'building' : 'buildings'} waiting for space',
    onTap: () => _explain(context),
    excludeSemantics: true,
    child: InkWell(
      onTap: () => _explain(context),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.hourglass_bottom, size: 18),
          const SizedBox(width: 4),
          Text('$count waiting', key: const ValueKey('hud-queue')),
        ],
      ),
    ),
  );
}

/// The streak flame and number as a button that opens "Your focus".
class _OpenFocus extends StatelessWidget {
  const new({required this.label, required this.child});

  final String label;
  final Widget child;

  void _open(BuildContext context) => Navigator.of(context)
      .push(MaterialPageRoute<void>(builder: (_) => const FocusTrendsScreen()));

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    onTap: () => _open(context),
    excludeSemantics: true,
    child: InkWell(
      onTap: () => _open(context),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.local_fire_department, size: 18),
          const SizedBox(width: 4),
          child,
        ],
      ),
    ),
  );
}

class _Stat extends StatelessWidget {
  const new(this.icon, this.label, this.value);

  final IconData icon;
  final String label;
  final Widget value;

  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    excludeSemantics: true,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [Icon(icon, size: 18), const SizedBox(width: 4), value],
    ),
  );
}

/// The town level and its bar. Seven quick taps open the debug screen: the
/// way in for testers on a release build.
class _LevelBadge extends ConsumerStatefulWidget {
  const new({required this.level, required this.progress});

  final String level;
  final double progress;

  @override
  ConsumerState<_LevelBadge> createState() => _LevelBadgeState();
}

class _LevelBadgeState extends ConsumerState<_LevelBadge> {
  static const _taps = 7;
  static const _window = Duration(seconds: 5);
  final List<DateTime> _tapped = [];

  void _tap() {
    final now = ref.read(clockProvider).nowWall();
    _tapped
      ..add(now)
      ..removeWhere((t) => now.difference(t) > _window);
    if (_tapped.length < _taps) return;
    _tapped.clear();
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const DebugScreen()));
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: _tap,
    child: Semantics(
      label:
          'Town level, ${widget.level}, '
          '${(widget.progress * 100).round()} percent to next level',
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.level, key: const ValueKey('hud-level')),
          SizedBox(
            width: 72,
            child: LinearProgressIndicator(
              key: const ValueKey('hud-bar'),
              value: widget.progress,
            ),
          ),
        ],
      ),
    ),
  );
}
