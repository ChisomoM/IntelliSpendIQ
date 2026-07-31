import 'package:flutter_test/flutter_test.dart';
import 'package:intellispendiq/accounts/accounts.dart';
import 'package:intellispendiq/app/app_services.dart';
import 'package:intellispendiq/core/ids.dart';
import 'package:intellispendiq/domain/models/enums.dart';
import 'package:intellispendiq/domain/models/transaction_draft.dart';

import '../../support/test_harness.dart';

void main() {
  late AppServices services;

  Future<AccountsCubit> cubitWith() async {
    services = await createTestServices();
    addTearDown(services.dispose);
    final cubit = AccountsCubit(services.accounts, services.transfers);
    await cubit.load();
    await Future<void>.delayed(Duration.zero);
    return cubit;
  }

  group('AccountsCubit', () {
    test('loads the seeded default account', () async {
      final cubit = await cubitWith();
      addTearDown(cubit.close);

      expect(cubit.state.status, AccountsStatus.loaded);
      expect(cubit.state.accounts, hasLength(1));
      expect(cubit.state.accounts.single.name, 'Airtel Money');
    });

    test('add() creates a new account of the chosen type', () async {
      final cubit = await cubitWith();
      addTearDown(cubit.close);

      await cubit.add(name: 'Cash wallet', type: AccountType.cash);
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.accounts, hasLength(2));
      expect(
        cubit.state.accounts.map((a) => a.name),
        contains('Cash wallet'),
      );
    });

    test('add() rejects an empty name', () async {
      final cubit = await cubitWith();
      addTearDown(cubit.close);

      await cubit.add(name: '   ', type: AccountType.cash);

      expect(cubit.state.status, AccountsStatus.invalid);
      expect(cubit.state.accounts, hasLength(1));
    });

    test('add() sets an opening balance checkpoint when given one', () async {
      final cubit = await cubitWith();
      addTearDown(cubit.close);

      await cubit.add(
        name: 'Old Bank',
        type: AccountType.bank,
        openingBalance: '500.00',
      );
      await Future<void>.delayed(Duration.zero);

      final created = cubit.state.accounts.firstWhere(
        (a) => a.name == 'Old Bank',
      );
      expect(created.balanceMinor, 50000);
      expect(cubit.state.balanceFor(created.id), 50000);
    });

    test('add() rejects an invalid opening balance', () async {
      final cubit = await cubitWith();
      addTearDown(cubit.close);

      await cubit.add(
        name: 'Old Bank',
        type: AccountType.bank,
        openingBalance: 'not a number',
      );

      expect(cubit.state.status, AccountsStatus.invalid);
      expect(
        cubit.state.accounts.map((a) => a.name),
        isNot(contains('Old Bank')),
        reason: 'an invalid opening balance must not create the account',
      );
    });

    test('delete() removes an account', () async {
      final cubit = await cubitWith();
      addTearDown(cubit.close);
      await cubit.add(name: 'Cash wallet', type: AccountType.cash);
      await Future<void>.delayed(Duration.zero);
      final toDelete = cubit.state.accounts.firstWhere(
        (a) => a.name == 'Cash wallet',
      );

      await cubit.delete(toDelete.id);
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.accounts, hasLength(1));
      expect(
        cubit.state.accounts.map((a) => a.id),
        isNot(contains(toDelete.id)),
      );
    });

    test('refuses to delete the last remaining account', () async {
      final cubit = await cubitWith();
      addTearDown(cubit.close);
      final onlyAccount = cubit.state.accounts.single;

      await cubit.delete(onlyAccount.id);

      expect(cubit.state.status, AccountsStatus.invalid);
      expect(cubit.state.accounts, hasLength(1));
    });

    test('updateBalance() sets the account balance by hand', () async {
      final cubit = await cubitWith();
      addTearDown(cubit.close);
      final account = cubit.state.accounts.single;

      await cubit.updateBalance(account.id, '250.00');
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.accounts.single.balanceMinor, 25000);
    });

    test('updateBalance() rejects a negative amount', () async {
      final cubit = await cubitWith();
      addTearDown(cubit.close);
      final account = cubit.state.accounts.single;

      await cubit.updateBalance(account.id, '-5');

      expect(cubit.state.status, AccountsStatus.invalid);
      expect(cubit.state.accounts.single.balanceMinor, isNull);
    });

    test(
      'balanceFor() sums confirmed transactions on top of a checkpoint',
      () async {
        final cubit = await cubitWith();
        addTearDown(cubit.close);
        final account = cubit.state.accounts.single;

        await cubit.updateBalance(account.id, '100.00');
        await Future<void>.delayed(Duration.zero);
        await services.transactions.insertDraft(
          TransactionDraft(
            amountMinor: 3000,
            direction: TxDirection.debit,
            source: TxSource.manual,
            transactedAt: DateTime.now(),
          ),
          accountId: account.id,
          idempotencyKey: 'test:${Ids.newId()}',
          status: TxStatus.confirmed,
        );
        await Future<void>.delayed(Duration.zero);

        expect(cubit.state.balanceFor(account.id), 7000);
        expect(cubit.state.totalBalanceMinor, 7000);
      },
    );

    test(
      'with no checkpoint set, balanceFor() sums the whole ledger',
      () async {
        final cubit = await cubitWith();
        addTearDown(cubit.close);
        final account = cubit.state.accounts.single;
        expect(account.balanceMinor, isNull);

        await services.transactions.insertDraft(
          TransactionDraft(
            amountMinor: 5000,
            direction: TxDirection.credit,
            source: TxSource.manual,
            transactedAt: DateTime.now(),
          ),
          accountId: account.id,
          idempotencyKey: 'test:${Ids.newId()}',
          status: TxStatus.confirmed,
        );
        await Future<void>.delayed(Duration.zero);

        expect(cubit.state.balanceFor(account.id), 5000);
      },
    );

    test(
      'recordTransfer() moves the computed balance between two accounts '
      'without needing any transaction on either side',
      () async {
        final cubit = await cubitWith();
        addTearDown(cubit.close);
        final mobileMoney = cubit.state.accounts.single;
        final cash = await services.accounts.create(
          name: 'Cash',
          type: AccountType.cash,
        );
        await Future<void>.delayed(Duration.zero);

        // The ATM-withdrawal case: the bank/mobile money side already
        // has a debit SMS, but nothing ever tells the app about the
        // cash side, so there's no transaction pair for auto-detection
        // to find.
        await cubit.recordTransfer(
          fromAccountId: mobileMoney.id,
          toAccountId: cash.id,
          amount: '200.00',
          transactedAt: DateTime.now(),
        );
        await Future<void>.delayed(Duration.zero);

        expect(cubit.state.status, isNot(AccountsStatus.invalid));
        expect(cubit.state.balanceFor(mobileMoney.id), -20000);
        expect(cubit.state.balanceFor(cash.id), 20000);
        final transfers = await services.transfers.watchAll().first;
        expect(transfers, hasLength(1));
      },
    );

    test('recordTransfer() rejects the same account on both sides', () async {
      final cubit = await cubitWith();
      addTearDown(cubit.close);
      final account = cubit.state.accounts.single;

      await cubit.recordTransfer(
        fromAccountId: account.id,
        toAccountId: account.id,
        amount: '50.00',
        transactedAt: DateTime.now(),
      );

      expect(cubit.state.status, AccountsStatus.invalid);
      final transfers = await services.transfers.watchAll().first;
      expect(transfers, isEmpty);
    });

    test('recordTransfer() rejects a non-positive amount', () async {
      final cubit = await cubitWith();
      addTearDown(cubit.close);
      final account = cubit.state.accounts.single;
      final cash = await services.accounts.create(
        name: 'Cash',
        type: AccountType.cash,
      );

      await cubit.recordTransfer(
        fromAccountId: account.id,
        toAccountId: cash.id,
        amount: '0',
        transactedAt: DateTime.now(),
      );

      expect(cubit.state.status, AccountsStatus.invalid);
      final transfers = await services.transfers.watchAll().first;
      expect(transfers, isEmpty);
    });
  });
}
