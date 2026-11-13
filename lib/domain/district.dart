// All fields are final; @immutable would need package:meta (not approved).
// ignore_for_file: avoid_equals_and_hash_code_on_mutable_classes

import 'package:focus_town/domain/parcel.dart';

/// A district has this many rows (stages).
const kDistrictRows = 8;

/// Parcels per side of a district.
const kDistrictSide = 8;

/// Focus minutes that build one row.
const kMinutesPerDistrictRow = 60;

/// Focus minutes for a whole district.
const int kDistrictMinutes = kDistrictRows * kMinutesPerDistrictRow;

/// Most districts a town can have at first (a frame rate and battery limit).
const kMaxDistricts = 3;

/// The side of the starting island a district is added on.
enum DistrictSide {
  /// Above the island (smaller rows).
  north,

  /// To the right of the island (larger columns).
  east,

  /// Below the island (larger rows).
  south,

  /// To the left of the island (smaller columns).
  west,
}

/// The district being built: its [side] and the [progress] in focus minutes.
class DistrictProject {
  /// Creates a project.
  const new(this.side, this.progress);

  /// Where it is built.
  final DistrictSide side;

  /// Focus minutes put in so far (0 to [kDistrictMinutes]).
  final int progress;

  /// Whole rows done.
  int get rows => (progress ~/ kMinutesPerDistrictRow).clamp(0, kDistrictRows);

  @override
  bool operator ==(Object other) =>
      other is DistrictProject &&
      other.side == side &&
      other.progress == progress;

  @override
  int get hashCode => Object.hash(side, progress);

  @override
  String toString() => 'DistrictProject($side, $progress)';
}

/// The 8 parcels of [row] (0 is the one next to the island or the district
/// before it) of the [index]th district on [side]. Districts on a side follow
/// each other outward from the starting island.
List<Parcel> districtRow(DistrictSide side, int index, int row) {
  final out = kDistrictSide * index + row;
  return [
    for (var i = 0; i < kDistrictSide; i++)
      switch (side) {
        DistrictSide.north => Parcel(i, -1 - out),
        DistrictSide.south => Parcel(i, kBaseParcelsPerSide + out),
        DistrictSide.west => Parcel(-1 - out, i),
        DistrictSide.east => Parcel(kBaseParcelsPerSide + out, i),
      },
  ];
}

/// Whether the [index]th district on [side] lies inside the world's edge.
bool districtFits(DistrictSide side, int index) {
  for (final p in [
    ...districtRow(side, index, 0),
    ...districtRow(side, index, kDistrictRows - 1),
  ]) {
    if (p.gx < kMinParcel || p.gx > kMaxParcel) return false;
    if (p.gy < kMinParcel || p.gy > kMaxParcel) return false;
  }
  return true;
}
