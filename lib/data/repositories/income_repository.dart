import 'package:drift/drift.dart';
import 'package:intellispendiq/core/ids.dart';
import 'package:intellispendiq/core/time.dart';
import 'package:intellispendiq/data/db/app_database.dart';
import 'package:intellispendiq/domain/models/monthly_income.dart';

/// One declared income figure per month, separate from per-category
/// budgets (plan-style: a single row keyed by period, not by category).
class IncomeRepository {
  IncomeRepository(this._db, {required this.userId});

  final AppDatabase _db;
  final String userId;

  static MonthlyIncome _fromRow(MonthlyIncomeRow row) => MonthlyIncome(
    id: row.id,
    period: row.period,
    amountMinor: row.amountMinor,
  );

  Stream<MonthlyIncome?> watchForPeriod(String period) {
    final query = _db.select(_db.monthlyIncomes)
      ..where(
        (i) =>
            i.userId.equals(userId) &
            i.period.equals(period) &
            i.deletedAt.isNull(),
      );
    return query.watchSingleOrNull().map(
      (row) => row == null ? null : _fromRow(row),
    );
  }

  Future<MonthlyIncome?> getForPeriod(String period) async {
    final query = _db.select(_db.monthlyIncomes)
      ..where(
        (i) =>
            i.userId.equals(userId) &
            i.period.equals(period) &
            i.deletedAt.isNull(),
      );
    final row = await query.getSingleOrNull();
    return row == null ? null : _fromRow(row);
  }

  Future<void> upsert({
    required String period,
    required int amountMinor,
  }) async {
    final existing =
        await (_db.select(_db.monthlyIncomes)..where(
              (i) => i.userId.equals(userId) & i.period.equals(period),
            ))
            .getSingleOrNull();
    final now = Iso.nowUtc();
    if (existing == null) {
      await _db
          .into(_db.monthlyIncomes)
          .insert(
            MonthlyIncomesCompanion.insert(
              id: Ids.newId(),
              userId: userId,
              createdAt: now,
              updatedAt: now,
              period: period,
              amountMinor: amountMinor,
            ),
          );
    } else {
      await (_db.update(
        _db.monthlyIncomes,
      )..where((i) => i.id.equals(existing.id))).write(
        MonthlyIncomesCompanion(
          amountMinor: Value(amountMinor),
          deletedAt: const Value(null),
          updatedAt: Value(now),
        ),
      );
    }
  }
}
