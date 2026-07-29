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
      accountId: accountId,
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

  group('monthly income', () {
    test('upsert replaces the declared income for the same month', () async {
      const period = '2026-07';
      await services.income.upsert(period: period, amountMinor: 500000);
      await services.income.upsert(period: period, amountMinor: 650000);

      final income = await services.income.getForPeriod(period);
      expect(income!.amountMinor, 650000);
    });

    test('no income set for a period returns null', () async {
      expect(await services.income.getForPeriod('2026-08'), isNull);
    });

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
