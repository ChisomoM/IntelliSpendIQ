import 'package:intellispendiq/core/time.dart';
import 'package:intellispendiq/domain/models/budget_schedule.dart';
import 'package:intellispendiq/domain/models/enums.dart';

/// Inclusive/exclusive local date bounds for one budget period under
/// a [BudgetSchedule].
typedef LocalPeriodBounds = ({DateTime start, DateTime endExclusive});

/// Pure period arithmetic — no DB. Bounds are local midnight dates;
/// callers convert to UTC ISO via [Iso.fromDateTime].
abstract final class BudgetPeriodGenerator {
  /// Period containing [reference] (local) for [schedule].
  static LocalPeriodBounds boundsContaining(
    BudgetSchedule schedule,
    DateTime reference,
  ) {
    final day = DateTime(reference.year, reference.month, reference.day);
    return switch (schedule.cadence) {
      BudgetCadence.calendarMonth => _calendarMonth(day),
      BudgetCadence.payday => _payday(day, schedule.anchorDay ?? 1),
      BudgetCadence.weekly => _weekly(day, schedule.startWeekday ?? DateTime.monday),
      BudgetCadence.biweekly => _fixedLength(
        day,
        schedule.anchorDate,
        days: 14,
      ),
      BudgetCadence.everyFourWeeks => _fixedLength(
        day,
        schedule.anchorDate,
        days: 28,
      ),
      BudgetCadence.custom => _calendarMonth(day),
    };
  }

  /// Adjacent period: [delta] of -1 or +1 from an existing window.
  static LocalPeriodBounds shift(
    BudgetSchedule schedule,
    DateTime startLocal,
    DateTime endExclusiveLocal,
    int delta,
  ) {
    if (delta == 0) {
      return (start: startLocal, endExclusive: endExclusiveLocal);
    }
    final probe = delta > 0
        ? endExclusiveLocal
        : startLocal.subtract(const Duration(days: 1));
    return boundsContaining(schedule, probe);
  }

  static String labelFor(LocalPeriodBounds bounds) =>
      Iso.periodLabel(bounds.start, bounds.endExclusive);

  static LocalPeriodBounds _calendarMonth(DateTime day) {
    final start = DateTime(day.year, day.month);
    final end = DateTime(day.year, day.month + 1);
    return (start: start, endExclusive: end);
  }

  static LocalPeriodBounds _payday(DateTime day, int anchorDay) {
    final thisMonthStart = _clampedDate(day.year, day.month, anchorDay);
    if (!day.isBefore(thisMonthStart)) {
      final next = DateTime(day.year, day.month + 1);
      return (
        start: thisMonthStart,
        endExclusive: _clampedDate(next.year, next.month, anchorDay),
      );
    }
    final prev = DateTime(day.year, day.month - 1);
    return (
      start: _clampedDate(prev.year, prev.month, anchorDay),
      endExclusive: thisMonthStart,
    );
  }

  static LocalPeriodBounds _weekly(DateTime day, int startWeekday) {
    final weekday = day.weekday;
    final daysBack = (weekday - startWeekday + 7) % 7;
    final start = day.subtract(Duration(days: daysBack));
    final end = start.add(const Duration(days: 7));
    return (
      start: DateTime(start.year, start.month, start.day),
      endExclusive: DateTime(end.year, end.month, end.day),
    );
  }

  static LocalPeriodBounds _fixedLength(
    DateTime day,
    String? anchorDate, {
    required int days,
  }) {
    final anchor = _parseAnchor(anchorDate) ?? DateTime(day.year, day.month, day.day);
    final anchorDay = DateTime(anchor.year, anchor.month, anchor.day);
    final diff = day.difference(anchorDay).inDays;
    final index = diff >= 0 ? diff ~/ days : -(((-diff - 1) ~/ days) + 1);
    final start = anchorDay.add(Duration(days: index * days));
    final end = start.add(Duration(days: days));
    return (
      start: DateTime(start.year, start.month, start.day),
      endExclusive: DateTime(end.year, end.month, end.day),
    );
  }

  static DateTime _clampedDate(int year, int month, int day) {
    final lastDay = DateTime(year, month + 1, 0).day;
    return DateTime(year, month, day.clamp(1, lastDay));
  }

  static DateTime? _parseAnchor(String? anchorDate) {
    if (anchorDate == null || anchorDate.isEmpty) return null;
    final parts = anchorDate.split('-');
    if (parts.length != 3) return null;
    return DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }
}
