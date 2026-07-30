import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:intellispendiq/app/app_services.dart';
import 'package:intellispendiq/core/ids.dart';
import 'package:intellispendiq/domain/models/enums.dart';
import 'package:intellispendiq/domain/models/transaction_draft.dart';
import 'package:intellispendiq/domain/services/backup_service.dart';

import '../../support/test_harness.dart';

/// `AppServices.backupService` resolves its temp directory through
/// `path_provider`, which needs a platform channel unavailable in
/// plain unit tests — build one against the same repositories but
/// pointed at the system temp dir instead.
BackupService _testBackupService(AppServices services) => BackupService(
  transactions: services.transactions,
  accounts: services.accounts,
  categories: services.categories,
  budgets: services.budgets,
  incomes: services.income,
  tempDirectory: () async => Directory.systemTemp,
);

void main() {
  late AppServices source;

  Future<void> addSpend({
    required String merchant,
    int amountMinor = 5000,
    String? categoryId,
  }) async {
    final foodCategoryId =
        categoryId ?? (await source.categories.byName('Food'))!.id;
    final accountId = (await source.accounts.getDefault()).id;
    await source.transactions.insertDraft(
      TransactionDraft(
        amountMinor: amountMinor,
        direction: TxDirection.debit,
        source: TxSource.manual,
        transactedAt: DateTime(2026, 7, 10),
        categoryId: foodCategoryId,
        merchant: merchant,
      ),
      accountId: accountId,
      idempotencyKey: 'test:${Ids.newId()}',
      status: TxStatus.confirmed,
    );
  }

  setUp(() async {
    source = await createTestServices();
  });
  tearDown(() async => source.dispose());

  group('exportTransactionsCsv', () {
    test('writes a header and one row per transaction', () async {
      await addSpend(merchant: 'Shoprite, Cairo Road');

      final file = await _testBackupService(source).exportTransactionsCsv();
      addTearDown(file.delete);
      final lines = (await file.readAsString()).trim().split('\n');

      expect(lines, hasLength(2));
      expect(lines.first, startsWith('Date,Merchant,Description,Category'));
      // The merchant contains a comma, so it must be quoted.
      expect(lines[1], contains('"Shoprite, Cairo Road"'));
      expect(lines[1], contains('Food'));
      expect(lines[1], contains('Airtel Money'));
      expect(lines[1], contains('50.00'));
    });
  });

  group('exportBackupJson / importBackupJson', () {
    test('round-trips every entity onto a fresh install', () async {
      await addSpend(merchant: 'Shoprite');
      final pets = await source.categories.create('Pets', icon: '🐕');
      await addSpend(merchant: 'Vet', categoryId: pets.id);
      await source.budgets.upsert(
        categoryId: pets.id,
        period: '2026-07',
        amountMinor: 20000,
      );
      await source.income.upsert(period: '2026-07', amountMinor: 500000);
      final cash = await source.accounts.create(
        name: 'Cash',
        type: AccountType.cash,
      );

      final file = await _testBackupService(source).exportBackupJson();
      addTearDown(file.delete);
      final document =
          jsonDecode(await file.readAsString()) as Map<String, Object?>;
      expect(document['version'], 1);

      // A brand-new install: its own seeded categories and default
      // account already exist before the backup is ever touched.
      final target = await createTestServices();
      addTearDown(target.dispose);

      final summary = await _testBackupService(target).importBackupJson(file);

      expect(summary.transactionsImported, 2);
      expect(summary.budgetsImported, 1);
      expect(summary.incomesImported, 1);
      expect(
        summary.accountsImported,
        1,
        reason: 'only the Cash account is new',
      );
      expect(
        summary.categoriesImported,
        1,
        reason: 'the ten seeds already exist on the target; only Pets is new',
      );

      final targetCategories = await target.categories.getAll();
      expect(
        targetCategories.where((c) => c.name == 'Food'),
        hasLength(1),
        reason: 'restoring must not duplicate a system category by name',
      );
      expect(targetCategories.map((c) => c.name), contains('Pets'));

      final targetAccounts = await target.accounts.getAll();
      expect(
        targetAccounts.where((a) => a.name == 'Airtel Money'),
        hasLength(1),
        reason: 'restoring must not duplicate the seeded default account',
      );
      expect(targetAccounts.map((a) => a.name), contains('Cash'));
      expect(targetAccounts.map((a) => a.id), contains(cash.id));

      final targetBudgets = await target.budgets.getForPeriod('2026-07');
      expect(targetBudgets.single.amountMinor, 20000);

      final targetIncome = await target.income.getForPeriod('2026-07');
      expect(targetIncome!.amountMinor, 500000);

      final targetTransactions = await target.transactions.getAllForExport();
      expect(targetTransactions, hasLength(2));
      expect(
        targetTransactions.map((tx) => tx.merchant),
        containsAll(['Shoprite', 'Vet']),
      );
    });

    test(
      'importing the same backup twice is a no-op the second time',
      () async {
        await addSpend(merchant: 'Shoprite');
        final file = await _testBackupService(source).exportBackupJson();
        addTearDown(file.delete);

        final target = await createTestServices();
        addTearDown(target.dispose);

        final targetBackup = _testBackupService(target);
        final first = await targetBackup.importBackupJson(file);
        expect(first.totalImported, greaterThan(0));

        final second = await targetBackup.importBackupJson(file);

        expect(second.totalImported, 0);
        final targetTransactions = await target.transactions.getAllForExport();
        expect(
          targetTransactions,
          hasLength(1),
          reason: 're-importing must not duplicate the transaction',
        );
      },
    );
  });
}
