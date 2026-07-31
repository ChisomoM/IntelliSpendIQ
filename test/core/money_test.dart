import 'package:flutter_test/flutter_test.dart';
import 'package:intellispendiq/core/money.dart';

void main() {
  group('tryParseToMinor', () {
    test('parses plain and decimal amounts', () {
      expect(Money.tryParseToMinor('10'), 1000);
      expect(Money.tryParseToMinor('10.00'), 1000);
      expect(Money.tryParseToMinor('0.75'), 75);
      expect(Money.tryParseToMinor('1350'), 135000);
    });

    test('treats a single decimal place as tenths', () {
      expect(Money.tryParseToMinor('10.5'), 1050);
    });

    test('handles thousands separators and currency prefixes', () {
      expect(Money.tryParseToMinor('1,350.00'), 135000);
      expect(Money.tryParseToMinor('ZMW 1,350.00'), 135000);
      expect(Money.tryParseToMinor('K300'), 30000);
      expect(Money.tryParseToMinor('K 300.50'), 30050);
    });

    test('rejects values that are not plain positive amounts', () {
      expect(Money.tryParseToMinor(''), isNull);
      expect(Money.tryParseToMinor('abc'), isNull);
      expect(Money.tryParseToMinor('-5.00'), isNull);
      expect(Money.tryParseToMinor('10.005'), isNull);
    });
  });

  group('minorFromDouble', () {
    test('rounds to the nearest ngwee', () {
      expect(Money.minorFromDouble(50), 5000);
      expect(Money.minorFromDouble(12.345), 1235);
      expect(Money.minorFromDouble(0.1), 10);
    });

    test('survives values that are not exact in binary floating point', () {
      // 0.1 + 0.2 == 0.30000000000000004 as a double; storing minor units
      // is what keeps totals from drifting.
      expect(Money.minorFromDouble(0.1 + 0.2), 30);
    });
  });

  group('format', () {
    test('uses the K symbol with no space, and always shows ngwee', () {
      expect(Money.format(1000), 'K10.00');
      expect(Money.format(135000), 'K1,350.00');
      expect(Money.format(75), 'K0.75');
      expect(Money.format(0), 'K0.00');
    });

    test('groups thousands', () {
      expect(Money.format(1248000), 'K12,480.00');
    });

    test('signs a negative with a true minus, not a hyphen', () {
      expect(Money.format(-1000), '−K10.00');
      expect(Money.format(-1000).contains('-'), isFalse);
    });

    test('names a foreign currency instead of showing a bare K', () {
      expect(Money.format(135000, currency: 'USD'), 'USD 1,350.00');
    });
  });

  group('signed', () {
    test('marks direction explicitly rather than reading the sign', () {
      expect(Money.signed(8900, isInflow: false), '−K89.00');
      expect(Money.signed(300000, isInflow: true), '+K3,000.00');
    });

    test('signs off the direction, not the stored magnitude', () {
      // The ledger stores every amount as a positive magnitude with a
      // separate direction column, so an outflow is still positive here.
      expect(Money.signed(8900, isInflow: false), startsWith(Money.minus));
    });
  });

  group('compact', () {
    test('drops ngwee and abbreviates for axes and headlines', () {
      expect(Money.compact(1248000), 'K12.5k');
      expect(Money.compact(99900), 'K999');
      expect(Money.compact(250000000), 'K2.5m');
      expect(Money.compact(0), 'K0');
    });

    test('keeps the true minus', () {
      expect(Money.compact(-1248000), '−K12.5k');
    });
  });

  group('withIsoCode', () {
    test('is the only form that shows ZMW', () {
      expect(Money.withIsoCode(135000), 'ZMW 1,350.00');
    });
  });

  test('round-trips parse and format without drift', () {
    // Formatting adds thousands separators, so compare against the
    // grouped form rather than the raw input.
    const cases = {
      '10.00': 'K10.00',
      '1,350.00': 'K1,350.00',
      '0.75': 'K0.75',
      '999999.99': 'K999,999.99',
    };
    cases.forEach((input, expected) {
      expect(Money.format(Money.tryParseToMinor(input)!), expected);
    });
  });
}
