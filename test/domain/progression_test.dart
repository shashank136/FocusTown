import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/domain/progression.dart';

void main() {
  group('levelFor', () {
    final cases = {
      0: TownLevel.camp,
      299: TownLevel.camp,
      300: TownLevel.village,
      1499: TownLevel.village,
      1500: TownLevel.town,
      5999: TownLevel.town,
      6000: TownLevel.city,
      14999: TownLevel.city,
      15000: TownLevel.metropolis,
      100000: TownLevel.metropolis,
    };
    for (final e in cases.entries) {
      test('${e.key} xp is ${e.value.name}', () {
        expect(Progression.levelFor(e.key), e.value);
      });
    }
  });

  group('progressToNext', () {
    test('0 xp is 0.0', () => expect(Progression.progressToNext(0), 0.0));
    test('150 xp is 0.5', () => expect(Progression.progressToNext(150), 0.5));
    test('300 xp starts village at 0.0', () {
      expect(Progression.progressToNext(300), 0.0);
    });
    test('900 xp is 0.5 of village', () {
      expect(Progression.progressToNext(900), 0.5);
    });
    test('15000 xp is 1.0', () {
      expect(Progression.progressToNext(15000), 1.0);
    });
    test('beyond the top level stays 1.0', () {
      expect(Progression.progressToNext(99999), 1.0);
    });
    test('one xp short of a level is just under 1.0', () {
      expect(Progression.progressToNext(299), closeTo(299 / 300, 1e-9));
    });
  });
}
