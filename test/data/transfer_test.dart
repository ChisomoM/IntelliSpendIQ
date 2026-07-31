import 'package:flutter_test/flutter_test.dart';
import 'package:intellispendiq/app/app_services.dart';
import 'package:intellispendiq/core/ids.dart';
import 'package:intellispendiq/domain/models/enums.dart';
import 'package:intellispendiq/domain/models/transaction_draft.dart';

import '../support/test_harness.dart';

void main() {
  late AppServices services;
  late String bankId;
  late String cashId;

  setUp(() async {
    services = await createTestServices();
    bankId = (await services.accounts.create(
      name: 'Bank',
      type: AccountType.bank,
    )).id;
    cashId = (await services.accounts.create(
      name: 'Cash',
      type: AccountType.cash,
    )).id;
  });
  tearDown(() async => services.dispose());

  Future<String> addTx({
    required String accountId,
    required int amountMinor,
    required TxDirection direction,
    required DateTime at,
  }) async {
    final tx = await services.transactions.insertDraft(
      TransactionDraft(
        amountMinor: amountMinor,
        direction: direction,
        source: TxSource.manual,
        transactedAt: at,
        merchant: 'Test',
      ),
      accountId: accountId,
      idempotencyKey: 'test:${Ids.newId()}',
      status: TxStatus.confirmed,
    );
    return tx.id;
  }

  group('watchTransferCandidates', () {
    test(
      'pairs a debit and credit of the same amount on different accounts',
      () async {
        await addTx(
          accountId: bankId,
          amountMinor: 50000,
          direction: TxDirection.debit,
          at: DateTime(2026, 7, 30, 9),
        );
        await addTx(
          accountId: cashId,
          amountMinor: 50000,
          direction: TxDirection.credit,
          at: DateTime(2026, 7, 30, 9, 20),
        );

        final candidates = await services.transactions
            .watchTransferCandidates()
            .first;

        expect(candidates, hasLength(1));
        expect(candidates.single.debit.accountId, bankId);
        expect(candidates.single.credit.accountId, cashId);
      },
    );

    test('does not pair two legs on the same account', () async {
      await addTx(
        accountId: bankId,
        amountMinor: 50000,
        direction: TxDirection.debit,
        at: DateTime(2026, 7, 30, 9),
      );
      await addTx(
        accountId: bankId,
        amountMinor: 50000,
        direction: TxDirection.credit,
        at: DateTime(2026, 7, 30, 9, 5),
      );

      final candidates = await services.transactions
          .watchTransferCandidates()
          .first;

      expect(candidates, isEmpty);
    });

    test('does not pair legs more than the window apart', () async {
      await addTx(
        accountId: bankId,
        amountMinor: 50000,
        direction: TxDirection.debit,
        at: DateTime(2026, 7, 30, 9),
      );
      await addTx(
        accountId: cashId,
        amountMinor: 50000,
        direction: TxDirection.credit,
        at: DateTime(2026, 7, 30, 10, 5),
      );

      final candidates = await services.transactions
          .watchTransferCandidates()
          .first;

      expect(candidates, isEmpty);
    });

    test('does not pair legs of different amounts', () async {
      await addTx(
        accountId: bankId,
        amountMinor: 50000,
        direction: TxDirection.debit,
        at: DateTime(2026, 7, 30, 9),
      );
      await addTx(
        accountId: cashId,
        amountMinor: 40000,
        direction: TxDirection.credit,
        at: DateTime(2026, 7, 30, 9, 5),
      );

      final candidates = await services.transactions
          .watchTransferCandidates()
          .first;

      expect(candidates, isEmpty);
    });

    test(
      'a dismissed pair stops being suggested even after reload',
      () async {
        final debitId = await addTx(
          accountId: bankId,
          amountMinor: 50000,
          direction: TxDirection.debit,
          at: DateTime(2026, 7, 30, 9),
        );
        final creditId = await addTx(
          accountId: cashId,
          amountMinor: 50000,
          direction: TxDirection.credit,
          at: DateTime(2026, 7, 30, 9, 5),
        );

        await services.transactions.dismissTransferCandidate(
          debitId: debitId,
          creditId: creditId,
        );

        final candidates = await services.transactions
            .watchTransferCandidates()
            .first;

        expect(candidates, isEmpty);
      },
    );
  });

  group('TransferRepository.linkTransfer', () {
    test(
      'creates a transfer and removes both legs from spend/income totals',
      () async {
        final debit = await services.transactions.insertDraft(
          TransactionDraft(
            amountMinor: 50000,
            direction: TxDirection.debit,
            source: TxSource.manual,
            transactedAt: DateTime(2026, 7, 30, 9),
            merchant: 'Test',
          ),
          accountId: bankId,
          idempotencyKey: 'test:${Ids.newId()}',
          status: TxStatus.confirmed,
        );
        final credit = await services.transactions.insertDraft(
          TransactionDraft(
            amountMinor: 50000,
            direction: TxDirection.credit,
            source: TxSource.manual,
            transactedAt: DateTime(2026, 7, 30, 9, 5),
            merchant: 'Test',
          ),
          accountId: cashId,
          idempotencyKey: 'test:${Ids.newId()}',
          status: TxStatus.confirmed,
        );

        final transfer = await services.transfers.linkTransfer(
          fromTransaction: debit,
          toTransaction: credit,
        );

        expect(transfer.fromAccountId, bankId);
        expect(transfer.toAccountId, cashId);
        expect(transfer.amountMinor, 50000);

        final remaining = await services.transactions.getAllForExport();
        expect(
          remaining,
          isEmpty,
          reason: 'both legs are soft-deleted once linked into a transfer',
        );

        final allTransfers = await services.transfers.watchAll().first;
        expect(allTransfers, hasLength(1));

        final stillCandidates = await services.transactions
            .watchTransferCandidates()
            .first;
        expect(stillCandidates, isEmpty);
      },
    );
  });
}
