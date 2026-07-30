import 'package:flutter_test/flutter_test.dart';
import 'package:intellispendiq/app/app_services.dart';
import 'package:intellispendiq/budgets/cubit/cubit.dart';
import 'package:intellispendiq/core/ids.dart';
import 'package:intellispendiq/domain/models/enums.dart';
import 'package:intellispendiq/domain/models/transaction_draft.dart';

import '../../support/test_harness.dart';

void main() {
  late AppServices services;
  const period = '2026-07';

  Future<BudgetsCubit> cubitWith() async {
    services = await createTestServices();
    addTearDown(services.dispose);
    return BudgetsCubit(
      categories: services.categories,
      overallBudgets: services.overallBudgets,
      transactions: services.transactions,
      period: period,
    );
  }

  Future<void> addConfirmedSpend(int amountMinor, {String? categoryId}) async {
    final foodCategoryId =
        categoryId ?? (await services.categories.byName('Food'))!.id;
    final accountId = (await services.accounts.getDefault()).id;
    await services.transactions.insertDraft(
      TransactionDraft(
        amountMinor: amountMinor,
        direction: TxDirection.debit,
        source: TxSource.manual,
        transactedAt: DateTime(2026, 7, 10),
        categoryId: foodCategoryId,
        merchant: 'Test',
      ),
      accountId: accountId,
      idempotencyKey: 'test:${Ids.newId()}',
      status: TxStatus.confirmed,
    );
  }

  group('BudgetsCubit income tracking', () {
    test('starts with no income set', () async {
      final cubit = await cubitWith();
      addTearDown(cubit.close);

      await cubit.load();

      expect(cubit.state.hasIncome, isFalse);
      expect(cubit.state.remainingMinor, 0);
    });

    test(
      'a budgeted income category surfaces the declared income and remaining amount',
      () async {
        final cubit = await cubitWith();
        addTearDown(cubit.close);
        await cubit.load();
        await addConfirmedSpend(30000);

        await services.categories.create(
          'Salary',
          type: CategoryType.income,
          budgetedAmountMinor: 50000,
        );
        await Future<void>.delayed(Duration.zero);

        expect(cubit.state.hasIncome, isTrue);
        expect(cubit.state.totalIncomeMinor, 50000);
        expect(cubit.state.totalSpent, 30000);
        expect(cubit.state.remainingMinor, 20000);
      },
    );

    test(
      'multiple income categories sum into totalIncomeMinor',
      () async {
        final cubit = await cubitWith();
        addTearDown(cubit.close);
        await cubit.load();

        await services.categories.create(
          'Salary',
          type: CategoryType.income,
          budgetedAmountMinor: 50000,
        );
        await Future<void>.delayed(Duration.zero);
        await services.categories.create(
          'Side hustle',
          type: CategoryType.income,
          budgetedAmountMinor: 15000,
        );
        await Future<void>.delayed(Duration.zero);

        expect(cubit.state.budgetedIncomeCategories, hasLength(2));
        expect(cubit.state.totalIncomeMinor, 65000);
      },
    );

    test(
      'an income category without a budget does not count as income',
      () async {
        final cubit = await cubitWith();
        addTearDown(cubit.close);
        await cubit.load();

        // The seeded "Income" category has no budget by default.
        await Future<void>.delayed(Duration.zero);

        expect(cubit.state.hasIncome, isFalse);
      },
    );

    test(
      'spending after income is set updates total spend on reload',
      () async {
        final cubit = await cubitWith();
        addTearDown(cubit.close);
        await cubit.load();
        await services.categories.create(
          'Salary',
          type: CategoryType.income,
          budgetedAmountMinor: 50000,
        );
        await Future<void>.delayed(Duration.zero);

        await addConfirmedSpend(10000);
        await cubit.load();
        await Future<void>.delayed(Duration.zero);

        expect(cubit.state.totalSpent, 10000);
        expect(cubit.state.hasIncome, isTrue);
      },
    );
  });

  group('BudgetsCubit overall vs category budgets', () {
    test(
      'totalPlannedMinor comes from overall budget, not categories',
      () async {
        final cubit = await cubitWith();
        addTearDown(cubit.close);
        await cubit.load();

        final foodId = (await services.categories.byName('Food'))!.id;
        final transportId = (await services.categories.byName('Transport'))!.id;
        await services.categories.update(foodId, budgetedAmountMinor: 100000);
        await services.categories.update(
          transportId,
          budgetedAmountMinor: 30000,
        );
        await Future<void>.delayed(Duration.zero);

        expect(cubit.state.totalPlannedMinor, 0);
        expect(cubit.state.totalAllocatedMinor, 130000);

        await cubit.setOverallBudget('5000');
        await Future<void>.delayed(Duration.zero);

        expect(cubit.state.hasOverallBudget, isTrue);
        expect(cubit.state.totalPlannedMinor, 500000);
        expect(cubit.state.totalAllocatedMinor, 130000);
      },
    );

    test('deleteOverallBudget clears the planned total', () async {
      final cubit = await cubitWith();
      addTearDown(cubit.close);
      await cubit.load();
      await cubit.setOverallBudget('5000');
      await Future<void>.delayed(Duration.zero);

      await cubit.deleteOverallBudget();
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.hasOverallBudget, isFalse);
      expect(cubit.state.totalPlannedMinor, 0);
    });

    test('setOverallBudget rejects a non-positive amount', () async {
      final cubit = await cubitWith();
      addTearDown(cubit.close);
      await cubit.load();

      await cubit.setOverallBudget('0');

      expect(cubit.state.status, BudgetsStatus.invalid);
      expect(cubit.state.hasOverallBudget, isFalse);
    });
  });

  group('BudgetsCubit transferBudget', () {
    test('moves budget between two expense categories', () async {
      final cubit = await cubitWith();
      addTearDown(cubit.close);
      await cubit.load();

      final foodId = (await services.categories.byName('Food'))!.id;
      final transportId = (await services.categories.byName('Transport'))!.id;
      await services.categories.update(foodId, budgetedAmountMinor: 100000);
      await services.categories.update(
        transportId,
        budgetedAmountMinor: 20000,
      );
      await Future<void>.delayed(Duration.zero);

      await cubit.transferBudget(
        fromCategoryId: foodId,
        toCategoryId: transportId,
        amount: '300',
      );
      await Future<void>.delayed(Duration.zero);

      final food = cubit.state.categories.firstWhere((c) => c.id == foodId);
      final transport = cubit.state.categories.firstWhere(
        (c) => c.id == transportId,
      );
      expect(food.budgetedAmountMinor, 70000);
      expect(transport.budgetedAmountMinor, 50000);
    });

    test('refuses to transfer more than is budgeted', () async {
      final cubit = await cubitWith();
      addTearDown(cubit.close);
      await cubit.load();

      final foodId = (await services.categories.byName('Food'))!.id;
      final transportId = (await services.categories.byName('Transport'))!.id;
      await services.categories.update(foodId, budgetedAmountMinor: 10000);
      await Future<void>.delayed(Duration.zero);

      await cubit.transferBudget(
        fromCategoryId: foodId,
        toCategoryId: transportId,
        amount: '300',
      );

      expect(cubit.state.status, BudgetsStatus.invalid);
    });
  });
}
