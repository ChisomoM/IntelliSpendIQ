import 'package:drift/drift.dart';
import 'package:intellispendiq/data/db/tables.dart';

export 'package:drift/drift.dart' show Value;

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    Accounts,
    Categories,
    Transactions,
    Budgets,
    MonthlyIncomes,
    RawCaptures,
    Settings,
    CustomSenderIds,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) await m.createTable(monthlyIncomes);
      if (from < 3) {
        await m.addColumn(transactions, transactions.receiptPath);
        // Multiple income streams per month need `label` in the
        // unique key rather than just `{userId, period}`, which only
        // a full table recreation can change.
        await m.alterTable(
          TableMigration(monthlyIncomes, newColumns: [monthlyIncomes.label]),
        );
        await m.createTable(customSenderIds);
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
