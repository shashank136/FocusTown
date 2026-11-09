// All fields are final; @immutable would need package:meta (not approved).
// ignore_for_file: avoid_equals_and_hash_code_on_mutable_classes

/// A calendar day with no time or zone. Immutable.
class LocalDate implements Comparable<LocalDate> {
  /// Creates a date from explicit parts.
  const new(this.year, this.month, this.day);

  /// Takes the year, month and day of [dt] as given; pass local time.
  // ignore: unnecessary_type_name_in_constructor, shorthand not valid for factories
  factory LocalDate.fromDateTime(DateTime dt) =>
      LocalDate(dt.year, dt.month, dt.day);

  /// Reads `yyyy-MM-dd`; throws [FormatException] on bad input.
  // ignore: unnecessary_type_name_in_constructor, shorthand not valid for factories
  factory LocalDate.parse(String s) {
    final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(s);
    if (m == null) throw FormatException('Expected yyyy-MM-dd', s);
    final y = int.parse(m[1]!);
    final mo = int.parse(m[2]!);
    final d = int.parse(m[3]!);
    // DateTime rolls invalid days over (Feb 30 -> Mar 2), so compare back.
    final check = DateTime.utc(y, mo, d);
    if (check.year != y || check.month != mo || check.day != d) {
      throw FormatException('Not a real date', s);
    }
    return LocalDate(y, mo, d);
  }

  /// Year.
  final int year;

  /// Month, 1-12.
  final int month;

  /// Day of month, 1-31.
  final int day;

  /// Days from this date to [other]; positive if [other] is later.
  int daysBetween(LocalDate other) => DateTime.utc(
    other.year,
    other.month,
    other.day,
  ).difference(DateTime.utc(year, month, day)).inDays;

  /// `yyyy-MM-dd`, zero padded.
  String toIso() =>
      '${year.toString().padLeft(4, '0')}-'
      '${month.toString().padLeft(2, '0')}-'
      '${day.toString().padLeft(2, '0')}';

  @override
  int compareTo(LocalDate other) {
    if (year != other.year) return year.compareTo(other.year);
    if (month != other.month) return month.compareTo(other.month);
    return day.compareTo(other.day);
  }

  @override
  bool operator ==(Object other) =>
      other is LocalDate &&
      other.year == year &&
      other.month == month &&
      other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);
}
