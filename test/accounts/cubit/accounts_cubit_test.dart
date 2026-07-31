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
    final cubit = AccountsCubit(services.accounts);
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
  });
}
