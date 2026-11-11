import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/domain/building_tier.dart';
import 'package:focus_town/domain/town.dart';
import 'package:focus_town/game/render/worker_painter.dart';
import 'package:focus_town/game/town_renderer.dart';
import 'package:focus_town/game/workers/worker_layout.dart';
import 'package:focus_town/game/workers/worker_model.dart';
import 'package:focus_town/game/world/block_material.dart';
import 'package:focus_town/game/world/plot_layout.dart';

const _size = ui.Size(400, 700);

Future<List<int>> _pixels(WidgetTester t, TownRenderer r) async {
  final img = await t.runAsync(() {
    final rec = ui.PictureRecorder();
    r.paint(ui.Canvas(rec), _size);
    return rec.endRecording().toImage(400, 700);
  });
  final d = await t.runAsync(img!.toByteData);
  return d!.buffer.asUint8List().toList();
}

void main() {
  // Zoomed in, a walking worker used to disturb pixels far from itself: the
  // blocks repainted over it blended their anti-aliased edges a second time.
  for (final tile in [12.0, 24.0, 40.0]) {
    for (final (dx, dy) in [(1.0, 6.5), (6.5, 2.0), (3.0, 3.0)]) {
      testWidgets(
        'worker at ($dx, $dy), tile $tile, changes only its own area',
        (tester) async {
          final initial = TownState.initial();
          final town = initial.copyWith(
            buildings: [
              ...initial.buildings,
              const TownBuilding(
                id: 'h',
                tier: BuildingTier.house,
                status: BuildingStatus.complete,
                plotIndex: 1,
              ),
            ],
          );
          final plot = kPlots[1];
          final r = TownRenderer()
            ..setTown(town)
            ..paint(ui.Canvas(ui.PictureRecorder()), _size)
            ..camera!.setPose(plot.center, tile);
          final base = await _pixels(tester, r);
          final worker = PlacedWorker(
            Worker(
              x: plot.originX + dx,
              y: plot.originY + dy,
              shirt: FlatColor.of(WorkerColors.shirt),
            ),
            Pose.walk1,
          );
          r.setWorkers([worker]);
          final withWorker = await _pixels(tester, r);
          final bounds = workerScreenBounds(
            worker,
            tile: r.camera!.tile,
            origin: r.camera!.origin,
          ).inflate(2);
          var outside = 0;
          for (var i = 0; i < base.length; i += 4) {
            final differs =
                base[i] != withWorker[i] ||
                base[i + 1] != withWorker[i + 1] ||
                base[i + 2] != withWorker[i + 2];
            if (!differs) continue;
            final q = i ~/ 4;
            if (!bounds.contains(
              ui.Offset((q % 400) + 0.5, (q ~/ 400) + 0.5),
            )) {
              outside++;
            }
          }
          expect(outside, 0);
        },
      );
    }
  }
}
