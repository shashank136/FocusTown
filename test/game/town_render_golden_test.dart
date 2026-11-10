import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/domain/building_tier.dart';
import 'package:focus_town/domain/town.dart';
import 'package:focus_town/game/town_game.dart';
import 'package:focus_town/game/town_renderer.dart';

const _size = ui.Size(400, 700);

Future<ui.Image> _render(WidgetTester tester, TownRenderer renderer) async {
  final image = await tester.runAsync(() {
    final recorder = ui.PictureRecorder();
    renderer.paint(ui.Canvas(recorder), _size);
    return recorder.endRecording().toImage(400, 700);
  });
  return image!;
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
}
