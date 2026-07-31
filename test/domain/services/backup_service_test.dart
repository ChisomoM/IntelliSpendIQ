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
  overallBudgets: services.overallBudgets,
  payees: services.payees,
  labels: services.labels,
  transfers: services.transfers,
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
      await source.categories.update(pets.id, budgetedAmountMinor: 20000);
      await source.overallBudgets.upsert(
        period: '2026-07',
        amountMinor: 800000,
      );
      final salary = await source.categories.create(
        'Salary',
        type: CategoryType.income,
        budgetedAmountMinor: 500000,
      );
      final cash = await source.accounts.create(
        name: 'Cash',
        type: AccountType.cash,
      );
      // A second user-created account, not tied to any SMS provider —
      // its id survives a restore intact, unlike the default seeded
      // Airtel Money account (which the target already has its own
      // copy of, so the source's copy is skipped on import).
      final bank = await source.accounts.create(
        name: 'Bank',
        type: AccountType.bank,
      );
      final debitLeg = await source.transactions.insertDraft(
        TransactionDraft(
          amountMinor: 15000,
          direction: TxDirection.debit,
          source: TxSource.manual,
          transactedAt: DateTime(2026, 7, 15, 9),
          merchant: 'To Cash',
        ),
        accountId: bank.id,
        idempotencyKey: 'test:${Ids.newId()}',
        status: TxStatus.confirmed,
      );
      final creditLeg = await source.transactions.insertDraft(
        TransactionDraft(
          amountMinor: 15000,
          direction: TxDirection.credit,
          source: TxSource.manual,
          transactedAt: DateTime(2026, 7, 15, 9, 5),
          merchant: 'From Bank',
        ),
        accountId: cash.id,
        idempotencyKey: 'test:${Ids.newId()}',
        status: TxStatus.confirmed,
      );
      await source.transfers.linkTransfer(
        fromTransaction: debitLeg,
        toTransaction: creditLeg,
      );

      final file = await _testBackupService(source).exportBackupJson();
      addTearDown(file.delete);
      final document =
          jsonDecode(await file.readAsString()) as Map<String, Object?>;
      expect(document['version'], 3);

      // A brand-new install: its own seeded categories and default
      // account already exist before the backup is ever touched.
      final target = await createTestServices();
      addTearDown(target.dispose);

      final summary = await _testBackupService(target).importBackupJson(file);

      expect(
        summary.transactionsImported,
        2,
        reason:
            'Shoprite and Vet only — the transfer legs were soft-deleted '
            'on the source once linked, so they were never exported',
      );
      expect(summary.transfersImported, 1);
      expect(summary.overallBudgetsImported, 1);
      expect(
        summary.accountsImported,
        2,
        reason: 'only Cash and Bank are new',
      );
      expect(
        summary.categoriesImported,
        2,
        reason:
            'the ten seeds already exist on the target; only Pets and '
            'the Salary income category are new',
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

      final targetPets = (await target.categories.getAll()).firstWhere(
        (c) => c.id == pets.id,
      );
      expect(targetPets.budgetedAmountMinor, 20000);

      final targetOverall = await target.overallBudgets.getForPeriod('2026-07');
      expect(targetOverall!.amountMinor, 800000);

      final targetSalary = (await target.categories.getAll()).firstWhere(
        (c) => c.id == salary.id,
      );
      expect(targetSalary.budgetedAmountMinor, 500000);

      final targetTransactions = await target.transactions.getAllForExport();
      expect(targetTransactions, hasLength(2));
      expect(
        targetTransactions.map((tx) => tx.merchant),
        containsAll(['Shoprite', 'Vet']),
      );

      final targetTransfers = await target.transfers.watchAll().first;
      expect(targetTransfers, hasLength(1));
      expect(targetTransfers.single.amountMinor, 15000);
      expect(targetTransfers.single.fromAccountId, bank.id);
      expect(targetTransfers.single.toAccountId, cash.id);
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
