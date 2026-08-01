import 'package:flutter_test/flutter_test.dart';
import 'package:intellispendiq/domain/models/enums.dart';
import 'package:intellispendiq/domain/models/parse_result.dart';
import 'package:intellispendiq/domain/models/transaction_draft.dart';
import 'package:intellispendiq/domain/parsers/airtel_money_parser.dart';

import '../../support/corpus.dart';

void main() {
  late AirtelMoneyParser parser;

  setUp(() => parser = AirtelMoneyParser());

  TransactionDraft parse(String body) {
    final result = parser.parse(Corpus.capture(body));
    expect(
      result,
      isA<ParseSuccess>(),
      reason: 'Expected a successful parse for: $body',
    );
    return (result as ParseSuccess).draft;
  }

  group('sender routing', () {
    test('claims both the alphanumeric and numeric sender IDs', () {
      expect(parser.canParse(Corpus.capture(Corpus.withdrawal)), isTrue);
      expect(
        parser.canParse(
          Corpus.capture(
            Corpus.withdrawal,
            sender: Corpus.airtelNumericSender,
          ),
        ),
        isTrue,
      );
    });

    test('normalizes senders with a leading + and spaces', () {
      expect(
        parser.canParse(
          Corpus.capture(Corpus.withdrawal, sender: '+247 835 66639'),
        ),
        isTrue,
      );
    });

    test('does not claim another provider', () {
      expect(
        parser.canParse(
          Corpus.capture(
            Corpus.stanChartTransfer,
            sender: Corpus.stanChartSender,
          ),
        ),
        isFalse,
      );
    });
  });

  group('payment_till', () {
    test('parses a named till payment', () {
      final draft = parse(Corpus.paymentTillNamed);

      expect(draft.amountMinor, 1000);
      expect(draft.direction, TxDirection.debit);
      expect(
        draft.merchant,
        'SOCHESCARE AIRTEL NETWORKS SELF CARE SOCHE',
      );
      expect(draft.externalRef, 'MP260728.0729.D08222');
      expect(draft.balanceMinor, 4523);
      expect(draft.typeHint, 'payment_till');
      expect(draft.paymentMethod, 'mobile_money');
    });

    test('separates a numeric till from the merchant name', () {
      final draft = parse(Corpus.paymentTillNumeric);

      expect(draft.amountMinor, 100);
      expect(draft.direction, TxDirection.debit);
      expect(draft.merchant, 'GOODFELLOW DIGITAL LIMITED');
      expect(draft.metadata['till'], '300770');
      expect(draft.externalRef, 'MP260727.1129.Y34799');
      expect(draft.balanceMinor, 46653);
    });
  });

  test('withdrawal keeps the agent name and number apart', () {
    final draft = parse(Corpus.withdrawal);

    expect(draft.amountMinor, 20000);
    expect(draft.direction, TxDirection.debit);
    expect(draft.merchant, 'FELIX MONDE');
    expect(draft.metadata['agent_number'], '20068466');
    expect(draft.externalRef, 'CO260727.1954.D21146');
    expect(draft.balanceMinor, 5523);
    expect(draft.typeHint, 'withdrawal');
  });

  test('money sent captures recipient and phone despite missing spaces', () {
    final draft = parse(Corpus.moneySent);

    expect(draft.amountMinor, 20500);
    expect(draft.direction, TxDirection.debit);
    expect(draft.merchant, 'Sibeso Nyumbu');
    expect(draft.metadata['recipient_phone'], '979142832');
    expect(draft.externalRef, 'PP260727.1512.M73944');
    expect(draft.balanceMinor, 26023);
  });

  group('paid_to', () {
    test('uses the embedded date rather than the received time', () {
      final draft = parse(Corpus.paidWithCharge);

      expect(draft.amountMinor, 60000);
      expect(draft.direction, TxDirection.debit);
      expect(draft.merchant, 'GLOBAL PAY COLLECTIONS');
      expect(draft.externalRef, 'XX260726.1524.M81597');
      expect(draft.balanceMinor, 60135);
      expect(draft.transactedAt, DateTime(2026, 7, 26, 15, 24));
    });

    test('ignores a zero charge instead of recording a fee line', () {
      expect(parse(Corpus.paidWithCharge).feeMinor, isNull);
    });

    test('records a non-zero charge as a fee', () {
      final draft = parse(
        'PAID K600.00 to GLOBAL PAY COLLECTIONS Charge K2.50, '
        'TID XX260726.1524.M81598. Bal K601.35 '
        'Date: 26-July-2026 15:24.',
      );

      expect(draft.amountMinor, 60000);
      expect(draft.feeMinor, 250);
    });

    test('strips the trailing marketing link from the merchant', () {
      expect(parse(Corpus.paidWithCharge).merchant, isNot(contains('http')));
    });
  });

  group('credits', () {
    test('accepts the K shorthand for kwacha', () {
      final draft = parse(Corpus.receivedShorthand);

      expect(draft.amountMinor, 30000);
      expect(draft.direction, TxDirection.credit);
      expect(draft.merchant, 'CHISOMO MUTALE');
      expect(draft.externalRef, 'CI260726.1522.A37452');
      expect(draft.description, 'Mobile Money Transfer');
    });

    test('parses a settlement credit and splits the account number', () {
      final draft = parse(Corpus.moneyReceived);

      expect(draft.amountMinor, 135000);
      expect(draft.direction, TxDirection.credit);
      expect(draft.merchant, 'NFS SETTLEMENT ACCOUNT');
      expect(draft.metadata['sender_number'], '0245970');
      expect(draft.externalRef, 'CI260726.1451.D36552');
    });
  });

  group('amount normalization', () {
    test('handles thousands separators', () {
      final draft = parse(
        'Money received K1,350.00 from 0245970 NFS SETTLEMENT ACCOUNT. '
        'TID: CI260726.1451.D36553',
      );
      expect(draft.amountMinor, 135000);
    });

    test('handles a K amount with a space and decimals', () {
      final draft = parse(
        'You have received K 300.50 from CHISOMO MUTALE. Txn. ID: '
        'CI260726.1522.A37453.',
      );
      expect(draft.amountMinor, 30050);
    });
  });

  group('failure handling', () {
    test('reports failure rather than guessing on an unknown template', () {
      final result = parser.parse(
        Corpus.capture('Your Airtel line has been recharged with 5GB of data.'),
      );

      expect(result, isA<ParseFailure>());
      expect((result as ParseFailure).reason, isNotEmpty);
    });

    test('never throws on arbitrary bodies', () {
      for (final body in ['', '   ', 'ZMW', 'Payment of ZMW', '¤¤¤ 12']) {
        expect(
          () => parser.parse(Corpus.capture(body)),
          returnsNormally,
          reason: 'Body: "$body"',
        );
      }
    });
  });

  test('every corpus sample parses successfully', () {
    for (final body in Corpus.airtelSamples) {
      expect(
        parser.parse(Corpus.capture(body)),
        isA<ParseSuccess>(),
        reason: 'Failed on: $body',
      );
    }
  });
}
