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

  test('a garden parcel is not the same land use as a forest one', () {
    expect(const Parcel(1, 1, garden: true), isNot(const Parcel(1, 1)));
    expect(const Parcel(1, 1).garden, isFalse);
    expect(const Parcel(1, 1, garden: true).encode(), '1:1:g');
    expect(Parcel.decode('1:1:g'), const Parcel(1, 1, garden: true));
  });

  test('the parcels of a town round trip through text', () {
    final list = [const Parcel(-1, 3), const Parcel(8, 0, garden: true)];
    expect(Parcel.decodeList(Parcel.encodeList(list)), list);
    expect(Parcel.decodeList(''), isEmpty);
  });
}
