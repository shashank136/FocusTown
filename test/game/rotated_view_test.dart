import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/app/focus_state.dart';
import 'package:focus_town/domain/town.dart';
import 'package:focus_town/game/effects/particles.dart';
import 'package:focus_town/game/town_game.dart';
import 'package:focus_town/game/town_renderer.dart';
import 'package:focus_town/game/workers/worker_layout.dart';
import 'package:focus_town/game/workers/worker_model.dart';
import 'package:focus_town/game/world/block_material.dart';
import 'package:focus_town/game/world/iso.dart';
import 'package:focus_town/game/world/plot_layout.dart';
import 'package:focus_town/game/world/town_world_builder.dart';
import 'package:focus_town/game/world/vec2.dart';
import 'package:focus_town/game/world/view_rotation.dart';
import 'package:focus_town/game/world/voxel_world.dart';

const _size = ui.Size(400, 700);

void _paint(TownRenderer r) => r.paint(ui.Canvas(ui.PictureRecorder()), _size);

TownGame _game() => TownGame()
  ..onGameResize(Vector2(400, 700))
  ..setFocus(FocusState(town: TownState.initial()))
  ..update(0.1)
  ..render(ui.Canvas(ui.PictureRecorder()));

Set<(int, int, int, Object)> _blocks(Iterable<VisibleBlock> blocks) => {
  for (final b in blocks) (b.x, b.y, b.z, b.material),
};

void main() {
  group('renderer', () {
    test('a turn redraws the town from the new side, once', () {
      final r = TownRenderer()..setTown(TownState.initial());
      _paint(r);
      final records = r.recordCount;
      final count = r.visibleBlockCount;
      r.setRotation(ViewRotation.none.next);
      _paint(r);
      expect(r.recordCount, records + 1);
      _paint(r);
      expect(r.recordCount, records + 1);
      expect(r.rotation, ViewRotation.none.next);
      expect(r.visibleBlockCount, count); // the same blocks, moved
    });

    test('the blocks are the rotated world, in every view', () {
      final town = TownState.initial();
      final r = TownRenderer()..setTown(town);
      for (var k = 0; k < 4; k++) {
        r.setRotation(ViewRotation(k));
        _paint(r);
        final expected = ViewRotation(k)
            .rotateWorld(buildTownWorld(town))
            .sortedVisible();
        expect(_blocks(r.visibleBlocks), _blocks(expected), reason: 'turn $k');
      }
    });

    test('the same turn again changes nothing', () {
      final r = TownRenderer()..setTown(TownState.initial());
      _paint(r);
      final records = r.recordCount;
      r.setRotation(ViewRotation.none);
      _paint(r);
      expect(r.recordCount, records);
    });

    test('workers and their way of facing turn with the view', () {
      final r = TownRenderer()
        ..setRotation(const ViewRotation(1))
        ..setWorkers([
          PlacedWorker(
            Worker(x: 10.5, y: 20.5, shirt: FlatColor.of(WorkerColors.vest)),
            Pose.idle,
          ),
        ]);
      final w = r.workers.single.worker;
      expect((w.x, w.y), (-20.5, 10.5));
      expect(w.facing, (-1, 0)); // it faced +y; +y turns to -x
    });

    test('particles turn with the view', () {
      final r = TownRenderer()
        ..setRotation(const ViewRotation(1))
        ..setParticles([
          Particle(
            x: 10,
            y: 20,
            z: 3,
            vx: 1,
            vy: 2,
            vz: 1,
            life: 1,
            color: 0xFFFFFFFF,
          ),
        ], 1);
      final p = r.particles.single;
      expect((p.x, p.y, p.z), (-20.0, 10.0, 3.0));
      expect((p.vx, p.vy), (-2.0, 1.0));
    });
  });

  group('game', () {
    // Screen point of the middle of plot [i]'s ground, in the current view.
    Vec2 center(TownGame g, int i) {
      final cam = g.renderer.camera!;
      final c = kPlots[i].center;
      final (x, y) = g.renderer.rotation.point(c.x, c.y);
      return project(x, y, 1, cam.tile, cam.origin);
    }

    test('the middle of each plot picks that plot, from all four sides', () {
      final g = _game();
      for (var k = 0; k < 4; k++) {
        for (var i = 0; i < 6; i++) {
          expect(g.plotAtScreen(center(g, i)), i, reason: 'turn $k plot $i');
        }
        g
          ..rotate(1)
          ..update(0.1)
          ..render(ui.Canvas(ui.PictureRecorder()));
      }
      expect(g.renderer.rotation, ViewRotation.none); // four turns round
    });

    test('a turn keeps looking at the same spot of the island', () {
      final g = _game();
      final before = g.renderer.camera!.centerWorld;
      final (wx, wy) = g.renderer.rotation.unpoint(before.x, before.y);
      g.rotate(1);
      final after = g.renderer.camera!.centerWorld;
      final (ax, ay) = g.renderer.rotation.unpoint(after.x, after.y);
      expect(ax, closeTo(wx, 1));
      expect(ay, closeTo(wy, 1));
    });

    test('a turn made before the first frame still frames the island', () {
      final g = TownGame()
        ..onGameResize(Vector2(400, 700))
        ..setFocus(FocusState(town: TownState.initial()))
        ..rotate(2)
        ..update(0.1)
        ..render(ui.Canvas(ui.PictureRecorder()));
      final cam = g.renderer.camera!;
      final (wx, wy) = g.renderer.rotation.unpoint(
        cam.centerWorld.x,
        cam.centerWorld.y,
      );
      // The middle of the starting island is still in the middle of the screen.
      expect(wx, closeTo(32, 12));
      expect(wy, closeTo(32, 12));
    });

    test('a turn made before the first frame still frames the island', () {
      final g = TownGame()
        ..onGameResize(Vector2(400, 700))
        ..setFocus(FocusState(town: TownState.initial()))
        ..rotate(2)
        ..update(0.1)
        ..render(ui.Canvas(ui.PictureRecorder()));
      final cam = g.renderer.camera!;
      final (wx, wy) = g.renderer.rotation.unpoint(
        cam.centerWorld.x,
        cam.centerWorld.y,
      );
      // The middle of the starting island is still in the middle of the screen.
      expect(wx, closeTo(32, 12));
      expect(wy, closeTo(32, 12));
    });

    group('twisting two fingers', () {
      void frames(TownGame g) {
        for (var i = 0; i < 10; i++) {
          g
            ..update(0.05)
            ..render(ui.Canvas(ui.PictureRecorder()));
        }
      }

      test('a small twist while pinching changes nothing', () {
        final g = _game()..onTwist(0.2);
        frames(g);
        expect(g.renderer.rotation, ViewRotation.none);
      });

      test('a clockwise twist turns right, an anticlockwise one left', () {
        final right = _game()..onTwist(0.8);
        frames(right);
        expect(right.renderer.rotation, const ViewRotation(1));
        final left = _game()..onTwist(-0.8);
        frames(left);
        expect(left.renderer.rotation, const ViewRotation(3));
      });

      test('one gesture turns once, the next gesture turns again', () {
        final g = _game()
          ..onTwist(0.8)
          ..onTwist(1.5)
          ..onTwist(2.5);
        frames(g);
        expect(g.renderer.rotation, const ViewRotation(1));
        g
          ..endTwist()
          ..onTwist(0.8);
        frames(g);
        expect(g.renderer.rotation, const ViewRotation(2));
      });
    });

    group('a turn with animation', () {
      void frames(TownGame g, int n) {
        for (var i = 0; i < n; i++) {
          g
            ..update(0.05)
            ..render(ui.Canvas(ui.PictureRecorder()));
        }
      }

      test('fades out, turns while the screen is covered, fades in', () {
        final g = _game()..turn(1);
        expect(g.renderer.rotation, ViewRotation.none);
        expect(g.turnFade, 0);
        frames(g, 2); // 0.1 s: on the way out
        expect(g.turnFade, inExclusiveRange(0, 1));
        expect(g.renderer.rotation, ViewRotation.none);
        frames(g, 2); // 0.2 s: turned
        expect(g.renderer.rotation, const ViewRotation(1));
        expect(g.view.value, const ViewRotation(1));
        frames(g, 8);
        expect(g.turnFade, 0);
      });

      test('turns pressed during a turn add up', () {
        final g = _game()
          ..turn(1)
          ..turn(1);
        frames(g, 20);
        expect(g.renderer.rotation, const ViewRotation(2));
      });

      test('with reduced motion the turn is at once', () {
        final g = _game()
          ..reducedMotion = true
          ..turn(1);
        expect(g.renderer.rotation, const ViewRotation(1));
        expect(g.turnFade, 0);
      });

      test('it tells which side it ended on', () {
        final seen = <int>[];
        final g = _game()
          ..onTurned = (v) {
            seen.add(v.turns);
          }
          ..turn(-1);
        frames(g, 20);
        expect(seen, [3]);
      });
    });

    test('turning back undoes a turn', () {
      final g = _game()
        ..rotate(1)
        ..rotate(-1);
      expect(g.renderer.rotation, ViewRotation.none);
    });
  });
}
