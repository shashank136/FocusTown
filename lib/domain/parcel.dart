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
