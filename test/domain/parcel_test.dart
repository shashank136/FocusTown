import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/domain/parcel.dart';

void main() {
  test('a parcel compares and encodes by its grid position', () {
    expect(const Parcel(-1, 3), const Parcel(-1, 3));
    expect(const Parcel(-1, 3), isNot(const Parcel(3, -1)));
    expect(
      Parcel.decode(const Parcel(-18, 16).encode()),
      const Parcel(-18, 16),
    );
  });

  test('the parcels of a town round trip through text', () {
    final list = [const Parcel(-1, 3), const Parcel(8, 0)];
    expect(Parcel.decodeList(Parcel.encodeList(list)), list);
    expect(Parcel.decodeList(''), isEmpty);
  });

  test(
    'with nothing claimed, the ring around the 8 x 8 island is claimable',
    () {
      final c = claimableParcels(const []);
      expect(c, hasLength(32));
      expect(c, contains(const Parcel(-1, 0)));
      expect(c, contains(const Parcel(8, 7)));
      expect(c, contains(const Parcel(3, -1)));
      expect(c, contains(const Parcel(7, 8)));
      expect(
        c,
        isNot(contains(const Parcel(-1, -1))),
      ); // a corner touches no side
      expect(c, isNot(contains(const Parcel(3, 3)))); // already island
    },
  );

  test('claiming one removes it and opens the parcel beyond it', () {
    final c = claimableParcels(const [Parcel(-1, 3)]);
    expect(c, isNot(contains(const Parcel(-1, 3))));
    expect(c, contains(const Parcel(-2, 3)));
    // Its other neighbours already touched the island.
    expect(c, hasLength(32));
  });

  test('nothing outside the world edge is claimable', () {
    final edge = [for (var g = 0; g > kMinParcel; g--) Parcel(g - 1, 3)];
    final c = claimableParcels(edge);
    expect(c.every((p) => p.gx >= kMinParcel && p.gy >= kMinParcel), isTrue);
    expect(c.every((p) => p.gx <= kMaxParcel && p.gy <= kMaxParcel), isTrue);
    expect(c, isNot(contains(const Parcel(kMinParcel - 1, 3))));
  });
}
