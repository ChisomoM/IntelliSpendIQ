import 'dart:convert';
import 'dart:io';

import 'package:excel/excel.dart'
    show
        CellIndex,
        CellStyle,
        CellValue,
        DateTimeCellValue,
        DoubleCellValue,
        Excel,
        NumFormat,
        Sheet,
        TextCellValue;
import 'package:intellispendiq/data/repositories/account_repository.dart';
import 'package:intellispendiq/data/repositories/budget_period_repository.dart';
import 'package:intellispendiq/data/repositories/category_repository.dart';
import 'package:intellispendiq/data/repositories/label_repository.dart';
import 'package:intellispendiq/data/repositories/overall_budget_repository.dart';
import 'package:intellispendiq/data/repositories/payee_repository.dart';
import 'package:intellispendiq/data/repositories/savings_goal_repository.dart';
import 'package:intellispendiq/data/repositories/transaction_repository.dart';
import 'package:intellispendiq/data/repositories/transfer_repository.dart';
import 'package:intellispendiq/data/repositories/wishlist_repository.dart';
import 'package:intellispendiq/domain/models/account.dart';
import 'package:intellispendiq/domain/models/category.dart';
import 'package:intellispendiq/domain/models/enums.dart';
import 'package:intellispendiq/domain/models/label.dart';
import 'package:intellispendiq/domain/models/overall_budget.dart';
import 'package:intellispendiq/domain/models/payee.dart';
import 'package:intellispendiq/domain/models/savings_goal.dart';
import 'package:intellispendiq/domain/models/savings_goal_entry.dart';
import 'package:intellispendiq/domain/models/transaction.dart';
import 'package:intellispendiq/domain/models/transfer.dart';
import 'package:intellispendiq/domain/models/wishlist_item.dart';
import 'package:intellispendiq/domain/models/wishlist_item_photo.dart';
import 'package:intellispendiq/domain/services/budget_report.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// The current backup file's schema version. Bump this only if a
/// future field is required for correct restore — `importBackupJson`
/// should keep reading older versions rather than refusing them.
///
/// v4 added `savingsGoals`/`savingsGoalEntries`; v5 added
/// `wishlistItems`/`wishlistItemPhotos`; v6 added `Account.linkedGoalId`,
/// `SavingsGoal.accountId` and `SavingsGoalEntry.linkedTransferId` (a
/// goal's contributions now move real money into its own hidden
/// account) and switched `accounts` export to include those hidden
/// accounts. An older file simply has no such keys, and `_listOf`
/// already treats a missing key as an empty list, so older backups
/// keep importing everything else fine — a goal restored from one just
/// gets a fresh hidden account lazily on first use, same as an
/// already-installed app upgrading in place.
const _backupSchemaVersion = 6;

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
    required this.savingsGoalsImported,
    required this.savingsGoalEntriesImported,
    required this.wishlistItemsImported,
    required this.wishlistItemPhotosImported,
    required this.skipped,
  });

  final int accountsImported;
  final int categoriesImported;
  final int overallBudgetsImported;
  final int payeesImported;
  final int labelsImported;
  final int transactionsImported;
  final int transfersImported;
  final int savingsGoalsImported;
  final int savingsGoalEntriesImported;
  final int wishlistItemsImported;
  final int wishlistItemPhotosImported;

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
      transfersImported +
      savingsGoalsImported +
      savingsGoalEntriesImported +
      wishlistItemsImported +
      wishlistItemPhotosImported;
}

/// One line of the transactions export, before it is turned into CSV
/// text or typed spreadsheet cells.
class _SheetRow {
  const _SheetRow({
    required this.when,
    required this.merchant,
    required this.description,
    required this.category,
    required this.subCategory,
    required this.account,
    required this.toAccount,
    required this.direction,
    required this.amountMinor,
    required this.currency,
    required this.status,
    required this.source,
  });

  final DateTime when;
  final String merchant;
  final String description;
  final String category;
  final String subCategory;
  final String account;
  final String toAccount;
  final String direction;
  final int? amountMinor;
  final String currency;
  final String status;
  final String source;
}

/// The window an export covers: [from] inclusive, [toExclusive]
/// exclusive, either open-ended. [label] is what the picker shows.
class ExportRange {
  const ExportRange({this.from, this.toExclusive, this.label = 'All time'});

  static const allTime = ExportRange();

  final DateTime? from;
  final DateTime? toExclusive;
  final String label;

  /// Tags the exported file's name with the window, e.g.
  /// `_20261001_20261031`. Empty for all time.
  String get fileSuffix {
    if (from == null && toExclusive == null) return '';
    String day(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}'
        '${d.month.toString().padLeft(2, '0')}'
        '${d.day.toString().padLeft(2, '0')}';
    final start = from == null ? 'start' : day(from!);
    final end = toExclusive == null
        ? 'now'
        : day(toExclusive!.subtract(const Duration(days: 1)));
    return '_${start}_$end';
  }
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
    required SavingsGoalRepository savingsGoals,
    required WishlistRepository wishlist,
    required BudgetPeriodRepository budgetPeriods,
    Future<Directory> Function()? tempDirectory,
  }) : _transactions = transactions,
       _accounts = accounts,
       _categories = categories,
       _overallBudgets = overallBudgets,
       _payees = payees,
       _labels = labels,
       _transfers = transfers,
       _savingsGoals = savingsGoals,
       _wishlist = wishlist,
       _budgetReport = BudgetReportBuilder(
         budgetPeriods: budgetPeriods,
         transactions: transactions,
         categories: categories,
       ),
       _tempDirectory = tempDirectory ?? getTemporaryDirectory;

  final TransactionRepository _transactions;
  final AccountRepository _accounts;
  final CategoryRepository _categories;
  final OverallBudgetRepository _overallBudgets;
  final PayeeRepository _payees;
  final LabelRepository _labels;
  final TransferRepository _transfers;
  final SavingsGoalRepository _savingsGoals;
  final WishlistRepository _wishlist;
  final BudgetReportBuilder _budgetReport;

  /// Defaults to `path_provider`'s temp directory; overridable so
  /// tests never need a platform channel just to write a file.
  final Future<Directory> Function() _tempDirectory;

  static const _columns = [
    'Date',
    'Merchant',
    'Description',
    'Category',
    'Sub category',
    'Account',
    'To account',
    'Direction',
    'Amount',
    'Currency',
    'Status',
    'Source',
  ];

  static const _budgetColumns = [
    'Cycle',
    'Type',
    'Category',
    'Sub category',
    'Budgeted',
    'Spent / received',
    'Planned (unpaid)',
    'Remaining',
  ];

  /// Writes the transactions and transfers inside [range] (everything,
  /// by default) as one CSV, newest first.
  ///
  /// A sub category is split across two columns: `Category` holds its
  /// parent and `Sub category` its own name, so the sheet can be grouped
  /// by parent. A top-level category fills `Category` alone.
  ///
  /// A transfer is one row with `Direction` set to `transfer`, the
  /// source account in `Account` and the destination in `To account`.
  /// The two transactions a transfer links are still listed as their
  /// own rows, so filter `transfer` out when summing money in and out.
  Future<File> exportTransactionsCsv({
    ExportRange range = ExportRange.allTime,
  }) async {
    final rows = await _collectRows(range);
    final buffer = StringBuffer()..writeln(_columns.map(_csvField).join(','));
    for (final row in rows) {
      buffer.writeln(
        [
          row.when.toLocal().toIso8601String(),
          row.merchant,
          row.description,
          row.category,
          row.subCategory,
          row.account,
          row.toAccount,
          row.direction,
          if (row.amountMinor == null)
            ''
          else
            (row.amountMinor! / 100).toStringAsFixed(2),
          row.currency,
          row.status,
          row.source,
        ].map(_csvField).join(','),
      );
    }
    return _writeTempFile(
      'transactions${range.fileSuffix}',
      'csv',
      buffer.toString(),
    );
  }

  /// Writes an Excel workbook with two sheets for [range].
  ///
  /// **Transactions** holds the same rows as [exportTransactionsCsv],
  /// with real dates and numbers. **Budget** holds, for each budget cycle
  /// touching the range, what was budgeted against what was spent or
  /// received and what is still planned, overall and by category with
  /// sub categories under their parent.
  ///
  /// A cycle that only partly falls inside a custom date range is
  /// reported whole on the Budget sheet, because its budgets belong to
  /// the cycle.
  Future<File> exportTransactionsXlsx({
    ExportRange range = ExportRange.allTime,
  }) async {
    final rows = await _collectRows(range);
    final budgetRows = await _budgetReport.build(
      from: range.from,
      toExclusive: range.toExclusive,
    );

    final workbook = Excel.createExcel();
    workbook.rename(workbook.getDefaultSheet()!, 'Transactions');
    final transactions = workbook['Transactions'];
    final budget = workbook['Budget'];

    final header = CellStyle(bold: true);
    final money = CellStyle(numberFormat: NumFormat.standard_4);
    final dateTime = CellStyle(
      numberFormat: NumFormat.custom(formatCode: 'yyyy-mm-dd hh:mm'),
    );

    void put(
      Sheet sheet,
      int column,
      int row,
      CellValue? value, [
      CellStyle? style,
    ]) => sheet.updateCell(
      CellIndex.indexByColumnRow(columnIndex: column, rowIndex: row),
      value,
      cellStyle: style,
    );
    CellValue text(String? value) => TextCellValue(value ?? '');
    CellValue? amount(int? minor) =>
        minor == null ? null : DoubleCellValue(minor / 100);

    for (final (column, name) in _columns.indexed) {
      put(transactions, column, 0, text(name), header);
    }
    for (final (index, row) in rows.indexed) {
      final r = index + 1;
      put(
        transactions,
        0,
        r,
        DateTimeCellValue.fromDateTime(row.when.toLocal()),
        dateTime,
      );
      put(transactions, 1, r, text(row.merchant));
      put(transactions, 2, r, text(row.description));
      put(transactions, 3, r, text(row.category));
      put(transactions, 4, r, text(row.subCategory));
      put(transactions, 5, r, text(row.account));
      put(transactions, 6, r, text(row.toAccount));
      put(transactions, 7, r, text(row.direction));
      put(transactions, 8, r, amount(row.amountMinor), money);
      put(transactions, 9, r, text(row.currency));
      put(transactions, 10, r, text(row.status));
      put(transactions, 11, r, text(row.source));
    }
    for (final (column, width) in const [
      20.0,
      24.0,
      28.0,
      18.0,
      18.0,
      18.0,
      18.0,
      11.0,
      14.0,
      9.0,
      12.0,
      11.0,
    ].indexed) {
      transactions.setColumnWidth(column, width);
    }

    for (final (column, name) in _budgetColumns.indexed) {
      put(budget, column, 0, text(name), header);
    }
    for (final (index, row) in budgetRows.indexed) {
      final r = index + 1;
      put(budget, 0, r, text(row.cycle));
      put(
        budget,
        1,
        r,
        text(switch (row.kind) {
          BudgetReportKind.overall => 'Overall',
          BudgetReportKind.expense => 'Expense',
          BudgetReportKind.income => 'Income',
        }),
      );
      put(budget, 2, r, text(row.category));
      put(budget, 3, r, text(row.subCategory));
      put(budget, 4, r, amount(row.budgetedMinor), money);
      put(budget, 5, r, amount(row.paidMinor), money);
      put(budget, 6, r, amount(row.plannedMinor), money);
      put(budget, 7, r, amount(row.remainingMinor), money);
    }
    final noteRow = budgetRows.length + 2;
    if (range.from != null || range.toExclusive != null) {
      put(
        budget,
        0,
        noteRow,
        text('Cycles that overlap the chosen dates are shown in full.'),
      );
    }
    if (budgetRows.isEmpty) {
      put(budget, 0, 1, text('No budget cycles in this range.'));
    }
    for (final (column, width) in const [
      24.0,
      10.0,
      20.0,
      20.0,
      14.0,
      16.0,
      16.0,
      14.0,
    ].indexed) {
      budget.setColumnWidth(column, width);
    }

    final bytes = workbook.encode();
    if (bytes == null) throw StateError('Could not build the Excel file.');
    return _writeTempBytes(
      'transactions${range.fileSuffix}',
      'xlsx',
      bytes,
    );
  }

  /// Transactions and transfers in [range] as typed rows, newest first.
  Future<List<_SheetRow>> _collectRows(ExportRange range) async {
    final transactions = await _transactions.getAllForExport(
      from: range.from,
      toExclusive: range.toExclusive,
    );
    final transfers = await _transfers.getAllForExport(
      from: range.from,
      toExclusive: range.toExclusive,
    );
    final categories = {
      for (final category in await _categories.getAll()) category.id: category,
    };
    final accountNames = {
      for (final account in await _accounts.getAll()) account.id: account.name,
    };

    final rows = <_SheetRow>[];
    for (final tx in transactions) {
      final category = categories[tx.categoryId];
      final parent = categories[category?.parentId];
      rows.add(
        _SheetRow(
          when: tx.transactedAt,
          merchant: tx.merchant ?? '',
          description: tx.description ?? '',
          // A parent that no longer exists leaves the child alone in
          // `Category` rather than dropping it.
          category: parent?.name ?? category?.name ?? '',
          subCategory: parent == null ? '' : category?.name ?? '',
          account: accountNames[tx.accountId] ?? '',
          toAccount: '',
          direction: tx.direction.name,
          amountMinor: tx.amountMinor,
          currency: tx.currency,
          status: tx.status.dbName,
          source: tx.source.name,
        ),
      );
    }
    for (final transfer in transfers) {
      rows.add(
        _SheetRow(
          when: transfer.transactedAt,
          merchant: '',
          description: transfer.note ?? '',
          category: '',
          subCategory: '',
          account: accountNames[transfer.fromAccountId] ?? '',
          toAccount: accountNames[transfer.toAccountId] ?? '',
          direction: 'transfer',
          amountMinor: transfer.amountMinor,
          currency: '',
          status: '',
          source: 'transfer',
        ),
      );
    }
    rows.sort((a, b) => b.when.compareTo(a.when));
    return rows;
  }

  Future<File> exportBackupJson() async {
    final document = <String, Object?>{
      'version': _backupSchemaVersion,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'accounts': (await _accounts.getAllForExport())
          .map(_accountToJson)
          .toList(),
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
      'savingsGoals': (await _savingsGoals.getAllForExport())
          .map(_savingsGoalToJson)
          .toList(),
      'savingsGoalEntries': (await _savingsGoals.getAllEntriesForExport())
          .map(_savingsGoalEntryToJson)
          .toList(),
      'wishlistItems': (await _wishlist.getAllForExport())
          .map(_wishlistItemToJson)
          .toList(),
      'wishlistItemPhotos': (await _wishlist.getAllPhotosForExport())
          .map(_wishlistItemPhotoToJson)
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
    var savingsGoalsImported = 0;
    var savingsGoalEntriesImported = 0;
    var wishlistItemsImported = 0;
    var wishlistItemPhotosImported = 0;
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
    // Goals before entries — an entry's `goalId` should resolve to an
    // already-restored goal, the same reason accounts/categories go
    // before transactions above.
    for (final entry in _listOf(document, 'savingsGoals')) {
      if (await _savingsGoals.restoreGoal(_savingsGoalFromJson(entry))) {
        savingsGoalsImported++;
      } else {
        skipped++;
      }
    }
    for (final entry in _listOf(document, 'savingsGoalEntries')) {
      if (await _savingsGoals.restoreEntry(_savingsGoalEntryFromJson(entry))) {
        savingsGoalEntriesImported++;
      } else {
        skipped++;
      }
    }
    // After both savingsGoals and transactions — a wishlist item's
    // linkedGoalId/linkedTransactionId should already resolve.
    for (final entry in _listOf(document, 'wishlistItems')) {
      if (await _wishlist.restoreItem(_wishlistItemFromJson(entry))) {
        wishlistItemsImported++;
      } else {
        skipped++;
      }
    }
    for (final entry in _listOf(document, 'wishlistItemPhotos')) {
      if (await _wishlist.restorePhoto(_wishlistItemPhotoFromJson(entry))) {
        wishlistItemPhotosImported++;
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
      savingsGoalsImported: savingsGoalsImported,
      savingsGoalEntriesImported: savingsGoalEntriesImported,
      wishlistItemsImported: wishlistItemsImported,
      wishlistItemPhotosImported: wishlistItemPhotosImported,
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

  Future<File> _writeTempBytes(
    String label,
    String extension,
    List<int> bytes,
  ) async {
    final dir = await _tempDirectory();
    final stamp = DateTime.now().toUtc().toIso8601String().replaceAll(
      RegExp('[^0-9]'),
      '',
    );
    final file = File(
      p.join(dir.path, 'intellispendiq_${label}_$stamp.$extension'),
    );
    await file.writeAsBytes(bytes);
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
    'linkedGoalId': account.linkedGoalId,
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
    linkedGoalId: json['linkedGoalId'] as String?,
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

  Map<String, Object?> _savingsGoalToJson(SavingsGoal goal) => {
    'id': goal.id,
    'name': goal.name,
    'targetMinor': goal.targetMinor,
    'targetDate': goal.targetDate?.toIso8601String(),
    'defaultAccountId': goal.defaultAccountId,
    'status': goal.status.dbName,
    'accountId': goal.accountId,
  };

  SavingsGoal _savingsGoalFromJson(Map<String, Object?> json) => SavingsGoal(
    id: json['id']! as String,
    name: json['name']! as String,
    targetMinor: json['targetMinor']! as int,
    targetDate: json['targetDate'] == null
        ? null
        : DateTime.parse(json['targetDate']! as String),
    defaultAccountId: json['defaultAccountId'] as String?,
    status: json['status'] == null
        ? GoalStatus.active
        : GoalStatus.fromDbName(json['status']! as String),
    accountId: json['accountId'] as String?,
  );

  Map<String, Object?> _savingsGoalEntryToJson(SavingsGoalEntry entry) => {
    'id': entry.id,
    'goalId': entry.goalId,
    'accountId': entry.accountId,
    'amountMinor': entry.amountMinor,
    'kind': entry.kind.dbName,
    'transactedAt': entry.transactedAt.toIso8601String(),
    'note': entry.note,
    'linkedTransactionId': entry.linkedTransactionId,
    'linkedTransferId': entry.linkedTransferId,
  };

  SavingsGoalEntry _savingsGoalEntryFromJson(Map<String, Object?> json) =>
      SavingsGoalEntry(
        id: json['id']! as String,
        goalId: json['goalId']! as String,
        accountId: json['accountId']! as String,
        amountMinor: json['amountMinor']! as int,
        kind: GoalEntryKind.fromDbName(json['kind']! as String),
        transactedAt: DateTime.parse(json['transactedAt']! as String),
        note: json['note'] as String?,
        linkedTransactionId: json['linkedTransactionId'] as String?,
        linkedTransferId: json['linkedTransferId'] as String?,
      );

  Map<String, Object?> _wishlistItemToJson(WishlistItem item) => {
    'id': item.id,
    'name': item.name,
    'estimatedPriceMinor': item.estimatedPriceMinor,
    'actualPriceMinor': item.actualPriceMinor,
    'seenAt': item.seenAt,
    'productUrl': item.productUrl,
    'note': item.note,
    'linkedGoalId': item.linkedGoalId,
    'linkedTransactionId': item.linkedTransactionId,
    'purchasedAt': item.purchasedAt?.toIso8601String(),
  };

  WishlistItem _wishlistItemFromJson(Map<String, Object?> json) => WishlistItem(
    id: json['id']! as String,
    name: json['name']! as String,
    estimatedPriceMinor: json['estimatedPriceMinor'] as int?,
    actualPriceMinor: json['actualPriceMinor'] as int?,
    seenAt: json['seenAt'] as String?,
    productUrl: json['productUrl'] as String?,
    note: json['note'] as String?,
    linkedGoalId: json['linkedGoalId'] as String?,
    linkedTransactionId: json['linkedTransactionId'] as String?,
    purchasedAt: json['purchasedAt'] == null
        ? null
        : DateTime.parse(json['purchasedAt']! as String),
  );

  /// Only the row is exported — the photo *file* itself is not part of
  /// the backup JSON, the same known limitation `Transaction.receiptPath`
  /// already has.
  Map<String, Object?> _wishlistItemPhotoToJson(WishlistItemPhoto photo) => {
    'id': photo.id,
    'wishlistItemId': photo.wishlistItemId,
    'path': photo.path,
    'sortOrder': photo.sortOrder,
  };

  WishlistItemPhoto _wishlistItemPhotoFromJson(Map<String, Object?> json) =>
      WishlistItemPhoto(
        id: json['id']! as String,
        wishlistItemId: json['wishlistItemId']! as String,
        path: json['path']! as String,
        sortOrder: json['sortOrder'] as int? ?? 0,
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
