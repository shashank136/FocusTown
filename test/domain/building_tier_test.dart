import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/domain/building_tier.dart';

void main() {
  group('forMinutes', () {
    const cases = {
      10: BuildingTier.hut,
      20: BuildingTier.hut,
      25: BuildingTier.house,
      40: BuildingTier.house,
      45: BuildingTier.workshop,
      60: BuildingTier.workshop,
      65: BuildingTier.tower,
      90: BuildingTier.tower,
      95: BuildingTier.castle,
      120: BuildingTier.castle,
    };
    cases.forEach((minutes, tier) {
      test('$minutes -> ${tier.name}', () {
        expect(BuildingTier.forMinutes(minutes), tier);
      });
    });

    for (final bad in [5, 0, -5, 11, 22, 125, 130]) {
      test('$bad throws', () {
        expect(() => BuildingTier.forMinutes(bad), throwsArgumentError);
      });
    }
  });

  test('tier ranges are contiguous: each starts right after the last ends', () {
    for (var i = 1; i < BuildingTier.values.length; i++) {
      expect(
        BuildingTier.values[i].minMinutes,
        BuildingTier.values[i - 1].maxMinutes + 1,
        reason: BuildingTier.values[i].name,
      );
    }
  });

  test('validDurations is 10..120 step 5', () {
    final d = BuildingTier.validDurations();
    expect(d, hasLength(23));
    expect(d.first, 10);
    expect(d.last, 120);
    expect(d.every((m) => m % 5 == 0), isTrue);
  });

  test('tier values', () {
    expect(BuildingTier.hut.workersAtRisk, 1);
    expect(BuildingTier.hut.workersAddedOnSuccess, 1);
    expect(BuildingTier.house.workersAddedOnSuccess, 2);
    expect(BuildingTier.workshop.workersAddedOnSuccess, 0);
    expect(BuildingTier.castle.workersAtRisk, 8);
  });

  group('largestAffordable', () {
    const cases = {
      0: null,
      1: BuildingTier.hut,
      2: BuildingTier.house,
      3: BuildingTier.workshop,
      4: BuildingTier.workshop,
      5: BuildingTier.tower,
      8: BuildingTier.castle,
      20: BuildingTier.castle,
    };
    cases.forEach((workers, tier) {
      test('$workers workers -> $tier', () {
        expect(BuildingTier.largestAffordable(workers), tier);
      });
    });
  });
}
