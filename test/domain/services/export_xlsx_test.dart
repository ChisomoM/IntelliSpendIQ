import 'dart:io';

import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intellispendiq/app/app_services.dart';
import 'package:intellispendiq/core/ids.dart';
import 'package:intellispendiq/domain/models/budget_period.dart';
import 'package:intellispendiq/domain/models/enums.dart';
import 'package:intellispendiq/domain/models/transaction_draft.dart';
import 'package:intellispendiq/domain/services/backup_service.dart';

import '../../support/test_harness.dart';

BackupService _backup(AppServices s) => BackupService(
  transactions: s.transactions,
  accounts: s.accounts,
  categories: s.categories,
  overallBudgets: s.overallBudgets,
  payees: s.payees,
  labels: s.labels,
  transfers: s.transfers,
  savingsGoals: s.savingsGoals,
  wishlist: s.wishlist,
  budgetPeriods: s.budgetPeriods,
  tempDirectory: () async => Directory.systemTemp,
);

String _text(Data? cell) {
  final value = cell?.value;
  return value is TextCellValue ? (value.value.text ?? '') : '';
}

num? _number(Data? cell) => switch (cell?.value) {
  IntCellValue(:final value) => value,
  DoubleCellValue(:final value) => value,
  _ => null,
};

/// A Budget-sheet row, keyed so a test can say "the Food row".
class _BudgetRow {
  _BudgetRow(List<Data?> cells)
    : cycle = _text(cells[0]),
      type = _text(cells[1]),
      category = _text(cells[2]),
      subCategory = _text(cells[3]),
      budgeted = _number(cells[4]),
      paid = _number(cells[5]),
      planned = _number(cells[6]),
      remaining = _number(cells[7]);

  final String cycle;
  final String type;
  final String category;
  final String subCategory;
  final num? budgeted;
  final num? paid;
  final num? planned;
  final num? remaining;
}

void main() {
  late AppServices services;
  late BudgetPeriod july;

  Future<void> record(
    num amount, {
    required String categoryId,
    TxDirection direction = TxDirection.debit,
    TxStatus status = TxStatus.confirmed,
    DateTime? on,
  }) async {
    final accountId = (await services.accounts.getDefault()).id;
    await services.transactions.insertDraft(
      TransactionDraft(
        amountMinor: (amount * 100).round(),
        direction: direction,
        source: TxSource.manual,
        transactedAt: on ?? DateTime(2026, 7, 10),
        categoryId: categoryId,
        merchant: 'Shop',
      ),
      accountId: accountId,
      idempotencyKey: 'test:${Ids.newId()}',
      status: status,
      periodId: july.id,
    );
  }

  Future<Excel> exported({ExportRange range = ExportRange.allTime}) async {
    final file = await _backup(services).exportTransactionsXlsx(range: range);
    addTearDown(file.delete);
    expect(file.path, endsWith('.xlsx'));
    return Excel.decodeBytes(await file.readAsBytes());
  }

  List<_BudgetRow> budgetRows(Excel workbook) => [
    for (final row in workbook['Budget'].rows.skip(1))
      if (_text(row[1]).isNotEmpty) _BudgetRow(row),
  ];

  setUp(() async {
    services = await createTestServices();
    july = await services.budgetPeriods.ensurePeriodContaining(
      DateTime(2026, 7, 10),
    );
  });
  tearDown(() async => services.dispose());

  test('writes a Transactions sheet and a Budget sheet', () async {
    final food = (await services.categories.byName('Food'))!;
    await record(50, categoryId: food.id);

    final workbook = await exported();

    expect(workbook.tables.keys, containsAll(['Transactions', 'Budget']));
    final header = workbook['Transactions'].rows.first.map(_text).toList();
    expect(header, [
      'Date',
      'Merchant',
      'Description',
      'Category',
      'Sub category',
      'Account',
      'To account',
      'Direction',
      'Amount',
      'Currency',
      'Status',
      'Source',
    ]);
    final first = workbook['Transactions'].rows[1];
    expect(_text(first[1]), 'Shop');
    expect(_text(first[3]), 'Food');
    expect(_number(first[8]), 50);
  });

  test(
    'Budget sheet: sub category under its parent, parent rolled up',
    () async {
      final food = (await services.categories.byName('Food'))!;
      final groceries = await services.categories.create(
        'Groceries',
        parentId: food.id,
      );
      await services.budgetPeriods.setOverallAmount(
        periodId: july.id,
        amountMinor: 300000,
      );
      await services.budgetPeriods.upsertCategoryBudget(
        periodId: july.id,
        categoryId: food.id,
        amountMinor: 150000,
      );
      await services.budgetPeriods.upsertCategoryBudget(
        periodId: july.id,
        categoryId: groceries.id,
        amountMinor: 50000,
      );
      await record(100, categoryId: food.id);
      await record(200, categoryId: groceries.id);
      await record(50, categoryId: food.id, status: TxStatus.planned);

      final rows = budgetRows(await exported());

      final overall = rows.singleWhere((r) => r.type == 'Overall');
      expect(overall.budgeted, 3000);
      expect(overall.paid, 300);
      expect(overall.planned, 50);
      expect(overall.remaining, 2650);

      final foodRow = rows.singleWhere(
        (r) => r.category == 'Food' && r.subCategory.isEmpty,
      );
      expect(foodRow.type, 'Expense');
      expect(foodRow.budgeted, 1500);
      // Its own 100 plus the 200 spent in Groceries.
      expect(foodRow.paid, 300);
      expect(foodRow.planned, 50);
      expect(foodRow.remaining, 1150);

      final groceriesRow = rows.singleWhere(
        (r) => r.subCategory == 'Groceries',
      );
      expect(groceriesRow.category, 'Food');
      expect(groceriesRow.budgeted, 500);
      expect(groceriesRow.paid, 200);
      expect(groceriesRow.planned, 0);
      expect(groceriesRow.remaining, 300);

      // The sub category comes straight after its parent.
      final names = [for (final r in rows) '${r.category}/${r.subCategory}'];
      expect(
        names.indexOf('Food/Groceries'),
        names.indexOf('Food/') + 1,
      );
      expect(rows.every((r) => r.cycle == july.label), isTrue);
    },
  );

  test('Budget sheet: income planned against received', () async {
    final salary = await services.categories.create(
      'Salary',
      type: CategoryType.income,
    );
    await services.budgetPeriods.upsertCategoryBudget(
      periodId: july.id,
      categoryId: salary.id,
      amountMinor: 800000,
    );
    await record(
      5000,
      categoryId: salary.id,
      direction: TxDirection.credit,
    );
    await record(
      1000,
      categoryId: salary.id,
      direction: TxDirection.credit,
      status: TxStatus.planned,
    );

    final row = budgetRows(await exported()).singleWhere(
      (r) => r.category == 'Salary',
    );

    expect(row.type, 'Income');
    expect(row.budgeted, 8000);
    expect(row.paid, 5000);
    expect(row.planned, 1000);
    // Income: what is still to come, not reduced by planned entries.
    expect(row.remaining, 3000);
  });

  test(
    'Budget sheet: unbudgeted spending and deleted categories still show',
    () async {
      final pets = await services.categories.create('Pets');
      await record(30, categoryId: pets.id);
      await services.categories.delete(pets.id);

      final rows = budgetRows(await exported());

      final row = rows.singleWhere((r) => r.category == 'Deleted category');
      expect(row.paid, 30);
      expect(row.budgeted, isNull);
      expect(row.remaining, isNull);
    },
  );

  test('a date range keeps only the cycles that overlap it', () async {
    final food = (await services.categories.byName('Food'))!;
    await record(100, categoryId: food.id);

    final inside = await exported(
      range: ExportRange(
        from: DateTime(2026, 7, 20),
        toExclusive: DateTime(2026, 8, 5),
      ),
    );
    expect(budgetRows(inside), isNotEmpty);
    // The note tells the reader partly-covered cycles are shown whole.
    expect(
      inside['Budget'].rows.expand((r) => r).map(_text),
      contains('Cycles that overlap the chosen dates are shown in full.'),
    );

    final outside = await exported(
      range: ExportRange(
        from: DateTime(2026, 8),
        toExclusive: DateTime(2026, 9),
      ),
    );
    expect(budgetRows(outside), isEmpty);
    expect(
      outside['Budget'].rows.expand((r) => r).map(_text),
      contains('No budget cycles in this range.'),
    );
  });
}
