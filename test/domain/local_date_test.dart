import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/domain/local_date.dart';

void main() {
  group('daysBetween', () {
    test('same day is 0', () {
      expect(
        const LocalDate(2026, 5, 1).daysBetween(const LocalDate(2026, 5, 1)),
        0,
      );
    });
    test('next day is 1', () {
      expect(
        const LocalDate(2026, 5, 1).daysBetween(const LocalDate(2026, 5, 2)),
        1,
      );
    });
    test('reverse is -1', () {
      expect(
        const LocalDate(2026, 5, 2).daysBetween(const LocalDate(2026, 5, 1)),
        -1,
      );
    });
    test('Jan 31 to Feb 1 is 1', () {
      expect(
        const LocalDate(2026, 1, 31).daysBetween(const LocalDate(2026, 2, 1)),
        1,
      );
    });
    test('Feb 28 to Mar 1 is 1 in 2026', () {
      expect(
        const LocalDate(2026, 2, 28).daysBetween(const LocalDate(2026, 3, 1)),
        1,
      );
    });
    test('Feb 28 to Mar 1 is 2 in leap year 2028', () {
      expect(
        const LocalDate(2028, 2, 28).daysBetween(const LocalDate(2028, 3, 1)),
        2,
      );
    });
    test('Dec 31 to Jan 1 is 1', () {
      expect(
        const LocalDate(2026, 12, 31).daysBetween(const LocalDate(2027, 1, 1)),
        1,
      );
    });
    test('across a DST change in local time is still 1', () {
      final a = LocalDate.fromDateTime(DateTime(2026, 3, 8, 23, 30));
      final b = LocalDate.fromDateTime(DateTime(2026, 3, 9, 0, 30));
      expect(a.daysBetween(b), 1);
      final c = LocalDate.fromDateTime(DateTime(2026, 11, 1, 23, 30));
      final d = LocalDate.fromDateTime(DateTime(2026, 11, 2, 0, 30));
      expect(c.daysBetween(d), 1);
    });
  });

  group('fromDateTime', () {
    test('uses year, month and day as given, ignoring time', () {
      expect(
        LocalDate.fromDateTime(DateTime(2026, 3, 5, 23, 59)),
        const LocalDate(2026, 3, 5),
      );
    });
  });

  group('toIso / parse', () {
    test('toIso zero pads', () {
      expect(const LocalDate(2026, 3, 5).toIso(), '2026-03-05');
    });
    test('round trip for 2026-03-05', () {
      final d = LocalDate.parse(const LocalDate(2026, 3, 5).toIso());
      expect(d, const LocalDate(2026, 3, 5));
    });
    test('parse throws FormatException on bad input', () {
      for (final bad in ['bad', '', '2026-3-5', '2026-13-01', '2026-02-30']) {
        expect(() => LocalDate.parse(bad), throwsFormatException, reason: bad);
      }
    });
  });

  group('equality and ordering', () {
    test('equal dates are equal with the same hashCode', () {
      expect(const LocalDate(2026, 5, 1), const LocalDate(2026, 5, 1));
      expect(
        const LocalDate(2026, 5, 1).hashCode,
        const LocalDate(2026, 5, 1).hashCode,
      );
    });
    test('different dates are unequal', () {
      expect(const LocalDate(2026, 5, 1), isNot(const LocalDate(2026, 5, 2)));
      expect(const LocalDate(2026, 5, 1), isNot(const LocalDate(2026, 6, 1)));
      expect(const LocalDate(2026, 5, 1), isNot(const LocalDate(2027, 5, 1)));
    });
    test('compareTo orders by year, month, day', () {
      final dates = [
        const LocalDate(2027, 1, 1),
        const LocalDate(2026, 5, 2),
        const LocalDate(2026, 5, 1),
        const LocalDate(2026, 1, 31),
      ]..sort();
      expect(dates.map((d) => d.toIso()), [
        '2026-01-31',
        '2026-05-01',
        '2026-05-02',
        '2027-01-01',
      ]);
    });
  });
}
