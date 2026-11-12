import 'package:focus_town/domain/building_tier.dart';

/// Every tier has this many looks (the second ones: cabin, townhouse,
/// smithy, lighthouse, pyramid).
const kLooksPerTier = 2;

/// Which look the building (or session) with [id] has. The id is stable, so
/// a building never changes its look. Not `hashCode` (may differ between
/// runs). FNV-1a, with the bit picked so the starter house keeps the classic
/// look.
int lookIndex(String id) {
  var h = 2166136261;
  for (final c in id.codeUnits) {
    h = ((h ^ c) * 16777619) & 0xFFFFFFFF;
  }
  return (h >> 3) % kLooksPerTier;
}

/// The name of look [look] of [tier]: the classic building, then its second
/// look.
String lookName(BuildingTier tier, int look) => switch ((tier, look)) {
  (BuildingTier.hut, 0) => 'Hut',
  (BuildingTier.hut, _) => 'Cabin',
  (BuildingTier.house, 0) => 'House',
  (BuildingTier.house, _) => 'Townhouse',
  (BuildingTier.workshop, 0) => 'Workshop',
  (BuildingTier.workshop, _) => 'Smithy',
  (BuildingTier.tower, 0) => 'Tower',
  (BuildingTier.tower, _) => 'Lighthouse',
  (BuildingTier.castle, 0) => 'Castle',
  (BuildingTier.castle, _) => 'Pyramid',
};
