import 'package:flutter_test/flutter_test.dart';
import 'package:intellispendiq/accounts/accounts.dart';
import 'package:intellispendiq/app/app_services.dart';
import 'package:intellispendiq/core/ids.dart';
import 'package:intellispendiq/domain/models/enums.dart';
import 'package:intellispendiq/domain/models/transaction_draft.dart';
import 'package:intellispendiq/transactions/cubit/activity_entry.dart';

import '../../support/test_harness.dart';

void main() {
  late AppServices services;
  late String accountId;

  Future<AccountDetailCubit> cubitFor(String id) async {
    final cubit = AccountDetailCubit(
      accounts: services.accounts,
      transactions: services.transactions,
      transfers: services.transfers,
      categories: services.categories,
      accountId: id,
    );
    await cubit.load();
    await Future<void>.delayed(Duration.zero);
    return cubit;
  }

  Future<void> addTransaction({
    required String merchant,
    required String txAccountId,
    int amountMinor = 5000,
    TxDirection direction = TxDirection.debit,
    TxStatus status = TxStatus.confirmed,
    DateTime? at,
  }) async {
    await services.transactions.insertDraft(
      TransactionDraft(
        amountMinor: amountMinor,
        direction: direction,
        source: TxSource.manual,
        transactedAt: at ?? DateTime.now(),
        merchant: merchant,
      ),
      accountId: txAccountId,
      idempotencyKey: 'test:${Ids.newId()}',
      status: status,
    );
  }

  setUp(() async {
    services = await createTestServices();
    accountId = (await services.accounts.getDefault()).id;
  });
  tearDown(() async => services.dispose());

  group('AccountDetailCubit', () {
    test("lists only this account's transactions", () async {
      final cash = await services.accounts.create(
        name: 'Cash',
        type: AccountType.cash,
      );
      await addTransaction(merchant: 'Shoprite', txAccountId: accountId);
      await addTransaction(merchant: 'Street food', txAccountId: cash.id);

      final cubit = await cubitFor(accountId);
      addTearDown(cubit.close);

      expect(cubit.state.status, AccountDetailStatus.loaded);
      expect(cubit.state.account?.id, accountId);
      expect(cubit.state.transactions, hasLength(1));
      expect(cubit.state.transactions.single.merchant, 'Shoprite');
    });

    test('includes transfers that credit or debit this account', () async {
      final cash = await services.accounts.create(
        name: 'Cash',
        type: AccountType.cash,
      );
      await services.transfers.create(
        fromAccountId: accountId,
        toAccountId: cash.id,
        amountMinor: 20000,
        transactedAt: DateTime.now(),
      );

      final cubit = await cubitFor(accountId);
      addTearDown(cubit.close);

      expect(cubit.state.transfers, hasLength(1));
      expect(cubit.state.feed.whereType<TransferEntry>(), hasLength(1));
    });

    test('excludes transfers between other accounts', () async {
      final cash = await services.accounts.create(
        name: 'Cash',
        type: AccountType.cash,
      );
      final bank = await services.accounts.create(
        name: 'Bank',
        type: AccountType.bank,
      );
      await services.transfers.create(
        fromAccountId: cash.id,
        toAccountId: bank.id,
        amountMinor: 15000,
        transactedAt: DateTime.now(),
      );

      final cubit = await cubitFor(accountId);
      addTearDown(cubit.close);

      expect(cubit.state.transfers, isEmpty);
    });

    test('money in and out ignore transfers and planned entries', () async {
      await addTransaction(
        merchant: 'Salary',
        txAccountId: accountId,
        amountMinor: 10000,
        direction: TxDirection.credit,
      );
      await addTransaction(
        merchant: 'Groceries',
        txAccountId: accountId,
        amountMinor: 4000,
      );
      await addTransaction(
        merchant: 'Upcoming bill',
        txAccountId: accountId,
        amountMinor: 2500,
        status: TxStatus.planned,
      );
      final cash = await services.accounts.create(
        name: 'Cash',
        type: AccountType.cash,
      );
      await services.transfers.create(
        fromAccountId: accountId,
        toAccountId: cash.id,
        amountMinor: 2000,
        transactedAt: DateTime.now(),
      );

      final cubit = await cubitFor(accountId);
      addTearDown(cubit.close);

      expect(cubit.state.moneyInMinor, 10000);
      expect(cubit.state.moneyOutMinor, 4000);
    });

    test("a day's net on this account includes transfers", () async {
      await addTransaction(
        merchant: 'Lunch',
        txAccountId: accountId,
        amountMinor: 3000,
      );
      final cash = await services.accounts.create(
        name: 'Cash',
        type: AccountType.cash,
      );
      await services.transfers.create(
        fromAccountId: accountId,
        toAccountId: cash.id,
        amountMinor: 2000,
        transactedAt: DateTime.now(),
      );

      final cubit = await cubitFor(accountId);
      addTearDown(cubit.close);

      expect(cubit.state.dayGroups, hasLength(1));
      expect(cubit.state.dayGroups.single.netMinor, -5000);
    });

    test('deleteTransaction() removes a transaction from the list', () async {
      await addTransaction(merchant: 'Duplicate', txAccountId: accountId);
      final cubit = await cubitFor(accountId);
      addTearDown(cubit.close);
      final saved = cubit.state.transactions.single;

      await cubit.deleteTransaction(saved.id);
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.transactions, isEmpty);
    });

    test('reports notFound after the account is deleted', () async {
      final cash = await services.accounts.create(
        name: 'Cash',
        type: AccountType.cash,
      );
      final cubit = await cubitFor(cash.id);
      addTearDown(cubit.close);
      expect(cubit.state.status, AccountDetailStatus.loaded);

      await services.accounts.delete(cash.id);
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.status, AccountDetailStatus.notFound);
    });
  });
}
