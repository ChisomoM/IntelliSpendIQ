import 'dart:convert';
import 'dart:io';

import 'package:intellispendiq/data/repositories/account_repository.dart';
import 'package:intellispendiq/data/repositories/budget_repository.dart';
import 'package:intellispendiq/data/repositories/category_repository.dart';
import 'package:intellispendiq/data/repositories/income_repository.dart';
import 'package:intellispendiq/data/repositories/transaction_repository.dart';
import 'package:intellispendiq/domain/models/account.dart';
import 'package:intellispendiq/domain/models/budget.dart';
import 'package:intellispendiq/domain/models/category.dart';
import 'package:intellispendiq/domain/models/enums.dart';
import 'package:intellispendiq/domain/models/monthly_income.dart';
import 'package:intellispendiq/domain/models/transaction.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// The current backup file's schema version. Bump this only if a
/// future field is required for correct restore — `importBackupJson`
/// should keep reading older versions rather than refusing them.
const _backupSchemaVersion = 1;

/// How many rows `importBackupJson` actually wrote, versus how many
/// it left alone because they (or something they collide with) were
/// already present.
class RestoreSummary {
  const RestoreSummary({
    required this.accountsImported,
    required this.categoriesImported,
    required this.budgetsImported,
    required this.incomesImported,
    required this.transactionsImported,
    required this.skipped,
  });

  final int accountsImported;
  final int categoriesImported;
  final int budgetsImported;
  final int incomesImported;
  final int transactionsImported;

  /// Rows that already existed (by id) or collided with an existing
  /// row's unique key — not an error, just nothing new to add.
  final int skipped;

  int get totalImported =>
      accountsImported +
      categoriesImported +
      budgetsImported +
      incomesImported +
      transactionsImported;
}

/// Exports the user's data for their own records and for moving it to
/// a new device — CSV for spreadsheets, JSON for a full restorable
/// backup. Restoring writes through the normal repositories with each
/// record's original id preserved, so it works on a brand-new install
/// regardless of that install's own encryption passphrase; it never
/// touches the encrypted database file directly.
class BackupService {
  BackupService({
    required TransactionRepository transactions,
    required AccountRepository accounts,
    required CategoryRepository categories,
    required BudgetRepository budgets,
    required IncomeRepository incomes,
    Future<Directory> Function()? tempDirectory,
  }) : _transactions = transactions,
       _accounts = accounts,
       _categories = categories,
       _budgets = budgets,
       _incomes = incomes,
       _tempDirectory = tempDirectory ?? getTemporaryDirectory;

  final TransactionRepository _transactions;
  final AccountRepository _accounts;
  final CategoryRepository _categories;
  final BudgetRepository _budgets;
  final IncomeRepository _incomes;

  /// Defaults to `path_provider`'s temp directory; overridable so
  /// tests never need a platform channel just to write a file.
  final Future<Directory> Function() _tempDirectory;

  static const _csvColumns = [
    'Date',
    'Merchant',
    'Description',
    'Category',
    'Account',
    'Direction',
    'Amount',
    'Currency',
    'Status',
    'Source',
  ];

  Future<File> exportTransactionsCsv() async {
    final transactions = await _transactions.getAllForExport();
    final categoryNames = {
      for (final category in await _categories.getAll())
        category.id: category.name,
    };
    final accountNames = {
      for (final account in await _accounts.getAll()) account.id: account.name,
    };

    final buffer = StringBuffer()
      ..writeln(_csvColumns.map(_csvField).join(','));
    for (final tx in transactions) {
      buffer.writeln(
        [
          tx.transactedAt.toLocal().toIso8601String(),
          tx.merchant ?? '',
          tx.description ?? '',
          categoryNames[tx.categoryId] ?? '',
          accountNames[tx.accountId] ?? '',
          tx.direction.name,
          (tx.amountMinor / 100).toStringAsFixed(2),
          tx.currency,
          tx.status.dbName,
          tx.source.name,
        ].map(_csvField).join(','),
      );
    }

    return _writeTempFile('transactions', 'csv', buffer.toString());
  }

  Future<File> exportBackupJson() async {
    final document = <String, Object?>{
      'version': _backupSchemaVersion,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'accounts': (await _accounts.getAll()).map(_accountToJson).toList(),
      'categories': (await _categories.getAll()).map(_categoryToJson).toList(),
      'budgets': (await _budgets.getAllForExport()).map(_budgetToJson).toList(),
      'monthlyIncomes': (await _incomes.getAllForExport())
          .map(_incomeToJson)
          .toList(),
      'transactions': (await _transactions.getAllForExport())
          .map(_transactionToJson)
          .toList(),
    };
    return _writeTempFile(
      'backup',
      'json',
      const JsonEncoder.withIndent('  ').convert(document),
    );
  }

  /// Restores every record in [file], skipping anything that already
  /// exists. Safe to run more than once with the same file — a repeat
  /// import just reports everything as skipped rather than
  /// duplicating data.
  Future<RestoreSummary> importBackupJson(File file) async {
    final document =
        jsonDecode(await file.readAsString()) as Map<String, Object?>;

    var accountsImported = 0;
    var categoriesImported = 0;
    var budgetsImported = 0;
    var incomesImported = 0;
    var transactionsImported = 0;
    var skipped = 0;

    // Accounts and categories first — transactions and budgets
    // reference them by id.
    for (final entry in _listOf(document, 'accounts')) {
      if (await _accounts.restoreAccount(_accountFromJson(entry))) {
        accountsImported++;
      } else {
        skipped++;
      }
    }
    for (final entry in _listOf(document, 'categories')) {
      if (await _categories.restoreCategory(_categoryFromJson(entry))) {
        categoriesImported++;
      } else {
        skipped++;
      }
    }
    for (final entry in _listOf(document, 'budgets')) {
      if (await _budgets.restoreBudget(_budgetFromJson(entry))) {
        budgetsImported++;
      } else {
        skipped++;
      }
    }
    for (final entry in _listOf(document, 'monthlyIncomes')) {
      if (await _incomes.restoreIncome(_incomeFromJson(entry))) {
        incomesImported++;
      } else {
        skipped++;
      }
    }
    for (final entry in _listOf(document, 'transactions')) {
      if (await _transactions.restoreTransaction(_transactionFromJson(entry))) {
        transactionsImported++;
      } else {
        skipped++;
      }
    }

    return RestoreSummary(
      accountsImported: accountsImported,
      categoriesImported: categoriesImported,
      budgetsImported: budgetsImported,
      incomesImported: incomesImported,
      transactionsImported: transactionsImported,
      skipped: skipped,
    );
  }

  List<Map<String, Object?>> _listOf(
    Map<String, Object?> document,
    String key,
  ) {
    final value = document[key];
    if (value is! List) return const [];
    return value.cast<Map<String, Object?>>();
  }

  Future<File> _writeTempFile(
    String label,
    String extension,
    String contents,
  ) async {
    final dir = await _tempDirectory();
    final stamp = DateTime.now().toUtc().toIso8601String().replaceAll(
      RegExp('[^0-9]'),
      '',
    );
    final file = File(
      p.join(dir.path, 'intellispendiq_${label}_$stamp.$extension'),
    );
    await file.writeAsString(contents);
    return file;
  }

  String _csvField(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  Map<String, Object?> _accountToJson(Account account) => {
    'id': account.id,
    'name': account.name,
    'type': account.type.dbName,
    'currency': account.currency,
    'isDefault': account.isDefault,
    'providerKey': account.providerKey,
    'balanceMinor': account.balanceMinor,
  };

  Account _accountFromJson(Map<String, Object?> json) => Account(
    id: json['id']! as String,
    name: json['name']! as String,
    type: AccountType.fromDbName(json['type']! as String),
    currency: json['currency'] as String? ?? 'ZMW',
    isDefault: json['isDefault'] as bool? ?? false,
    providerKey: json['providerKey'] as String?,
    balanceMinor: json['balanceMinor'] as int?,
  );

  Map<String, Object?> _categoryToJson(Category category) => {
    'id': category.id,
    'name': category.name,
    'icon': category.icon,
    'color': category.color,
    'parentId': category.parentId,
    'isSystem': category.isSystem,
    'sortOrder': category.sortOrder,
  };

  Category _categoryFromJson(Map<String, Object?> json) => Category(
    id: json['id']! as String,
    name: json['name']! as String,
    icon: json['icon'] as String?,
    color: json['color'] as String?,
    parentId: json['parentId'] as String?,
    isSystem: json['isSystem'] as bool? ?? false,
    sortOrder: json['sortOrder'] as int? ?? 0,
  );

  Map<String, Object?> _budgetToJson(Budget budget) => {
    'id': budget.id,
    'categoryId': budget.categoryId,
    'period': budget.period,
    'amountMinor': budget.amountMinor,
    'carryOver': budget.carryOver,
  };

  Budget _budgetFromJson(Map<String, Object?> json) => Budget(
    id: json['id']! as String,
    categoryId: json['categoryId']! as String,
    period: json['period']! as String,
    amountMinor: json['amountMinor']! as int,
    carryOver: json['carryOver'] as bool? ?? true,
  );

  Map<String, Object?> _incomeToJson(MonthlyIncome income) => {
    'id': income.id,
    'period': income.period,
    'amountMinor': income.amountMinor,
    'label': income.label,
  };

  MonthlyIncome _incomeFromJson(Map<String, Object?> json) => MonthlyIncome(
    id: json['id']! as String,
    period: json['period']! as String,
    amountMinor: json['amountMinor']! as int,
    label: json['label'] as String?,
  );

  Map<String, Object?> _transactionToJson(Transaction tx) => {
    'id': tx.id,
    'accountId': tx.accountId,
    'categoryId': tx.categoryId,
    'amountMinor': tx.amountMinor,
    'currency': tx.currency,
    'direction': tx.direction.name,
    'merchant': tx.merchant,
    'description': tx.description,
    'transactedAt': tx.transactedAt.toIso8601String(),
    'source': tx.source.name,
    'confidence': tx.confidence,
    'status': tx.status.dbName,
    'rawCaptureId': tx.rawCaptureId,
    'idempotencyKey': tx.idempotencyKey,
    'duplicateOfId': tx.duplicateOfId,
    'paymentMethod': tx.paymentMethod,
    'externalRef': tx.externalRef,
    'metadata': tx.metadata,
  };

  Transaction _transactionFromJson(Map<String, Object?> json) => Transaction(
    id: json['id']! as String,
    accountId: json['accountId']! as String,
    categoryId: json['categoryId'] as String?,
    amountMinor: json['amountMinor']! as int,
    currency: json['currency'] as String? ?? 'ZMW',
    direction: TxDirection.fromName(json['direction']! as String),
    merchant: json['merchant'] as String?,
    description: json['description'] as String?,
    transactedAt: DateTime.parse(json['transactedAt']! as String),
    source: TxSource.fromName(json['source']! as String),
    confidence: (json['confidence'] as num?)?.toDouble(),
    status: TxStatus.fromDbName(json['status']! as String),
    rawCaptureId: json['rawCaptureId'] as String?,
    idempotencyKey: json['idempotencyKey']! as String,
    duplicateOfId: json['duplicateOfId'] as String?,
    paymentMethod: json['paymentMethod'] as String?,
    externalRef: json['externalRef'] as String?,
    metadata: (json['metadata'] as Map<String, Object?>?) ?? const {},
  );
}
