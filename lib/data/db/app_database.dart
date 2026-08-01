import 'package:drift/drift.dart';
import 'package:intellispendiq/core/ids.dart';
import 'package:intellispendiq/core/time.dart';
import 'package:intellispendiq/data/db/tables.dart';
import 'package:intellispendiq/domain/models/enums.dart';

export 'package:drift/drift.dart' show Value;

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    Accounts,
    Categories,
    Transactions,
    OverallBudgets,
    BudgetSchedules,
    BudgetPeriods,
    CategoryBudgets,
    Payees,
    Labels,
    TransactionLabels,
    Transfers,
    RawCaptures,
    Settings,
    CustomSenderIds,
    MerchantCategoryRules,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 9;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      // Drift does not wrap onUpgrade in a transaction by default, so a
      // crash mid-step leaves columns/tables applied while user_version
      // stays old. Transaction + idempotent helpers recover from that.
      await transaction(() async {
        if (from < 2) await customStatement(_createMonthlyIncomesV2Sql);
        if (from < 3) {
          await _addColumnIfMissing(m, transactions, transactions.receiptPath);
          await _addColumnIfMissingRaw('monthly_incomes', 'label', '''
ALTER TABLE monthly_incomes ADD COLUMN label TEXT NULL
''');
          await _createTableIfMissing(m, customSenderIds);
        }
        if (from < 4) await _createTableIfMissing(m, overallBudgets);
        if (from < 5) {
          await _addColumnIfMissing(m, categories, categories.categoryType);
          await _addColumnIfMissing(
            m,
            categories,
            categories.budgetedAmountMinor,
          );
          await _addColumnIfMissing(m, transactions, transactions.payeeId);
          await _createTableIfMissing(m, payees);
          await _createTableIfMissing(m, labels);
          await _createTableIfMissing(m, transactionLabels);
          await _foldBudgetsAndIncomeIntoCategories(this);
          await customStatement('DROP TABLE IF EXISTS budgets');
          await customStatement('DROP TABLE IF EXISTS monthly_incomes');
        }
        if (from < 6) {
          await _addColumnIfMissing(
            m,
            transactions,
            transactions.transferDismissedAt,
          );
          await _createTableIfMissing(m, transfers);
        }
        if (from < 7) {
          await _addColumnIfMissing(m, accounts, accounts.balanceAsOf);
          // Any account with an existing cached balance already reflects
          // every transaction recorded up to now — anchoring it to the
          // present moment (rather than leaving it null, which would
          // default to the account's creation date) stops that history
          // from being summed a second time on top of it.
          // customStatement binds args directly to sqlite3 — pass raw
          // values, not Drift Variable wrappers (those are for customSelect).
          await customStatement(
            'UPDATE accounts SET balance_as_of = ? '
            'WHERE balance_minor IS NOT NULL AND balance_as_of IS NULL',
            [Iso.nowUtc()],
          );
        }
        if (from < 8) {
          await _createTableIfMissing(m, budgetSchedules);
          await _createTableIfMissing(m, budgetPeriods);
          await _createTableIfMissing(m, categoryBudgets);
          await _migrateOverallBudgetsToPeriods(this);
        }
        if (from < 9) {
          await _createTableIfMissing(m, merchantCategoryRules);
        }
      });
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  Future<bool> _tableExists(String table) async {
    final rows = await customSelect(
      "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ?",
      variables: [Variable.withString(table)],
    ).get();
    return rows.isNotEmpty;
  }

  Future<bool> _columnExists(String table, String column) async {
    if (!await _tableExists(table)) return false;
    final rows = await customSelect('PRAGMA table_info($table)').get();
    return rows.any((r) => r.read<String>('name') == column);
  }

  Future<void> _addColumnIfMissing(
    Migrator m,
    TableInfo<Table, dynamic> table,
    GeneratedColumn<Object> column,
  ) async {
    if (await _columnExists(table.actualTableName, column.name)) return;
    await m.addColumn(table, column);
  }

  Future<void> _addColumnIfMissingRaw(
    String table,
    String column,
    String sql,
  ) async {
    if (await _columnExists(table, column)) return;
    await customStatement(sql);
  }

  Future<void> _createTableIfMissing(
    Migrator m,
    TableInfo<Table, dynamic> table,
  ) async {
    if (await _tableExists(table.actualTableName)) return;
    await m.createTable(table);
  }
}

/// `budgets`/`monthly_incomes` no longer have generated Dart tables to
/// query once dropped from `tables:` above, so this reads them with
/// raw SQL — the last thing that happens before [m.deleteTable] below
/// removes them for good.
Future<void> _foldBudgetsAndIncomeIntoCategories(AppDatabase db) async {
  if (await db._tableExists('budgets')) {
    final budgetRows = await db
        .customSelect(
          'SELECT category_id, amount_minor, period FROM budgets '
          'WHERE deleted_at IS NULL ORDER BY period DESC',
        )
        .get();
    final latestBudgetByCategory = <String, int>{};
    for (final row in budgetRows) {
      latestBudgetByCategory.putIfAbsent(
        row.read<String>('category_id'),
        () => row.read<int>('amount_minor'),
      );
    }
    for (final entry in latestBudgetByCategory.entries) {
      await (db.update(
        db.categories,
      )..where((c) => c.id.equals(entry.key))).write(
        CategoriesCompanion(budgetedAmountMinor: Value(entry.value)),
      );
    }
  }

  if (!await db._tableExists('monthly_incomes')) return;

  final incomeRows = await db
      .customSelect(
        'SELECT user_id, label, amount_minor, period, created_at '
        'FROM monthly_incomes WHERE deleted_at IS NULL ORDER BY period DESC',
      )
      .get();
  final latestIncomeByKey = <String, QueryRow>{};
  for (final row in incomeRows) {
    final key =
        '${row.read<String>('user_id')}|'
        '${row.readNullable<String>('label') ?? ''}';
    latestIncomeByKey.putIfAbsent(key, () => row);
  }
  final now = Iso.nowUtc();
  for (final row in latestIncomeByKey.values) {
    final label = row.readNullable<String>('label');
    await db
        .into(db.categories)
        .insert(
          CategoriesCompanion.insert(
            id: Ids.newId(),
            userId: row.read<String>('user_id'),
            createdAt: row.read<String>('created_at'),
            updatedAt: now,
            name: (label == null || label.trim().isEmpty) ? 'Income' : label,
            categoryType: const Value('income'),
            budgetedAmountMinor: Value(row.read<int>('amount_minor')),
            sortOrder: const Value(1000),
          ),
        );
  }
}

/// Recreates the original v2 `monthly_incomes` table shape (before the
/// v3 migration added `label`), for installs upgrading from v1
/// straight past it.
const _createMonthlyIncomesV2Sql = '''
CREATE TABLE IF NOT EXISTS monthly_incomes (
  id TEXT NOT NULL PRIMARY KEY,
  user_id TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  deleted_at TEXT NULL,
  period TEXT NOT NULL,
  amount_minor INTEGER NOT NULL
)
''';

/// v8: fold legacy `YYYY-MM` overall budgets into calendar-month
/// [BudgetPeriods], snapshot standing category limits onto those
/// periods, and ensure every user with data gets a default schedule.
Future<void> _migrateOverallBudgetsToPeriods(AppDatabase db) async {
  final now = Iso.nowUtc();
  final userIds = <String>{};

  final overallRows = await db
      .customSelect(
        'SELECT id, user_id, period, amount_minor, carry_over '
        'FROM overall_budgets WHERE deleted_at IS NULL',
      )
      .get();
  for (final row in overallRows) {
    userIds.add(row.read<String>('user_id'));
  }

  final categoryUsers = await db
      .customSelect(
        'SELECT DISTINCT user_id FROM categories WHERE deleted_at IS NULL',
      )
      .get();
  for (final row in categoryUsers) {
    userIds.add(row.read<String>('user_id'));
  }

  if (userIds.isEmpty) return;

  for (final userId in userIds) {
    final existingSchedule = await (db.select(
      db.budgetSchedules,
    )..where((s) => s.userId.equals(userId) & s.deletedAt.isNull()))
        .getSingleOrNull();
    final scheduleId = existingSchedule?.id ?? Ids.newId();
    if (existingSchedule == null) {
      await db
          .into(db.budgetSchedules)
          .insert(
            BudgetSchedulesCompanion.insert(
              id: scheduleId,
              userId: userId,
              createdAt: now,
              updatedAt: now,
              cadence: BudgetCadence.calendarMonth.dbName,
            ),
          );
    }

    final userOveralls = overallRows.where(
      (r) => r.read<String>('user_id') == userId,
    );
    final periodsCreated = <String>{};

    for (final row in userOveralls) {
      final monthKey = row.read<String>('period');
      final (startUtc, endUtc) = Iso.monthBoundsUtc(monthKey);
      final parts = monthKey.split('-');
      final year = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final label = Iso.periodLabel(
        DateTime(year, month),
        DateTime(year, month + 1),
      );

      final existingPeriod =
          await (db.select(db.budgetPeriods)..where(
                (p) =>
                    p.userId.equals(userId) &
                    p.startAt.equals(startUtc) &
                    p.endAt.equals(endUtc) &
                    p.deletedAt.isNull(),
              ))
              .getSingleOrNull();
      if (existingPeriod != null) {
        periodsCreated.add(existingPeriod.id);
        continue;
      }

      final periodId = Ids.newId();
      await db
          .into(db.budgetPeriods)
          .insert(
            BudgetPeriodsCompanion.insert(
              id: periodId,
              userId: userId,
              createdAt: now,
              updatedAt: now,
              scheduleId: scheduleId,
              startAt: startUtc,
              endAt: endUtc,
              label: label,
              overallAmountMinor: Value(row.read<int>('amount_minor')),
              carryOver: Value(row.read<bool>('carry_over')),
            ),
          );
      periodsCreated.add(periodId);
    }

    // Ensure the current calendar month exists even with no overall row.
    final currentKey = Iso.monthKey(DateTime.now());
    final (curStart, curEnd) = Iso.monthBoundsUtc(currentKey);
    final currentExists =
        await (db.select(db.budgetPeriods)..where(
              (p) =>
                  p.userId.equals(userId) &
                  p.startAt.equals(curStart) &
                  p.endAt.equals(curEnd) &
                  p.deletedAt.isNull(),
            ))
            .getSingleOrNull();
    if (currentExists == null) {
      final parts = currentKey.split('-');
      final year = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final periodId = Ids.newId();
      await db
          .into(db.budgetPeriods)
          .insert(
            BudgetPeriodsCompanion.insert(
              id: periodId,
              userId: userId,
              createdAt: now,
              updatedAt: now,
              scheduleId: scheduleId,
              startAt: curStart,
              endAt: curEnd,
              label: Iso.periodLabel(
                DateTime(year, month),
                DateTime(year, month + 1),
              ),
            ),
          );
      periodsCreated.add(periodId);
    } else {
      periodsCreated.add(currentExists.id);
    }

    final budgetedCategories = await (db.select(
      db.categories,
    )..where(
          (c) =>
              c.userId.equals(userId) &
              c.deletedAt.isNull() &
              c.budgetedAmountMinor.isNotNull(),
        ))
        .get();

    for (final periodId in periodsCreated) {
      for (final category in budgetedCategories) {
        final amount = category.budgetedAmountMinor;
        if (amount == null) continue;
        final exists =
            await (db.select(db.categoryBudgets)..where(
                  (b) =>
                      b.userId.equals(userId) &
                      b.periodId.equals(periodId) &
                      b.categoryId.equals(category.id) &
                      b.deletedAt.isNull(),
                ))
                .getSingleOrNull();
        if (exists != null) continue;
        await db
            .into(db.categoryBudgets)
            .insert(
              CategoryBudgetsCompanion.insert(
                id: Ids.newId(),
                userId: userId,
                createdAt: now,
                updatedAt: now,
                periodId: periodId,
                categoryId: category.id,
                amountMinor: amount,
              ),
            );
      }
    }
  }
}