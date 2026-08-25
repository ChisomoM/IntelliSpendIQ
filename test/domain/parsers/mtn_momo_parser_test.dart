import 'package:flutter_test/flutter_test.dart';
import 'package:intellispendiq/domain/models/enums.dart';
import 'package:intellispendiq/domain/models/parse_result.dart';
import 'package:intellispendiq/domain/models/transaction_draft.dart';
import 'package:intellispendiq/domain/parsers/mtn_momo_parser.dart';

import '../../support/corpus.dart';

void main() {
  late MtnMoMoParser parser;

  setUp(() => parser = MtnMoMoParser());

  TransactionDraft parse(String body, {String sender = Corpus.mtnSender}) {
    final result = parser.parse(Corpus.capture(body, sender: sender));
    expect(
      result,
      isA<ParseSuccess>(),
      reason: 'Expected a successful parse for: $body',
    );
    return (result as ParseSuccess).draft;
  }

  group('sender routing', () {
    test('claims both the shortcode and the shared numeric sender', () {
      expect(
        parser.canParse(
          Corpus.capture(Corpus.mtnTransfer, sender: Corpus.mtnSender),
        ),
        isTrue,
      );
      expect(
        parser.canParse(
          Corpus.capture(
            Corpus.mtnPaymentNfs,
            sender: Corpus.airtelNumericSender,
          ),
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

  test('parses an NFS merchant payment', () {
    final draft = parse(Corpus.mtnPaymentNfs);

    expect(draft.amountMinor, 303500);
    expect(draft.direction, TxDirection.debit);
    expect(draft.merchant, 'AIRTEL NFS');
    expect(draft.description, 'Chedvah Lombe,24879');
    expect(draft.externalRef, '9963344611');
    expect(draft.balanceMinor, 30084);
    expect(draft.transactedAt, DateTime(2026, 7, 13, 9, 24, 45));
    expect(draft.typeHint, 'payment');
    expect(draft.paymentMethod, 'mobile_money');
  });

  test('parses a P2P transfer', () {
    final draft = parse(Corpus.mtnTransfer);

    expect(draft.amountMinor, 100);
    expect(draft.direction, TxDirection.debit);
    expect(draft.merchant, 'Brenda Mutalama');
    expect(draft.description, isNull);
    expect(draft.metadata['recipient_phone'], '260769953282');
    expect(draft.metadata['wallet_account'], '64254454');
    expect(draft.externalRef, '10210893931');
    expect(draft.balanceMinor, 3725);
    expect(draft.transactedAt, DateTime(2026, 8, 10, 11, 25, 11));
    expect(draft.typeHint, 'send');
  });

  group('failure handling', () {
    test('reports failure rather than guessing on an unknown template', () {
      final result = parser.parse(
        Corpus.capture(
          'Y\'ello. You have received ZMW 50.00 from Jane.',
          sender: Corpus.mtnSender,
        ),
      );

      expect(result, isA<ParseFailure>());
      expect((result as ParseFailure).reason, isNotEmpty);
    });

    test('never throws on arbitrary bodies', () {
      for (final body in ['', '   ', 'Y\'ello.', 'Payment of ZMW', '¤¤¤ 12']) {
        expect(
          () => parser.parse(Corpus.capture(body, sender: Corpus.mtnSender)),
          returnsNormally,
          reason: 'Body: "$body"',
        );
      }
    });
  });

  test('every corpus sample parses successfully', () {
    for (final body in Corpus.mtnSamples) {
      expect(
        parser.parse(Corpus.capture(body, sender: Corpus.mtnSender)),
        isA<ParseSuccess>(),
        reason: 'Failed on: $body',
      );
    }
  });
}
