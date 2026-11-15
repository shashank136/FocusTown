import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/app/focus_state.dart';
import 'package:focus_town/domain/town.dart';
import 'package:focus_town/game/town_game.dart';
import 'package:focus_town/game/world/iso.dart';
import 'package:focus_town/game/world/vec2.dart';
import 'package:focus_town/game/world/view_rotation.dart';

const double _quarter = math.pi / 2;

TownGame _game() => TownGame()
  ..onGameResize(Vector2(400, 700))
  ..setFocus(FocusState(town: TownState.initial()))
  ..update(0.1)
  ..render(ui.Canvas(ui.PictureRecorder()));

void _frames(TownGame g, [int n = 30]) {
  for (var i = 0; i < n; i++) {
    g
      ..update(0.05)
      ..render(ui.Canvas(ui.PictureRecorder()));
  }
}

Future<Uint8List> _shot(TownGame g) async {
  final rec = ui.PictureRecorder();
  g.render(ui.Canvas(rec));
  final image = await rec.endRecording().toImage(400, 700);
  return (await image.toByteData())!.buffer.asUint8List();
}

void main() {
  group('the view follows a finger', () {
    test('it is turned part of the way while the finger is down', () {
      final g = _game()..spinBy(0.5);
      expect(g.spin, 0.5);
      expect(g.renderer.rotation, ViewRotation.none);
      g.spinBy(0.2);
      expect(g.spin, closeTo(0.7, 1e-9));
    });

    test('let go past half way it settles on the next side', () {
      final g = _game()
        ..spinBy(0.9)
        ..releaseSpin();
      _frames(g);
      expect(g.renderer.rotation, const ViewRotation(1));
      expect(g.spin, 0);
    });

    test('let go before half way it settles back where it was', () {
      final g = _game()
        ..spinBy(-0.5)
        ..releaseSpin();
      _frames(g);
      expect(g.renderer.rotation, ViewRotation.none);
      expect(g.spin, 0);
    });

    test('a quick flick turns it even if the finger went a short way', () {
      final g = _game()
        ..spinBy(0.3)
        ..releaseSpin(6); // radians per second
      _frames(g);
      expect(g.renderer.rotation, const ViewRotation(1));
    });

    test('it settles slowly, not at once', () {
      final g = _game()
        ..spinBy(0.9)
        ..releaseSpin();
      _frames(g, 2);
      expect(g.spin, inExclusiveRange(0.9, _quarter));
      expect(g.renderer.rotation, ViewRotation.none);
    });

    test('it tells which side it ended on, once', () {
      final seen = <int>[];
      final g = _game()
        ..onTurned = (v) {
          seen.add(v.turns);
        }
        ..spinBy(-0.9)
        ..releaseSpin();
      _frames(g);
      expect(seen, [3]);
    });
  });

  group('the axis is through the middle of the island', () {
    // Where the middle of the island is on the screen.
    Vec2 middle(TownGame g) {
      final cam = g.renderer.camera!;
      final p = g.renderer.spinPivot;
      return project(p.x, p.y, 0, cam.tile, cam.origin);
    }

    test('it stays where it is while the view turns and settles', () {
      // The camera is off to one side and zoomed in, so the middle of the
      // island is not the middle of the screen.
      final g = _game()
        ..onPan(const Vec2(70, -40))
        ..onPinch(const Vec2(200, 350), 1.5);
      final before = middle(g);
      g.spinBy(0.9);
      expect(middle(g), before);
      g.releaseSpin();
      _frames(g);
      expect(g.renderer.rotation, const ViewRotation(1));
      final after = middle(g);
      expect(after.x, closeTo(before.x, 1));
      expect(after.y, closeTo(before.y, 1));
    });

    test('a turn by the buttons keeps it there too, from every side', () {
      final g = _game()..onPan(const Vec2(-50, 30));
      final before = middle(g);
      for (var k = 0; k < 4; k++) {
        g.turn(1);
        _frames(g, 40);
        final now = middle(g);
        expect(now.x, closeTo(before.x, 1), reason: 'turn $k');
        expect(now.y, closeTo(before.y, 1), reason: 'turn $k');
      }
    });
  });

  group('one finger', () {
    test('a sideways glide turns the view, and does not pan', () {
      final g = _game();
      final before = g.renderer.camera!.origin;
      g
        ..onOneFinger(const Vec2(-20, 2))
        ..onOneFinger(const Vec2(-40, 3));
      expect(g.spin, greaterThan(0)); // dragged left: turned the other way
      expect(g.renderer.camera!.origin, before);
    });

    test('a glide to the right turns it the opposite way', () {
      final g = _game()
        ..onOneFinger(const Vec2(30, 0))
        ..onOneFinger(const Vec2(30, 0));
      expect(g.spin, lessThan(0));
    });

    test('a slanting glide turns it too, by its sideways part', () {
      final g = _game();
      final before = g.renderer.camera!.origin;
      g
        ..onOneFinger(const Vec2(-10, 40))
        ..onOneFinger(const Vec2(-10, 40));
      expect(g.spin, closeTo(20 * 0.006, 1e-9));
      expect(g.renderer.camera!.origin, before);
    });

    test('a glide straight up and down leaves the view as it is', () {
      final g = _game();
      final before = g.renderer.camera!.origin;
      g
        ..onOneFinger(const Vec2(0, 50))
        ..endOneFinger();
      _frames(g);
      expect(g.spin, 0);
      expect(g.renderer.rotation, ViewRotation.none);
      expect(g.renderer.camera!.origin, before);
    });

    test('lifting the finger lets the view settle', () {
      final g = _game()
        ..onOneFinger(const Vec2(-150, 0))
        ..onOneFinger(const Vec2(-150, 0))
        ..endOneFinger();
      _frames(g);
      expect(g.renderer.rotation, isNot(ViewRotation.none));
      expect(g.spin, 0);
    });
  });

  group('the buttons and the twist turn it slowly too', () {
    test('a turn goes through the angles in between', () {
      final g = _game()..turn(1);
      expect(g.renderer.rotation, ViewRotation.none);
      g
        ..update(0.1)
        ..render(ui.Canvas(ui.PictureRecorder()));
      expect(g.spin, inExclusiveRange(0, _quarter));
      _frames(g);
      expect(g.renderer.rotation, const ViewRotation(1));
      expect(g.spin, 0);
    });

    test('turns pressed during a turn add up', () {
      final g = _game()
        ..turn(1)
        ..turn(1);
      _frames(g);
      expect(g.renderer.rotation, const ViewRotation(2));
    });

    test('turning back mid-way goes back', () {
      final g = _game()..turn(1);
      _frames(g, 3);
      g.turn(-1);
      _frames(g);
      expect(g.renderer.rotation, ViewRotation.none);
    });

    test('with reduced motion the turn is at once', () {
      final g = _game()
        ..reducedMotion = true
        ..turn(1);
      expect(g.renderer.rotation, const ViewRotation(1));
      expect(g.spin, 0);
    });

    test('a twist of two fingers turns once per gesture', () {
      final g = _game()
        ..onTwist(0.2)
        ..onTwist(0.8)
        ..onTwist(2.5);
      _frames(g);
      expect(g.renderer.rotation, const ViewRotation(1));
      g
        ..endTwist()
        ..onTwist(-0.8);
      _frames(g);
      expect(g.renderer.rotation, ViewRotation.none);
    });
  });

  group('the live view', () {
    // Share of pixels that differ clearly between two pictures.
    double differ(Uint8List a, Uint8List b) {
      var n = 0;
      for (var i = 0; i < a.length; i += 4) {
        if ((a[i] - b[i]).abs() > 48 ||
            (a[i + 1] - b[i + 1]).abs() > 48 ||
            (a[i + 2] - b[i + 2]).abs() > 48) {
          n++;
        }
      }
      return n / (a.length / 4);
    }

    testWidgets('at a quarter turn it looks like the stored view', (
      tester,
    ) async {
      await tester.runAsync(() async {
        for (final k in [0, 1, 2, -1]) {
          final live = _game()..spinBy(k * _quarter);
          // The same quarter turn, let go and settled.
          final done = _game()
            ..spinBy(k * _quarter)
            ..releaseSpin();
          _frames(done);
          final a = await _shot(live..update(0.01));
          final b = await _shot(done..update(0.01));
          expect(differ(a, b), lessThan(0.04), reason: 'turn $k');
        }
      });
    });

    testWidgets('half way it is a picture of the island, not the sky', (
      tester,
    ) async {
      await tester.runAsync(() async {
        final g = _game();
        final rest = await _shot(g..update(0.01));
        final mid = await _shot(_game()..spinBy(_quarter / 2));
        expect(differ(rest, mid), greaterThan(0.01));
        // Some of it is island: green is found well away from the sky.
        var green = 0;
        for (var i = 0; i < mid.length; i += 4) {
          if (mid[i + 1] > mid[i] + 30 && mid[i + 1] > mid[i + 2] + 30) green++;
        }
        expect(green, greaterThan(2000));
      });
    });
  });
}
