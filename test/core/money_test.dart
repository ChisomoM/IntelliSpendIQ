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
      expect(Money.tryParseToMinor('K1,350.00'), 135000);
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
    test('formats minor units as Kwith two decimals', () {
      expect(Money.format(1000), 'K10.00');
      expect(Money.format(135000), 'K1,350.00');
      expect(Money.format(75), 'K0.75');
      expect(Money.format(0), 'K0.00');
    });

    test('keeps the sign outside the currency code', () {
      expect(Money.format(-1000), '-K10.00');
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
