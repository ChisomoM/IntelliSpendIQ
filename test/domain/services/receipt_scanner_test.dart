import 'package:flutter_test/flutter_test.dart';
import 'package:intellispendiq/domain/services/receipt_scanner.dart';

void main() {
  group('ReceiptScanner.parseText', () {
    test('extracts merchant, total and date from a typical receipt', () {
      final result = ReceiptScanner.parseText('''
Shoprite Mukuba
Cairo Road, Ndola
Tel: 0211 123 456
Date: 12/03/2026
Bread             15.00
Milk              22.50
SUBTOTAL          37.50
TOTAL             45.00
CASH              50.00
Thank you for shopping
''');

      expect(result.merchant, 'Shoprite Mukuba');
      expect(result.amountMinor, 4500);
      expect(result.transactedAt, DateTime(2026, 3, 12));
    });

    test('picks the grand total over a smaller subtotal line', () {
      final result = ReceiptScanner.parseText('''
Some Store
SUBTOTAL 10.00
GRAND TOTAL 12.50
''');

      expect(result.amountMinor, 1250);
    });

    test('parses an ISO-style date', () {
      final result = ReceiptScanner.parseText('Store\n2026-01-05\nTOTAL 5.00');

      expect(result.transactedAt, DateTime(2026, 1, 5));
    });

    test('recognizes "Amount Due" as a total label', () {
      final result = ReceiptScanner.parseText('Store\nAmount Due: 99.99');

      expect(result.amountMinor, 9999);
    });

    test('returns nulls for text with nothing recognizable', () {
      final result = ReceiptScanner.parseText('12345\n67890\n---');

      expect(result.merchant, isNull);
      expect(result.amountMinor, isNull);
      expect(result.transactedAt, isNull);
    });

    test('does not crash on an invalid calendar date', () {
      final result = ReceiptScanner.parseText('Store\n31/02/2026\nTOTAL 5.00');

      expect(result.transactedAt, isNull);
    });
  });
}
