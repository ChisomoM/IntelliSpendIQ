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
      budgets: services.budgets,
      overallBudgets: services.overallBudgets,
      categories: services.categories,
      transactions: services.transactions,
      income: services.income,
      period: period,
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
      'addIncome() surfaces the declared income and remaining amount',
      () async {
        final cubit = await cubitWith();
        addTearDown(cubit.close);
        await cubit.load();
        await addConfirmedSpend(30000);

        await cubit.addIncome('500');
        await Future<void>.delayed(Duration.zero);

        expect(cubit.state.hasIncome, isTrue);
        expect(cubit.state.totalIncomeMinor, 50000);
        expect(cubit.state.totalSpent, 30000);
        expect(cubit.state.remainingMinor, 20000);
      },
    );

    test('addIncome() rejects a non-positive amount', () async {
      final cubit = await cubitWith();
      addTearDown(cubit.close);
      await cubit.load();

      await cubit.addIncome('0');

      expect(cubit.state.status, BudgetsStatus.invalid);
      expect(cubit.state.hasIncome, isFalse);
    });

    test(
      'multiple income streams sum into totalIncomeMinor',
      () async {
        final cubit = await cubitWith();
        addTearDown(cubit.close);
        await cubit.load();

        await cubit.addIncome('500', label: 'Salary');
        await Future<void>.delayed(Duration.zero);
        await cubit.addIncome('150', label: 'Side hustle');
        await Future<void>.delayed(Duration.zero);

        expect(cubit.state.incomeSources, hasLength(2));
        expect(cubit.state.totalIncomeMinor, 65000);
      },
    );

    test('deleteIncome() removes a single stream', () async {
      final cubit = await cubitWith();
      addTearDown(cubit.close);
      await cubit.load();
      await cubit.addIncome('500', label: 'Salary');
      await Future<void>.delayed(Duration.zero);
      await cubit.addIncome('150', label: 'Side hustle');
      await Future<void>.delayed(Duration.zero);

      final toDelete = cubit.state.incomeSources.firstWhere(
        (i) => i.label == 'Side hustle',
      );
      await cubit.deleteIncome(toDelete.id);
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.incomeSources, hasLength(1));
      expect(cubit.state.incomeSources.single.label, 'Salary');
    });

    test(
      'spending after income is set updates total spend on reload',
      () async {
        final cubit = await cubitWith();
        addTearDown(cubit.close);
        await cubit.load();
        await cubit.addIncome('500');
        await Future<void>.delayed(Duration.zero);

        await addConfirmedSpend(10000);
        // Budget/income streams only re-emit when a budget or income row
        // changes, so a fresh load() picks up the new spend total, same
        // as the existing per-category numbers.
        await cubit.load();
        await Future<void>.delayed(Duration.zero);

        expect(cubit.state.totalSpent, 10000);
        expect(cubit.state.hasIncome, isTrue);
      },
    );
  });

  group('BudgetsCubit overall vs category budgets', () {
    test('totalPlannedMinor comes from overall budget, not categories', () async {
      final cubit = await cubitWith();
      addTearDown(cubit.close);
      await cubit.load();

      final foodId = (await services.categories.byName('Food'))!.id;
      final transportId = (await services.categories.byName('Transport'))!.id;
      await cubit.upsert(categoryId: foodId, amount: '1000');
      await cubit.upsert(categoryId: transportId, amount: '300');
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.totalPlannedMinor, 0);
      expect(cubit.state.totalAllocatedMinor, 130000);

      await cubit.setOverallBudget('5000');
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.hasOverallBudget, isTrue);
      expect(cubit.state.totalPlannedMinor, 500000);
      expect(cubit.state.totalAllocatedMinor, 130000);
    });

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
}
