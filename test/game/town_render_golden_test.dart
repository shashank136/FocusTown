import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/domain/building_tier.dart';
import 'package:focus_town/domain/town.dart';
import 'package:focus_town/game/effects/particles.dart';
import 'package:focus_town/game/effects/site_transition.dart';
import 'package:focus_town/game/town_game.dart';
import 'package:focus_town/game/town_renderer.dart';
import 'package:focus_town/game/workers/worker_layout.dart';
import 'package:focus_town/game/workers/worker_model.dart';
import 'package:focus_town/game/world/active_site.dart';
import 'package:focus_town/game/world/block_material.dart';
import 'package:focus_town/game/world/plot_layout.dart';

const _size = ui.Size(400, 700);

Future<ui.Image> _render(WidgetTester tester, TownRenderer renderer) async {
  final image = await tester.runAsync(() {
    final recorder = ui.PictureRecorder();
    renderer.paint(ui.Canvas(recorder), _size);
    return recorder.endRecording().toImage(400, 700);
  });
  return image!;
}

Future<List<int>> _bytes(WidgetTester tester, TownRenderer r) async {
  final image = await _render(tester, r);
  final data = await tester.runAsync(image.toByteData);
  return data!.buffer.asUint8List().toList();
}

TownBuilding _b(int plot, BuildingTier t, [BuildingStatus? s]) => TownBuilding(
  id: 'b$plot',
  tier: t,
  status: s ?? BuildingStatus.complete,
  plotIndex: plot,
);

TownState _five() {
  final initial = TownState.initial();
  return initial.copyWith(
    buildings: [
      ...initial.buildings,
      _b(1, BuildingTier.hut),
      _b(2, BuildingTier.workshop),
      _b(3, BuildingTier.tower),
      _b(4, BuildingTier.house, BuildingStatus.ruin),
    ],
  );
}

void main() {
  testWidgets('golden: the initial town', (tester) async {
    final r = TownRenderer()..setTown(TownState.initial());
    final image = await _render(tester, r);
    await expectLater(image, matchesGoldenFile('goldens/town_initial.png'));
  });

  testWidgets('golden: a hut, workshop, tower and ruin added', (tester) async {
    final r = TownRenderer()..setTown(_five());
    final image = await _render(tester, r);
    await expectLater(
      image,
      matchesGoldenFile('goldens/town_five_buildings.png'),
    );
  });

  testWidgets('records once for two paints, again after a new town', (
    tester,
  ) async {
    final r = TownRenderer()..setTown(TownState.initial());
    await _render(tester, r);
    await _render(tester, r);
    expect(r.recordCount, 1);
    r.setTown(_five());
    await _render(tester, r);
    expect(r.recordCount, 2);
  });

  testWidgets('painting before any town only draws the sky', (tester) async {
    final r = TownRenderer();
    await _render(tester, r);
    expect(r.recordCount, 0);
  });

  testWidgets('TownGame forwards the town and renders it', (tester) async {
    final game = TownGame()
      ..onGameResize(Vector2(400, 700))
      ..setTown(TownState.initial());
    await tester.runAsync(() async {
      final recorder = ui.PictureRecorder();
      game.render(ui.Canvas(recorder));
    });
    expect(game.renderer.recordCount, 1);
  });

  testWidgets('workers set on the renderer change the picture', (tester) async {
    final r = TownRenderer()..setTown(TownState.initial());
    final bare = await _bytes(tester, r);
    r.setWorkers([
      PlacedWorker(
        Worker(x: 31.6, y: 20, shirt: FlatColor.of(WorkerColors.shirt)),
        Pose.walk1,
      ),
      PlacedWorker(
        Worker(x: 27, y: 33, shirt: FlatColor.of(WorkerColors.vest)),
        Pose.hammerUp,
      ),
    ]);
    final withWorkers = await _bytes(tester, r);
    expect(withWorkers, isNot(bare));
    expect(r.recordCount, 1); // workers never re-record the static layer
    r.setWorkers(const []);
    expect(await _bytes(tester, r), bare);
  });

  testWidgets('golden: a house at stage 4 with 3 builders', (tester) async {
    final town = TownState.initial().copyWith(workers: 5);
    final r = TownRenderer()
      ..setTown(town)
      ..setSite(const ActiveSite(BuildingTier.house, 4))
      ..setWorkers(siteWorkers(kPlots[1], BuildingTier.house, 3, 0))
      ..paint(ui.Canvas(ui.PictureRecorder()), _size)
      ..camera!.setPose(kPlots[1].center, 26);
    final image = await _render(tester, r);
    await expectLater(
      image,
      matchesGoldenFile('goldens/town_mid_construction.png'),
    );
  });

  testWidgets('golden: a ruin with dead workers and smoke', (tester) async {
    final initial = TownState.initial().copyWith(workers: 5);
    final smoke = ParticleSystem(1)
      ..burst(
        (kPlots[1].center.x, kPlots[1].center.y, 2),
        const [0xFF4a4038],
        25,
        life: 1.5,
        speed: 0.4,
      )
      ..step(const Duration(milliseconds: 500));
    final r = TownRenderer()
      ..setTown(
        initial.copyWith(
          buildings: [
            ...initial.buildings,
            _b(1, BuildingTier.hut, BuildingStatus.ruin),
          ],
        ),
      )
      ..setWorkers(deadWorkers(siteWorkers(kPlots[1], BuildingTier.hut, 3, 0)))
      ..setParticles(smoke.alive, 1)
      ..paint(ui.Canvas(ui.PictureRecorder()), _size)
      ..camera!.setPose(kPlots[1].center, 26);
    final image = await _render(tester, r);
    await expectLater(image, matchesGoldenFile('goldens/town_failed_site.png'));
  });
}
