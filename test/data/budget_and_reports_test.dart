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

  group('category budgets', () {
    test(
      'a category carries a standing budget, not a per-period row',
      () async {
        await services.categories.update(
          foodCategoryId,
          budgetedAmountMinor: 100000,
        );
        var food = (await services.categories.getAll()).firstWhere(
          (c) => c.id == foodCategoryId,
        );
        expect(food.budgetedAmountMinor, 100000);

        await services.categories.update(
          foodCategoryId,
          budgetedAmountMinor: 150000,
        );
        food = (await services.categories.getAll()).firstWhere(
          (c) => c.id == foodCategoryId,
        );
        expect(food.budgetedAmountMinor, 150000);
      },
    );

    test('clearBudget removes the budget entirely', () async {
      await services.categories.update(
        foodCategoryId,
        budgetedAmountMinor: 100000,
      );

      await services.categories.update(foodCategoryId, clearBudget: true);

      final food = (await services.categories.getAll()).firstWhere(
        (c) => c.id == foodCategoryId,
      );
      expect(food.budgetedAmountMinor, isNull);
    });

    test('transferBudget moves ngwee between two categories', () async {
      final transportId = (await services.categories.byName('Transport'))!.id;
      await services.categories.update(
        foodCategoryId,
        budgetedAmountMinor: 100000,
      );
      await services.categories.update(transportId, budgetedAmountMinor: 20000);

      final moved = await services.categories.transferBudget(
        fromCategoryId: foodCategoryId,
        toCategoryId: transportId,
        amountMinor: 30000,
      );

      expect(moved, isTrue);
      final all = await services.categories.getAll();
      expect(
        all.firstWhere((c) => c.id == foodCategoryId).budgetedAmountMinor,
        70000,
      );
      expect(
        all.firstWhere((c) => c.id == transportId).budgetedAmountMinor,
        50000,
      );
    });

    test('transferBudget refuses to overdraw the source category', () async {
      final transportId = (await services.categories.byName('Transport'))!.id;
      await services.categories.update(
        foodCategoryId,
        budgetedAmountMinor: 10000,
      );

      final moved = await services.categories.transferBudget(
        fromCategoryId: foodCategoryId,
        toCategoryId: transportId,
        amountMinor: 30000,
      );

      expect(moved, isFalse);
      final food = (await services.categories.getAll()).firstWhere(
        (c) => c.id == foodCategoryId,
      );
      expect(food.budgetedAmountMinor, 10000);
    });
  });

  group('overall budgets', () {
    test('upsert sets the month total independent of categories', () async {
      await services.overallBudgets.upsert(
        period: '2026-07',
        amountMinor: 500000,
      );
      await services.categories.update(
        foodCategoryId,
        budgetedAmountMinor: 100000,
      );

      final overall = await services.overallBudgets.getForPeriod('2026-07');
      expect(overall!.amountMinor, 500000);
      final food = (await services.categories.getAll()).firstWhere(
        (c) => c.id == foodCategoryId,
      );
      expect(food.budgetedAmountMinor, 100000);
    });

    test('carries last month forward as an editable default', () async {
      await services.overallBudgets.upsert(
        period: '2026-06',
        amountMinor: 400000,
      );

      expect(await services.overallBudgets.carryOverInto('2026-07'), isTrue);
      final july = await services.overallBudgets.getForPeriod('2026-07');
      expect(july!.amountMinor, 400000);
    });

    test('carry-over never overwrites a total already set', () async {
      await services.overallBudgets.upsert(
        period: '2026-06',
        amountMinor: 400000,
      );
      await services.overallBudgets.upsert(
        period: '2026-07',
        amountMinor: 600000,
      );

      expect(await services.overallBudgets.carryOverInto('2026-07'), isFalse);
      final july = await services.overallBudgets.getForPeriod('2026-07');
      expect(july!.amountMinor, 600000);
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

  group('income categories', () {
    test('a category budgeted with type income counts as income', () async {
      final salary = await services.categories.create(
        'Salary',
        type: CategoryType.income,
        budgetedAmountMinor: 500000,
      );
      await services.categories.update(salary.id, budgetedAmountMinor: 650000);

      final updated = (await services.categories.getAll()).firstWhere(
        (c) => c.id == salary.id,
      );
      expect(updated.budgetedAmountMinor, 650000);
      expect(updated.isIncome, isTrue);
    });

    test(
      'multiple income categories coexist independently',
      () async {
        await services.categories.create(
          'Salary',
          type: CategoryType.income,
          budgetedAmountMinor: 500000,
        );
        await services.categories.create(
          'Side hustle',
          type: CategoryType.income,
          budgetedAmountMinor: 150000,
        );

        final incomeCategories = (await services.categories.getAll())
            .where((c) => c.isIncome && c.hasBudget)
            .toList();
        expect(incomeCategories, hasLength(2));
        expect(
          incomeCategories
              .map((c) => c.budgetedAmountMinor!)
              .reduce((a, b) => a + b),
          650000,
        );
      },
    );

    test(
      'deleting an income category removes it without touching others',
      () async {
        final salary = await services.categories.create(
          'Salary',
          type: CategoryType.income,
          budgetedAmountMinor: 500000,
        );
        await services.categories.create(
          'Side hustle',
          type: CategoryType.income,
          budgetedAmountMinor: 150000,
        );

        await services.categories.delete(salary.id);

        final remaining = (await services.categories.getAll())
            .where((c) => c.isIncome && c.hasBudget)
            .toList();
        expect(remaining, hasLength(1));
        expect(remaining.single.name, 'Side hustle');
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

    test('a December overall budget carries into January', () async {
      await services.overallBudgets.upsert(
        period: '2025-12',
        amountMinor: 500000,
      );

      expect(await services.overallBudgets.carryOverInto('2026-01'), isTrue);
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
