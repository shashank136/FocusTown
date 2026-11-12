// All fields are final; @immutable would need package:meta (not approved).
// ignore_for_file: avoid_equals_and_hash_code_on_mutable_classes

/// The starting island is a square of this many parcels on each side.
const kBaseParcelsPerSide = 8;

/// The lowest and highest parcel position on either axis. Beyond these the
/// tiles would leave the voxel world's 8-bit coordinates.
const kMinParcel = -18;

/// See [kMinParcel].
const kMaxParcel = 16;

/// One plot-sized square of land at a grid position. The 64 starting parcels
/// sit at 0..7 on both axes; claimed land lies beyond them. A [garden] is open
/// space: it is land, but not a plot to build on.
class Parcel {
  /// Creates a parcel at ([gx], [gy]).
  const new(this.gx, this.gy, {this.garden = false});

  /// Reads `gx:gy` or `gx:gy:g`.
  // ignore: unnecessary_type_name_in_constructor, shorthand not valid for factories
  factory Parcel.decode(String s) {
    final parts = s.split(':');
    return Parcel(
      int.parse(parts[0]),
      int.parse(parts[1]),
      garden: parts.length > 2 && parts[2] == 'g',
    );
  }

  /// Reads a list written by [encodeList].
  static List<Parcel> decodeList(String s) =>
      s.isEmpty ? const [] : [for (final p in s.split(',')) Parcel.decode(p)];

  /// Writes [parcels] as `gx:gy,gx:gy`.
  static String encodeList(List<Parcel> parcels) =>
      parcels.map((p) => p.encode()).join(',');

  /// Column.
  final int gx;

  /// Row.
  final int gy;

  /// Open space instead of a plot.
  final bool garden;

  /// `gx:gy`, with `:g` for a garden.
  String encode() => garden ? '$gx:$gy:g' : '$gx:$gy';

  @override
  bool operator ==(Object other) =>
      other is Parcel &&
      other.gx == gx &&
      other.gy == gy &&
      other.garden == garden;

  @override
  int get hashCode => Object.hash(gx, gy, garden);

  @override
  String toString() => 'Parcel($gx, $gy)';
}

bool _isBase(int gx, int gy) =>
    gx >= 0 && gx < kBaseParcelsPerSide && gy >= 0 && gy < kBaseParcelsPerSide;

/// The parcels next to the island (the starting square plus [claimed]) that
/// nobody has claimed yet, row by row. Only the four sides count as next to.
List<Parcel> claimableParcels(List<Parcel> claimed) {
  final owned = {for (final p in claimed) (p.gx, p.gy)};
  bool isIsland(int gx, int gy) => _isBase(gx, gy) || owned.contains((gx, gy));
  final found = <Parcel>{};
  void consider(int gx, int gy) {
    if (gx < kMinParcel || gx > kMaxParcel) return;
    if (gy < kMinParcel || gy > kMaxParcel) return;
    if (!isIsland(gx, gy)) found.add(Parcel(gx, gy));
  }

  void around(int gx, int gy) {
    consider(gx - 1, gy);
    consider(gx + 1, gy);
    consider(gx, gy - 1);
    consider(gx, gy + 1);
  }

  for (var gx = 0; gx < kBaseParcelsPerSide; gx++) {
    for (var gy = 0; gy < kBaseParcelsPerSide; gy++) {
      around(gx, gy);
    }
  }
  for (final p in claimed) {
    around(p.gx, p.gy);
  }
  return found.toList()..sort(
    (a, b) => a.gy != b.gy ? a.gy.compareTo(b.gy) : a.gx.compareTo(b.gx),
  );
}
