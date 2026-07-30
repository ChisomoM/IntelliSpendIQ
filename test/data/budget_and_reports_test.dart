import 'package:flutter_test/flutter_test.dart';
import 'package:intellispendiq/app/app_services.dart';
import 'package:intellispendiq/core/ids.dart';
import 'package:intellispendiq/core/time.dart';
import 'package:intellispendiq/domain/models/enums.dart';
import 'package:intellispendiq/domain/models/transaction_draft.dart';

import '../support/corpus.dart';
import '../support/test_harness.dart';

void main() {
  late AppServices services;
  late String foodCategoryId;
  late String accountId;

  setUp(() async {
    services = await createTestServices();
    foodCategoryId = (await services.categories.byName('Food'))!.id;
    accountId = (await services.accounts.getDefault()).id;
  });
  tearDown(() async => services.dispose());

  Future<void> addSpend({
    required int amountMinor,
    required DateTime at,
    String? categoryId,
    String? txAccountId,
    TxStatus status = TxStatus.confirmed,
    TxDirection direction = TxDirection.debit,
  }) async {
    await services.transactions.insertDraft(
      TransactionDraft(
        amountMinor: amountMinor,
        direction: direction,
        source: TxSource.manual,
        transactedAt: at,
        categoryId: categoryId ?? foodCategoryId,
        merchant: 'Test',
      ),
      accountId: txAccountId ?? accountId,
      idempotencyKey: 'test:${Ids.newId()}',
      status: status,
    );
  }

  group('seeds', () {
    test('creates the default categories once', () async {
      final first = await services.categories.getAll();
      expect(first, hasLength(10));
      expect(first.map((c) => c.name), contains('Uncategorized'));

      await services.categories.ensureSeeds();
      expect(await services.categories.getAll(), hasLength(10));
    });

    test('creates one default Airtel Money account', () async {
      final accounts = await services.accounts.getAll();
      expect(accounts, hasLength(1));
      expect(accounts.single.name, 'Airtel Money');
      expect(accounts.single.isDefault, isTrue);
      expect(accounts.single.type, AccountType.mobileMoney);
    });
  });

  group('category spend', () {
    test('counts only confirmed debits in the period', () async {
      final period = Iso.monthKey(DateTime(2026, 7, 15));

      await addSpend(amountMinor: 5000, at: DateTime(2026, 7, 15));
      await addSpend(amountMinor: 2500, at: DateTime(2026, 7, 20));
      // Excluded: not yet confirmed.
      await addSpend(
        amountMinor: 9999,
        at: DateTime(2026, 7, 21),
        status: TxStatus.needsReview,
      );
      // Excluded: a credit, not spending.
      await addSpend(
        amountMinor: 9999,
        at: DateTime(2026, 7, 22),
        direction: TxDirection.credit,
      );
      // Excluded: a different month.
      await addSpend(amountMinor: 9999, at: DateTime(2026, 6, 30));

      expect(
        await services.transactions.spentForCategory(foodCategoryId, period),
        7500,
      );
    });

    test('excludes soft-deleted transactions', () async {
      final period = Iso.monthKey(DateTime(2026, 7, 15));
      await addSpend(amountMinor: 5000, at: DateTime(2026, 7, 15));
      final rows = await services.transactions.watchRecent().first;
      await services.transactions.softDelete(rows.single.id);

      expect(
        await services.transactions.spentForCategory(foodCategoryId, period),
        0,
      );
    });

    test('groups the monthly report by category, largest first', () async {
      final transportId = (await services.categories.byName('Transport'))!.id;
      await addSpend(amountMinor: 2000, at: DateTime(2026, 7, 5));
      await addSpend(
        amountMinor: 7000,
        at: DateTime(2026, 7, 6),
        categoryId: transportId,
      );

      final report = await services.transactions
          .watchSpendByCategory(Iso.monthKey(DateTime(2026, 7)))
          .first;

      expect(report, hasLength(2));
      expect(report.first.categoryName, 'Transport');
      expect(report.first.spentMinor, 7000);
      expect(report.last.spentMinor, 2000);
    });
  });

  group('budgets', () {
    test('upsert replaces the limit for the same category and month', () async {
      const period = '2026-07';
      await services.budgets.upsert(
        categoryId: foodCategoryId,
        period: period,
        amountMinor: 100000,
      );
      await services.budgets.upsert(
        categoryId: foodCategoryId,
        period: period,
        amountMinor: 150000,
      );

      final budgets = await services.budgets.getForPeriod(period);
      expect(budgets, hasLength(1));
      expect(budgets.single.amountMinor, 150000);
    });

    test('carries last month forward as an editable default', () async {
      await services.budgets.upsert(
        categoryId: foodCategoryId,
        period: '2026-06',
        amountMinor: 120000,
      );

      final created = await services.budgets.carryOverInto('2026-07');

      expect(created, 1);
      final july = await services.budgets.getForPeriod('2026-07');
      expect(july.single.amountMinor, 120000);
    });

    test('carry-over never overwrites a budget already set', () async {
      await services.budgets.upsert(
        categoryId: foodCategoryId,
        period: '2026-06',
        amountMinor: 120000,
      );
      await services.budgets.upsert(
        categoryId: foodCategoryId,
        period: '2026-07',
        amountMinor: 80000,
      );

      await services.budgets.carryOverInto('2026-07');

      final july = await services.budgets.getForPeriod('2026-07');
      expect(july.single.amountMinor, 80000);
    });

    test('does not carry a budget marked as non-recurring', () async {
      await services.budgets.upsert(
        categoryId: foodCategoryId,
        period: '2026-06',
        amountMinor: 120000,
        carryOver: false,
      );

      expect(await services.budgets.carryOverInto('2026-07'), 0);
      expect(await services.budgets.getForPeriod('2026-07'), isEmpty);
    });

    test('a deleted budget disappears from the period', () async {
      await services.budgets.upsert(
        categoryId: foodCategoryId,
        period: '2026-07',
        amountMinor: 120000,
      );
      final budget = (await services.budgets.getForPeriod('2026-07')).single;

      await services.budgets.delete(budget.id);

      expect(await services.budgets.getForPeriod('2026-07'), isEmpty);
    });
  });

  group('accounts', () {
    test('creates additional accounts of any type', () async {
      final account = await services.accounts.create(
        name: 'Piggy Bank',
        type: AccountType.cash,
      );

      final all = await services.accounts.getAll();
      expect(all, hasLength(2));
      expect(all.map((a) => a.name), contains('Piggy Bank'));
      expect(account.type, AccountType.cash);
    });

    test('a deleted account disappears from the list', () async {
      final account = await services.accounts.create(
        name: 'Extra Bank',
        type: AccountType.bank,
      );

      await services.accounts.delete(account.id);

      final all = await services.accounts.getAll();
      expect(all.map((a) => a.id), isNot(contains(account.id)));
    });

    test(
      'deleting the default account promotes another as the new default',
      () async {
        final original = await services.accounts.getDefault();
        final second = await services.accounts.create(
          name: 'Cash',
          type: AccountType.cash,
        );

        await services.accounts.delete(original.id);

        final newDefault = await services.accounts.getDefault();
        expect(newDefault.id, second.id);
        expect(newDefault.isDefault, isTrue);
      },
    );
  });

  group('categories', () {
    test('creates a custom category', () async {
      final category = await services.categories.create('Pets', icon: '🐕');

      final all = await services.categories.getAll();
      expect(all.map((c) => c.name), contains('Pets'));
      expect(category.isSystem, isFalse);
    });

    test('update renames a category and changes its icon', () async {
      final category = await services.categories.create('Pets', icon: '🐕');

      await services.categories.update(
        category.id,
        name: 'Pet care',
        icon: '🐈',
      );

      final all = await services.categories.getAll();
      final updated = all.firstWhere((c) => c.id == category.id);
      expect(updated.name, 'Pet care');
      expect(updated.icon, '🐈');
    });

    test('update can clear an icon', () async {
      final category = await services.categories.create('Pets', icon: '🐕');

      await services.categories.update(category.id, clearIcon: true);

      final all = await services.categories.getAll();
      expect(all.firstWhere((c) => c.id == category.id).icon, isNull);
    });

    test('deletes a user-created category', () async {
      final category = await services.categories.create('Pets');

      final removed = await services.categories.delete(category.id);

      expect(removed, isTrue);
      final all = await services.categories.getAll();
      expect(all.map((c) => c.id), isNot(contains(category.id)));
    });

    test('refuses to delete a system category', () async {
      final food = (await services.categories.byName('Food'))!;

      final removed = await services.categories.delete(food.id);

      expect(removed, isFalse);
      final all = await services.categories.getAll();
      expect(all.map((c) => c.id), contains(food.id));
    });
  });

  group('monthly income', () {
    test('upsert replaces the declared income for the same month', () async {
      const period = '2026-07';
      await services.income.upsert(period: period, amountMinor: 500000);
      await services.income.upsert(period: period, amountMinor: 650000);

      final income = await services.income.getForPeriod(period);
      expect(income.single.amountMinor, 650000);
    });

    test('no income set for a period returns an empty list', () async {
      expect(await services.income.getForPeriod('2026-08'), isEmpty);
    });

    test(
      'different labels create separate streams for the same month',
      () async {
        const period = '2026-07';
        await services.income.upsert(
          period: period,
          amountMinor: 500000,
          label: 'Salary',
        );
        await services.income.upsert(
          period: period,
          amountMinor: 150000,
          label: 'Side hustle',
        );

        final income = await services.income.getForPeriod(period);
        expect(income, hasLength(2));
        expect(
          income.map((i) => i.amountMinor).reduce((a, b) => a + b),
          650000,
        );
      },
    );

    test(
      'deleteSource removes a single stream without touching others',
      () async {
        const period = '2026-07';
        await services.income.upsert(
          period: period,
          amountMinor: 500000,
          label: 'Salary',
        );
        await services.income.upsert(
          period: period,
          amountMinor: 150000,
          label: 'Side hustle',
        );
        final toDelete = (await services.income.getForPeriod(
          period,
        )).firstWhere((i) => i.label == 'Side hustle');

        await services.income.deleteSource(toDelete.id);

        final remaining = await services.income.getForPeriod(period);
        expect(remaining, hasLength(1));
        expect(remaining.single.label, 'Salary');
      },
    );

    test('totalSpent sums confirmed debits across every category', () async {
      final transportId = (await services.categories.byName('Transport'))!.id;
      await addSpend(amountMinor: 3000, at: DateTime(2026, 7, 5));
      await addSpend(
        amountMinor: 7000,
        at: DateTime(2026, 7, 6),
        categoryId: transportId,
      );
      // Excluded: not yet confirmed.
      await addSpend(
        amountMinor: 9999,
        at: DateTime(2026, 7, 7),
        status: TxStatus.needsReview,
      );
      // Excluded: a credit, not spending.
      await addSpend(
        amountMinor: 9999,
        at: DateTime(2026, 7, 8),
        direction: TxDirection.credit,
      );

      expect(await services.transactions.totalSpent('2026-07'), 10000);
    });
  });

  group('reports aggregation', () {
    test('watchDailySpend groups confirmed debits by local day', () async {
      await addSpend(amountMinor: 3000, at: DateTime(2026, 7, 5, 9));
      await addSpend(amountMinor: 2000, at: DateTime(2026, 7, 5, 18));
      await addSpend(amountMinor: 4000, at: DateTime(2026, 7, 10));
      // Excluded: not confirmed.
      await addSpend(
        amountMinor: 9999,
        at: DateTime(2026, 7, 12),
        status: TxStatus.needsReview,
      );

      final daily = await services.transactions
          .watchDailySpend('2026-07')
          .first;

      expect(daily, hasLength(2));
      expect(daily.first.date, DateTime(2026, 7, 5));
      expect(daily.first.spentMinor, 5000);
      expect(daily.last.date, DateTime(2026, 7, 10));
      expect(daily.last.spentMinor, 4000);
    });

    test("transactionsOnDate returns only that day's transactions", () async {
      await addSpend(amountMinor: 3000, at: DateTime(2026, 7, 5, 9));
      await addSpend(amountMinor: 4000, at: DateTime(2026, 7, 6, 9));

      final onDay = await services.transactions.transactionsOnDate(
        DateTime(2026, 7, 5),
      );

      expect(onDay, hasLength(1));
      expect(onDay.single.amountMinor, 3000);
    });

    test('spendTrend returns the trailing months oldest-first', () async {
      await addSpend(amountMinor: 1000, at: DateTime(2026, 5, 10));
      await addSpend(amountMinor: 2000, at: DateTime(2026, 6, 10));
      await addSpend(amountMinor: 3000, at: DateTime(2026, 7, 10));

      final trend = await services.transactions.spendTrend(
        '2026-07',
        months: 3,
      );

      expect(trend.map((m) => m.period).toList(), [
        '2026-05',
        '2026-06',
        '2026-07',
      ]);
      expect(trend.map((m) => m.spentMinor).toList(), [1000, 2000, 3000]);
    });

    test(
      'watchSpendByAccount groups confirmed debits by account, largest first',
      () async {
        final secondAccount = await services.accounts.create(
          name: 'Cash',
          type: AccountType.cash,
        );
        await addSpend(amountMinor: 2000, at: DateTime(2026, 7, 5));
        await addSpend(
          amountMinor: 6000,
          at: DateTime(2026, 7, 6),
          txAccountId: secondAccount.id,
        );

        final byAccount = await services.transactions
            .watchSpendByAccount('2026-07')
            .first;

        expect(byAccount, hasLength(2));
        expect(byAccount.first.accountName, 'Cash');
        expect(byAccount.first.spentMinor, 6000);
        expect(byAccount.last.accountName, 'Airtel Money');
        expect(byAccount.last.spentMinor, 2000);
      },
    );
  });

  group('month boundaries', () {
    test('previousMonthKey rolls back across the new year', () {
      expect(Iso.previousMonthKey('2026-01'), '2025-12');
      expect(Iso.previousMonthKey('2026-07'), '2026-06');
    });

    test('a December budget carries into January', () async {
      await services.budgets.upsert(
        categoryId: foodCategoryId,
        period: '2025-12',
        amountMinor: 50000,
      );

      expect(await services.budgets.carryOverInto('2026-01'), 1);
    });

    test('spend on the last day of the month counts in that month', () async {
      await addSpend(
        amountMinor: 3000,
        at: DateTime(2026, 7, 31, 23, 30),
      );

      expect(
        await services.transactions.spentForCategory(foodCategoryId, '2026-07'),
        3000,
      );
      expect(
        await services.transactions.spentForCategory(foodCategoryId, '2026-08'),
        0,
      );
    });
  });

  test('capture health counts by source and parse status', () async {
    await addSpend(amountMinor: 1000, at: DateTime(2026, 7, 10));
    await services.captureService.ingest(
      Corpus.capture('Nonsense from a known sender'),
    );

    final bySource = await services.transactions.countBySource('2026-07');
    expect(bySource[TxSource.manual.name], 1);

    final byStatus = await services.rawCaptures.countByParseStatus();
    expect(byStatus[ParseStatus.failed.name], 1);
  });
}
