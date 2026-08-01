import 'package:flutter_test/flutter_test.dart';
import 'package:intellispendiq/domain/models/enums.dart';
import 'package:intellispendiq/domain/models/parse_result.dart';
import 'package:intellispendiq/domain/parsers/stanchart_parser.dart';

import '../../support/corpus.dart';

void main() {
  late StanChartParser parser;

  setUp(() => parser = StanChartParser());

  test('claims both StanChart sender IDs', () {
    expect(
      parser.canParse(
        Corpus.capture(
          Corpus.stanChartTransfer,
          sender: Corpus.stanChartSender,
        ),
      ),
      isTrue,
    );
    expect(
      parser.canParse(
        Corpus.capture(
          Corpus.stanChartTransfer,
          sender: Corpus.stanChartNumericSender,
        ),
      ),
      isTrue,
    );
  });

  test('parses the outbound transfer template', () {
    final result = parser.parse(
      Corpus.capture(
        Corpus.stanChartTransfer,
        sender: Corpus.stanChartSender,
      ),
    );

    expect(result, isA<ParseSuccess>());
    final draft = (result as ParseSuccess).draft;
    expect(draft.amountMinor, 30000);
    expect(draft.direction, TxDirection.debit);
    expect(draft.merchant, 'Airtel');
    expect(draft.externalRef, 'ZM2607260050941958');
    expect(draft.paymentMethod, 'bank');
  });

  test(
    'sends unknown bank templates to review rather than guessing',
    () {
      // Only the outbound-transfer format is known so far. POS, ATM, and
      // incoming templates must fail loudly so they surface in the
      // Review Inbox and can be added to the parser.
      const posPurchase =
          'Dear Client, your card ending 1234 was used for a POS purchase '
          'of K250.00 at SHOPRITE.';
      const incoming =
          'Dear Client, K500.00 has been credited to your account.';
      const atmWithdrawal =
          'Your ATM withdrawal of K1000.00 was successful.';
      final unknownTemplates = [posPurchase, incoming, atmWithdrawal];

      for (final body in unknownTemplates) {
        expect(
          parser.parse(
            Corpus.capture(body, sender: Corpus.stanChartSender),
          ),
          isA<ParseFailure>(),
          reason: 'Should not have parsed: $body',
        );
      }
    },
  );

  test('never throws on arbitrary bodies', () {
    for (final body in ['', 'transaction of', 'ref.']) {
      expect(
        () => parser.parse(
          Corpus.capture(body, sender: Corpus.stanChartSender),
        ),
        returnsNormally,
      );
    }
  });
}
