import 'dart:io';

import 'package:drift/drift.dart' show DatabaseConnectionUser;
import 'package:intellispendiq/core/money.dart';
import 'package:intellispendiq/data/repositories/account_repository.dart';
import 'package:intellispendiq/data/repositories/budget_period_repository.dart';
import 'package:intellispendiq/data/repositories/category_repository.dart';
import 'package:intellispendiq/data/repositories/transaction_repository.dart';
import 'package:intellispendiq/domain/models/category.dart';
import 'package:intellispendiq/domain/models/enums.dart';
import 'package:intellispendiq/domain/models/transaction_draft.dart';
import 'package:intellispendiq/domain/services/csv_reader.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// One budget line from the file, validated and ready to save.
class BudgetImportRow {
  const BudgetImportRow({
    required this.line,
    required this.date,
    required this.category,
    required this.amountMinor,
    required this.isPaid,
    required this.key,
    this.subCategory,
    this.accountId,
    this.merchant,
    this.note,
  });

  /// 1-based line number in the file, for messages.
  final int line;

  /// Local noon on the line's date, so the entry stays on its day and in
  /// its cycle whatever the time zone.
  final DateTime date;
  final String category;
  final String? subCategory;
  final int amountMinor;

  /// Paid becomes a confirmed expense, unpaid a planned one — the same
  /// split as the "Already paid" switch on the expense form.
  final bool isPaid;

  /// Null means the default account.
  final String? accountId;

  /// The merchant or person, as in the form's "Merchant or person" field.
  final String? merchant;
  final String? note;

  /// Idempotency key: the same line imported twice is recognised and
  /// skipped the second time.
  final String key;
}

/// A line imported earlier without a merchant, now given one in the file.
class BudgetImportBackfill {
  const BudgetImportBackfill({required this.transactionId, required this.merchant});

  final String transactionId;
  final String merchant;
}

class BudgetImportError {
  const BudgetImportError(this.line, this.message);

  final int line;
  final String message;

  @override
  String toString() => 'Line $line: $message';
}

/// What an import would do, worked out without writing anything.
class BudgetImportPlan {
  const BudgetImportPlan({
    required this.rows,
    required this.errors,
    required this.alreadyPresent,
    required this.newCategories,
    this.backfills = const [],
  });

  /// Lines that will be saved.
  final List<BudgetImportRow> rows;
  final List<BudgetImportError> errors;

  /// Lines skipped because an identical one was imported before.
  final int alreadyPresent;

  /// Categories to create, as `Food` or `Food > Snacks`, in creation
  /// order.
  final List<String> newCategories;

  /// Earlier imports that have no merchant yet and get one from this
  /// file. Counted apart from [alreadyPresent].
  final List<BudgetImportBackfill> backfills;

  int get paidCount => rows.where((row) => row.isPaid).length;
  int get plannedCount => rows.length - paidCount;
  bool get hasWork => rows.isNotEmpty || backfills.isNotEmpty;
}

/// Bulk-creates budget lines from a CSV: each line is something the
/// user is budgeting for, saved as an expense in the cycle holding its
/// date — planned until paid, confirmed once paid.
///
/// Missing categories and sub categories are created. Lines already
/// imported are skipped, so a file can be re-imported safely.
class BudgetImportService {
  BudgetImportService({
    required DatabaseConnectionUser db,
    required TransactionRepository transactions,
    required CategoryRepository categories,
    required AccountRepository accounts,
    required BudgetPeriodRepository budgetPeriods,
    Future<Directory> Function()? tempDirectory,
  }) : _db = db,
       _transactions = transactions,
       _categories = categories,
       _accounts = accounts,
       _budgetPeriods = budgetPeriods,
       _tempDirectory = tempDirectory ?? getTemporaryDirectory;

  final DatabaseConnectionUser _db;
  final TransactionRepository _transactions;
  final CategoryRepository _categories;
  final AccountRepository _accounts;
  final BudgetPeriodRepository _budgetPeriods;
  final Future<Directory> Function() _tempDirectory;

  static const templateColumns = [
    'Date',
    'Category',
    'Sub category',
    'Amount',
    'Paid',
    'Account',
    'Merchant',
    'Note',
  ];

  static const _aliases = {
    'date': 'date',
    'category': 'category',
    'subcategory': 'sub',
    'sub category': 'sub',
    'sub-category': 'sub',
    'amount': 'amount',
    'paid': 'paid',
    'already paid': 'paid',
    'account': 'account',
    'merchant': 'merchant',
    'payee': 'merchant',
    'person': 'merchant',
    'merchant/person': 'merchant',
    'merchant or person': 'merchant',
    'name': 'merchant',
    'vendor': 'merchant',
    'note': 'note',
    'notes': 'note',
    'description': 'note',
  };

  /// Writes a small example file to fill in.
  Future<File> writeTemplate() async {
    final dir = await _tempDirectory();
    final file = File(p.join(dir.path, 'intellispendiq_budget_template.csv'));
    await file.writeAsString(
      '${templateColumns.join(',')}\n'
      '2026-10-05,Food,Snacks,400.00,yes,,Kiosk,Lunch\n'
      '2026-10-28,Rent,,6500.00,no,,Mr Banda,October rent\n',
    );
    return file;
  }

  /// Reads [csv] and works out what importing it would do. Writes
  /// nothing. Throws [FormatException] if the header lacks a required
  /// column (Date, Category, Amount).
  Future<BudgetImportPlan> parse(String csv) async {
    final table = readCsv(csv);
    if (table.isEmpty) throw const FormatException('The file is empty.');

    final columns = <String, int>{};
    for (final (index, name) in table.first.indexed) {
      final key = _aliases[name.trim().toLowerCase()];
      if (key != null) columns.putIfAbsent(key, () => index);
    }
    final missing = [
      for (final (key, label) in const [
        ('date', 'Date'),
        ('category', 'Category'),
        ('amount', 'Amount'),
      ])
        if (!columns.containsKey(key)) label,
    ];
    if (missing.isNotEmpty) {
      throw FormatException('Missing column: ${missing.join(', ')}.');
    }

    final categories = await _categories.getAll();
    final accountsByName = {
      for (final account in await _accounts.getAll())
        _norm(account.name): account.id,
    };

    String cell(List<String> row, String key) {
      final index = columns[key];
      return index == null || index >= row.length ? '' : row[index].trim();
    }

    final rows = <BudgetImportRow>[];
    final errors = <BudgetImportError>[];
    final newCategories = <String>[];
    final backfills = <BudgetImportBackfill>[];
    final occurrences = <String, int>{};
    var alreadyPresent = 0;

    for (var i = 1; i < table.length; i++) {
      final row = table[i];
      final line = i + 1;

      final date = _parseDate(cell(row, 'date'));
      if (date == null) {
        errors.add(
          BudgetImportError(
            line,
            'date "${cell(row, 'date')}" is not YYYY-MM-DD or DD/MM/YYYY',
          ),
        );
        continue;
      }
      final category = cell(row, 'category');
      if (category.isEmpty) {
        errors.add(BudgetImportError(line, 'category is empty'));
        continue;
      }
      final amountMinor = Money.tryParseToMinor(cell(row, 'amount'));
      if (amountMinor == null || amountMinor <= 0) {
        errors.add(
          BudgetImportError(
            line,
            'amount "${cell(row, 'amount')}" is not a positive number',
          ),
        );
        continue;
      }
      final paid = _parsePaid(cell(row, 'paid'));
      if (paid == null) {
        errors.add(
          BudgetImportError(
            line,
            'paid "${cell(row, 'paid')}" should be yes or no',
          ),
        );
        continue;
      }
      String? accountId;
      final accountName = cell(row, 'account');
      if (accountName.isNotEmpty) {
        accountId = accountsByName[_norm(accountName)];
        if (accountId == null) {
          errors.add(BudgetImportError(line, 'unknown account "$accountName"'));
          continue;
        }
      }
      final subCategory = cell(row, 'sub');

      final topLevel = _find(categories, category, parentId: null);
      if (topLevel != null && !topLevel.isExpense) {
        errors.add(
          BudgetImportError(line, '"$category" is an income category'),
        );
        continue;
      }
      if (topLevel == null && !newCategories.contains(category)) {
        newCategories.add(category);
      }
      if (subCategory.isNotEmpty) {
        final child = topLevel == null
            ? null
            : _find(categories, subCategory, parentId: topLevel.id);
        final label = '$category > $subCategory';
        if (child == null && !newCategories.contains(label)) {
          newCategories.add(label);
        }
      }

      final base = [
        date.year,
        date.month,
        date.day,
        _norm(category),
        _norm(subCategory),
        amountMinor,
        accountId ?? '',
      ].join('|');
      final nth = occurrences.update(base, (n) => n + 1, ifAbsent: () => 1);
      final key = 'budget-import:$base|$nth';

      final merchant = cell(row, 'merchant');
      final existing = await _transactions.byIdempotencyKey(key);
      if (existing != null) {
        // Fill empty: an earlier import that left the merchant blank
        // picks it up now, but a merchant already there is never
        // overwritten.
        if (merchant.isNotEmpty && (existing.merchant ?? '').trim().isEmpty) {
          backfills.add(
            BudgetImportBackfill(
              transactionId: existing.id,
              merchant: merchant,
            ),
          );
        } else {
          alreadyPresent++;
        }
        continue;
      }
      final note = cell(row, 'note');
      rows.add(
        BudgetImportRow(
          line: line,
          date: DateTime(date.year, date.month, date.day, 12),
          category: category,
          subCategory: subCategory.isEmpty ? null : subCategory,
          amountMinor: amountMinor,
          isPaid: paid,
          accountId: accountId,
          merchant: merchant.isEmpty ? null : merchant,
          note: note.isEmpty ? null : note,
          key: key,
        ),
      );
    }

    return BudgetImportPlan(
      rows: rows,
      errors: errors,
      alreadyPresent: alreadyPresent,
      newCategories: newCategories,
      backfills: backfills,
    );
  }

  /// Creates the missing categories and saves every line of [plan] in
  /// one database transaction, so a failure leaves nothing half done.
  /// Returns how many entries were saved or filled in.
  Future<int> apply(BudgetImportPlan plan) {
    return _db.transaction(() async {
      final categories = await _categories.getAll();
      final defaultAccountId = (await _accounts.getDefault()).id;

      Future<Category> categoryFor(String name, {String? parentId}) async {
        final existing = _find(categories, name, parentId: parentId);
        if (existing != null) return existing;
        final created = await _categories.create(name, parentId: parentId);
        categories.add(created);
        return created;
      }

      for (final row in plan.rows) {
        final parent = await categoryFor(row.category);
        final category = row.subCategory == null
            ? parent
            : await categoryFor(row.subCategory!, parentId: parent.id);
        final period = await _budgetPeriods.ensurePeriodContaining(row.date);
        await _transactions.insertDraft(
          TransactionDraft(
            amountMinor: row.amountMinor,
            direction: TxDirection.debit,
            source: TxSource.manual,
            transactedAt: row.date,
            merchant: row.merchant,
            description: row.note,
            categoryId: category.id,
            confidence: 1,
          ),
          accountId: row.accountId ?? defaultAccountId,
          idempotencyKey: row.key,
          status: row.isPaid ? TxStatus.confirmed : TxStatus.planned,
          periodId: period.id,
        );
      }
      for (final backfill in plan.backfills) {
        await _transactions.updateFields(
          backfill.transactionId,
          merchant: backfill.merchant,
        );
      }
      return plan.rows.length + plan.backfills.length;
    });
  }

  static Category? _find(
    List<Category> categories,
    String name, {
    required String? parentId,
  }) {
    final wanted = _norm(name);
    for (final category in categories) {
      if (category.parentId == parentId && _norm(category.name) == wanted) {
        return category;
      }
    }
    return null;
  }

  static String _norm(String value) =>
      value.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

  /// `2026-10-05` (optionally followed by a time) or `05/10/2026`.
  static DateTime? _parseDate(String raw) {
    final iso = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})(?:[T ].*)?$');
    final dmy = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})$');
    int year;
    int month;
    int day;
    final isoMatch = iso.firstMatch(raw.trim());
    final dmyMatch = dmy.firstMatch(raw.trim());
    if (isoMatch != null) {
      year = int.parse(isoMatch.group(1)!);
      month = int.parse(isoMatch.group(2)!);
      day = int.parse(isoMatch.group(3)!);
    } else if (dmyMatch != null) {
      day = int.parse(dmyMatch.group(1)!);
      month = int.parse(dmyMatch.group(2)!);
      year = int.parse(dmyMatch.group(3)!);
    } else {
      return null;
    }
    final date = DateTime(year, month, day);
    // DateTime rolls 31 Feb into March; reject that instead.
    if (date.year != year || date.month != month || date.day != day) {
      return null;
    }
    return date;
  }

  /// Blank counts as unpaid, the safer default: a planned entry doesn't
  /// count toward totals until it is paid.
  static bool? _parsePaid(String raw) {
    switch (raw.trim().toLowerCase()) {
      case '':
      case 'no':
      case 'n':
      case 'false':
      case '0':
      case 'unpaid':
        return false;
      case 'yes':
      case 'y':
      case 'true':
      case '1':
      case 'paid':
        return true;
    }
    return null;
  }
}
