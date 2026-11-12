import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/domain/building_look.dart';
import 'package:focus_town/domain/building_tier.dart';
import 'package:focus_town/domain/town.dart';

void main() {
  test('a look comes from the id and never changes', () {
    expect(lookIndex('s1700000000123'), lookIndex('s1700000000123'));
  });

  test('the starter house keeps the classic look', () {
    expect(lookIndex('starter'), 0);
  });

  test('every look is in range and both looks occur', () {
    final looks = {
      for (var i = 0; i < 60; i++) lookIndex('s1700000000${i}000'),
    };
    expect(looks, {for (var i = 0; i < kLooksPerTier; i++) i});
  });

  test('every tier names both looks', () {
    for (final t in BuildingTier.values) {
      final names = [for (var l = 0; l < kLooksPerTier; l++) lookName(t, l)];
      expect(names.toSet(), hasLength(kLooksPerTier), reason: t.name);
    }
    expect(lookName(BuildingTier.castle, 0), 'Castle');
    expect(lookName(BuildingTier.castle, 1), 'Pyramid');
  });

  test('a stored look wins; otherwise the id decides', () {
    const id = 'starter';
    const by = TownBuilding(
      id: id,
      tier: BuildingTier.house,
      status: BuildingStatus.complete,
      plotIndex: 0,
    );
    expect(by.effectiveLook, lookIndex(id));
    const chosen = TownBuilding(
      id: id,
      tier: BuildingTier.house,
      status: BuildingStatus.complete,
      plotIndex: 0,
      look: 1,
    );
    expect(chosen.effectiveLook, 1);
    expect(chosen, isNot(by));
    expect(
      const QueuedBuilding(
        id: id,
        tier: BuildingTier.hut,
        look: 1,
      ).effectiveLook,
      1,
    );
    expect(
      const QueuedBuilding(id: id, tier: BuildingTier.hut).effectiveLook,
      lookIndex(id),
    );
  });
}
