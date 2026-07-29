import 'package:drift/drift.dart';
import 'package:intellispendiq/core/ids.dart';
import 'package:intellispendiq/core/time.dart';
import 'package:intellispendiq/data/db/app_database.dart';
import 'package:intellispendiq/domain/models/budget.dart';

class BudgetRepository {
  BudgetRepository(this._db, {required this.userId});

  final AppDatabase _db;
  final String userId;

  static Budget _fromRow(BudgetRow row) => Budget(
    id: row.id,
    categoryId: row.categoryId,
    period: row.period,
    amountMinor: row.amountMinor,
    carryOver: row.carryOver,
  );

  Stream<List<Budget>> watchForPeriod(String period) {
    final query = _db.select(_db.budgets)
      ..where(
        (b) =>
            b.userId.equals(userId) &
            b.period.equals(period) &
            b.deletedAt.isNull(),
      );
    return query.watch().map((rows) => rows.map(_fromRow).toList());
  }

  Future<List<Budget>> getForPeriod(String period) async {
    final query = _db.select(_db.budgets)
      ..where(
        (b) =>
            b.userId.equals(userId) &
            b.period.equals(period) &
            b.deletedAt.isNull(),
      );
    return (await query.get()).map(_fromRow).toList();
  }

  Future<void> upsert({
    required String categoryId,
    required String period,
    required int amountMinor,
    bool carryOver = true,
  }) async {
    final existing =
        await (_db.select(_db.budgets)..where(
              (b) =>
                  b.userId.equals(userId) &
                  b.categoryId.equals(categoryId) &
                  b.period.equals(period),
            ))
            .getSingleOrNull();
    final now = Iso.nowUtc();
    if (existing == null) {
      await _db
          .into(_db.budgets)
          .insert(
            BudgetsCompanion.insert(
              id: Ids.newId(),
              userId: userId,
              createdAt: now,
              updatedAt: now,
              categoryId: categoryId,
              period: period,
              amountMinor: amountMinor,
              carryOver: Value(carryOver),
            ),
          );
    } else {
      await (_db.update(
        _db.budgets,
      )..where((b) => b.id.equals(existing.id))).write(
        BudgetsCompanion(
          amountMinor: Value(amountMinor),
          carryOver: Value(carryOver),
          deletedAt: const Value(null),
          updatedAt: Value(now),
        ),
      );
    }
  }

  Future<void> delete(String id) async {
    final now = Iso.nowUtc();
    await (_db.update(_db.budgets)..where((b) => b.id.equals(id))).write(
      BudgetsCompanion(deletedAt: Value(now), updatedAt: Value(now)),
    );
  }

  /// New month: carry the previous month's carry-over budgets in as
  /// editable defaults (plan §11). Only fills gaps — never overwrites
  /// budgets the user already set for [period].
  Future<int> carryOverInto(String period) async {
    final previous = await getForPeriod(Iso.previousMonthKey(period));
    final current = await getForPeriod(period);
    final existingCategories = current.map((b) => b.categoryId).toSet();
    var created = 0;
    for (final budget in previous) {
      if (!budget.carryOver) continue;
      if (existingCategories.contains(budget.categoryId)) continue;
      await upsert(
        categoryId: budget.categoryId,
        period: period,
        amountMinor: budget.amountMinor,
      );
      created++;
    }
    return created;
  }
}
