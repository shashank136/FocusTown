import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/game/workers/worker_model.dart';
import 'package:focus_town/game/world/block_material.dart';

Worker _worker({(int, int) facing = (0, 1)}) => Worker(
  x: 10,
  y: 20,
  facing: facing,
  shirt: FlatColor.of(WorkerColors.vest),
);

double _height(List<WorkerBox> boxes) =>
    boxes.map((b) => b.z + b.h).reduce((a, b) => a > b ? a : b) - 1;

final int _toolTop = FlatColor.of(WorkerColors.tool).top;

bool _hasTool(List<WorkerBox> boxes) =>
    boxes.any((b) => b.color.top == _toolTop);

void main() {
  const alive = [
    Pose.idle,
    Pose.hammerUp,
    Pose.hammerDown,
    Pose.walk1,
    Pose.walk2,
  ];

  test('the body of every alive pose is about 1.6 blocks tall', () {
    for (final p in alive) {
      // The first four boxes are pants, shirt, head and helmet.
      final h = _height(boxesFor(_worker(), p).take(4).toList());
      expect(h, inInclusiveRange(1.5, 1.7), reason: p.name);
    }
  });

  test('idle and walk poses, arm included, are about 1.6 blocks tall', () {
    for (final p in [Pose.idle, Pose.walk1, Pose.walk2]) {
      expect(_height(boxesFor(_worker(), p)), inInclusiveRange(1.5, 1.7));
    }
  });

  test('a raised hammer reaches above the helmet', () {
    expect(_height(boxesFor(_worker(), Pose.hammerUp)), greaterThan(1.7));
  });

  test('every pose has 4 to 6 boxes', () {
    for (final p in Pose.values) {
      expect(
        boxesFor(_worker(), p).length,
        inInclusiveRange(4, 6),
        reason: p.name,
      );
    }
  });

  test('hammerUp and hammerDown differ and both carry the tool', () {
    final up = boxesFor(_worker(), Pose.hammerUp);
    final down = boxesFor(_worker(), Pose.hammerDown);
    expect(_hasTool(up), isTrue);
    expect(_hasTool(down), isTrue);
    expect(
      up.map((b) => (b.x, b.y, b.z)).toList(),
      isNot(down.map((b) => (b.x, b.y, b.z)).toList()),
    );
  });

  test('idle and walk poses carry no tool', () {
    for (final p in [Pose.idle, Pose.walk1, Pose.walk2]) {
      expect(_hasTool(boxesFor(_worker(), p)), isFalse, reason: p.name);
    }
  });

  test('walk1 and walk2 differ only by the 0.04 bob', () {
    final a = boxesFor(_worker(), Pose.walk1);
    final b = boxesFor(_worker(), Pose.walk2);
    expect(a.length, b.length);
    var bobbed = 0;
    for (var i = 0; i < a.length; i++) {
      expect(
        (a[i].x, a[i].y, a[i].w, a[i].d, a[i].h),
        (b[i].x, b[i].y, b[i].w, b[i].d, b[i].h),
      );
      final dz = b[i].z - a[i].z;
      if (dz != 0) {
        expect(dz, closeTo(0.04, 1e-12));
        bobbed++;
      }
    }
    expect(bobbed, 3); // shirt, head, helmet
  });

  test('hammerDown bobs like walk2', () {
    final idle = boxesFor(_worker(), Pose.idle);
    final down = boxesFor(_worker(), Pose.hammerDown);
    // The shirt is the second box in every alive pose.
    expect(down[1].z - idle[1].z, closeTo(0.04, 1e-12));
  });

  test('the dead pose lies flat, under 0.4 high', () {
    final h = _height(boxesFor(_worker(), Pose.dead));
    expect(h, lessThan(0.4));
    expect(boxesFor(_worker(), Pose.dead), hasLength(4));
  });

  test('the arm and hammer follow the facing direction', () {
    WorkerBox arm(Worker w, Pose p) => boxesFor(w, p)[4];
    final south = arm(_worker(), Pose.hammerUp); // facing (0, 1)
    final east = arm(_worker(facing: (1, 0)), Pose.hammerUp);
    // facing (0, 1): reach 0.26 along y, shifted 0.2 along x
    expect(south.x, closeTo(10 + 0 * 0.26 - 0.06 + 0.2, 1e-12));
    expect(south.y, closeTo(20 + 1 * 0.26 - 0.06, 1e-12));
    // facing (1, 0): reach along x, shifted 0.2 along y
    expect(east.x, closeTo(10 + 0.26 - 0.06, 1e-12));
    expect(east.y, closeTo(20 - 0.06 + 0.2, 1e-12));
    final hammer = boxesFor(_worker(facing: (1, 0)), Pose.hammerUp)[5];
    expect(hammer.x, closeTo(east.x + 0.12 - 0.05, 1e-12));
    expect(hammer.z, closeTo(2.35 + 0.3, 1e-12));
  });

  test('hammer heights and arm heights per pose', () {
    expect(boxesFor(_worker(), Pose.hammerUp)[4].z, 2.35);
    expect(boxesFor(_worker(), Pose.hammerDown)[4].z, 1.95);
    expect(boxesFor(_worker(), Pose.idle)[4].z, 1.3);
    expect(
      boxesFor(_worker(), Pose.hammerDown)[5].z,
      closeTo(1.95 - 0.06, 1e-12),
    );
  });

  test('depthKey is the box center summed', () {
    final b = WorkerBox(
      x: 1,
      y: 2,
      z: 3,
      w: 0.5,
      d: 1,
      h: 2,
      color: FlatColor.of(WorkerColors.vest),
    );
    expect(b.depthKey, closeTo(1.25 + 2.5 + 4, 1e-12));
  });

  test('body parts are where the prototype puts them', () {
    final b = boxesFor(_worker(), Pose.idle);
    expect((b[0].x, b[0].y, b[0].z, b[0].h), (10 - 0.18, 20 - 0.12, 1.0, 0.6));
    expect((b[2].z, b[2].w), (2.1, 0.34)); // head
    expect(b[3].z, 2.44); // helmet
  });
}
