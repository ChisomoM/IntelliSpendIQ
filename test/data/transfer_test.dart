import 'package:flutter_test/flutter_test.dart';
import 'package:intellispendiq/app/app_services.dart';
import 'package:intellispendiq/core/ids.dart';
import 'package:intellispendiq/data/repositories/transfer_repository.dart';
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

  group('TransferRepository.create', () {
    test(
      'records a transfer with no transaction on either side — the ATM '
      'cash-withdrawal case, where cash has no way to send its own SMS',
      () async {
        final transfer = await services.transfers.create(
          fromAccountId: bankId,
          toAccountId: cashId,
          amountMinor: 20000,
          transactedAt: DateTime(2026, 7, 30, 14),
        );

        expect(transfer.fromAccountId, bankId);
        expect(transfer.toAccountId, cashId);
        expect(transfer.amountMinor, 20000);

        final balances = await services.accounts.watchComputedBalances().first;
        expect(balances[bankId], -20000);
        expect(balances[cashId], 20000);

        final all = await services.transfers.watchAll().first;
        expect(all, hasLength(1));
        expect(all.single.id, transfer.id);
      },
    );

    test(
      'optional fee becomes a Fees/Charges debit on the from-account',
      () async {
        final feeCategory = await services.categories.byName('Fees/Charges');
        expect(feeCategory, isNotNull);

        final transfer = await services.transfers.create(
          fromAccountId: bankId,
          toAccountId: cashId,
          amountMinor: 30000,
          transactedAt: DateTime(2026, 7, 30, 14),
          feeMinor: 500,
        );

        final fee = await services.transfers.findFeeForTransfer(transfer.id);
        expect(fee, isNotNull);
        expect(fee!.amountMinor, 500);
        expect(fee.accountId, bankId);
        expect(fee.direction, TxDirection.debit);
        expect(fee.categoryId, feeCategory!.id);
        expect(fee.metadata['family'], 'fee');
        expect(fee.metadata['transferId'], transfer.id);
        expect(
          fee.idempotencyKey,
          TransferRepository.feeIdempotencyKey(transfer.id),
        );

        final balances = await services.accounts.watchComputedBalances().first;
        // Transfer moves 300; fee spend takes another 5 from bank.
        expect(balances[bankId], -30500);
        expect(balances[cashId], 30000);
      },
    );
  });

  group('TransferRepository.convertFromTransaction', () {
    test(
      'debit becomes from→to transfer and leaves spend totals',
      () async {
        final debit = await services.transactions.insertDraft(
          TransactionDraft(
            amountMinor: 15000,
            direction: TxDirection.debit,
            source: TxSource.manual,
            transactedAt: DateTime(2026, 7, 30, 11),
            merchant: 'ATM Withdrawal',
          ),
          accountId: bankId,
          idempotencyKey: 'test:${Ids.newId()}',
          status: TxStatus.confirmed,
        );

        final transfer = await services.transfers.convertFromTransaction(
          source: debit,
          otherAccountId: cashId,
          amountMinor: debit.amountMinor,
          transactedAt: debit.transactedAt,
          note: debit.merchant,
        );

        expect(transfer.fromAccountId, bankId);
        expect(transfer.toAccountId, cashId);
        expect(transfer.amountMinor, 15000);
        expect(transfer.note, 'ATM Withdrawal');

        final remaining = await services.transactions.getAllForExport();
        expect(remaining, isEmpty);

        final balances = await services.accounts.watchComputedBalances().first;
        expect(balances[bankId], -15000);
        expect(balances[cashId], 15000);
      },
    );

    test(
      'credit becomes to-side transfer (money arrived from other account)',
      () async {
        final credit = await services.transactions.insertDraft(
          TransactionDraft(
            amountMinor: 8000,
            direction: TxDirection.credit,
            source: TxSource.manual,
            transactedAt: DateTime(2026, 7, 30, 12),
            merchant: 'Bank deposit',
          ),
          accountId: cashId,
          idempotencyKey: 'test:${Ids.newId()}',
          status: TxStatus.confirmed,
        );

        final transfer = await services.transfers.convertFromTransaction(
          source: credit,
          otherAccountId: bankId,
          amountMinor: credit.amountMinor,
          transactedAt: credit.transactedAt,
        );

        expect(transfer.fromAccountId, bankId);
        expect(transfer.toAccountId, cashId);
        expect(transfer.amountMinor, 8000);

        final remaining = await services.transactions.getAllForExport();
        expect(remaining, isEmpty);
      },
    );

    test('convert with fee keeps a spend line on the from-account', () async {
      final debit = await services.transactions.insertDraft(
        TransactionDraft(
          amountMinor: 20000,
          direction: TxDirection.debit,
          source: TxSource.manual,
          transactedAt: DateTime(2026, 7, 30, 11),
        ),
        accountId: bankId,
        idempotencyKey: 'test:${Ids.newId()}',
        status: TxStatus.confirmed,
      );

      final transfer = await services.transfers.convertFromTransaction(
        source: debit,
        otherAccountId: cashId,
        amountMinor: 20000,
        transactedAt: debit.transactedAt,
        feeMinor: 250,
      );

      final live = await services.transactions.getAllForExport();
      expect(live, hasLength(1));
      expect(live.single.amountMinor, 250);
      expect(live.single.accountId, bankId);
      expect(live.single.metadata['transferId'], transfer.id);

      final balances = await services.accounts.watchComputedBalances().first;
      expect(balances[bankId], -20250);
      expect(balances[cashId], 20000);
    });
  });

  group('TransferRepository.updateFields and softDelete', () {
    test('updates amount and note, then soft-delete removes it from watchAll',
        () async {
      final transfer = await services.transfers.create(
        fromAccountId: bankId,
        toAccountId: cashId,
        amountMinor: 10000,
        transactedAt: DateTime(2026, 7, 30, 15),
        note: 'Original',
      );

      await services.transfers.updateFields(
        transfer.id,
        amountMinor: 12000,
        note: 'Updated',
      );

      final updated = await services.transfers.watchAll().first;
      expect(updated, hasLength(1));
      expect(updated.single.amountMinor, 12000);
      expect(updated.single.note, 'Updated');

      await services.transfers.softDelete(transfer.id);
      expect(await services.transfers.watchAll().first, isEmpty);

      await services.transfers.undelete(transfer.id);
      final restored = await services.transfers.watchAll().first;
      expect(restored, hasLength(1));
      expect(restored.single.id, transfer.id);
      expect(restored.single.amountMinor, 12000);
    });

    test('soft-delete cascades to the linked fee; undelete restores both',
        () async {
      final transfer = await services.transfers.create(
        fromAccountId: bankId,
        toAccountId: cashId,
        amountMinor: 10000,
        transactedAt: DateTime(2026, 7, 30, 15),
        feeMinor: 100,
      );

      expect(await services.transfers.findFeeForTransfer(transfer.id), isNotNull);

      await services.transfers.softDelete(transfer.id);
      expect(await services.transfers.findFeeForTransfer(transfer.id), isNull);
      expect(await services.transactions.getAllForExport(), isEmpty);

      await services.transfers.undelete(transfer.id);
      final fee = await services.transfers.findFeeForTransfer(transfer.id);
      expect(fee, isNotNull);
      expect(fee!.amountMinor, 100);

      final balances = await services.accounts.watchComputedBalances().first;
      expect(balances[bankId], -10100);
      expect(balances[cashId], 10000);
    });

    test('updateFields can add, change, and clear a fee', () async {
      final transfer = await services.transfers.create(
        fromAccountId: bankId,
        toAccountId: cashId,
        amountMinor: 10000,
        transactedAt: DateTime(2026, 7, 30, 15),
      );

      await services.transfers.updateFields(transfer.id, feeMinor: 200);
      expect(
        (await services.transfers.findFeeForTransfer(transfer.id))!.amountMinor,
        200,
      );

      await services.transfers.updateFields(transfer.id, feeMinor: 350);
      expect(
        (await services.transfers.findFeeForTransfer(transfer.id))!.amountMinor,
        350,
      );

      await services.transfers.updateFields(transfer.id, clearFee: true);
      expect(await services.transfers.findFeeForTransfer(transfer.id), isNull);
    });
  });

  group('findTransferCandidateFor', () {
    test('returns the candidate that involves the transaction', () async {
      final debitId = await addTx(
        accountId: bankId,
        amountMinor: 50000,
        direction: TxDirection.debit,
        at: DateTime(2026, 7, 30, 9),
      );
      await addTx(
        accountId: cashId,
        amountMinor: 50000,
        direction: TxDirection.credit,
        at: DateTime(2026, 7, 30, 9, 10),
      );

      final match = await services.transactions.findTransferCandidateFor(
        debitId,
      );

      expect(match, isNotNull);
      expect(match!.debit.id, debitId);
      expect(match.credit.accountId, cashId);
    });
  });
}
