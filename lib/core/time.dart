/// Time helpers. All persisted timestamps are ISO-8601 UTC strings.
abstract final class Iso {
  static String nowUtc() => DateTime.now().toUtc().toIso8601String();

  static String fromDateTime(DateTime value) => value.toUtc().toIso8601String();

  static DateTime toDateTime(String iso) => DateTime.parse(iso);

  /// Month key `YYYY-MM` for budgets/reports, in local time — budgets
  /// follow the user's calendar month.
  static String monthKey(DateTime local) =>
      '${local.year.toString().padLeft(4, '0')}-${local.month.toString().padLeft(2, '0')}';

  /// Previous month key for budget carry-over.
  static String previousMonthKey(String period) {
    final parts = period.split('-');
    var year = int.parse(parts[0]);
    var month = int.parse(parts[1]) - 1;
    if (month == 0) {
      month = 12;
      year -= 1;
    }
    return '$year-${month.toString().padLeft(2, '0')}';
  }

  /// UTC [start, end) bounds of a local calendar month `YYYY-MM`.
  static (String, String) monthBoundsUtc(String period) {
    final parts = period.split('-');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    final start = DateTime(year, month);
    final end = DateTime(year, month + 1);
    return (fromDateTime(start), fromDateTime(end));
  }
}
