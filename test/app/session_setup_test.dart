import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/app/session_setup.dart';
import 'package:focus_town/domain/building_tier.dart';
import 'package:focus_town/domain/town.dart';

TownState _town({int workers = 3, bool recovery = false}) =>
    TownState.initial().copyWith(workers: workers, inRecoveryMode: recovery);

DurationOption _at(List<DurationOption> o, int minutes) =>
    o.singleWhere((x) => x.minutes == minutes);

void main() {
  group('durationOptions', () {
    test('one option per valid duration', () {
      final o = durationOptions(_town());
      expect([for (final x in o) x.minutes], BuildingTier.validDurations());
    });

    test('a 3 worker town can start 10 to 60 minutes', () {
      final o = durationOptions(_town());
      for (final x in o) {
        expect(x.enabled, x.minutes <= 60, reason: '${x.minutes} min');
      }
      expect(_at(o, 60).tier, BuildingTier.workshop);
    });

    test('the reasons for a disabled option name the missing workers', () {
      final o = durationOptions(_town());
      expect(_at(o, 65).reason, 'Needs 5 workers, you have 3');
      expect(_at(o, 95).reason, 'Needs 8 workers, you have 3');
      expect(_at(o, 25).reason, isNull);
    });

    test('recovery mode allows only huts and says so', () {
      final o = durationOptions(_town(workers: 0, recovery: true));
      for (final x in o) {
        expect(x.enabled, x.minutes <= 20, reason: '${x.minutes} min');
        if (!x.enabled) expect(x.reason, 'Recovery mode: huts only');
      }
      expect(_at(o, 10).workersAtRisk, 0);
      expect(_at(o, 25).workersAtRisk, 0);
    });

    test('risk and gain follow the tier', () {
      final o = durationOptions(_town(workers: 10));
      expect(_at(o, 10).workersAtRisk, 1);
      expect(_at(o, 25).workersAtRisk, 2);
      expect(_at(o, 95).workersAtRisk, 8);
      expect(_at(o, 10).workersGained, 1);
      expect(_at(o, 25).workersGained, 2);
      expect(_at(o, 45).workersGained, 0);
    });

    test('a rich town enables everything', () {
      expect(
        durationOptions(_town(workers: 10)).every((x) => x.enabled),
        isTrue,
      );
    });
  });

  group('defaultMinutes', () {
    test('the last used one when it is enabled', () {
      expect(defaultMinutes(durationOptions(_town()), 25), 25);
    });

    test('the largest enabled one below a disabled last used', () {
      expect(defaultMinutes(durationOptions(_town()), 95), 60);
    });

    test('in recovery, the largest hut below the last used', () {
      expect(
        defaultMinutes(durationOptions(_town(workers: 0, recovery: true)), 25),
        20,
      );
    });

    test('the smallest enabled one when nothing at or below is enabled', () {
      final o = [
        for (final x in durationOptions(_town()))
          if (x.minutes >= 30) x,
      ];
      expect(
        defaultMinutes([
          for (final x in o)
            if (x.minutes != 30) x,
        ], 10),
        35,
      );
    });

    test('10 when nothing is enabled', () {
      expect(defaultMinutes(const [], 25), 10);
    });
  });
}
