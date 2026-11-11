import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focus_town/app/providers.dart';
import 'package:focus_town/domain/local_date.dart';
import 'package:focus_town/domain/progression.dart';

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
    final placed = town.buildings.length;
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
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Stat(
                  Icons.local_fire_department,
                  'Streak',
                  Text('$streak', key: const ValueKey('hud-streak')),
                ),
                const SizedBox(width: 12),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${level[0].toUpperCase()}${level.substring(1)}',
                      key: const ValueKey('hud-level'),
                    ),
                    SizedBox(
                      width: 72,
                      child: LinearProgressIndicator(
                        key: const ValueKey('hud-bar'),
                        value: Progression.progressToNext(town.xp),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                _Stat(
                  Icons.engineering,
                  'Workers',
                  Text('${town.workers}', key: const ValueKey('hud-workers')),
                ),
                const SizedBox(width: 12),
                _Stat(
                  Icons.grid_view,
                  'Plots',
                  Text(
                    '$placed/${town.plotsUnlocked}',
                    key: const ValueKey('hud-plots'),
                  ),
                ),
                if (town.queue.isNotEmpty) ...[
                  const SizedBox(width: 12),
                  _Stat(
                    Icons.hourglass_bottom,
                    'Waiting for a plot',
                    Text(
                      '${town.queue.length}',
                      key: const ValueKey('hud-queue'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const new(this.icon, this.label, this.value);

  final IconData icon;
  final String label;
  final Widget value;

  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [Icon(icon, size: 18), const SizedBox(width: 4), value],
    ),
  );
}
