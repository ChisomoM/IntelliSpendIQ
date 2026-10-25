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
  savingsGoals: services.savingsGoals,
  wishlist: services.wishlist,
  budgetPeriods: services.budgetPeriods,
  tempDirectory: () async => Directory.systemTemp,
);

void main() {
  late AppServices source;

  Future<void> addSpend({
    required String merchant,
    int amountMinor = 5000,
    String? categoryId,
    DateTime? on,
  }) async {
    final foodCategoryId =
        categoryId ?? (await source.categories.byName('Food'))!.id;
    final accountId = (await source.accounts.getDefault()).id;
    await source.transactions.insertDraft(
      TransactionDraft(
        amountMinor: amountMinor,
        direction: TxDirection.debit,
        source: TxSource.manual,
        transactedAt: on ?? DateTime(2026, 7, 10),
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

    test('splits a sub category into Category and Sub category', () async {
      final food = (await source.categories.byName('Food'))!;
      final snacks = await source.categories.create(
        'Snacks',
        parentId: food.id,
      );
      await addSpend(merchant: 'Kiosk', categoryId: snacks.id);
      await addSpend(merchant: 'Shoprite');

      final file = await _testBackupService(source).exportTransactionsCsv();
      addTearDown(file.delete);
      final lines = (await file.readAsString()).trim().split('\n');
      final header = lines.first.split(',');
      final categoryAt = header.indexOf('Category');
      final subAt = header.indexOf('Sub category');
      final byMerchant = {
        for (final line in lines.skip(1)) line.split(',')[1]: line.split(','),
      };

      expect(subAt, categoryAt + 1);
      expect(byMerchant['Kiosk']![categoryAt], 'Food');
      expect(byMerchant['Kiosk']![subAt], 'Snacks');
      expect(byMerchant['Shoprite']![categoryAt], 'Food');
      expect(byMerchant['Shoprite']![subAt], isEmpty);
    });

    test('only includes rows inside the range, end exclusive', () async {
      await addSpend(merchant: 'Before', on: DateTime(2026, 6, 30, 23));
      await addSpend(merchant: 'First day', on: DateTime(2026, 7));
      await addSpend(merchant: 'Last day', on: DateTime(2026, 7, 31, 23));
      await addSpend(merchant: 'After', on: DateTime(2026, 8));

      final file = await _testBackupService(source).exportTransactionsCsv(
        range: ExportRange(
          from: DateTime(2026, 7),
          toExclusive: DateTime(2026, 8),
        ),
      );
      addTearDown(file.delete);
      final contents = await file.readAsString();

      expect(contents, contains('First day'));
      expect(contents, contains('Last day'));
      expect(contents, isNot(contains('Before')));
      expect(contents, isNot(contains('After')));
      expect(file.path, contains('_20260701_20260731'));
    });

    test('records a transfer as one row with both accounts', () async {
      final cash = await source.accounts.create(
        name: 'Cash',
        type: AccountType.cash,
      );
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
        ),
        accountId: cash.id,
        idempotencyKey: 'test:${Ids.newId()}',
        status: TxStatus.confirmed,
      );
      await source.transfers.linkTransfer(
        fromTransaction: debitLeg,
        toTransaction: creditLeg,
        note: 'ATM',
      );

      final file = await _testBackupService(source).exportTransactionsCsv();
      addTearDown(file.delete);
      final lines = (await file.readAsString()).trim().split('\n');
      final transferRows = lines
          .skip(1)
          .where((line) => line.split(',')[7] == 'transfer')
          .toList();

      expect(transferRows, hasLength(1));
      expect(transferRows.single, contains('ATM'));
      expect(transferRows.single, contains('Bank,Cash,transfer,150.00'));
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

      final goal = await source.savingsGoals.create(
        name: 'New Laptop',
        targetMinor: 1500000,
      );
      await source.savingsGoals.contribute(
        goalId: goal.id,
        accountId: bank.id,
        amountMinor: 200000,
        transactedAt: DateTime(2026, 7, 16),
      );
      await source.savingsGoals.spend(
        goalId: goal.id,
        accountId: bank.id,
        amountMinor: 150000,
        transactedAt: DateTime(2026, 7, 17),
        merchant: 'Laptop Shop',
      );

      final file = await _testBackupService(source).exportBackupJson();
      addTearDown(file.delete);
      final document =
          jsonDecode(await file.readAsString()) as Map<String, Object?>;
      expect(document['version'], 6);

      // A brand-new install: its own seeded categories and default
      // account already exist before the backup is ever touched.
      final target = await createTestServices();
      addTearDown(target.dispose);

      final summary = await _testBackupService(target).importBackupJson(file);

      expect(
        summary.transactionsImported,
        3,
        reason:
            'Shoprite, Vet, and the goal-funded Laptop Shop purchase — the '
            'transfer legs were soft-deleted on the source once linked, so '
            'they were never exported',
      );
      expect(
        summary.transfersImported,
        2,
        reason:
            'the bank-to-cash transfer, plus the real transfer the '
            'contribution made into the goal\'s own hidden account',
      );
      expect(summary.overallBudgetsImported, 1);
      expect(summary.savingsGoalsImported, 1);
      expect(
        summary.savingsGoalEntriesImported,
        2,
        reason: 'the contribution and the goal-funded portion of the spend',
      );
      expect(
        summary.accountsImported,
        3,
        reason:
            'Cash and Bank, plus the goal\'s own hidden account — only '
            'the seeded default Airtel Money account already exists',
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
      expect(targetTransfers, hasLength(2));
      final bankToCash = targetTransfers.firstWhere(
        (t) => t.toAccountId == cash.id,
      );
      expect(bankToCash.amountMinor, 15000);
      expect(bankToCash.fromAccountId, bank.id);

      final targetGoals = await target.savingsGoals.watchAll().first;
      expect(targetGoals, hasLength(1));
      expect(targetGoals.single.id, goal.id);
      expect(targetGoals.single.targetMinor, 1500000);
      expect(
        targetGoals.single.accountId,
        isNotNull,
        reason: 'the goal\'s own hidden account must resolve after restore',
      );
      expect(
        (await target.accounts.getAllForExport())
            .map((a) => a.id),
        contains(targetGoals.single.accountId),
      );

      final targetSaved = await target.savingsGoals.watchSaved().first;
      expect(
        targetSaved[goal.id],
        50000,
        reason:
            'contributed 2000, 1500 of it was released by the spend, '
            '500 remains saved',
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
