import 'package:flutter_test/flutter_test.dart';
import 'package:intellispendiq/app/app_services.dart';
import 'package:intellispendiq/budgets/cubit/cubit.dart';
import 'package:intellispendiq/core/ids.dart';
import 'package:intellispendiq/domain/models/enums.dart';
import 'package:intellispendiq/domain/models/transaction_draft.dart';

import '../../support/test_harness.dart';

void main() {
  late AppServices services;

  Future<BudgetsCubit> cubitWith() async {
    services = await createTestServices();
    addTearDown(services.dispose);
    final period = await services.budgetPeriods.ensurePeriodContaining(
      DateTime(2026, 7, 15),
    );
    return BudgetsCubit(
      categories: services.categories,
      budgetPeriods: services.budgetPeriods,
      transactions: services.transactions,
      initialPeriod: period,
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
      expect(cubit.state.totalIncomeMinor, 0);
    });

    test(
      'a budgeted income category surfaces the declared income and remaining amount',
      () async {
        final cubit = await cubitWith();
        addTearDown(cubit.close);
        await cubit.load();

        await services.categories.create(
          'Salary',
          type: CategoryType.income,
          budgetedAmountMinor: 50000,
        );
        final period = cubit.state.budgetPeriod!;
        await services.budgetPeriods.upsertCategoryBudget(
          periodId: period.id,
          categoryId: (await services.categories.byName('Salary'))!.id,
          amountMinor: 50000,
        );
        await Future<void>.delayed(Duration.zero);

        expect(cubit.state.hasIncome, isTrue);
        expect(cubit.state.totalIncomeMinor, 50000);
        expect(cubit.state.remainingMinor, 50000);
      },
    );

    test('multiple income categories sum into totalIncomeMinor', () async {
      final cubit = await cubitWith();
      addTearDown(cubit.close);
      await cubit.load();

      await services.categories.create(
        'Salary',
        type: CategoryType.income,
        budgetedAmountMinor: 40000,
      );
      await services.categories.create(
        'Side hustle',
        type: CategoryType.income,
        budgetedAmountMinor: 10000,
      );
      final period = cubit.state.budgetPeriod!;
      await services.budgetPeriods.upsertCategoryBudget(
        periodId: period.id,
        categoryId: (await services.categories.byName('Salary'))!.id,
        amountMinor: 40000,
      );
      await services.budgetPeriods.upsertCategoryBudget(
        periodId: period.id,
        categoryId: (await services.categories.byName('Side hustle'))!.id,
        amountMinor: 10000,
      );
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.topLevelIncomeCategories, hasLength(greaterThanOrEqualTo(2)));
      expect(cubit.state.budgetedIncomeCategories, hasLength(2));
      expect(cubit.state.totalIncomeMinor, 50000);
    });

    test(
      'an income category without a budget does not count as income',
      () async {
        final cubit = await cubitWith();
        addTearDown(cubit.close);
        await cubit.load();
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
        final period = cubit.state.budgetPeriod!;
        await services.budgetPeriods.upsertCategoryBudget(
          periodId: period.id,
          categoryId: (await services.categories.byName('Salary'))!.id,
          amountMinor: 50000,
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
        final period = cubit.state.budgetPeriod!;
        await services.budgetPeriods.upsertCategoryBudget(
          periodId: period.id,
          categoryId: foodId,
          amountMinor: 100000,
        );
        await services.budgetPeriods.upsertCategoryBudget(
          periodId: period.id,
          categoryId: transportId,
          amountMinor: 30000,
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
      final period = cubit.state.budgetPeriod!;
      await services.budgetPeriods.upsertCategoryBudget(
        periodId: period.id,
        categoryId: foodId,
        amountMinor: 100000,
      );
      await services.budgetPeriods.upsertCategoryBudget(
        periodId: period.id,
        categoryId: transportId,
        amountMinor: 20000,
      );
      await Future<void>.delayed(Duration.zero);

      await cubit.transferBudget(
        fromCategoryId: foodId,
        toCategoryId: transportId,
        amount: '200',
      );
      await Future<void>.delayed(Duration.zero);

      expect(
        cubit.state.categories
            .firstWhere((c) => c.id == foodId)
            .budgetedAmountMinor,
        80000,
      );
      expect(
        cubit.state.categories
            .firstWhere((c) => c.id == transportId)
            .budgetedAmountMinor,
        40000,
      );
    });

    test('refuses to transfer more than is budgeted', () async {
      final cubit = await cubitWith();
      addTearDown(cubit.close);
      await cubit.load();

      final foodId = (await services.categories.byName('Food'))!.id;
      final transportId = (await services.categories.byName('Transport'))!.id;
      final period = cubit.state.budgetPeriod!;
      await services.budgetPeriods.upsertCategoryBudget(
        periodId: period.id,
        categoryId: foodId,
        amountMinor: 10000,
      );
      await Future<void>.delayed(Duration.zero);

      await cubit.transferBudget(
        fromCategoryId: foodId,
        toCategoryId: transportId,
        amount: '300',
      );

      expect(cubit.state.status, BudgetsStatus.invalid);
    });
  });

  group('BudgetsCubit hierarchical budgets', () {
    test(
      'a top-level category rolls up its subcategories\' spend',
      () async {
        final cubit = await cubitWith();
        addTearDown(cubit.close);
        await cubit.load();

        final food = (await services.categories.byName('Food'))!;
        final takeaways = await services.categories.create(
          'Takeaways',
          parentId: food.id,
          budgetedAmountMinor: 20000,
        );
        final period = cubit.state.budgetPeriod!;
        await services.budgetPeriods.upsertCategoryBudget(
          periodId: period.id,
          categoryId: food.id,
          amountMinor: 100000,
        );
        await services.budgetPeriods.upsertCategoryBudget(
          periodId: period.id,
          categoryId: takeaways.id,
          amountMinor: 20000,
        );
        await Future<void>.delayed(Duration.zero);

        // Spend posted directly on Food...
        await addConfirmedSpend(10000, categoryId: food.id);
        // ...and spend posted on its subcategory...
        await addConfirmedSpend(5000, categoryId: takeaways.id);
        await cubit.load();
        await Future<void>.delayed(Duration.zero);

        // ...both count toward Food's own progress.
        expect(cubit.state.spentFor(food.id), 15000);
      },
    );
  });

  group('BudgetsCubit visible expense categories', () {
    test('hides unbudgeted categories with no spend', () async {
      final cubit = await cubitWith();
      addTearDown(cubit.close);
      await cubit.load();
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.visibleExpenseCategories, isEmpty);
      expect(cubit.state.isEmpty, isTrue);
    });

    test('shows an unbudgeted category once it has confirmed spend', () async {
      final cubit = await cubitWith();
      addTearDown(cubit.close);
      await cubit.load();

      final food = (await services.categories.byName('Food'))!;
      await addConfirmedSpend(2500, categoryId: food.id);
      await cubit.load();
      await Future<void>.delayed(Duration.zero);

      expect(
        cubit.state.visibleExpenseCategories.map((c) => c.id),
        contains(food.id),
      );
      expect(cubit.state.spentFor(food.id), 2500);
      expect(cubit.state.budgetedExpenseCategories, isEmpty);
    });

    test(
      'shows a parent when only a subcategory has confirmed spend',
      () async {
        final cubit = await cubitWith();
        addTearDown(cubit.close);
        await cubit.load();

        final food = (await services.categories.byName('Food'))!;
        final takeaways = await services.categories.create(
          'Takeaways',
          parentId: food.id,
        );
        await addConfirmedSpend(4000, categoryId: takeaways.id);
        await cubit.load();
        await Future<void>.delayed(Duration.zero);

        expect(
          cubit.state.visibleExpenseCategories.map((c) => c.id),
          contains(food.id),
        );
        expect(cubit.state.spentFor(food.id), 4000);
        expect(food.hasBudget, isFalse);
      },
    );

    test(
      'shows a parent when only a subcategory has money assigned',
      () async {
        final cubit = await cubitWith();
        addTearDown(cubit.close);
        await cubit.load();

        final food = (await services.categories.byName('Food'))!;
        final takeaways = await services.categories.create(
          'Takeaways',
          parentId: food.id,
          budgetedAmountMinor: 15000,
        );
        final period = cubit.state.budgetPeriod!;
        await services.budgetPeriods.upsertCategoryBudget(
          periodId: period.id,
          categoryId: takeaways.id,
          amountMinor: 15000,
        );
        await Future<void>.delayed(Duration.zero);

        expect(
          cubit.state.visibleExpenseCategories.map((c) => c.id),
          contains(food.id),
        );
        expect(cubit.state.budgetedExpenseCategories, isEmpty);
      },
    );
  });

  group('BudgetsCubit shiftPeriod', () {
    test('moves the window and reloads spend for the new period', () async {
      final cubit = await cubitWith();
      addTearDown(cubit.close);
      await cubit.load();
      await addConfirmedSpend(10000);
      await cubit.load();
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.periodLabel, '01/07/2026 – 31/07/2026');
      expect(cubit.state.totalSpent, 10000);

      await cubit.setOverallBudget('5000');
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.hasOverallBudget, isTrue);

      cubit.shiftPeriod(1);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(cubit.state.periodLabel, '01/08/2026 – 31/08/2026');
      expect(cubit.state.totalSpent, 0);
    });

    test('setOverallBudget writes to the currently selected period', () async {
      final cubit = await cubitWith();
      addTearDown(cubit.close);
      await cubit.load();

      cubit.shiftPeriod(1);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await cubit.setOverallBudget('3000');
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.periodLabel, '01/08/2026 – 31/08/2026');
      expect(cubit.state.totalPlannedMinor, 300000);

      final period = cubit.state.budgetPeriod!;
      expect(period.overallAmountMinor, 300000);
    });
  });
}
