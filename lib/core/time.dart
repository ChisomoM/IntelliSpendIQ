/// Time helpers. All persisted timestamps are ISO-8601 UTC strings.
abstract final class Iso {
  static String nowUtc() => DateTime.now().toUtc().toIso8601String();

  static String fromDateTime(DateTime value) => value.toUtc().toIso8601String();

  static DateTime toDateTime(String iso) => DateTime.parse(iso);

  /// Local calendar date as `YYYY-MM-DD` (anchors, not display).
  static String localDateKey(DateTime local) {
    final day = DateTime(local.year, local.month, local.day);
    return '${day.year.toString().padLeft(4, '0')}-'
        '${day.month.toString().padLeft(2, '0')}-'
        '${day.day.toString().padLeft(2, '0')}';
  }

  /// Display date `DD/MM/YYYY` in local calendar terms.
  static String formatDateDdMmYyyy(DateTime local) {
    final day = DateTime(local.year, local.month, local.day);
    return '${day.day.toString().padLeft(2, '0')}/'
        '${day.month.toString().padLeft(2, '0')}/'
        '${day.year.toString().padLeft(4, '0')}';
  }

  /// Budget period label for a half-open local `[start, endExclusive)`.
  /// Shows inclusive end date: `01/07/2026 – 31/07/2026`.
  static String periodLabel(DateTime startLocal, DateTime endExclusiveLocal) {
    final start = DateTime(startLocal.year, startLocal.month, startLocal.day);
    final endExclusive = DateTime(
      endExclusiveLocal.year,
      endExclusiveLocal.month,
      endExclusiveLocal.day,
    );
    final endInclusive = endExclusive.subtract(const Duration(days: 1));
    return '${formatDateDdMmYyyy(start)} – ${formatDateDdMmYyyy(endInclusive)}';
  }

  /// Month key `YYYY-MM` for calendar reports, in local time.
  static String monthKey(DateTime local) =>
      '${local.year.toString().padLeft(4, '0')}-${local.month.toString().padLeft(2, '0')}';

  /// Previous month key for report windows / legacy carry-over.
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
