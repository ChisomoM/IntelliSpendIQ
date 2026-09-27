import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:intellispendiq/app/app_services.dart';
import 'package:intellispendiq/domain/services/receipt_scanner.dart';
import 'package:intellispendiq/receipts/cubit/receipt_items_cubit.dart';

import '../../support/test_harness.dart';

void main() {
  late AppServices services;
  late File photo;

  setUp(() async {
    services = await createTestServices();
    final dir = await Directory.systemTemp.createTemp();
    photo = await File('${dir.path}/receipt.jpg').writeAsBytes([0]);
  });
  tearDown(() async => services.dispose());

  ReceiptItemsCubit buildCubit(ReceiptScanResult scan) {
    return ReceiptItemsCubit(
      transactions: services.transactions,
      accounts: services.accounts,
      budgetPeriods: services.budgetPeriods,
      scan: scan,
      sourcePath: photo.path,
      documentsDirectory: () async => Directory.systemTemp.createTemp(),
    );
  }

  const scan = ReceiptScanResult(
    rawText: 'Shoprite Mukuba\nBread 15.00\nMilk 22.50\nTOTAL 37.50',
    merchant: 'Shoprite Mukuba',
    amountMinor: 3750,
    lineItems: [
      ReceiptLineItem(name: 'Bread', amountMinor: 1500),
      ReceiptLineItem(name: 'Milk', amountMinor: 2250),
    ],
  );

  test('seeds one row per scanned line item, all checked', () {
    final cubit = buildCubit(scan);

    expect(cubit.state.items, hasLength(2));
    expect(cubit.state.items.every((i) => i.included), isTrue);
    expect(cubit.state.items[0].name, 'Bread');
    expect(cubit.state.items[0].amount, '15.00');
    expect(cubit.state.merchant, 'Shoprite Mukuba');
    expect(cubit.state.canSave, isTrue);
  });

  test('unchecking an item excludes it from canSave\'s count', () {
    final cubit = buildCubit(scan);

    cubit.itemToggled(0);

    expect(cubit.state.includedCount, 1);
    expect(cubit.state.canSave, isTrue);
  });

  test('canSave is false once nothing is checked', () {
    final cubit = buildCubit(scan);

    cubit.itemToggled(0);
    cubit.itemToggled(1);

    expect(cubit.state.canSave, isFalse);
  });

  test('canSave is false when a checked item has an invalid amount', () {
    final cubit = buildCubit(scan);

    cubit.itemAmountChanged(0, 'not a number');

    expect(cubit.state.canSave, isFalse);
  });

  test('addBlankItem appends an unchecked empty row', () {
    final cubit = buildCubit(scan);

    cubit.addBlankItem();

    expect(cubit.state.items, hasLength(3));
    expect(cubit.state.items.last.included, isFalse);
    expect(cubit.state.items.last.name, isEmpty);
  });

  test('removeItem drops the row without disturbing the others', () {
    final cubit = buildCubit(scan);

    cubit.removeItem(0);

    expect(cubit.state.items, hasLength(1));
    expect(cubit.state.items.single.name, 'Milk');
  });

  test('submit saves one transaction per checked item, uncategorized', () async {
    final cubit = buildCubit(scan);

    await cubit.submit();

    expect(cubit.state.status, ReceiptItemsStatus.saved);
    final all = await services.transactions.getAllForExport();
    expect(all, hasLength(2));
    expect(all.map((t) => t.description), containsAll(['Bread', 'Milk']));
    expect(all.every((t) => t.merchant == 'Shoprite Mukuba'), isTrue);
    expect(all.every((t) => t.categoryId == null), isTrue);
    expect(all.every((t) => t.receiptPath != null), isTrue);
    // Both items point at the same copied photo, not the picker's
    // original temp path.
    expect(all[0].receiptPath, all[1].receiptPath);
    expect(all[0].receiptPath, isNot(photo.path));
  });

  test('an unchecked item is not saved', () async {
    final cubit = buildCubit(scan);
    cubit.itemToggled(0);

    await cubit.submit();

    final all = await services.transactions.getAllForExport();
    expect(all, hasLength(1));
    expect(all.single.description, 'Milk');
  });

  test('submit fails fast when nothing is checked', () async {
    final cubit = buildCubit(scan);
    cubit.itemToggled(0);
    cubit.itemToggled(1);

    await cubit.submit();

    expect(cubit.state.status, ReceiptItemsStatus.failure);
    expect(await services.transactions.getAllForExport(), isEmpty);
  });
}
