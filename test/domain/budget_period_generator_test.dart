import 'package:flutter_test/flutter_test.dart';
import 'package:intellispendiq/core/time.dart';
import 'package:intellispendiq/domain/models/budget_schedule.dart';
import 'package:intellispendiq/domain/models/enums.dart';
import 'package:intellispendiq/domain/services/budget_period_generator.dart';

void main() {
  group('Iso date display', () {
    test('formatDateDdMmYyyy uses DD/MM/YYYY', () {
      expect(Iso.formatDateDdMmYyyy(DateTime(2026, 7, 5)), '05/07/2026');
      expect(Iso.formatDateDdMmYyyy(DateTime(2026, 12, 31)), '31/12/2026');
    });

    test('periodLabel shows inclusive end date', () {
      expect(
        Iso.periodLabel(DateTime(2026, 7), DateTime(2026, 8)),
        '01/07/2026 – 31/07/2026',
      );
    });
  });

  group('BudgetPeriodGenerator', () {
    const monthSchedule = BudgetSchedule(
      id: 's',
      cadence: BudgetCadence.calendarMonth,
    );

    test('calendar month bounds', () {
      final bounds = BudgetPeriodGenerator.boundsContaining(
        monthSchedule,
        DateTime(2026, 7, 15),
      );
      expect(bounds.start, DateTime(2026, 7));
      expect(bounds.endExclusive, DateTime(2026, 8));
      expect(
        BudgetPeriodGenerator.labelFor(bounds),
        '01/07/2026 – 31/07/2026',
      );
    });

    test('payday 25th cycle', () {
      const schedule = BudgetSchedule(
        id: 's',
        cadence: BudgetCadence.payday,
        anchorDay: 25,
      );
      final mid = BudgetPeriodGenerator.boundsContaining(
        schedule,
        DateTime(2026, 7, 28),
      );
      expect(mid.start, DateTime(2026, 7, 25));
      expect(mid.endExclusive, DateTime(2026, 8, 25));
      expect(
        BudgetPeriodGenerator.labelFor(mid),
        '25/07/2026 – 24/08/2026',
      );

      final early = BudgetPeriodGenerator.boundsContaining(
        schedule,
        DateTime(2026, 7, 10),
      );
      expect(early.start, DateTime(2026, 6, 25));
      expect(early.endExclusive, DateTime(2026, 7, 25));
    });

    test('weekly Monday cycle', () {
      const schedule = BudgetSchedule(
        id: 's',
        cadence: BudgetCadence.weekly,
        startWeekday: DateTime.monday,
      );
      // 2026-07-15 is a Wednesday.
      final bounds = BudgetPeriodGenerator.boundsContaining(
        schedule,
        DateTime(2026, 7, 15),
      );
      expect(bounds.start, DateTime(2026, 7, 13));
      expect(bounds.endExclusive, DateTime(2026, 7, 20));
      expect(
        BudgetPeriodGenerator.labelFor(bounds),
        '13/07/2026 – 19/07/2026',
      );
    });

    test('biweekly from anchor', () {
      const schedule = BudgetSchedule(
        id: 's',
        cadence: BudgetCadence.biweekly,
        anchorDate: '2026-07-01',
      );
      final first = BudgetPeriodGenerator.boundsContaining(
        schedule,
        DateTime(2026, 7, 5),
      );
      expect(first.start, DateTime(2026, 7));
      expect(first.endExclusive, DateTime(2026, 7, 15));

      final second = BudgetPeriodGenerator.boundsContaining(
        schedule,
        DateTime(2026, 7, 20),
      );
      expect(second.start, DateTime(2026, 7, 15));
      expect(second.endExclusive, DateTime(2026, 7, 29));
    });

    test('shift moves to adjacent calendar month', () {
      final next = BudgetPeriodGenerator.shift(
        monthSchedule,
        DateTime(2026, 7),
        DateTime(2026, 8),
        1,
      );
      expect(next.start, DateTime(2026, 8));
      expect(next.endExclusive, DateTime(2026, 9));
    });
  });
}
