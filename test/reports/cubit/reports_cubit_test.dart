import 'package:flutter_test/flutter_test.dart';
import 'package:intellispendiq/app/app_services.dart';
import 'package:intellispendiq/core/ids.dart';
import 'package:intellispendiq/domain/models/enums.dart';
import 'package:intellispendiq/domain/models/transaction_draft.dart';
import 'package:intellispendiq/reports/cubit/cubit.dart';

import '../../support/test_harness.dart';

void main() {
  late AppServices services;

  Future<ReportsCubit> cubitWith() async {
    services = await createTestServices();
    addTearDown(services.dispose);
    return ReportsCubit(services.transactions, period: '2026-07');
  }

  Future<void> addSpend(
    int amountMinor,
    DateTime at, {
    String? accountId,
  }) async {
    final foodCategoryId = (await services.categories.byName('Food'))!.id;
    final defaultAccount =
        accountId ?? (await services.accounts.getDefault()).id;
    await services.transactions.insertDraft(
      TransactionDraft(
        amountMinor: amountMinor,
        direction: TxDirection.debit,
        source: TxSource.manual,
        transactedAt: at,
        categoryId: foodCategoryId,
        merchant: 'Test',
      ),
      accountId: defaultAccount,
      idempotencyKey: 'test:${Ids.newId()}',
      status: TxStatus.confirmed,
    );
  }

  group('ReportsCubit', () {
    test('load() surfaces category rows, daily spend, and trend', () async {
      final cubit = await cubitWith();
      addTearDown(cubit.close);

      await addSpend(5000, DateTime(2026, 7, 10));
      cubit.load();
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.status, ReportsStatus.loaded);
      expect(cubit.state.rows, hasLength(1));
      expect(cubit.state.totalMinor, 5000);
      expect(cubit.state.dailySpend, hasLength(1));
      expect(cubit.state.dailySpend.single.spentMinor, 5000);
      expect(cubit.state.monthTrend, hasLength(6));
      expect(cubit.state.monthTrend.last.period, '2026-07');
      expect(cubit.state.monthTrend.last.spentMinor, 5000);
    });

    test('shiftMonth() moves the window and reloads every dataset', () async {
      final cubit = await cubitWith();
      addTearDown(cubit.close);
      cubit.load();
      await Future<void>.delayed(Duration.zero);

      await addSpend(3000, DateTime(2026, 8, 5));
      cubit.shiftMonth(1);
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.period, '2026-08');
      expect(cubit.state.totalMinor, 3000);
    });

    test('breakdownChanged() switches the active dimension', () async {
      final cubit = await cubitWith();
      addTearDown(cubit.close);
      cubit.load();
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.breakdown, ReportsBreakdown.category);
      cubit.breakdownChanged(ReportsBreakdown.account);
      expect(cubit.state.breakdown, ReportsBreakdown.account);
    });

    test('account rows are grouped and sorted, largest first', () async {
      final cubit = await cubitWith();
      addTearDown(cubit.close);
      final cash = await services.accounts.create(
        name: 'Cash',
        type: AccountType.cash,
      );

      await addSpend(2000, DateTime(2026, 7, 5));
      await addSpend(9000, DateTime(2026, 7, 6), accountId: cash.id);
      cubit.load();
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.accountRows, hasLength(2));
      expect(cubit.state.accountRows.first.accountName, 'Cash');
      expect(cubit.state.accountRows.first.spentMinor, 9000);
    });
  });
}
