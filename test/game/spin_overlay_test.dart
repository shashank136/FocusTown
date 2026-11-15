import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/app/focus_state.dart';
import 'package:focus_town/domain/district.dart';
import 'package:focus_town/domain/session_engine.dart';
import 'package:focus_town/domain/testing/fake_clock.dart';
import 'package:focus_town/domain/time_stamp.dart';
import 'package:focus_town/domain/town.dart';
import 'package:focus_town/game/effects/particles.dart';
import 'package:focus_town/game/town_game.dart';
import 'package:focus_town/game/town_renderer.dart';
import 'package:focus_town/game/workers/worker_layout.dart';
import 'package:focus_town/game/workers/worker_model.dart';
import 'package:focus_town/game/world/block_material.dart';
import 'package:focus_town/game/world/iso.dart';
import 'package:focus_town/game/world/plot_layout.dart';
import 'package:focus_town/game/world/vec2.dart';

const _w = 400;
const _h = 700;
const _angle = 0.6;

TownRenderer _renderer() {
  final r = TownRenderer()
    ..setTown(TownState.initial())
    ..paint(ui.Canvas(ui.PictureRecorder()), const ui.Size(_w * 1.0, _h * 1.0));
  return r;
}

Future<Uint8List> _shot(TownRenderer r, {double spin = _angle}) async {
  r.setSpin(spin);
  final rec = ui.PictureRecorder();
  r.paint(ui.Canvas(rec), const ui.Size(_w * 1.0, _h * 1.0));
  final image = await rec.endRecording().toImage(_w, _h);
  return (await image.toByteData())!.buffer.asUint8List();
}

// Where the view point ([x], [y], [z]) is on screen once turned by [_angle]
// about the middle of the island.
Vec2 _screen(TownRenderer r, double x, double y, double z) {
  final pivot = r.spinPivot;
  final dx = x - pivot.x;
  final dy = y - pivot.y;
  final c = math.cos(_angle);
  final s = math.sin(_angle);
  final cam = r.camera!;
  return project(
    pivot.x + dx * c - dy * s,
    pivot.y + dx * s + dy * c,
    z,
    cam.tile,
    cam.origin,
  );
}

// How many pixels differ clearly between [a] and [b] inside [box], and outside
// it.
({int inside, int outside}) _differ(Uint8List a, Uint8List b, ui.Rect box) {
  var inside = 0;
  var outside = 0;
  for (var y = 0; y < _h; y++) {
    for (var x = 0; x < _w; x++) {
      final i = (y * _w + x) * 4;
      final d =
          (a[i] - b[i]).abs() +
          (a[i + 1] - b[i + 1]).abs() +
          (a[i + 2] - b[i + 2]).abs();
      if (d < 30) continue;
      if (box.contains(ui.Offset(x.toDouble(), y.toDouble()))) {
        inside++;
      } else {
        outside++;
      }
    }
  }
  return (inside: inside, outside: outside);
}

void main() {
  // A road crossing away from the middle, so nothing hides what is put there.
  const spot = Vec2(31.5, 22.5);

  testWidgets('a worker is drawn while the island turns', (tester) async {
    await tester.runAsync(() async {
      final r = _renderer();
      final without = await _shot(r);
      r.setWorkers([
        PlacedWorker(
          Worker(x: spot.x, y: spot.y, shirt: FlatColor.of(0xFFFF00FF)),
          Pose.idle,
        ),
      ]);
      final withWorker = await _shot(r);
      final at = _screen(r, spot.x, spot.y, 1);
      final t = r.camera!.tile;
      final box = ui.Rect.fromCenter(
        center: ui.Offset(at.x, at.y - 1.5 * t),
        width: 6 * t,
        height: 6 * t,
      );
      final d = _differ(without, withWorker, box);
      expect(d.inside, greaterThan(10));
      expect(d.outside, 0);
    });
  });

  testWidgets('smoke is drawn while the island turns, and fades', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final r = _renderer();
      final without = await _shot(r);
      final puff = Particle(
        x: spot.x,
        y: spot.y,
        z: 2,
        vx: 0,
        vy: 0,
        vz: 0,
        life: 1,
        color: 0xFFFF0000,
      );
      r.setParticles([puff], 1);
      final solid = await _shot(r);
      final at = _screen(r, spot.x, spot.y, 2);
      final t = r.camera!.tile;
      final box = ui.Rect.fromCenter(
        center: ui.Offset(at.x, at.y),
        width: 4 * t,
        height: 4 * t,
      );
      final d = _differ(without, solid, box);
      expect(d.inside, greaterThan(3));
      expect(d.outside, 0);
      // Fully faded away: nothing is left.
      r.setParticles([puff], 0);
      expect(_differ(without, await _shot(r), box).inside, 0);
    });
  });

  testWidgets('plot outlines are drawn while the island turns', (tester) async {
    await tester.runAsync(() async {
      final r = _renderer();
      final without = await _shot(r);
      r.setPlotOverlay({0, 5}, 0);
      final withOutline = await _shot(r);
      // A corner of plot 0, on the ground (the outline is at height 1).
      final corner = _screen(
        r,
        kPlots[0].originX.toDouble(),
        kPlots[0].originY.toDouble(),
        1,
      );
      final box = ui.Rect.fromCenter(
        center: ui.Offset(corner.x, corner.y),
        width: 12,
        height: 12,
      );
      expect(_differ(without, withOutline, box).inside, greaterThan(5));
    });
  });

  testWidgets('the row about to be built is lit up while it turns', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final r = _renderer();
      final without = await _shot(r);
      final row = districtRow(DistrictSide.east, 0, 0);
      r.setRowHighlight(row);
      final lit = await _shot(r);
      // The middle square of the row.
      final mid = row[row.length ~/ 2];
      final at = _screen(
        r,
        parcelOrigin(mid.gx) + kPlotSize / 2,
        parcelOrigin(mid.gy) + kPlotSize / 2,
        1,
      );
      final box = ui.Rect.fromCenter(
        center: ui.Offset(at.x, at.y),
        width: 20,
        height: 20,
      );
      expect(_differ(without, lit, box).inside, greaterThan(50));
    });
  });

  testWidgets('at a quarter turn the workers are where they will be', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final clock = FakeClock();
      final town = TownState.initial().copyWith(workers: 10);
      final session = SessionEngine.start(
        id: 's',
        minutes: 25,
        workersAvailable: 10,
        now: TimeStamp.now(clock),
      );
      TownGame make() {
        final g = TownGame(clock: clock)
          ..onGameResize(Vector2(_w * 1.0, _h * 1.0))
          ..setFocus(FocusState(town: town, active: session));
        for (var i = 0; i < 12; i++) {
          g
            ..update(0.1)
            ..render(ui.Canvas(ui.PictureRecorder()));
        }
        return g;
      }

      Future<Uint8List> shot(TownGame g) async {
        final rec = ui.PictureRecorder();
        g.render(ui.Canvas(rec));
        final image = await rec.endRecording().toImage(_w, _h);
        return (await image.toByteData())!.buffer.asUint8List();
      }

      final live = make()..spinBy(math.pi / 2);
      final done = make()
        ..spinBy(math.pi / 2)
        ..releaseSpin();
      for (var i = 0; i < 30; i++) {
        done
          ..update(0.05)
          ..render(ui.Canvas(ui.PictureRecorder()));
      }
      expect(live.renderer.workers, isNotEmpty);
      final a = await shot(live..update(0.01));
      final b = await shot(done..update(0.01));
      final d = _differ(a, b, ui.Rect.zero);
      // Flat colors against textured faces differ a little everywhere when the
      // town is this close.
      expect(d.outside / (_w * _h), lessThan(0.1));
    });
  });
}
