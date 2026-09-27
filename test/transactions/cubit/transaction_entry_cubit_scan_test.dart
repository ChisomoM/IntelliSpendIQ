import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:intellispendiq/app/app_services.dart';
import 'package:intellispendiq/domain/ai/claude_receipt_scanner.dart';
import 'package:intellispendiq/domain/services/receipt_scanner.dart';
import 'package:intellispendiq/transactions/cubit/cubit.dart';

import '../../support/test_harness.dart';

/// Stands in for [ClaudeReceiptScanner] so tests never make a real
/// Anthropic API call — mirrors the fakes in test_harness.dart for
/// other externally-backed services.
class _FakeReceiptScanner extends ClaudeReceiptScanner {
  _FakeReceiptScanner(this.result, {required super.secureStore});

  final ReceiptScanResult result;

  @override
  Future<ReceiptScanResult> scanImage(String imagePath) async => result;

  @override
  Future<void> dispose() async {}
}

class _ThrowingReceiptScanner extends ClaudeReceiptScanner {
  _ThrowingReceiptScanner({required super.secureStore});

  @override
  Future<ReceiptScanResult> scanImage(String imagePath) =>
      throw StateError('Scan failed');

  @override
  Future<void> dispose() async {}
}

void main() {
  late AppServices services;

  setUp(() async => services = await createTestServices());
  tearDown(() async => services.dispose());

  TransactionEntryCubit buildCubit(ClaudeReceiptScanner scanner) {
    return TransactionEntryCubit(
      transactions: services.transactions,
      accounts: services.accounts,
      categories: services.categories,
      payees: services.payees,
      labels: services.labels,
      rawCaptures: services.rawCaptures,
      transfers: services.transfers,
      budgetPeriods: services.budgetPeriods,
      secureStore: services.secureStore,
      categorizer: services.merchantCategorizer,
      receiptScanner: scanner,
      documentsDirectory: () async => Directory.systemTemp.createTemp(),
    );
  }

  group('scanReceipt', () {
    test('fills blank amount, merchant and category from the scan', () async {
      final cubit = buildCubit(
        _FakeReceiptScanner(
          const ReceiptScanResult(
            rawText: 'Shoprite Mukuba\nTOTAL 45.00',
            merchant: 'Shoprite Mukuba',
            amountMinor: 4500,
          ),
          secureStore: services.secureStore,
        ),
      );
      final photo = await _tempImageFile();

      await cubit.scanReceipt(photo.path);

      expect(cubit.state.amount, '45.00');
      expect(cubit.state.merchant, 'Shoprite Mukuba');
      expect(cubit.state.receiptPath, isNotNull);
      final category = (await services.categories.getAll()).firstWhere(
        (c) => c.id == cubit.state.categoryId,
      );
      expect(category.name, 'Shopping');
      await cubit.close();
    });

    test('never overwrites a field the user already typed', () async {
      final cubit = buildCubit(
        _FakeReceiptScanner(
          const ReceiptScanResult(
            rawText: 'Some Store\nTOTAL 99.00',
            merchant: 'Some Store',
            amountMinor: 9900,
          ),
          secureStore: services.secureStore,
        ),
      );
      cubit.amountChanged('12.34');
      cubit.merchantChanged('My own note');
      final photo = await _tempImageFile();

      await cubit.scanReceipt(photo.path);

      expect(cubit.state.amount, '12.34');
      expect(cubit.state.merchant, 'My own note');
      await cubit.close();
    });

    test('still attaches the photo when the scan finds nothing', () async {
      final cubit = buildCubit(
        _FakeReceiptScanner(
          const ReceiptScanResult(rawText: 'garbled text'),
          secureStore: services.secureStore,
        ),
      );
      final photo = await _tempImageFile();

      await cubit.scanReceipt(photo.path);

      expect(cubit.state.receiptPath, isNotNull);
      expect(cubit.state.amount, isEmpty);
      expect(cubit.state.merchant, isEmpty);
      await cubit.close();
    });

    test('still attaches the photo when the scan throws', () async {
      final cubit = buildCubit(
        _ThrowingReceiptScanner(secureStore: services.secureStore),
      );
      final photo = await _tempImageFile();

      await cubit.scanReceipt(photo.path);

      expect(cubit.state.receiptPath, isNotNull);
      await cubit.close();
    });
  });
}

Future<File> _tempImageFile() async {
  final dir = await Directory.systemTemp.createTemp();
  final file = File('${dir.path}/receipt.jpg');
  return file.writeAsBytes([0]);
}
