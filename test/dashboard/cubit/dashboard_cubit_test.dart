import 'package:flutter_test/flutter_test.dart';
import 'package:intellispendiq/app/app_services.dart';
import 'package:intellispendiq/core/ids.dart';
import 'package:intellispendiq/dashboard/cubit/cubit.dart';
import 'package:intellispendiq/domain/models/enums.dart';
import 'package:intellispendiq/domain/models/transaction_draft.dart';

import '../../support/test_harness.dart';

void main() {
  late AppServices services;

  Future<DashboardCubit> cubitWith() async {
    services = await createTestServices();
    addTearDown(services.dispose);
    final period = await services.budgetPeriods.ensurePeriodContaining(
      DateTime(2026, 7, 15),
    );
    return DashboardCubit(
      transactions: services.transactions,
      categories: services.categories,
      budgetPeriods: services.budgetPeriods,
      rawCaptures: services.rawCaptures,
      accounts: services.accounts,
      initialPeriod: period,
    );
  }

  Future<void> addConfirmedSpend(int amountMinor) async {
    final foodCategoryId = (await services.categories.byName('Food'))!.id;
    final accountId = (await services.accounts.getDefault()).id;
    await services.transactions.insertDraft(
      TransactionDraft(
        amountMinor: amountMinor,
        direction: TxDirection.debit,
        source: TxSource.manual,
        transactedAt: DateTime(2026, 7, 10),
        categoryId: foodCategoryId,
        merchant: 'Shoprite',
      ),
      accountId: accountId,
      idempotencyKey: 'test:${Ids.newId()}',
      status: TxStatus.confirmed,
    );
  }

  group('DashboardCubit', () {
    test('starts empty with no income, spend, or activity', () async {
      final cubit = await cubitWith();
      addTearDown(cubit.close);

      await cubit.load();
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.periodLabel, '01/07/2026 – 31/07/2026');
      expect(cubit.state.hasIncome, isFalse);
      expect(cubit.state.totalSpent, 0);
      expect(cubit.state.topCategories, isEmpty);
      expect(cubit.state.recentTransactions, isEmpty);
      expect(cubit.state.pendingReviewCount, 0);
    });

    test('surfaces spend, top categories, and recent activity', () async {
      final cubit = await cubitWith();
      addTearDown(cubit.close);
      await cubit.load();
      await Future<void>.delayed(Duration.zero);

      await addConfirmedSpend(5000);
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.totalSpent, 5000);
      expect(cubit.state.topCategories, hasLength(1));
      expect(cubit.state.topCategories.single.categoryName, 'Food');
      expect(cubit.state.recentTransactions, hasLength(1));
      expect(cubit.state.recentTransactions.single.merchant, 'Shoprite');
    });

    test('tracks income against spend', () async {
      final cubit = await cubitWith();
      addTearDown(cubit.close);
      await cubit.load();
      await addConfirmedSpend(30000);
      await Future<void>.delayed(Duration.zero);

      final salary = await services.categories.create(
        'Salary',
        type: CategoryType.income,
        budgetedAmountMinor: 100000,
      );
      await services.budgetPeriods.upsertCategoryBudget(
        periodId: cubit.state.budgetPeriod!.id,
        categoryId: salary.id,
        amountMinor: 100000,
      );
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.hasIncome, isTrue);
      expect(cubit.state.totalIncomeMinor, 100000);
      expect(cubit.state.remainingMinor, 70000);
      // No overall budget set, so income stands in as the ceiling.
      expect(cubit.state.planSource, PlanSource.income);
      expect(cubit.state.planMinor, 100000);
    });

    test('measures spend against the overall budget ahead of income', () async {
      final cubit = await cubitWith();
      addTearDown(cubit.close);
      await cubit.load();
      await addConfirmedSpend(30000);

      final salary = await services.categories.create(
        'Salary',
        type: CategoryType.income,
        budgetedAmountMinor: 100000,
      );
      await services.budgetPeriods.upsertCategoryBudget(
        periodId: cubit.state.budgetPeriod!.id,
        categoryId: salary.id,
        amountMinor: 100000,
      );
      await services.budgetPeriods.setOverallAmount(
        periodId: cubit.state.budgetPeriod!.id,
        amountMinor: 50000,
      );
      await Future<void>.delayed(Duration.zero);

      // Both are set: the budget is what the user planned, income is
      // only a fallback, so the budget wins.
      expect(cubit.state.planSource, PlanSource.overallBudget);
      expect(cubit.state.planMinor, 50000);
      expect(cubit.state.remainingMinor, 20000);
      expect(cubit.state.isOverPlan, isFalse);
    });

    test('reports overspend against the plan', () async {
      final cubit = await cubitWith();
      addTearDown(cubit.close);
      await cubit.load();
      await services.budgetPeriods.setOverallAmount(
        periodId: cubit.state.budgetPeriod!.id,
        amountMinor: 10000,
      );
      await addConfirmedSpend(15000);
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.isOverPlan, isTrue);
      expect(cubit.state.remainingMinor, -5000);
      expect(cubit.state.planRatio, greaterThan(1));
    });

    test('has no plan when neither a budget nor income is set', () async {
      final cubit = await cubitWith();
      addTearDown(cubit.close);
      await cubit.load();
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.planSource, PlanSource.none);
      expect(cubit.state.planMinor, isNull);
      expect(cubit.state.hasPlan, isFalse);
      expect(cubit.state.planRatio, 0);
    });

    test('exposes accounts and their computed balances', () async {
      final cubit = await cubitWith();
      addTearDown(cubit.close);
      await cubit.load();
      await Future<void>.delayed(Duration.zero);

      // One default account is seeded on first launch.
      expect(cubit.state.accounts, isNotEmpty);
      final defaultAccount = await services.accounts.getDefault();
      expect(cubit.state.accountBalances, contains(defaultAccount.id));
    });

    test('shiftPeriod moves the window and reloads its totals', () async {
      final cubit = await cubitWith();
      addTearDown(cubit.close);
      await cubit.load();
      await addConfirmedSpend(5000);
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.totalSpent, 5000);

      cubit.shiftPeriod(-1);
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.periodLabel, '01/06/2026 – 30/06/2026');
      // July's spend must not leak into June's totals.
      expect(cubit.state.totalSpent, 0);
      expect(cubit.state.topCategories, isEmpty);
    });

    test('describes the period in prose for the greeting', () async {
      final cubit = await cubitWith();
      addTearDown(cubit.close);
      await cubit.load();
      await Future<void>.delayed(Duration.zero);

      // The stored label is machine output; the greeting needs prose.
      expect(cubit.state.periodLabel, '01/07/2026 – 31/07/2026');
      expect(cubit.state.periodDisplayLabel, '1 – 31 Jul');
    });

    test('surfaces the review-pending count', () async {
      final cubit = await cubitWith();
      addTearDown(cubit.close);
      await cubit.load();
      await Future<void>.delayed(Duration.zero);

      final accountId = (await services.accounts.getDefault()).id;
      await services.transactions.insertDraft(
        TransactionDraft(
          amountMinor: 1000,
          direction: TxDirection.debit,
          source: TxSource.voice,
          transactedAt: DateTime(2026, 7),
          merchant: 'Unclear',
        ),
        accountId: accountId,
        idempotencyKey: 'test:${Ids.newId()}',
        status: TxStatus.needsReview,
      );
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.pendingReviewCount, 1);
    });
  });
}
