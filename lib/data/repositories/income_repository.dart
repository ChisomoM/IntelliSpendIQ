import 'package:drift/drift.dart';
import 'package:intellispendiq/core/ids.dart';
import 'package:intellispendiq/core/time.dart';
import 'package:intellispendiq/data/db/app_database.dart';
import 'package:intellispendiq/domain/models/monthly_income.dart';

/// Declared income for a month, possibly split across several streams
/// (e.g. "Salary" and "Side hustle") tracked together against overall
/// spend, separate from per-category budgets.
class IncomeRepository {
  IncomeRepository(this._db, {required this.userId});

  final AppDatabase _db;
  final String userId;

  static MonthlyIncome _fromRow(MonthlyIncomeRow row) => MonthlyIncome(
    id: row.id,
    period: row.period,
    amountMinor: row.amountMinor,
    label: row.label,
  );

  Stream<List<MonthlyIncome>> watchForPeriod(String period) {
    final query = _db.select(_db.monthlyIncomes)
      ..where(
        (i) =>
            i.userId.equals(userId) &
            i.period.equals(period) &
            i.deletedAt.isNull(),
      )
      ..orderBy([(i) => OrderingTerm.asc(i.createdAt)]);
    return query.watch().map((rows) => rows.map(_fromRow).toList());
  }

  Future<List<MonthlyIncome>> getForPeriod(String period) async {
    final query = _db.select(_db.monthlyIncomes)
      ..where(
        (i) =>
            i.userId.equals(userId) &
            i.period.equals(period) &
            i.deletedAt.isNull(),
      )
      ..orderBy([(i) => OrderingTerm.asc(i.createdAt)]);
    return (await query.get()).map(_fromRow).toList();
  }

  /// Every declared income stream across every period, unbounded — for
  /// backups.
  Future<List<MonthlyIncome>> getAllForExport() async {
    final query = _db.select(_db.monthlyIncomes)
      ..where((i) => i.userId.equals(userId) & i.deletedAt.isNull());
    return (await query.get()).map(_fromRow).toList();
  }

  /// Adds a new income stream, or updates the existing one with the
  /// same [label] for [period] if one is already there — the same
  /// "set a figure for this month" gesture as before, just scoped to a
  /// named stream rather than the whole month.
  Future<void> upsert({
    required String period,
    required int amountMinor,
    String? label,
  }) async {
    final normalizedLabel = _normalizeLabel(label);
    var predicate =
        _db.monthlyIncomes.userId.equals(userId) &
        _db.monthlyIncomes.period.equals(period);
    predicate =
        predicate &
        (normalizedLabel == null
            ? _db.monthlyIncomes.label.isNull()
            : _db.monthlyIncomes.label.equals(normalizedLabel));
    final existing = await (_db.select(
      _db.monthlyIncomes,
    )..where((_) => predicate)).getSingleOrNull();

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
              label: Value(normalizedLabel),
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

  /// Renames and/or re-amounts an existing income stream by id, rather
  /// than by the `{period, label}` match [upsert] uses — needed once a
  /// stream's label itself is being changed.
  Future<void> updateSource(
    String id, {
    String? label,
    int? amountMinor,
    bool clearLabel = false,
  }) async {
    await (_db.update(
      _db.monthlyIncomes,
    )..where((i) => i.id.equals(id))).write(
      MonthlyIncomesCompanion(
        amountMinor: amountMinor == null
            ? const Value.absent()
            : Value(amountMinor),
        label: clearLabel
            ? const Value(null)
            : (label == null
                  ? const Value.absent()
                  : Value(_normalizeLabel(label))),
        updatedAt: Value(Iso.nowUtc()),
      ),
    );
  }

  Future<void> deleteSource(String id) async {
    final now = Iso.nowUtc();
    await (_db.update(
      _db.monthlyIncomes,
    )..where((i) => i.id.equals(id))).write(
      MonthlyIncomesCompanion(deletedAt: Value(now), updatedAt: Value(now)),
    );
  }

  String? _normalizeLabel(String? label) {
    final trimmed = label?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  /// Re-inserts an income stream from a backup, preserving its
  /// original id so importing the same backup twice does not
  /// duplicate anything. Returns false without writing if an income
  /// with this id already exists, or if `{userId, period, label}`
  /// collides with a different row (its unique constraint).
  Future<bool> restoreIncome(MonthlyIncome income) async {
    final existing = await (_db.select(
      _db.monthlyIncomes,
    )..where((i) => i.id.equals(income.id))).getSingleOrNull();
    if (existing != null) return false;

    final now = Iso.nowUtc();
    try {
      await _db
          .into(_db.monthlyIncomes)
          .insert(
            MonthlyIncomesCompanion.insert(
              id: income.id,
              userId: userId,
              createdAt: now,
              updatedAt: now,
              period: income.period,
              amountMinor: income.amountMinor,
              label: Value(income.label),
            ),
          );
      return true;
    } on Exception {
      return false;
    }
  }
}
