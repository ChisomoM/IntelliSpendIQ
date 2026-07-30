import 'package:flutter_test/flutter_test.dart';
import 'package:intellispendiq/domain/parsers/parser_registry.dart';

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
    });
  });
}
