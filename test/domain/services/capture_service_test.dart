import 'package:flutter_test/flutter_test.dart';
import 'package:intellispendiq/app/app_services.dart';
import 'package:intellispendiq/domain/models/enums.dart';
import 'package:intellispendiq/domain/parsers/airtel_money_parser.dart';
import 'package:intellispendiq/domain/parsers/stanchart_parser.dart';
import 'package:intellispendiq/domain/services/capture_service.dart';

import '../../support/corpus.dart';
import '../../support/test_harness.dart';

void main() {
  late AppServices services;

  setUp(() async => services = await createTestServices());
  tearDown(() async => services.dispose());

  group('happy path', () {
    test('auto-saves a parsed Airtel payment as confirmed', () async {
      final result = await services.captureService.ingest(
        Corpus.capture(Corpus.paymentTillNamed),
      );

      expect(result.status, IngestStatus.saved);
      expect(result.transaction, isNotNull);
      expect(result.transaction!.status, TxStatus.confirmed);
      expect(result.transaction!.amountMinor, 1000);
      expect(result.transaction!.source, TxSource.sms);
      expect(result.transaction!.externalRef, 'MP260728.0729.D08222');
    });

    test('links the transaction back to its raw capture', () async {
      final result = await services.captureService.ingest(
        Corpus.capture(Corpus.withdrawal),
      );

      final raw = await services.rawCaptures.byId(result.rawCapture!.id);
      expect(raw!.parseStatus, ParseStatus.parsed);
      expect(raw.parsedTransactionId, result.transaction!.id);
      expect(raw.parserKey, AirtelMoneyParser.providerKey);
      expect(result.transaction!.rawCaptureId, raw.id);
    });

    test(
      'does not treat the balance reported by the message as ground '
      'truth — SMS delivery is not reliable enough for that',
      () async {
        await services.captureService.ingest(
          Corpus.capture(Corpus.paymentTillNamed),
        );

        final account = await services.accounts.findOrCreateForProvider(
          AirtelMoneyParser.providerKey,
        );
        expect(
          account.balanceMinor,
          isNull,
          reason: 'balanceMinor is a manual checkpoint only, never SMS-set',
        );

        final computed = await services.accounts.watchComputedBalances().first;
        expect(
          computed[account.id],
          -1000,
          reason:
              'with no checkpoint set, the computed balance is just the '
              'ledger from account creation — one confirmed debit of '
              '10.00 kwacha',
        );
      },
    );

    test('creates the StanChart account on its first parsed message', () async {
      final before = await services.accounts.getAll();
      expect(before.map((a) => a.providerKey), isNot(contains('stan_chart')));

      final result = await services.captureService.ingest(
        Corpus.capture(
          Corpus.stanChartTransfer,
          sender: Corpus.stanChartSender,
        ),
      );

      expect(result.status, IngestStatus.saved);
      final after = await services.accounts.getAll();
      final stanChart = after.firstWhere(
        (a) => a.providerKey == StanChartParser.providerKey,
      );
      expect(result.transaction!.accountId, stanChart.id);
      expect(stanChart.type, AccountType.bank);
    });

    test('records a non-zero charge as its own fee transaction', () async {
      await services.captureService.ingest(
        Corpus.capture(
          'PAID K600.00 to GLOBAL PAY COLLECTIONS Charge K2.50, '
          'TID XX260726.1524.M81599. Bal K601.35 '
          'Date: 26-July-2026 15:24.',
        ),
      );

      final rows = await services.transactions.watchRecent().first;
      expect(rows, hasLength(2));
      final fee = rows.firstWhere((r) => r.amountMinor == 250);
      final feeCategory = await services.categories.byName('Fees/Charges');
      expect(fee.categoryId, feeCategory!.id);
    });
  });

  group('never drops a capture', () {
    test('stores the raw body when no parser rule matches', () async {
      const body = 'Your Airtel line has been recharged with 5GB of data.';
      final result = await services.captureService.ingest(
        Corpus.capture(body),
      );

      expect(result.status, IngestStatus.parseFailed);
      expect(result.transaction, isNull);
      final raw = await services.rawCaptures.byId(result.rawCapture!.id);
      expect(raw!.body, body, reason: 'The original text must be preserved');
      expect(raw.parseStatus, ParseStatus.failed);
      expect(raw.error, isNotEmpty);
    });

    test('failed parses surface in the review inbox', () async {
      await services.captureService.ingest(
        Corpus.capture('Something we cannot read'),
      );

      final failed = await services.rawCaptures.watchFailed().first;
      expect(failed, hasLength(1));
    });

    test('stores messages from unknown senders as ignored', () async {
      final result = await services.captureService.ingest(
        Corpus.capture('Hey, are we still meeting at 5?', sender: 'Mum'),
      );

      expect(result.status, IngestStatus.ignored);
      final raw = await services.rawCaptures.byId(result.rawCapture!.id);
      expect(raw!.parseStatus, ParseStatus.ignored);
      expect(raw.body, 'Hey, are we still meeting at 5?');

      // Ignored captures are stored but must not clutter the inbox.
      final failed = await services.rawCaptures.watchFailed().first;
      expect(failed, isEmpty);
    });
  });

  group('duplicate handling', () {
    test('re-delivering the same message does not double-count', () async {
      final first = await services.captureService.ingest(
        Corpus.capture(Corpus.paymentTillNamed),
      );
      final second = await services.captureService.ingest(
        Corpus.capture(Corpus.paymentTillNamed),
      );

      expect(first.status, IngestStatus.saved);
      expect(second.status, IngestStatus.skippedExisting);

      final rows = await services.transactions.watchRecent().first;
      expect(rows, hasLength(1));
    });

    test('a re-backfill with the same SMS id is skipped', () async {
      await services.captureService.ingest(
        Corpus.capture(Corpus.withdrawal, androidSmsId: '42'),
      );
      final second = await services.captureService.ingest(
        Corpus.capture(
          Corpus.withdrawal,
          androidSmsId: '42',
          // Different timestamp so only the SMS id can catch it.
          receivedAt: DateTime(2026, 7, 29, 11),
        ),
      );

      expect(second.status, IngestStatus.skippedExisting);
      expect(await services.transactions.watchRecent().first, hasLength(1));
    });

    test(
      'the same TID arriving later links instead of inserting again',
      () async {
        await services.captureService.ingest(
          Corpus.capture(Corpus.withdrawal),
        );
        // Same provider reference, delivered hours later — a genuine
        // re-send, not a second withdrawal.
        final second = await services.captureService.ingest(
          Corpus.capture(
            Corpus.withdrawal,
            receivedAt: DateTime(2026, 7, 28, 18, 45),
          ),
        );

        expect(second.status, IngestStatus.alreadyCaptured);
        expect(second.transaction, isNotNull);
        expect(await services.transactions.watchRecent().first, hasLength(1));

        final raw = await services.rawCaptures.byId(second.rawCapture!.id);
        expect(raw!.parsedTransactionId, second.transaction!.id);
      },
    );

    test(
      'a same-amount same-merchant repeat is flagged, not dropped',
      () async {
        await services.captureService.ingest(
          Corpus.capture(Corpus.withdrawal),
        );
        // Same amount and agent minutes later with a different TID: could
        // be a real second withdrawal, so a human decides.
        final second = await services.captureService.ingest(
          Corpus.capture(
            'You have withdrawn K200.00 from 20068466 FELIX MONDE. '
            'Bal is K55.23. TID: CO260727.1958.D21999.',
            receivedAt: DateTime(2026, 7, 28, 9, 45),
          ),
        );

        expect(second.status, IngestStatus.duplicateSuspect);
        expect(
          second.transaction!.status,
          TxStatus.duplicateSuspect,
          reason: 'The suspect must still be stored for review',
        );
        expect(second.transaction!.duplicateOfId, isNotNull);
        expect(await services.transactions.watchRecent().first, hasLength(2));
      },
    );

    test('confirming a suspect keeps both transactions', () async {
      await services.captureService.ingest(Corpus.capture(Corpus.withdrawal));
      final suspect = await services.captureService.ingest(
        Corpus.capture(
          'You have withdrawn K200.00 from 20068466 FELIX MONDE. '
          'Bal is K55.23. TID: CO260727.1958.D21999.',
          receivedAt: DateTime(2026, 7, 28, 9, 45),
        ),
      );

      await services.transactions.confirm(suspect.transaction!.id);

      final rows = await services.transactions.watchRecent().first;
      expect(rows, hasLength(2), reason: 'Keeping both must delete neither');
      expect(
        rows.map((r) => r.status),
        everyElement(TxStatus.confirmed),
      );
      expect(
        await services.transactions
            .watchByStatus(TxStatus.duplicateSuspect)
            .first,
        isEmpty,
      );
    });

    test('a different merchant at the same amount is not flagged', () async {
      await services.captureService.ingest(Corpus.capture(Corpus.withdrawal));
      final second = await services.captureService.ingest(
        Corpus.capture(
          'You have withdrawn K200.00 from 20068477 MARY BANDA. '
          'Bal is K55.23. TID: CO260727.1959.D21888.',
          receivedAt: DateTime(2026, 7, 28, 9, 45),
        ),
      );

      expect(second.status, IngestStatus.saved);
    });
  });

  test('the whole corpus is captured without loss', () async {
    for (final body in Corpus.airtelSamples) {
      final result = await services.captureService.ingest(
        Corpus.capture(body),
      );
      expect(
        result.status,
        IngestStatus.saved,
        reason: 'Expected a clean capture for: $body',
      );
    }
    await services.captureService.ingest(
      Corpus.capture(
        Corpus.stanChartTransfer,
        sender: Corpus.stanChartSender,
      ),
    );

    final rows = await services.transactions.watchRecent().first;
    // Seven Airtel samples plus the StanChart transfer; no fee lines
    // because every charge in the corpus is zero.
    expect(rows, hasLength(8));
    expect(await services.rawCaptures.watchFailed().first, isEmpty);
  });

  group('merchant categorization', () {
    test(
      'auto-categorizes a fuel station payment as Transport by keyword',
      () async {
        final result = await services.captureService.ingest(
          Corpus.capture(
            'Payment of K10.00 Till Number FUEL STATION PUMA ENERGY. '
            'Airtel Money bal is K45.23. TID : MP260728.0729.D08222.',
          ),
        );

        final transport = await services.categories.byName('Transport');
        expect(result.transaction!.categoryId, transport!.id);
      },
    );

    test('leaves an unrecognized merchant uncategorized', () async {
      final result = await services.captureService.ingest(
        Corpus.capture(Corpus.paymentTillNamed),
      );

      expect(result.transaction!.categoryId, isNull);
    });

    test(
      'a learned correction is applied to the next capture from the same '
      'merchant',
      () async {
        const merchant = 'CORNER CAFE LUSAKA';
        final shopping = await services.categories.byName('Shopping');

        // First capture: "cafe" would default to Food, but nothing has
        // been learned yet either way — assert the keyword default...
        final first = await services.captureService.ingest(
          Corpus.capture(
            'Payment of K10.00 Till Number $merchant. Airtel Money bal is '
            'K45.23. TID : MP260728.0729.D08222.',
          ),
        );
        final food = await services.categories.byName('Food');
        expect(first.transaction!.categoryId, food!.id);

        // ...then the user recategorizes it as Shopping, which should
        // stick for the next message from the same merchant.
        await services.merchantCategorizer.learnFrom(
          merchant: merchant,
          categoryId: shopping!.id,
        );

        final second = await services.captureService.ingest(
          Corpus.capture(
            'Payment of K15.00 Till Number $merchant. Airtel Money bal is '
            'K30.23. TID : MP260728.0730.D08223.',
          ),
        );

        expect(second.transaction!.categoryId, shopping.id);
      },
    );
  });
}
