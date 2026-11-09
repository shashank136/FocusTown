import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/domain/building_tier.dart';
import 'package:focus_town/domain/town.dart';
import 'package:focus_town/domain/town_rules.dart';

TownBuilding _b(int plot, {BuildingStatus s = BuildingStatus.complete}) =>
    TownBuilding(
      id: 'b$plot',
      tier: BuildingTier.hut,
      status: s,
      plotIndex: plot,
    );

TownState _town({
  int workers = 3,
  int plots = 6,
  List<TownBuilding> buildings = const [],
  bool recovery = false,
}) => TownState(
  workers: workers,
  plotsUnlocked: plots,
  buildings: buildings,
  queue: const [],
  inRecoveryMode: recovery,
);

void main() {
  group('nextFreePlot', () {
    test('initial town gives plot 1', () {
      expect(TownRules.nextFreePlot(TownState.initial()), 1);
    });

    test('buildings on 0, 1, 3 give plot 2', () {
      final t = _town(buildings: [_b(0), _b(1), _b(3)]);
      expect(TownRules.nextFreePlot(t), 2);
    });

    test('all 6 plots used gives null', () {
      final t = _town(buildings: [for (var i = 0; i < 6; i++) _b(i)]);
      expect(TownRules.nextFreePlot(t), isNull);
    });

    test('a ruin on plot 0 still blocks it', () {
      final t = _town(buildings: [_b(0, s: BuildingStatus.ruin)]);
      expect(TownRules.nextFreePlot(t), 1);
    });

    test('7 unlocked with 6 used gives plot 6', () {
      final t = _town(plots: 7, buildings: [for (var i = 0; i < 6; i++) _b(i)]);
      expect(TownRules.nextFreePlot(t), 6);
    });

    test('an occupied plot beyond plotsUnlocked is ignored', () {
      final t = _town(plots: 1, buildings: [_b(0)]);
      expect(TownRules.nextFreePlot(t), isNull);
    });
  });

  group('canStart', () {
    const tiers = {10: 1, 25: 2, 45: 3, 65: 5, 95: 8};
    for (final e in tiers.entries) {
      for (final workers in [0, 1, 2, 3, 4, 5, 8]) {
        test('${e.key} min with $workers workers: ${workers >= e.value}', () {
          expect(
            TownRules.canStart(_town(workers: workers), e.key),
            workers >= e.value,
          );
        });
      }
    }

    test('invalid minutes are false, not an error', () {
      expect(TownRules.canStart(_town(workers: 8), 7), isFalse);
      expect(TownRules.canStart(_town(workers: 8), 130), isFalse);
    });

    test('recovery with 0 workers allows huts only', () {
      final t = _town(workers: 0, recovery: true);
      expect(TownRules.canStart(t, 10), isTrue);
      expect(TownRules.canStart(t, 20), isTrue);
      expect(TownRules.canStart(t, 25), isFalse);
    });

    test('recovery with 2 workers still refuses a house', () {
      expect(
        TownRules.canStart(_town(workers: 2, recovery: true), 25),
        isFalse,
      );
    });
  });
}
