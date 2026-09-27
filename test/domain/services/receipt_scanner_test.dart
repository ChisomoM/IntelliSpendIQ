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
      expect(result.lineItems, [
        const ReceiptLineItem(name: 'Bread', amountMinor: 1500),
        const ReceiptLineItem(name: 'Milk', amountMinor: 2250),
      ]);
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

  group('ReceiptScanner.parseText line items', () {
    test('ignores a bare integer with no decimal (e.g. a phone number)', () {
      final result = ReceiptScanner.parseText('Store\nTel 0211 123 456');

      expect(result.lineItems, isEmpty);
    });

    test('ignores total/subtotal/cash/tax lines even with a decimal', () {
      final result = ReceiptScanner.parseText('''
Store
SUBTOTAL 37.50
TOTAL 45.00
CASH 50.00
VAT 5.00
''');

      expect(result.lineItems, isEmpty);
    });

    test('skips a line whose name is too short or has no letters', () {
      final result = ReceiptScanner.parseText('''
Store
1 45.00
X-- 12.00
''');

      expect(result.lineItems, isEmpty);
    });

    test('returns an empty list rather than null when nothing matches', () {
      final result = ReceiptScanner.parseText('Store\nTOTAL 5.00');

      expect(result.lineItems, isEmpty);
    });
  });
}
