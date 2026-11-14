import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/app/focus_state.dart';
import 'package:focus_town/domain/district.dart';
import 'package:focus_town/domain/session_engine.dart';
import 'package:focus_town/domain/testing/fake_clock.dart';
import 'package:focus_town/domain/time_stamp.dart';
import 'package:focus_town/domain/town.dart';
import 'package:focus_town/domain/town_rules.dart';
import 'package:focus_town/game/town_game.dart';
import 'package:focus_town/game/town_renderer.dart';
import 'package:focus_town/game/world/town_world_builder.dart';
import 'package:focus_town/game/world/voxel_world.dart';

const _size = ui.Size(400, 700);

Set<(int, int, int, Object)> _blocks(Iterable<VisibleBlock> blocks) => {
  for (final b in blocks) (b.x, b.y, b.z, b.material),
};

void main() {
  test('the renderer draws extra land as part of the island', () {
    final town = TownState.initial();
    final rows = districtRow(DistrictSide.east, 0, 0);
    final r = TownRenderer()
      ..setTown(town)
      ..setExtraLand(rows)
      ..paint(ui.Canvas(ui.PictureRecorder()), _size);
    final expected = buildTownWorld(town.copyWith(parcels: rows))
        .sortedVisible();
    expect(_blocks(r.visibleBlocks), _blocks(expected));
    // Nothing changes when the same land is given again, and it goes away.
    final records = r.recordCount;
    r
      ..setExtraLand(rows)
      ..paint(ui.Canvas(ui.PictureRecorder()), _size);
    expect(r.recordCount, records);
    r
      ..setExtraLand(const [])
      ..paint(ui.Canvas(ui.PictureRecorder()), _size);
    expect(
      _blocks(r.visibleBlocks),
      _blocks(buildTownWorld(town).sortedVisible()),
    );
  });

  group('a running district session shows its rows as time passes', () {
    final clock = FakeClock();
    late TownGame game;
    late FocusState focus;

    // A 120-minute district session; the testing aid makes it last 1 minute.
    void start() {
      final town = TownRules.beginDistrict(
        TownState.initial(),
        DistrictSide.north,
      )!;
      final session = SessionEngine.startDistrict(
        id: 'd',
        side: DistrictSide.north,
        minutes: 120,
        now: TimeStamp.now(clock),
      ).copyWith(plannedMinutes: 1);
      focus = FocusState(town: town, active: session);
      game = TownGame(clock: clock)
        ..onGameResize(Vector2(400, 700))
        ..setFocus(focus)
        ..update(0.1)
        ..render(ui.Canvas(ui.PictureRecorder()));
    }

    void frame() => game
      ..update(0.1)
      ..render(ui.Canvas(ui.PictureRecorder()));

    test('nothing at first, a row at half time, two at the end', () {
      start();
      expect(game.renderer.extraLand, isEmpty);
      clock.advance(const Duration(seconds: 29));
      frame();
      expect(game.renderer.extraLand, isEmpty);
      clock.advance(const Duration(seconds: 2)); // 31 of 60 seconds
      frame();
      expect(game.renderer.extraLand, districtRow(DistrictSide.north, 0, 0));
      clock.advance(const Duration(seconds: 29)); // 60 of 60 seconds
      frame();
      expect(game.renderer.extraLand, hasLength(16));
    });

    test('it goes away when the session is over', () {
      start();
      clock.advance(const Duration(seconds: 40));
      frame();
      expect(game.renderer.extraLand, isNotEmpty);
      game
        ..setFocus(FocusState(town: focus.town))
        ..update(0.1);
      expect(game.renderer.extraLand, isEmpty);
    });
  });
}
