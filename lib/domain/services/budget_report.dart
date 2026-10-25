import 'package:intellispendiq/data/repositories/budget_period_repository.dart';
import 'package:intellispendiq/data/repositories/category_repository.dart';
import 'package:intellispendiq/data/repositories/transaction_repository.dart';
import 'package:intellispendiq/domain/models/category.dart';
import 'package:intellispendiq/domain/models/enums.dart';

enum BudgetReportKind { overall, expense, income }

/// One line of the exported Budget sheet: what was budgeted for a
/// category (or the cycle as a whole) against what actually happened.
class BudgetReportRow {
  const BudgetReportRow({
    required this.cycle,
    required this.kind,
    required this.category,
    required this.paidMinor,
    required this.plannedMinor,
    this.subCategory,
    this.budgetedMinor,
  });

  /// The cycle's label, e.g. `25/09/2026 – 24/10/2026`.
  final String cycle;
  final BudgetReportKind kind;
  final String category;

  /// Set on a row that belongs to a sub category; [category] is then its
  /// parent.
  final String? subCategory;

  /// Null when nothing was budgeted for this line.
  final int? budgetedMinor;

  /// Spent (confirmed expenses) or received (confirmed income).
  final int paidMinor;

  /// Entered but not yet paid or received.
  final int plannedMinor;

  /// What is left of the budget. Spending counts planned entries as
  /// already committed; income only counts what has been received. Null
  /// when there is no budget to measure against.
  int? get remainingMinor {
    final budgeted = budgetedMinor;
    if (budgeted == null) return null;
    return kind == BudgetReportKind.income
        ? budgeted - paidMinor
        : budgeted - paidMinor - plannedMinor;
  }
}

/// Builds the rows of the Budget sheet, one block per cycle.
///
/// A parent category's spending includes its sub categories', the same
/// roll-up the Budgets screen shows: a sub category's budget is carved
/// out of its parent's. Totals use the cycle a transaction was assigned
/// to, exactly as the Budgets screen does.
class BudgetReportBuilder {
  BudgetReportBuilder({
    required BudgetPeriodRepository budgetPeriods,
    required TransactionRepository transactions,
    required CategoryRepository categories,
  }) : _budgetPeriods = budgetPeriods,
       _transactions = transactions,
       _categories = categories;

  final BudgetPeriodRepository _budgetPeriods;
  final TransactionRepository _transactions;
  final CategoryRepository _categories;

  /// Every cycle overlapping `[from, toExclusive)`, newest first. A
  /// cycle that only partly overlaps is reported whole, since its budgets
  /// belong to the cycle, not to a slice of it.
  Future<List<BudgetReportRow>> build({
    DateTime? from,
    DateTime? toExclusive,
  }) async {
    final periods = await _budgetPeriods.periodsOverlapping(
      from: from,
      toExclusive: toExclusive,
    );
    final categories = await _categories.getAll();
    final rows = <BudgetReportRow>[];

    for (final period in periods) {
      final budgets = {
        for (final budget in await _budgetPeriods.categoryBudgetsFor(
          period.id,
        ))
          budget.categoryId: budget.amountMinor,
      };
      final totals = await _transactions.categoryTotalsForPeriod(period.id);
      rows.addAll(
        _rowsFor(
          cycle: period.label,
          overallMinor: period.overallAmountMinor,
          categories: categories,
          budgets: budgets,
          totals: totals,
        ),
      );
    }
    return rows;
  }

  static List<BudgetReportRow> _rowsFor({
    required String cycle,
    required int? overallMinor,
    required List<Category> categories,
    required Map<String, int> budgets,
    required List<CategoryPeriodTotal> totals,
  }) {
    // Per category and kind: [paid, planned].
    final expense = <String?, List<int>>{};
    final income = <String?, List<int>>{};
    var spent = 0;
    var planned = 0;
    for (final total in totals) {
      final isPaid = total.status == TxStatus.confirmed;
      if (total.direction == TxDirection.debit) {
        final cell = expense.putIfAbsent(total.categoryId, () => [0, 0]);
        cell[isPaid ? 0 : 1] += total.totalMinor;
        if (isPaid) {
          spent += total.totalMinor;
        } else {
          planned += total.totalMinor;
        }
      } else {
        final cell = income.putIfAbsent(total.categoryId, () => [0, 0]);
        cell[isPaid ? 0 : 1] += total.totalMinor;
      }
    }

    final allIds = {for (final category in categories) category.id};

    final rows = <BudgetReportRow>[
      if (overallMinor != null || spent > 0 || planned > 0)
        BudgetReportRow(
          cycle: cycle,
          kind: BudgetReportKind.overall,
          category: 'Overall',
          budgetedMinor: overallMinor,
          paidMinor: spent,
          plannedMinor: planned,
        ),
      ..._section(
        cycle: cycle,
        kind: BudgetReportKind.expense,
        categories: categories.where((c) => c.isExpense).toList(),
        budgets: budgets,
        amounts: expense,
        allIds: allIds,
        uncategorizedName: 'Uncategorized',
      ),
      ..._section(
        cycle: cycle,
        kind: BudgetReportKind.income,
        categories: categories.where((c) => c.isIncome).toList(),
        budgets: budgets,
        amounts: income,
        allIds: allIds,
        uncategorizedName: 'Uncategorized income',
      ),
    ];
    return rows;
  }

  /// The rows for one side (expense or income): each top-level category
  /// followed by its sub categories, then anything whose category no
  /// longer exists.
  static List<BudgetReportRow> _section({
    required String cycle,
    required BudgetReportKind kind,
    required List<Category> categories,
    required Map<String, int> budgets,
    required Map<String?, List<int>> amounts,
    required Set<String> allIds,
    required String uncategorizedName,
  }) {
    int order(Category a, Category b) {
      final bySort = a.sortOrder.compareTo(b.sortOrder);
      return bySort != 0 ? bySort : a.name.compareTo(b.name);
    }

    List<int> own(String? id) => amounts[id] ?? const [0, 0];
    bool hasActivity(String id) =>
        budgets.containsKey(id) || own(id).any((value) => value != 0);

    final ids = {for (final category in categories) category.id};
    // A sub category whose parent is not on this side is shown as a
    // top-level line rather than lost.
    final topLevel =
        categories
            .where((c) => c.parentId == null || !ids.contains(c.parentId))
            .toList()
          ..sort(order);

    final rows = <BudgetReportRow>[];
    for (final parent in topLevel) {
      final children = categories.where((c) => c.parentId == parent.id).toList()
        ..sort(order);
      final shownChildren = children.where((c) => hasActivity(c.id)).toList();
      if (!hasActivity(parent.id) && shownChildren.isEmpty) continue;

      var paid = own(parent.id)[0];
      var planned = own(parent.id)[1];
      for (final child in children) {
        paid += own(child.id)[0];
        planned += own(child.id)[1];
      }
      rows.add(
        BudgetReportRow(
          cycle: cycle,
          kind: kind,
          category: parent.name,
          budgetedMinor: budgets[parent.id],
          paidMinor: paid,
          plannedMinor: planned,
        ),
      );
      for (final child in shownChildren) {
        rows.add(
          BudgetReportRow(
            cycle: cycle,
            kind: kind,
            category: parent.name,
            subCategory: child.name,
            budgetedMinor: budgets[child.id],
            paidMinor: own(child.id)[0],
            plannedMinor: own(child.id)[1],
          ),
        );
      }
    }

    // Activity under no category, or under one that has since been
    // deleted (its history is kept).
    for (final entry in amounts.entries) {
      final id = entry.key;
      // A category of the other type (a refund credited to an expense
      // category) is not part of this section, and not deleted either.
      if (id != null && allIds.contains(id)) continue;
      if (entry.value.every((value) => value == 0)) continue;
      rows.add(
        BudgetReportRow(
          cycle: cycle,
          kind: kind,
          category: id == null ? uncategorizedName : 'Deleted category',
          paidMinor: entry.value[0],
          plannedMinor: entry.value[1],
        ),
      );
    }
    return rows;
  }
}
