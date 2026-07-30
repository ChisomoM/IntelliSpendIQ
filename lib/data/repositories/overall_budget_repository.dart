import 'package:drift/drift.dart';
import 'package:intellispendiq/core/ids.dart';
import 'package:intellispendiq/core/time.dart';
import 'package:intellispendiq/data/db/app_database.dart';
import 'package:intellispendiq/domain/models/overall_budget.dart';

/// Persists the month's overall spending budget, independent of
/// per-category [BudgetRepository] rows.
class OverallBudgetRepository {
  OverallBudgetRepository(this._db, {required this.userId});

  final AppDatabase _db;
  final String userId;

  static OverallBudget _fromRow(OverallBudgetRow row) => OverallBudget(
    id: row.id,
    period: row.period,
    amountMinor: row.amountMinor,
    carryOver: row.carryOver,
  );

  Stream<OverallBudget?> watchForPeriod(String period) {
    final query = _db.select(_db.overallBudgets)
      ..where(
        (b) =>
            b.userId.equals(userId) &
            b.period.equals(period) &
            b.deletedAt.isNull(),
      );
    return query.watch().map(
      (rows) => rows.isEmpty ? null : _fromRow(rows.first),
    );
  }

  Future<OverallBudget?> getForPeriod(String period) async {
    final query = _db.select(_db.overallBudgets)
      ..where(
        (b) =>
            b.userId.equals(userId) &
            b.period.equals(period) &
            b.deletedAt.isNull(),
      );
    final row = await query.getSingleOrNull();
    return row == null ? null : _fromRow(row);
  }

  /// Every overall budget across every period — for backups.
  Future<List<OverallBudget>> getAllForExport() async {
    final query = _db.select(_db.overallBudgets)
      ..where((b) => b.userId.equals(userId) & b.deletedAt.isNull());
    return (await query.get()).map(_fromRow).toList();
  }

  Future<void> upsert({
    required String period,
    required int amountMinor,
    bool carryOver = true,
  }) async {
    final existing =
        await (_db.select(
              _db.overallBudgets,
            )..where(
              (b) => b.userId.equals(userId) & b.period.equals(period),
            ))
            .getSingleOrNull();
    final now = Iso.nowUtc();
    if (existing == null) {
      await _db
          .into(_db.overallBudgets)
          .insert(
            OverallBudgetsCompanion.insert(
              id: Ids.newId(),
              userId: userId,
              createdAt: now,
              updatedAt: now,
              period: period,
              amountMinor: amountMinor,
              carryOver: Value(carryOver),
            ),
          );
    } else {
      await (_db.update(
        _db.overallBudgets,
      )..where((b) => b.id.equals(existing.id))).write(
        OverallBudgetsCompanion(
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
    await (_db.update(
      _db.overallBudgets,
    )..where((b) => b.id.equals(id))).write(
      OverallBudgetsCompanion(deletedAt: Value(now), updatedAt: Value(now)),
    );
  }

  /// New month: carry the previous month's overall budget in as an
  /// editable default. No-op if [period] already has one, or if last
  /// month's budget opted out of carry-over.
  Future<bool> carryOverInto(String period) async {
    final existing = await getForPeriod(period);
    if (existing != null) return false;

    final previous = await getForPeriod(Iso.previousMonthKey(period));
    if (previous == null || !previous.carryOver) return false;

    await upsert(period: period, amountMinor: previous.amountMinor);
    return true;
  }

  /// Re-inserts an overall budget from a backup, preserving its
  /// original id. Returns false if this id already exists, or if
  /// `{userId, period}` collides with a different row.
  Future<bool> restoreOverallBudget(OverallBudget budget) async {
    final existing = await (_db.select(
      _db.overallBudgets,
    )..where((b) => b.id.equals(budget.id))).getSingleOrNull();
    if (existing != null) return false;

    final now = Iso.nowUtc();
    try {
      await _db
          .into(_db.overallBudgets)
          .insert(
            OverallBudgetsCompanion.insert(
              id: budget.id,
              userId: userId,
              createdAt: now,
              updatedAt: now,
              period: budget.period,
              amountMinor: budget.amountMinor,
              carryOver: Value(budget.carryOver),
            ),
          );
      return true;
    } on Exception {
      return false;
    }
  }
}
