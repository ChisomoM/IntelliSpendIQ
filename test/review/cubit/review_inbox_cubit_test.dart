import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intellispendiq/app/app_services.dart';
import 'package:intellispendiq/core/ids.dart';
import 'package:intellispendiq/domain/models/enums.dart';
import 'package:intellispendiq/domain/models/transaction_draft.dart';
import 'package:intellispendiq/review/review.dart';

import '../../support/corpus.dart';
import '../../support/test_harness.dart';

void main() {
  late AppServices services;

  setUp(() async => services = await createTestServices());
  tearDown(() async => services.dispose());

  ReviewInboxCubit buildCubit() => ReviewInboxCubit(
    transactions: services.transactions,
    rawCaptures: services.rawCaptures,
    transfers: services.transfers,
  );

  group('ReviewInboxCubit', () {
    test('starts empty and idle', () {
      final cubit = buildCubit();
      addTearDown(cubit.close);

      expect(cubit.state.status, ReviewInboxStatus.initial);
      expect(cubit.state.isEmpty, isTrue);
      expect(cubit.state.pendingCount, 0);
    });

    blocTest<ReviewInboxCubit, ReviewInboxState>(
      'surfaces a message no parser could read',
      setUp: () async {
        await services.captureService.ingest(
          Corpus.capture('Airtel: your data bundle expires tomorrow.'),
        );
      },
      build: buildCubit,
      act: (cubit) => cubit.subscribe(),
      wait: const Duration(milliseconds: 100),
      verify: (cubit) {
        expect(cubit.state.failedCaptures, hasLength(1));
        expect(
          cubit.state.failedCaptures.single.body,
          'Airtel: your data bundle expires tomorrow.',
          reason: 'The original text must survive into the inbox',
        );
        expect(cubit.state.pendingCount, 1);
      },
    );

    blocTest<ReviewInboxCubit, ReviewInboxState>(
      'stays empty when everything parsed cleanly',
      setUp: () async {
        await services.captureService.ingest(
          Corpus.capture(Corpus.paymentTillNamed),
        );
      },
      build: buildCubit,
      act: (cubit) => cubit.subscribe(),
      wait: const Duration(milliseconds: 100),
      verify: (cubit) => expect(cubit.state.isEmpty, isTrue),
    );

    blocTest<ReviewInboxCubit, ReviewInboxState>(
      'flags a duplicate suspect without deleting either transaction',
      setUp: () async {
        await services.captureService.ingest(
          Corpus.capture(Corpus.withdrawal),
        );
        await services.captureService.ingest(
          Corpus.capture(
            'You have withdrawn K200.00 from 20068466 FELIX MONDE. '
            'Bal is K55.23. TID: CO260727.1958.D21999.',
            receivedAt: DateTime(2026, 7, 28, 9, 45),
          ),
        );
      },
      build: buildCubit,
      act: (cubit) => cubit.subscribe(),
      wait: const Duration(milliseconds: 100),
      verify: (cubit) async {
        expect(cubit.state.duplicates, hasLength(1));
        expect(
          await services.transactions.watchRecent().first,
          hasLength(2),
        );
      },
    );

    blocTest<ReviewInboxCubit, ReviewInboxState>(
      'confirming a suspect clears it from the inbox',
      setUp: () async {
        await services.captureService.ingest(
          Corpus.capture(Corpus.withdrawal),
        );
        await services.captureService.ingest(
          Corpus.capture(
            'You have withdrawn K200.00 from 20068466 FELIX MONDE. '
            'Bal is K55.23. TID: CO260727.1958.D21999.',
            receivedAt: DateTime(2026, 7, 28, 9, 45),
          ),
        );
      },
      build: buildCubit,
      act: (cubit) async {
        cubit.subscribe();
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await cubit.confirm(cubit.state.duplicates.single.id);
      },
      wait: const Duration(milliseconds: 100),
      verify: (cubit) async {
        expect(cubit.state.isEmpty, isTrue);
        expect(
          await services.transactions.watchRecent().first,
          hasLength(2),
          reason: 'Keeping both must delete neither',
        );
      },
    );

    blocTest<ReviewInboxCubit, ReviewInboxState>(
      'discarding a duplicate removes only that transaction',
      setUp: () async {
        await services.captureService.ingest(
          Corpus.capture(Corpus.withdrawal),
        );
        await services.captureService.ingest(
          Corpus.capture(
            'You have withdrawn K200.00 from 20068466 FELIX MONDE. '
            'Bal is K55.23. TID: CO260727.1958.D21999.',
            receivedAt: DateTime(2026, 7, 28, 9, 45),
          ),
        );
      },
      build: buildCubit,
      act: (cubit) async {
        cubit.subscribe();
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await cubit.discardDuplicate(cubit.state.duplicates.single.id);
      },
      wait: const Duration(milliseconds: 100),
      verify: (cubit) async {
        expect(cubit.state.isEmpty, isTrue);
        expect(
          await services.transactions.watchRecent().first,
          hasLength(1),
        );
      },
    );

    blocTest<ReviewInboxCubit, ReviewInboxState>(
      'categorizing confirms the transaction in one step',
      setUp: () async {
        await services.captureService.ingest(
          Corpus.capture('Unreadable but financial'),
        );
      },
      build: buildCubit,
      act: (cubit) async {
        final food = await services.categories.byName('Food');
        final tx = await services.transactions.insertDraft(
          _draft(),
          accountId: (await services.accounts.getDefault()).id,
          idempotencyKey: 'test:categorize',
          status: TxStatus.needsReview,
        );
        cubit.subscribe();
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await cubit.categorize(tx.id, food!.id);
      },
      wait: const Duration(milliseconds: 100),
      verify: (cubit) {
        expect(cubit.state.needsReview, isEmpty);
      },
    );

    blocTest<ReviewInboxCubit, ReviewInboxState>(
      'ignoring a capture keeps the text but clears the inbox',
      setUp: () async {
        await services.captureService.ingest(
          Corpus.capture('Airtel: promo message'),
        );
      },
      build: buildCubit,
      act: (cubit) async {
        cubit.subscribe();
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await cubit.ignoreCapture(cubit.state.failedCaptures.single.id);
      },
      wait: const Duration(milliseconds: 100),
      verify: (cubit) async {
        expect(cubit.state.isEmpty, isTrue);
        final counts = await services.rawCaptures.countByParseStatus();
        expect(counts[ParseStatus.ignored.name], 1);
      },
    );

    blocTest<ReviewInboxCubit, ReviewInboxState>(
      'surfaces a same-amount debit/credit pair on different accounts as '
      'a transfer candidate',
      setUp: () async {
        final cash = await services.accounts.create(
          name: 'Cash',
          type: AccountType.cash,
        );
        final airtel = await services.accounts.getDefault();
        await services.transactions.insertDraft(
          TransactionDraft(
            amountMinor: 30000,
            direction: TxDirection.debit,
            source: TxSource.manual,
            transactedAt: DateTime(2026, 7, 30, 9),
            merchant: 'Withdrawal',
          ),
          accountId: airtel.id,
          idempotencyKey: 'test:${Ids.newId()}',
          status: TxStatus.confirmed,
        );
        await services.transactions.insertDraft(
          TransactionDraft(
            amountMinor: 30000,
            direction: TxDirection.credit,
            source: TxSource.manual,
            transactedAt: DateTime(2026, 7, 30, 9, 10),
            merchant: 'Deposit',
          ),
          accountId: cash.id,
          idempotencyKey: 'test:${Ids.newId()}',
          status: TxStatus.confirmed,
        );
      },
      build: buildCubit,
      act: (cubit) => cubit.subscribe(),
      wait: const Duration(milliseconds: 100),
      verify: (cubit) {
        expect(cubit.state.transferCandidates, hasLength(1));
        expect(cubit.state.pendingCount, 1);
      },
    );

    blocTest<ReviewInboxCubit, ReviewInboxState>(
      'linking a transfer candidate removes it from the inbox and creates '
      'a Transfer',
      setUp: () async {
        final cash = await services.accounts.create(
          name: 'Cash',
          type: AccountType.cash,
        );
        final airtel = await services.accounts.getDefault();
        await services.transactions.insertDraft(
          TransactionDraft(
            amountMinor: 30000,
            direction: TxDirection.debit,
            source: TxSource.manual,
            transactedAt: DateTime(2026, 7, 30, 9),
            merchant: 'Withdrawal',
          ),
          accountId: airtel.id,
          idempotencyKey: 'test:${Ids.newId()}',
          status: TxStatus.confirmed,
        );
        await services.transactions.insertDraft(
          TransactionDraft(
            amountMinor: 30000,
            direction: TxDirection.credit,
            source: TxSource.manual,
            transactedAt: DateTime(2026, 7, 30, 9, 10),
            merchant: 'Deposit',
          ),
          accountId: cash.id,
          idempotencyKey: 'test:${Ids.newId()}',
          status: TxStatus.confirmed,
        );
      },
      build: buildCubit,
      act: (cubit) async {
        cubit.subscribe();
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await cubit.linkTransfer(cubit.state.transferCandidates.single);
      },
      wait: const Duration(milliseconds: 100),
      verify: (cubit) async {
        expect(cubit.state.transferCandidates, isEmpty);
        expect(cubit.state.isEmpty, isTrue);
        final transfers = await services.transfers.watchAll().first;
        expect(transfers, hasLength(1));
        expect(transfers.single.amountMinor, 30000);
      },
    );

    blocTest<ReviewInboxCubit, ReviewInboxState>(
      'dismissing a transfer candidate keeps both transactions and stops '
      're-suggesting them',
      setUp: () async {
        final cash = await services.accounts.create(
          name: 'Cash',
          type: AccountType.cash,
        );
        final airtel = await services.accounts.getDefault();
        await services.transactions.insertDraft(
          TransactionDraft(
            amountMinor: 30000,
            direction: TxDirection.debit,
            source: TxSource.manual,
            transactedAt: DateTime(2026, 7, 30, 9),
            merchant: 'Withdrawal',
          ),
          accountId: airtel.id,
          idempotencyKey: 'test:${Ids.newId()}',
          status: TxStatus.confirmed,
        );
        await services.transactions.insertDraft(
          TransactionDraft(
            amountMinor: 30000,
            direction: TxDirection.credit,
            source: TxSource.manual,
            transactedAt: DateTime(2026, 7, 30, 9, 10),
            merchant: 'Deposit',
          ),
          accountId: cash.id,
          idempotencyKey: 'test:${Ids.newId()}',
          status: TxStatus.confirmed,
        );
      },
      build: buildCubit,
      act: (cubit) async {
        cubit.subscribe();
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await cubit.dismissTransferCandidate(
          cubit.state.transferCandidates.single,
        );
      },
      wait: const Duration(milliseconds: 100),
      verify: (cubit) async {
        expect(cubit.state.transferCandidates, isEmpty);
        expect(cubit.state.isEmpty, isTrue);
        expect(
          await services.transactions.watchRecent().first,
          hasLength(2),
          reason: 'dismissing must not delete either transaction',
        );
      },
    );
  });
}

TransactionDraft _draft() => TransactionDraft(
  amountMinor: 4200,
  direction: TxDirection.debit,
  source: TxSource.manual,
  transactedAt: DateTime(2026, 7, 28),
  merchant: 'Needs a category',
);
