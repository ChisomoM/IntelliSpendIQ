import 'package:flutter_test/flutter_test.dart';
import 'package:intellispendiq/domain/models/parse_result.dart';
import 'package:intellispendiq/domain/parsers/airtel_money_parser.dart';
import 'package:intellispendiq/domain/parsers/mtn_momo_parser.dart';
import 'package:intellispendiq/domain/parsers/parser_registry.dart';

import '../../support/corpus.dart';

void main() {
  group('ParserRegistry custom senders', () {
    test('addCustomSender() routes an unrecognized sender to a provider', () {
      final registry = ParserRegistry();

      expect(registry.findBySender('MyBankZM'), isNull);

      registry.addCustomSender('stan_chart', 'MyBankZM');

      expect(registry.findBySender('MyBankZM')?.key, 'stan_chart');
      expect(registry.isKnownSender('MyBankZM'), isTrue);
      expect(registry.knownSenderIds, contains('mybankzm'));
    });

    test('removeCustomSender() stops routing it', () {
      final registry = ParserRegistry()
        ..addCustomSender('airtel_money', '90210');

      registry.removeCustomSender('90210');

      expect(registry.findBySender('90210'), isNull);
    });

    test('setCustomSenders() replaces the whole map at once', () {
      final registry = ParserRegistry()
        ..addCustomSender('airtel_money', 'old-sender');

      registry.setCustomSenders({'new-sender': 'stan_chart'});

      expect(registry.findBySender('old-sender'), isNull);
      expect(registry.findBySender('new-sender')?.key, 'stan_chart');
    });

    test('built-in sender IDs still resolve alongside custom ones', () {
      final registry = ParserRegistry()
        ..addCustomSender('stan_chart', 'MyBankZM');

      expect(registry.findBySender('airtelmoney')?.key, 'airtel_money');
      expect(registry.findBySender('6666')?.key, 'mtn_momo');
    });
  });

  group('shared numeric sender', () {
    test('routes an Airtel body on the shared number to Airtel', () {
      final parsed = ParserRegistry().parse(
        Corpus.capture(
          Corpus.withdrawal,
          sender: Corpus.airtelNumericSender,
        ),
      );

      expect(parsed, isNotNull);
      final (provider, result) = parsed!;
      expect(provider.key, AirtelMoneyParser.providerKey);
      expect(result, isA<ParseSuccess>());
    });

    test('falls through to MTN when the Airtel rules miss', () {
      final parsed = ParserRegistry().parse(
        Corpus.capture(
          Corpus.mtnPaymentNfs,
          sender: Corpus.airtelNumericSender,
        ),
      );

      expect(parsed, isNotNull);
      final (provider, result) = parsed!;
      expect(provider.key, MtnMoMoParser.providerKey);
      expect(result, isA<ParseSuccess>());
      expect((result as ParseSuccess).draft.externalRef, '9963344611');
    });

    test('routes the MTN shortcode without touching Airtel', () {
      final parsed = ParserRegistry().parse(
        Corpus.capture(Corpus.mtnTransfer, sender: Corpus.mtnSender),
      );

      expect(parsed, isNotNull);
      expect(parsed!.$1.key, MtnMoMoParser.providerKey);
      expect(parsed.$2, isA<ParseSuccess>());
    });
  });
}
