import 'package:flutter_test/flutter_test.dart';
import 'package:intellispendiq/app/app_services.dart';
import 'package:intellispendiq/core/ids.dart';
import 'package:intellispendiq/domain/models/enums.dart';
import 'package:intellispendiq/domain/models/transaction_draft.dart';
import 'package:intellispendiq/transactions/cubit/activity_entry.dart';
import 'package:intellispendiq/transactions/cubit/cubit.dart';

import '../../support/test_harness.dart';

void main() {
  late AppServices services;
  late String accountId;

  Future<TransactionsCubit> cubitWith() async {
    services = await createTestServices();
    addTearDown(services.dispose);
    accountId = (await services.accounts.getDefault()).id;
    return TransactionsCubit(
      transactions: services.transactions,
      categories: services.categories,
      accounts: services.accounts,
      transfers: services.transfers,
    );
  }

  Future<void> addTransaction({
    required String merchant,
    int amountMinor = 5000,
    DateTime? at,
    String? categoryId,
    String? txAccountId,
  }) async {
    await services.transactions.insertDraft(
      TransactionDraft(
        amountMinor: amountMinor,
        direction: TxDirection.debit,
        source: TxSource.manual,
        transactedAt: at ?? DateTime.now(),
        merchant: merchant,
        categoryId: categoryId,
      ),
      accountId: txAccountId ?? accountId,
      idempotencyKey: 'test:${Ids.newId()}',
      status: TxStatus.confirmed,
    );
  }

  group('TransactionsCubit', () {
    test('subscribe() streams the recent transaction list', () async {
      final cubit = await cubitWith();
      addTearDown(cubit.close);
      await addTransaction(merchant: 'Shoprite');

      await cubit.subscribe();
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.transactions, hasLength(1));
      expect(cubit.state.transactions.single.merchant, 'Shoprite');
    });

    test('delete() removes a transaction from the list', () async {
      final cubit = await cubitWith();
      addTearDown(cubit.close);
      await addTransaction(merchant: 'Duplicate transfer');
      await cubit.subscribe();
      await Future<void>.delayed(Duration.zero);
      final saved = cubit.state.transactions.single;
      expect(cubit.state.transactions, hasLength(1));

      await cubit.delete(saved.id);
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.transactions, isEmpty);
    });

    test('queryChanged() debounces and matches merchant text', () async {
      final cubit = await cubitWith();
      addTearDown(cubit.close);
      await addTransaction(merchant: 'Shoprite Cairo Road');
      await addTransaction(merchant: 'Taxi rank');
      await cubit.subscribe();
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.transactions, hasLength(2));

      cubit.queryChanged('shoprite');
      expect(
        cubit.state.transactions,
        hasLength(2),
        reason: 'the list should not change until the debounce fires',
      );
      await Future<void>.delayed(const Duration(milliseconds: 350));

      expect(cubit.state.transactions, hasLength(1));
      expect(cubit.state.transactions.single.merchant, 'Shoprite Cairo Road');
    });

    test('categoryFilterChanged() narrows to one category', () async {
      final cubit = await cubitWith();
      addTearDown(cubit.close);
      final transportId = (await services.categories.byName('Transport'))!.id;
      await addTransaction(merchant: 'Shoprite');
      await addTransaction(merchant: 'Taxi', categoryId: transportId);
      await cubit.subscribe();
      await Future<void>.delayed(Duration.zero);

      cubit.categoryFilterChanged(transportId);
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.transactions, hasLength(1));
      expect(cubit.state.transactions.single.merchant, 'Taxi');
    });

    test('accountFilterChanged() narrows to one account', () async {
      final cubit = await cubitWith();
      addTearDown(cubit.close);
      final cash = await services.accounts.create(
        name: 'Cash',
        type: AccountType.cash,
      );
      await addTransaction(merchant: 'Shoprite');
      await addTransaction(merchant: 'Market', txAccountId: cash.id);
      await cubit.subscribe();
      await Future<void>.delayed(Duration.zero);

      cubit.accountFilterChanged(cash.id);
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.transactions, hasLength(1));
      expect(cubit.state.transactions.single.merchant, 'Market');
    });

    test('dateRangeChanged() narrows to an inclusive day range', () async {
      final cubit = await cubitWith();
      addTearDown(cubit.close);
      await addTransaction(merchant: 'In range', at: DateTime(2026, 7, 10));
      await addTransaction(merchant: 'Before range', at: DateTime(2026, 7));
      await cubit.subscribe();
      await Future<void>.delayed(Duration.zero);

      cubit.dateRangeChanged(
        from: DateTime(2026, 7, 5),
        to: DateTime(2026, 7, 10),
      );
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.transactions, hasLength(1));
      expect(cubit.state.transactions.single.merchant, 'In range');
    });

    test('clearFilters() resets every filter and reloads everything', () async {
      final cubit = await cubitWith();
      addTearDown(cubit.close);
      await addTransaction(merchant: 'Shoprite');
      await addTransaction(merchant: 'Taxi');
      await cubit.subscribe();
      await Future<void>.delayed(Duration.zero);
      cubit.queryChanged('shoprite');
      await Future<void>.delayed(const Duration(milliseconds: 350));
      expect(cubit.state.transactions, hasLength(1));

      cubit.clearFilters();
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.hasFilters, isFalse);
      expect(cubit.state.transactions, hasLength(2));
    });

    test(
      'feed merges a linked transfer alongside ordinary transactions',
      () async {
        final cubit = await cubitWith();
        addTearDown(cubit.close);
        await addTransaction(merchant: 'Shoprite', at: DateTime(2026, 7, 20));

        final cash = await services.accounts.create(
          name: 'Cash',
          type: AccountType.cash,
        );
        final debit = await services.transactions.insertDraft(
          TransactionDraft(
            amountMinor: 20000,
            direction: TxDirection.debit,
            source: TxSource.manual,
            transactedAt: DateTime(2026, 7, 25, 9),
          ),
          accountId: accountId,
          idempotencyKey: 'test:${Ids.newId()}',
          status: TxStatus.confirmed,
        );
        final credit = await services.transactions.insertDraft(
          TransactionDraft(
            amountMinor: 20000,
            direction: TxDirection.credit,
            source: TxSource.manual,
            transactedAt: DateTime(2026, 7, 25, 9, 5),
          ),
          accountId: cash.id,
          idempotencyKey: 'test:${Ids.newId()}',
          status: TxStatus.confirmed,
        );
        await services.transfers.linkTransfer(
          fromTransaction: debit,
          toTransaction: credit,
        );

        await cubit.subscribe();
        await Future<void>.delayed(Duration.zero);

        expect(
          cubit.state.transactions,
          hasLength(1),
          reason: 'the transfer legs were soft-deleted once linked',
        );
        expect(cubit.state.feed, hasLength(2));
        expect(cubit.state.feed.first, isA<TransferEntry>());
      },
    );

    test('groups the feed by day and nets each day out', () async {
      final cubit = await cubitWith();
      addTearDown(cubit.close);
      final today = DateTime.now();
      final yesterday = today.subtract(const Duration(days: 1));

      await addTransaction(merchant: 'Shoprite', amountMinor: 5000, at: today);
      await addTransaction(merchant: 'Bus', amountMinor: 2000, at: today);
      await addTransaction(merchant: 'Airtime', amountMinor: 1000, at: yesterday);

      await cubit.subscribe();
      await Future<void>.delayed(Duration.zero);

      final groups = cubit.state.dayGroups;
      expect(groups, hasLength(2));
      expect(groups.first.entries, hasLength(2));
      // Both are debits, so the day nets negative.
      expect(groups.first.netMinor, -7000);
      expect(groups.last.netMinor, -1000);
    });

    test('a transfer never counts toward a day net', () async {
      final cubit = await cubitWith();
      addTearDown(cubit.close);
      final other = await services.accounts.create(
        name: 'Cash',
        type: AccountType.cash,
      );
      final debit = await services.transactions.insertDraft(
        TransactionDraft(
          amountMinor: 20000,
          direction: TxDirection.debit,
          source: TxSource.manual,
          transactedAt: DateTime.now(),
        ),
        accountId: accountId,
        idempotencyKey: 'test:${Ids.newId()}',
        status: TxStatus.confirmed,
      );
      final credit = await services.transactions.insertDraft(
        TransactionDraft(
          amountMinor: 20000,
          direction: TxDirection.credit,
          source: TxSource.manual,
          transactedAt: DateTime.now(),
        ),
        accountId: other.id,
        idempotencyKey: 'test:${Ids.newId()}',
        status: TxStatus.confirmed,
      );
      await services.transfers.linkTransfer(
        fromTransaction: debit,
        toTransaction: credit,
      );

      await cubit.subscribe();
      await Future<void>.delayed(Duration.zero);

      // Moving your own money between accounts is not spending it.
      expect(cubit.state.dayGroups.single.netMinor, 0);
    });

    test('the direction filter splits money in from money out', () async {
      final cubit = await cubitWith();
      addTearDown(cubit.close);
      await addTransaction(merchant: 'Shoprite', amountMinor: 5000);
      await services.transactions.insertDraft(
        TransactionDraft(
          amountMinor: 90000,
          direction: TxDirection.credit,
          source: TxSource.manual,
          transactedAt: DateTime.now(),
          merchant: 'Salary',
        ),
        accountId: accountId,
        idempotencyKey: 'test:${Ids.newId()}',
        status: TxStatus.confirmed,
      );
      await cubit.subscribe();
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.feed, hasLength(2));

      cubit.directionFilterChanged(TxDirection.credit);
      expect(cubit.state.feed, hasLength(1));
      expect(cubit.state.hasFilters, isTrue);
      // The chip row shows its own state, so the sheet's badge stays off.
      expect(cubit.state.hasSheetFilters, isFalse);

      cubit.directionFilterChanged(null);
      expect(cubit.state.feed, hasLength(2));
      expect(cubit.state.hasFilters, isFalse);
    });
  });
}
