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
      'setIncome() surfaces the declared income and remaining amount',
      () async {
        final cubit = await cubitWith();
        addTearDown(cubit.close);
        await cubit.load();
        await addConfirmedSpend(30000);

        await cubit.setIncome('500');
        await Future<void>.delayed(Duration.zero);

        expect(cubit.state.hasIncome, isTrue);
        expect(cubit.state.income!.amountMinor, 50000);
        expect(cubit.state.totalSpent, 30000);
        expect(cubit.state.remainingMinor, 20000);
      },
    );

    test('setIncome() rejects a non-positive amount', () async {
      final cubit = await cubitWith();
      addTearDown(cubit.close);
      await cubit.load();

      await cubit.setIncome('0');

      expect(cubit.state.status, BudgetsStatus.invalid);
      expect(cubit.state.hasIncome, isFalse);
    });

    test(
      'spending after income is set updates total spend on reload',
      () async {
        final cubit = await cubitWith();
        addTearDown(cubit.close);
        await cubit.load();
        await cubit.setIncome('500');
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
}
