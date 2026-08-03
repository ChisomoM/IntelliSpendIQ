import 'package:flutter_test/flutter_test.dart';
import 'package:intellispendiq/app/app_services.dart';
import 'package:intellispendiq/core/ids.dart';
import 'package:intellispendiq/domain/models/enums.dart';
import 'package:intellispendiq/domain/models/transaction_draft.dart';

import '../support/test_harness.dart';

void main() {
  late AppServices services;
  late String accountId;

  setUp(() async {
    services = await createTestServices();
    accountId = (await services.accounts.getDefault()).id;
  });
  tearDown(() async => services.dispose());

  Future<void> addTx({
    required int amountMinor,
    required TxDirection direction,
    required DateTime at,
    String? txAccountId,
    TxStatus status = TxStatus.confirmed,
  }) async {
    await services.transactions.insertDraft(
      TransactionDraft(
        amountMinor: amountMinor,
        direction: direction,
        source: TxSource.manual,
        transactedAt: at,
      ),
      accountId: txAccountId ?? accountId,
      idempotencyKey: 'test:${Ids.newId()}',
      status: status,
    );
  }

  group('AccountRepository.watchComputedBalances', () {
    test('with no checkpoint, sums the whole confirmed ledger', () async {
      await addTx(
        amountMinor: 5000,
        direction: TxDirection.credit,
        at: DateTime(2026),
      );
      await addTx(
        amountMinor: 2000,
        direction: TxDirection.debit,
        at: DateTime(2026, 7, 30),
      );

      final balances = await services.accounts.watchComputedBalances().first;

      expect(balances[accountId], 3000);
    });

    test('ignores transactions dated before account creation', () async {
      // A backdated transaction shouldn't be excluded just because it
      // predates the row's own created_at — the account (e.g. a real
      // mobile money account) existed before the app ever heard of it.
      await addTx(
        amountMinor: 10000,
        direction: TxDirection.credit,
        at: DateTime(2020),
      );

      final balances = await services.accounts.watchComputedBalances().first;

      expect(balances[accountId], 10000);
    });

    test(
      'a manual checkpoint excludes everything recorded before it',
      () async {
        // Dated well in the past, so it's unambiguously before the
        // checkpoint set with "now" below regardless of when this
        // test happens to run.
        await addTx(
          amountMinor: 10000,
          direction: TxDirection.credit,
          at: DateTime(2020),
        );
        await services.accounts.updateBalance(accountId, 3000);
        await addTx(
          amountMinor: 1000,
          direction: TxDirection.debit,
          at: DateTime.now().add(const Duration(days: 1)),
        );

        final balances = await services.accounts.watchComputedBalances().first;

        expect(
          balances[accountId],
          2000,
          reason:
              'checkpoint (3000) minus the 1000 debit after it; the '
              '10000 credit from before the checkpoint is not recounted',
        );
      },
    );

    test('excludes unconfirmed and soft-deleted transactions', () async {
      await addTx(
        amountMinor: 5000,
        direction: TxDirection.credit,
        at: DateTime(2026, 7, 30),
        status: TxStatus.needsReview,
      );
      final confirmed = await services.transactions.insertDraft(
        TransactionDraft(
          amountMinor: 4000,
          direction: TxDirection.credit,
          source: TxSource.manual,
          transactedAt: DateTime(2026, 7, 30),
        ),
        accountId: accountId,
        idempotencyKey: 'test:${Ids.newId()}',
        status: TxStatus.confirmed,
      );
      await services.transactions.softDelete(confirmed.id);

      final balances = await services.accounts.watchComputedBalances().first;

      expect(balances[accountId], 0);
    });

    test('a linked transfer moves the balance between both accounts', () async {
      final cash = await services.accounts.create(
        name: 'Cash',
        type: AccountType.cash,
      );
      final debit = await services.transactions.insertDraft(
        TransactionDraft(
          amountMinor: 15000,
          direction: TxDirection.debit,
          source: TxSource.manual,
          transactedAt: DateTime(2026, 7, 30, 9),
        ),
        accountId: accountId,
        idempotencyKey: 'test:${Ids.newId()}',
        status: TxStatus.confirmed,
      );
      final credit = await services.transactions.insertDraft(
        TransactionDraft(
          amountMinor: 15000,
          direction: TxDirection.credit,
          source: TxSource.manual,
          transactedAt: DateTime(2026, 7, 30, 9, 5),
        ),
        accountId: cash.id,
        idempotencyKey: 'test:${Ids.newId()}',
        status: TxStatus.confirmed,
      );
      await services.transfers.linkTransfer(
        fromTransaction: debit,
        toTransaction: credit,
      );

      final balances = await services.accounts.watchComputedBalances().first;

      expect(balances[accountId], -15000);
      expect(balances[cash.id], 15000);
    });

    test(
      'editing account or direction moves the computed balance',
      () async {
        final cash = await services.accounts.create(
          name: 'Cash',
          type: AccountType.cash,
        );
        final tx = await services.transactions.insertDraft(
          TransactionDraft(
            amountMinor: 5000,
            direction: TxDirection.debit,
            source: TxSource.manual,
            transactedAt: DateTime(2026, 7, 30),
          ),
          accountId: accountId,
          idempotencyKey: 'test:${Ids.newId()}',
          status: TxStatus.confirmed,
        );

        await services.transactions.updateFields(
          tx.id,
          accountId: cash.id,
          direction: TxDirection.credit,
        );

        final balances = await services.accounts.watchComputedBalances().first;

        expect(balances[accountId], 0);
        expect(balances[cash.id], 5000);
      },
    );
  });
}
