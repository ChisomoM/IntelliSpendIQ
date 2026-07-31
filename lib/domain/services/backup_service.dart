import 'dart:convert';
import 'dart:io';

import 'package:intellispendiq/data/repositories/account_repository.dart';
import 'package:intellispendiq/data/repositories/category_repository.dart';
import 'package:intellispendiq/data/repositories/label_repository.dart';
import 'package:intellispendiq/data/repositories/overall_budget_repository.dart';
import 'package:intellispendiq/data/repositories/payee_repository.dart';
import 'package:intellispendiq/data/repositories/transaction_repository.dart';
import 'package:intellispendiq/data/repositories/transfer_repository.dart';
import 'package:intellispendiq/domain/models/account.dart';
import 'package:intellispendiq/domain/models/category.dart';
import 'package:intellispendiq/domain/models/enums.dart';
import 'package:intellispendiq/domain/models/label.dart';
import 'package:intellispendiq/domain/models/overall_budget.dart';
import 'package:intellispendiq/domain/models/payee.dart';
import 'package:intellispendiq/domain/models/transaction.dart';
import 'package:intellispendiq/domain/models/transfer.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// The current backup file's schema version. Bump this only if a
/// future field is required for correct restore — `importBackupJson`
/// should keep reading older versions rather than refusing them.
const _backupSchemaVersion = 3;

/// How many rows `importBackupJson` actually wrote, versus how many
/// it left alone because they (or something they collide with) were
/// already present.
class RestoreSummary {
  const RestoreSummary({
    required this.accountsImported,
    required this.categoriesImported,
    required this.overallBudgetsImported,
    required this.payeesImported,
    required this.labelsImported,
    required this.transactionsImported,
    required this.transfersImported,
    required this.skipped,
  });

  final int accountsImported;
  final int categoriesImported;
  final int overallBudgetsImported;
  final int payeesImported;
  final int labelsImported;
  final int transactionsImported;
  final int transfersImported;

  /// Rows that already existed (by id) or collided with an existing
  /// row's unique key — not an error, just nothing new to add.
  final int skipped;

  int get totalImported =>
      accountsImported +
      categoriesImported +
      overallBudgetsImported +
      payeesImported +
      labelsImported +
      transactionsImported +
      transfersImported;
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
    required OverallBudgetRepository overallBudgets,
    required PayeeRepository payees,
    required LabelRepository labels,
    required TransferRepository transfers,
    Future<Directory> Function()? tempDirectory,
  }) : _transactions = transactions,
       _accounts = accounts,
       _categories = categories,
       _overallBudgets = overallBudgets,
       _payees = payees,
       _labels = labels,
       _transfers = transfers,
       _tempDirectory = tempDirectory ?? getTemporaryDirectory;

  final TransactionRepository _transactions;
  final AccountRepository _accounts;
  final CategoryRepository _categories;
  final OverallBudgetRepository _overallBudgets;
  final PayeeRepository _payees;
  final LabelRepository _labels;
  final TransferRepository _transfers;

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
      'overallBudgets': (await _overallBudgets.getAllForExport())
          .map(_overallBudgetToJson)
          .toList(),
      'payees': (await _payees.getAll()).map(_payeeToJson).toList(),
      'labels': (await _labels.getAll()).map(_labelToJson).toList(),
      'transactions': (await _transactions.getAllForExport())
          .map(_transactionToJson)
          .toList(),
      'transfers': (await _transfers.getAllForExport())
          .map(_transferToJson)
          .toList(),
      'transactionLabels': (await _transactions.getAllLabelLinksForExport())
          .map(
            (link) => {'transactionId': link.$1, 'labelId': link.$2},
          )
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
    var overallBudgetsImported = 0;
    var payeesImported = 0;
    var labelsImported = 0;
    var transactionsImported = 0;
    var transfersImported = 0;
    var skipped = 0;

    // Accounts, categories, payees and labels first — transactions
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
    for (final entry in _listOf(document, 'overallBudgets')) {
      if (await _overallBudgets.restoreOverallBudget(
        _overallBudgetFromJson(entry),
      )) {
        overallBudgetsImported++;
      } else {
        skipped++;
      }
    }
    for (final entry in _listOf(document, 'payees')) {
      if (await _payees.restorePayee(_payeeFromJson(entry))) {
        payeesImported++;
      } else {
        skipped++;
      }
    }
    for (final entry in _listOf(document, 'labels')) {
      if (await _labels.restoreLabel(_labelFromJson(entry))) {
        labelsImported++;
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
    for (final entry in _listOf(document, 'transfers')) {
      if (await _transfers.restoreTransfer(_transferFromJson(entry))) {
        transfersImported++;
      } else {
        skipped++;
      }
    }
    for (final entry in _listOf(document, 'transactionLabels')) {
      final transactionId = entry['transactionId'] as String?;
      final labelId = entry['labelId'] as String?;
      if (transactionId == null || labelId == null) continue;
      if (!await _transactions.restoreLabelLink(transactionId, labelId)) {
        skipped++;
      }
    }

    return RestoreSummary(
      accountsImported: accountsImported,
      categoriesImported: categoriesImported,
      overallBudgetsImported: overallBudgetsImported,
      payeesImported: payeesImported,
      labelsImported: labelsImported,
      transactionsImported: transactionsImported,
      transfersImported: transfersImported,
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
    'balanceAsOf': account.balanceAsOf?.toIso8601String(),
  };

  Account _accountFromJson(Map<String, Object?> json) => Account(
    id: json['id']! as String,
    name: json['name']! as String,
    type: AccountType.fromDbName(json['type']! as String),
    currency: json['currency'] as String? ?? 'ZMW',
    isDefault: json['isDefault'] as bool? ?? false,
    providerKey: json['providerKey'] as String?,
    balanceMinor: json['balanceMinor'] as int?,
    balanceAsOf: json['balanceAsOf'] == null
        ? null
        : DateTime.parse(json['balanceAsOf']! as String),
  );

  Map<String, Object?> _categoryToJson(Category category) => {
    'id': category.id,
    'name': category.name,
    'icon': category.icon,
    'color': category.color,
    'parentId': category.parentId,
    'isSystem': category.isSystem,
    'sortOrder': category.sortOrder,
    'type': category.type.dbName,
    'budgetedAmountMinor': category.budgetedAmountMinor,
  };

  Category _categoryFromJson(Map<String, Object?> json) => Category(
    id: json['id']! as String,
    name: json['name']! as String,
    icon: json['icon'] as String?,
    color: json['color'] as String?,
    parentId: json['parentId'] as String?,
    isSystem: json['isSystem'] as bool? ?? false,
    sortOrder: json['sortOrder'] as int? ?? 0,
    type: json['type'] == null
        ? CategoryType.expense
        : CategoryType.fromDbName(json['type']! as String),
    budgetedAmountMinor: json['budgetedAmountMinor'] as int?,
  );

  Map<String, Object?> _overallBudgetToJson(OverallBudget budget) => {
    'id': budget.id,
    'period': budget.period,
    'amountMinor': budget.amountMinor,
    'carryOver': budget.carryOver,
  };

  OverallBudget _overallBudgetFromJson(Map<String, Object?> json) =>
      OverallBudget(
        id: json['id']! as String,
        period: json['period']! as String,
        amountMinor: json['amountMinor']! as int,
        carryOver: json['carryOver'] as bool? ?? true,
      );

  Map<String, Object?> _payeeToJson(Payee payee) => {
    'id': payee.id,
    'name': payee.name,
  };

  Payee _payeeFromJson(Map<String, Object?> json) => Payee(
    id: json['id']! as String,
    name: json['name']! as String,
  );

  Map<String, Object?> _labelToJson(Label label) => {
    'id': label.id,
    'name': label.name,
    'color': label.color,
  };

  Label _labelFromJson(Map<String, Object?> json) => Label(
    id: json['id']! as String,
    name: json['name']! as String,
    color: json['color'] as String?,
  );

  Map<String, Object?> _transferToJson(Transfer transfer) => {
    'id': transfer.id,
    'fromAccountId': transfer.fromAccountId,
    'toAccountId': transfer.toAccountId,
    'amountMinor': transfer.amountMinor,
    'transactedAt': transfer.transactedAt.toIso8601String(),
    'note': transfer.note,
  };

  Transfer _transferFromJson(Map<String, Object?> json) => Transfer(
    id: json['id']! as String,
    fromAccountId: json['fromAccountId']! as String,
    toAccountId: json['toAccountId']! as String,
    amountMinor: json['amountMinor']! as int,
    transactedAt: DateTime.parse(json['transactedAt']! as String),
    note: json['note'] as String?,
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
    'receiptPath': tx.receiptPath,
    'payeeId': tx.payeeId,
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
    receiptPath: json['receiptPath'] as String?,
    payeeId: json['payeeId'] as String?,
  );
}
