import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focus_town/app/providers.dart';
import 'package:focus_town/domain/session_engine.dart';
import 'package:focus_town/domain/time_stamp.dart';
import 'package:focus_town/game/world/plot_layout.dart';

/// Debug card showing how many blocks the real town is made of.
class WorldStatsCard extends ConsumerWidget {
  /// Creates the card.
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final focus = ref.watch(focusControllerProvider).value;
    if (focus == null) return const Text('World: loading...');
    final active = focus.active;
    final clock = ref.watch(clockProvider);
    final stage = activeStage(
      active,
      active == null ? 0 : SessionEngine.progress(active, TimeStamp.now(clock)),
    );
    final key = (town: focus.town, active: active, stage: stage);
    final world = ref.watch(townWorldProvider(key));
    final visible = ref.watch(visibleBlocksProvider(key)).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('World: ${world.blockCount} blocks, $visible visible'),
        for (final b in focus.town.buildings)
          Text(
            '${b.tier.name} ${b.status.name} plot ${b.plotIndex}: '
            '${_blocksInPlot(
              world.blocks,
              plotFor(b.plotIndex, focus.town.parcels),
            )} blocks',
          ),
      ],
    );
  }

  // Blocks above the ground inside the plot's footprint.
  static int _blocksInPlot(
    Iterable<({int x, int y, int z, Object material})> blocks,
    Plot p,
  ) => blocks
      .where(
        (b) =>
            b.z >= 1 &&
            b.x >= p.originX &&
            b.x < p.originX + p.size &&
            b.y >= p.originY &&
            b.y < p.originY + p.size,
      )
      .length;
}
