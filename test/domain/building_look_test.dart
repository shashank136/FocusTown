import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/domain/building_look.dart';

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
}
