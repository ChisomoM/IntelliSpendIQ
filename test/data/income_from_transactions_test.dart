import 'package:flutter_test/flutter_test.dart';
import 'package:intellispendiq/app/app_services.dart';
import 'package:intellispendiq/core/ids.dart';
import 'package:intellispendiq/data/repositories/budget_period_repository.dart';
import 'package:intellispendiq/domain/models/budget_period.dart';
import 'package:intellispendiq/domain/models/category.dart';
import 'package:intellispendiq/domain/models/enums.dart';
import 'package:intellispendiq/domain/models/transaction_draft.dart';

import '../support/test_harness.dart';

void main() {
  late AppServices services;
  late BudgetPeriod july;
  late Category salary;
  late String accountId;

  /// Records money the way any capture path does: just a transaction with
  /// a category, nothing to do with a budget line or "mark as paid".
  Future<String> record(
    int amountMinor, {
    String? categoryId,
    TxDirection direction = TxDirection.credit,
    TxStatus status = TxStatus.confirmed,
    DateTime? on,
  }) async {
    final tx = await services.transactions.insertDraft(
      TransactionDraft(
        amountMinor: amountMinor,
        direction: direction,
        source: TxSource.sms,
        transactedAt: on ?? DateTime(2026, 7, 20),
        categoryId: categoryId ?? salary.id,
      ),
      accountId: accountId,
      idempotencyKey: 'test:${Ids.newId()}',
      status: status,
    );
    return tx.id;
  }

  Future<IncomeTotals> totals() =>
      services.budgetPeriods.incomeTotalsForPeriod(july.id);

  setUp(() async {
    services = await createTestServices();
    july = await services.budgetPeriods.ensurePeriodContaining(
      DateTime(2026, 7, 10),
    );
    salary = await services.categories.create(
      'Salary',
      type: CategoryType.income,
    );
    accountId = (await services.accounts.getDefault()).id;
  });
  tearDown(() async => services.dispose());

  test(
    'income recorded with a category counts, with no plan and no tick',
    () async {
      await record(500000);

      final result = await totals();

      expect(result.actualMinor, 500000);
      expect(result.provisionalMinor, 500000);
      expect(result.receivedBySource, {salary.id: 500000});
    },
  );

  test('a sub category counts under its parent source', () async {
    final bonus = await services.categories.create(
      'Bonus',
      type: CategoryType.income,
      parentId: salary.id,
    );
    await record(400000);
    await record(100000, categoryId: bonus.id);

    final result = await totals();

    expect(result.receivedBySource, {salary.id: 500000});
    expect(result.actualMinor, 500000);
  });

  test(
    'part of a plan received: actual is what arrived, expected is the plan',
    () async {
      await services.budgetPeriods.upsertCategoryBudget(
        periodId: july.id,
        categoryId: salary.id,
        amountMinor: 800000,
      );
      await record(300000);

      final result = await totals();

      expect(result.actualMinor, 300000);
      expect(result.provisionalMinor, 800000);
      expect(result.plannedBySource, {salary.id: 800000});
    },
  );

  test('more than planned counts in full', () async {
    await services.budgetPeriods.upsertCategoryBudget(
      periodId: july.id,
      categoryId: salary.id,
      amountMinor: 800000,
    );
    await record(1000000);

    final result = await totals();

    expect(result.actualMinor, 1000000);
    expect(result.provisionalMinor, 1000000);
  });

  test(
    'only confirmed credits in an income category inside the cycle count',
    () async {
      final food = (await services.categories.byName('Food'))!;
      await record(100000, status: TxStatus.planned);
      await record(200000, direction: TxDirection.debit);
      await record(300000, categoryId: food.id);
      await record(400000, on: DateTime(2026, 8, 20));
      final deleted = await record(500000);
      await services.transactions.softDelete(deleted);
      final accountId = (await services.accounts.getDefault()).id;
      await services.transactions.insertDraft(
        TransactionDraft(
          amountMinor: 600000,
          direction: TxDirection.credit,
          source: TxSource.sms,
          transactedAt: DateTime(2026, 7, 20),
        ),
        accountId: accountId,
        idempotencyKey: 'test:${Ids.newId()}',
        status: TxStatus.confirmed,
      );

      final result = await totals();

      expect(result.actualMinor, 0);
      expect(result.provisionalMinor, 0);
    },
  );

  test(
    'marking a source paid is counted once, not on top of the receipt',
    () async {
      await services.budgetPeriods.upsertCategoryBudget(
        periodId: july.id,
        categoryId: salary.id,
        amountMinor: 800000,
      );
      await services.budgetPeriods.markCategoryBudgetPaid(
        periodId: july.id,
        categoryId: salary.id,
        accountId: accountId,
        amountMinor: 800000,
        transactedAt: DateTime(2026, 7, 25),
      );

      final result = await totals();

      expect(result.actualMinor, 800000);
      expect(result.provisionalMinor, 800000);
    },
  );

  test('recording part of the plan leaves the plan alone', () async {
    await services.budgetPeriods.upsertCategoryBudget(
      periodId: july.id,
      categoryId: salary.id,
      amountMinor: 800000,
    );
    await services.budgetPeriods.markCategoryBudgetPaid(
      periodId: july.id,
      categoryId: salary.id,
      accountId: accountId,
      amountMinor: 300000,
      transactedAt: DateTime(2026, 7, 25),
    );

    final budgets = await services.budgetPeriods.categoryBudgetsFor(july.id);
    final result = await totals();

    expect(budgets.single.amountMinor, 800000);
    expect(result.actualMinor, 300000);
    expect(result.provisionalMinor, 800000);
  });

  test('deleting the transaction takes the income away again', () async {
    final id = await record(500000);
    expect((await totals()).actualMinor, 500000);

    await services.transactions.softDelete(id);

    expect((await totals()).actualMinor, 0);
  });

  test('re-categorising a credit moves it in and out of income', () async {
    final food = (await services.categories.byName('Food'))!;
    final id = await record(500000, categoryId: food.id);
    expect((await totals()).actualMinor, 0);

    await services.transactions.updateFields(id, categoryId: salary.id);

    expect((await totals()).actualMinor, 500000);
  });
}
