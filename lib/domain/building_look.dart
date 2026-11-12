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
