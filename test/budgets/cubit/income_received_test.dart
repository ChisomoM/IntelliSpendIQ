import 'package:flutter_test/flutter_test.dart';
import 'package:intellispendiq/app/app_services.dart';
import 'package:intellispendiq/budgets/cubit/cubit.dart';
import 'package:intellispendiq/core/ids.dart';
import 'package:intellispendiq/domain/models/category.dart';
import 'package:intellispendiq/domain/models/enums.dart';
import 'package:intellispendiq/domain/models/transaction_draft.dart';

import '../../support/test_harness.dart';

void main() {
  late AppServices services;
  late BudgetsCubit cubit;
  late Category salary;
  late String accountId;

  Future<String> receive(
    int amountMinor, {
    String? categoryId,
    TxStatus status = TxStatus.confirmed,
  }) async {
    final tx = await services.transactions.insertDraft(
      TransactionDraft(
        amountMinor: amountMinor,
        direction: TxDirection.credit,
        source: TxSource.sms,
        transactedAt: DateTime(2026, 7, 20),
        categoryId: categoryId,
      ),
      accountId: accountId,
      idempotencyKey: 'test:${Ids.newId()}',
      status: status,
    );
    return tx.id;
  }

  /// Waits for the cubit to reach a state, as the screen would.
  Future<void> until(bool Function(BudgetsState) reached) async {
    if (reached(cubit.state)) return;
    await cubit.stream
        .firstWhere(reached)
        .timeout(
          const Duration(seconds: 5),
          onTimeout: () =>
              fail('never reached the expected state: ${cubit.state}'),
        );
  }

  setUp(() async {
    services = await createTestServices();
    final period = await services.budgetPeriods.ensurePeriodContaining(
      DateTime(2026, 7, 15),
    );
    salary = await services.categories.create(
      'Salary',
      type: CategoryType.income,
    );
    accountId = (await services.accounts.getDefault()).id;
    cubit = BudgetsCubit(
      categories: services.categories,
      budgetPeriods: services.budgetPeriods,
      transactions: services.transactions,
      initialPeriod: period,
    );
    await cubit.load();
    await until((s) => s.status == BudgetsStatus.loaded);
  });
  tearDown(() async {
    await cubit.close();
    await services.dispose();
  });

  test(
    'income that arrives shows up as it is recorded, with no mark as paid',
    () async {
      expect(cubit.state.actualIncomeMinor, 0);

      await receive(500000, categoryId: salary.id);
      await until((s) => s.actualIncomeMinor == 500000);

      expect(cubit.state.receivedByCategory, {salary.id: 500000});
      expect(cubit.state.incomeStatusByCategory[salary.id], IncomeStatus.paid);
      // What is left to spend follows the money that really came in.
      expect(cubit.state.remainingMinor, 500000);
    },
  );

  test(
    'a credit with no category waits, then counts once it has one',
    () async {
      final id = await receive(500000);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(cubit.state.actualIncomeMinor, 0);

      await services.transactions.updateFields(id, categoryId: salary.id);
      await until((s) => s.actualIncomeMinor == 500000);

      expect(cubit.state.incomeStatusByCategory[salary.id], IncomeStatus.paid);
    },
  );

  test(
    'part of a plan received reads as part paid, then paid in full',
    () async {
      final period = cubit.state.budgetPeriod!;
      await services.budgetPeriods.upsertCategoryBudget(
        periodId: period.id,
        categoryId: salary.id,
        amountMinor: 800000,
      );
      await until((s) => s.provisionalIncomeMinor == 800000);
      expect(
        cubit.state.incomeStatusByCategory[salary.id],
        IncomeStatus.unpaid,
      );

      await receive(300000, categoryId: salary.id);
      await until((s) => s.actualIncomeMinor == 300000);
      expect(
        cubit.state.incomeStatusByCategory[salary.id],
        IncomeStatus.unpaid,
      );
      expect(cubit.state.provisionalIncomeMinor, 800000);

      await receive(500000, categoryId: salary.id);
      await until((s) => s.actualIncomeMinor == 800000);
      expect(cubit.state.incomeStatusByCategory[salary.id], IncomeStatus.paid);
    },
  );

  test('deleting the transaction takes the income away', () async {
    final id = await receive(500000, categoryId: salary.id);
    await until((s) => s.actualIncomeMinor == 500000);

    await services.transactions.softDelete(id);
    await until((s) => s.actualIncomeMinor == 0);

    expect(cubit.state.receivedByCategory, isEmpty);
  });

  test('marking a source paid still works and is not counted twice', () async {
    final period = cubit.state.budgetPeriod!;
    await services.budgetPeriods.upsertCategoryBudget(
      periodId: period.id,
      categoryId: salary.id,
      amountMinor: 800000,
    );
    await until((s) => s.provisionalIncomeMinor == 800000);

    await cubit.markIncomePaid(
      categoryId: salary.id,
      accountId: accountId,
      amountMinor: 800000,
      transactedAt: DateTime(2026, 7, 25),
    );
    // The receipt transaction and the paid line are written one after the
    // other, so wait for both to have been seen.
    await until(
      (s) =>
          s.actualIncomeMinor == 800000 &&
          s.receiptTransactionByCategory.isNotEmpty,
    );

    expect(cubit.state.provisionalIncomeMinor, 800000);
    expect(cubit.state.incomeStatusByCategory[salary.id], IncomeStatus.paid);
    expect(cubit.state.receiptTransactionByCategory.keys, [salary.id]);
  });
}
