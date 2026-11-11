import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/domain/building_tier.dart';
import 'package:focus_town/domain/town.dart';
import 'package:focus_town/game/demo/demo_script.dart';
import 'package:focus_town/game/workers/worker_model.dart';

int _ruins(DemoFrame f) =>
    f.town.buildings.where((b) => b.status == BuildingStatus.ruin).length;

String _sig(DemoFrame f) =>
    '${f.town.buildings.length} ${f.site?.tier} ${f.site?.stage} '
    '${f.smoke} '
    '${[for (final w in f.workers) (w.worker.x, w.worker.y, w.pose)]}';

void main() {
  test('every demo loops after 6 seconds', () {
    expect(kDemoLoop, 6);
    for (final k in DemoKind.values) {
      expect(_sig(demoFrame(k, 0)), _sig(demoFrame(k, 6)), reason: '$k');
      expect(_sig(demoFrame(k, 2.5)), _sig(demoFrame(k, 8.5)), reason: '$k');
    }
  });

  test('a frame depends on time only', () {
    for (final k in DemoKind.values) {
      expect(_sig(demoFrame(k, 1.3)), _sig(demoFrame(k, 1.3)));
    }
  });

  test('the build demo rises to the last stage with 3 workers', () {
    var last = 0;
    for (var t = 0.0; t < kDemoLoop; t += 0.1) {
      final f = demoFrame(DemoKind.build, t);
      expect(f.site!.tier, BuildingTier.house);
      expect(f.site!.stage, greaterThanOrEqualTo(last));
      expect(f.workers, hasLength(3));
      last = f.site!.stage;
    }
    expect(last, 7);
    expect(demoFrame(DemoKind.build, 0).site!.stage, 1);
  });

  test('the ruin demo builds for 3 seconds, then fails', () {
    final before = demoFrame(DemoKind.ruin, 2.9);
    expect(before.site!.stage, 5);
    expect(before.smoke, isFalse);
    expect(_ruins(before), 0);

    final after = demoFrame(DemoKind.ruin, 3.1);
    expect(after.site, isNull);
    expect(after.smoke, isTrue);
    expect(_ruins(after), 1);
    expect(after.workers, isNotEmpty);
    expect(after.workers.every((w) => w.pose == Pose.dead), isTrue);
  });

  test('the start demo shows a hut at stage 1 with one worker', () {
    final f = demoFrame(DemoKind.start, 1);
    expect(f.site!.tier, BuildingTier.hut);
    expect(f.site!.stage, 1);
    expect(f.workers, hasLength(1));
    expect(f.town, TownState.initial());
  });

  test('the demo plot is the first free one, not under the starter', () {
    final f = demoFrame(DemoKind.build, 0);
    expect(f.site!.plotIndex, isNot(0));
  });
}
