import 'package:flutter_test/flutter_test.dart';
import 'package:intellispendiq/app/app_services.dart';
import 'package:intellispendiq/core/ids.dart';
import 'package:intellispendiq/dashboard/cubit/cubit.dart';
import 'package:intellispendiq/domain/models/enums.dart';
import 'package:intellispendiq/domain/models/transaction_draft.dart';

import '../../support/test_harness.dart';

void main() {
  late AppServices services;
  const period = '2026-07';

  Future<DashboardCubit> cubitWith() async {
    services = await createTestServices();
    addTearDown(services.dispose);
    return DashboardCubit(
      transactions: services.transactions,
      income: services.income,
      rawCaptures: services.rawCaptures,
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

      await services.income.upsert(period: period, amountMinor: 100000);
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.hasIncome, isTrue);
      expect(cubit.state.totalIncomeMinor, 100000);
      expect(cubit.state.remainingMinor, 70000);
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
