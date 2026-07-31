import 'package:drift/drift.dart';
import 'package:intellispendiq/core/ids.dart';
import 'package:intellispendiq/core/time.dart';
import 'package:intellispendiq/data/db/tables.dart';

export 'package:drift/drift.dart' show Value;

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    Accounts,
    Categories,
    Transactions,
    OverallBudgets,
    Payees,
    Labels,
    TransactionLabels,
    Transfers,
    RawCaptures,
    Settings,
    CustomSenderIds,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 8;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) await customStatement(_createMonthlyIncomesV2Sql);
      if (from < 3) {
        await m.addColumn(transactions, transactions.receiptPath);
        await customStatement(
          'ALTER TABLE monthly_incomes ADD COLUMN label TEXT NULL',
        );
        await m.createTable(customSenderIds);
      }
      if (from < 4) await m.createTable(overallBudgets);
      if (from < 5) {
        await m.addColumn(categories, categories.categoryType);
        await m.addColumn(categories, categories.budgetedAmountMinor);
        await m.addColumn(transactions, transactions.payeeId);
        await m.createTable(payees);
        await m.createTable(labels);
        await m.createTable(transactionLabels);
        await _foldBudgetsAndIncomeIntoCategories(this);
        await m.deleteTable('budgets');
        await m.deleteTable('monthly_incomes');
      }
      if (from < 6) {
        await m.addColumn(transactions, transactions.transferDismissedAt);
        await m.createTable(transfers);
      }
      if (from < 7) {
        await m.addColumn(accounts, accounts.balanceAsOf);
        // Any account with an existing cached balance already reflects
        // every transaction recorded up to now — anchoring it to the
        // present moment (rather than leaving it null, which would
        // default to the account's creation date) stops that history
        // from being summed a second time on top of it.
        await customStatement(
          'UPDATE accounts SET balance_as_of = ? WHERE balance_minor IS NOT NULL',
          [Variable.withString(Iso.nowUtc())],
        );
      }
      if (from < 8) {
        // Category icons used to be emoji glyphs. Rewrite the ones we
        // seeded into the icon-registry keys that replaced them.
        //
        // A custom category whose icon the user pasted themselves has no
        // key to map to and is left alone — `CategoryIcons.resolve`
        // still renders it, falling back to a generic icon.
        for (final pair in _v8EmojiToIconKey.entries) {
          await customStatement(
            'UPDATE categories SET icon = ? WHERE icon = ?',
            [Variable.withString(pair.value), Variable.withString(pair.key)],
          );
        }
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}

/// `budgets`/`monthly_incomes` no longer have generated Dart tables to
/// query once dropped from `tables:` above, so this reads them with
/// raw SQL — the last thing that happens before [m.deleteTable] below
/// removes them for good.
/// The emoji the v1 seeds shipped with, mapped to the icon-registry keys
/// that replaced them in v8.
///
/// Deliberately a frozen literal rather than a read of
/// `CategoryIcons.legacyPairs`: a migration describes one historical
/// moment, so it must not change behaviour when someone later edits the
/// live registry. It also keeps the data layer from importing `ui/`.
const _v8EmojiToIconKey = <String, String>{
  '🍲': 'food',
  '🚌': 'transport',
  '📱': 'airtime',
  '🔁': 'transfer',
  '🛍️': 'shopping',
  '🛍': 'shopping',
  '🧾': 'bills',
  '💰': 'income',
  '🏦': 'fees',
  '❓': 'unknown',
  '📦': 'other',
};

Future<void> _foldBudgetsAndIncomeIntoCategories(AppDatabase db) async {
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
