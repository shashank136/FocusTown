import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/app/focus_state.dart';
import 'package:focus_town/domain/building_tier.dart';
import 'package:focus_town/domain/session_engine.dart';
import 'package:focus_town/domain/testing/fake_clock.dart';
import 'package:focus_town/domain/time_stamp.dart';
import 'package:focus_town/domain/town.dart';
import 'package:focus_town/game/town_game.dart';
import 'package:focus_town/game/world/building_defs.dart';

// The shortest session of each tier, in minutes.
const Map<BuildingTier, int> _minutes = {
  BuildingTier.hut: 10,
  BuildingTier.house: 25,
  BuildingTier.workshop: 45,
  BuildingTier.tower: 65,
  BuildingTier.castle: 95,
};

class _Rig {
  new(BuildingTier tier, {Duration startUptime = Duration.zero}) {
    clock.advance(startUptime);
    final town = TownState.initial().copyWith(workers: 10);
    final session = SessionEngine.start(
      id: 's',
      minutes: _minutes[tier]!,
      workersAvailable: 10,
      now: TimeStamp.now(clock),
    );
    focus = FocusState(town: town, active: session);
    game = TownGame(clock: clock)
      ..onGameResize(Vector2(400, 700))
      ..setFocus(focus);
    frame();
    this.tier = tier;
  }

  final FakeClock clock = FakeClock();
  late final TownGame game;
  late final FocusState focus;
  late final BuildingTier tier;

  /// One 0.1 s update plus a render (the limiter always allows at this pace).
  void frame() {
    game
      ..update(0.1)
      ..render(ui.Canvas(ui.PictureRecorder()));
  }

  /// Moves the clock to [elapsed] after the start and draws a frame.
  void at(Duration elapsed, Duration from) {
    clock.advance(elapsed - from);
    frame();
  }

  int get stage => game.renderer.site?.stage ?? 0;
}

void main() {
  for (final tier in BuildingTier.values) {
    group('${tier.name} stages follow the clock', () {
      final planned = Duration(minutes: _minutes[tier]!);
      final max = maxStage(tier);

      test('the first stage shows at the start', () {
        final rig = _Rig(tier);
        expect(rig.stage, 1);
        expect(rig.game.renderer.site?.tier, tier);
      });

      test('stage s starts at (s - 1) / max of the planned time', () {
        final rig = _Rig(tier);
        var now = Duration.zero;
        final thresholds = [for (var s = 2; s <= max; s++) s];
        // First and last three thresholds.
        final checked = {
          ...thresholds.take(3),
          ...thresholds.skip(thresholds.length - 3),
        };
        for (final s in thresholds) {
          final start = Duration(
            microseconds: (planned.inMicroseconds * (s - 1) / max).round(),
          );
          if (!checked.contains(s)) continue;
          rig.at(start - const Duration(seconds: 1), now);
          now = start - const Duration(seconds: 1);
          expect(rig.stage, s - 1, reason: 'just before stage $s');
          rig.at(start + const Duration(seconds: 1), now);
          now = start + const Duration(seconds: 1);
          expect(rig.stage, s, reason: 'just after stage $s starts');
        }
      });

      test('the stage never decreases and re-records once per change', () {
        final rig = _Rig(tier);
        var last = rig.stage;
        var changes = 0;
        final records = rig.game.renderer.recordCount;
        final steps = planned.inSeconds ~/ 5;
        for (var i = 1; i <= steps; i++) {
          rig.at(Duration(seconds: i * 5), Duration(seconds: (i - 1) * 5));
          expect(rig.stage, greaterThanOrEqualTo(last));
          if (rig.stage != last) changes++;
          last = rig.stage;
        }
        expect(last, max);
        expect(changes, max - 1);
        expect(rig.game.renderer.recordCount, records + changes);
      });
    });
  }

  test('the stage follows time even while the app was locked', () {
    // Nothing happens in the game while locked; time still passes.
    final rig = _Rig(BuildingTier.house)
      ..at(const Duration(minutes: 12), Duration.zero);
    expect(rig.stage, 4); // 12 / 25 = 0.48 -> 1 + floor(3.36)
  });

  test('a reboot uses the wall clock and never moves the stage back', () {
    final rig = _Rig(BuildingTier.house, startUptime: const Duration(hours: 1))
      ..at(const Duration(minutes: 10), Duration.zero);
    final before = rig.stage;
    rig.clock
      ..simulateReboot()
      ..advance(const Duration(minutes: 5));
    rig.frame();
    expect(rig.stage, greaterThanOrEqualTo(before));
    // 15 minutes of wall time have passed since the start: 15 / 25 = 0.6
    expect(rig.stage, 1 + (0.6 * 7).floor());
  });

  test('no session clears the site', () {
    final rig = _Rig(BuildingTier.hut);
    expect(rig.stage, 1);
    rig.game.setFocus(FocusState(town: rig.focus.town));
    rig.frame();
    expect(rig.game.renderer.site, isNull);
  });
}
