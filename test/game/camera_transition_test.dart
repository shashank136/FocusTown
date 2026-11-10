import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/game/camera/camera_transition.dart';
import 'package:focus_town/game/world/vec2.dart';

void main() {
  const from = CameraPose(Vec2(10, 20), 8);
  const to = CameraPose(Vec2(30, 4), 20);

  test('at t = 0 the pose equals the start', () {
    final t = CameraTransition(from: from, to: to);
    final p = t.step(Duration.zero);
    expect(p.center, from.center);
    expect(p.tile, from.tile);
    expect(t.isDone, isFalse);
  });

  test('after 400 ms the pose equals the target and it is done', () {
    final t = CameraTransition(from: from, to: to);
    final p = t.step(const Duration(milliseconds: 400));
    expect(p.center.x, closeTo(to.center.x, 1e-9));
    expect(p.center.y, closeTo(to.center.y, 1e-9));
    expect(p.tile, closeTo(to.tile, 1e-9));
    expect(t.isDone, isTrue);
  });

  test('ease-out: the midpoint is past halfway', () {
    final t = CameraTransition(from: from, to: to);
    final p = t.step(const Duration(milliseconds: 200));
    final progress = (p.tile - from.tile) / (to.tile - from.tile);
    expect(progress, closeTo(0.875, 1e-9)); // 1 - (1 - 0.5)^3
    expect(progress, greaterThan(0.5));
  });

  test('it never overshoots and never goes backwards', () {
    final t = CameraTransition(from: from, to: to);
    var last = from.tile;
    for (var i = 0; i < 60; i++) {
      final p = t.step(const Duration(milliseconds: 10));
      expect(p.tile, inInclusiveRange(from.tile, to.tile));
      expect(p.center.x, inInclusiveRange(from.center.x, to.center.x));
      expect(p.center.y, inInclusiveRange(to.center.y, from.center.y));
      expect(p.tile, greaterThanOrEqualTo(last));
      last = p.tile;
    }
    expect(t.isDone, isTrue);
  });

  test('stepping after it is done stays on the target', () {
    final t = CameraTransition(from: from, to: to)
      ..step(const Duration(seconds: 2));
    final p = t.step(const Duration(seconds: 1));
    expect(p.tile, to.tile);
    expect(p.center, to.center);
  });
}
