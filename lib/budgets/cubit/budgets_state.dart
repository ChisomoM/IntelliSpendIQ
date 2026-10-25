part of 'budgets_cubit.dart';

enum BudgetsStatus { initial, loading, loaded, invalid }

class BudgetsState extends Equatable {
  const BudgetsState({
    this.budgetPeriod,
    this.status = BudgetsStatus.initial,
    this.overallBudget,
    this.categories = const [],
    this.categoryBudgets = const {},
    this.incomeStatusByCategory = const {},
    this.receivedByCategory = const {},
    this.receiptTransactionByCategory = const {},
    this.actualIncomeMinor = 0,
    this.provisionalIncomeMinor = 0,
    this.spentByCategory = const {},
    this.totalSpent = 0,
    this.includePlanned = false,
    this.errorMessage,
  });

  final BudgetsStatus status;

  /// Active budget window. Null only before the first [BudgetsCubit.load].
  final BudgetPeriod? budgetPeriod;

  /// Convenience view of [BudgetPeriod.overallAmountMinor] for editors.
  final OverallBudget? overallBudget;

  /// Categories with period-specific amounts overlaid when available.
  final List<Category> categories;

  /// Raw per-period category envelopes keyed by category id.
  final Map<String, int> categoryBudgets;

  /// Whether each income source has been received in [budgetPeriod]:
  /// [IncomeStatus.paid] once what arrived covers what was planned (or
  /// anything arrived with no plan), [IncomeStatus.unpaid] while something
  /// is planned or only part has arrived. Absent for a source with neither.
  /// Worked out from the transactions, not from a manual "mark as paid".
  final Map<String, IncomeStatus> incomeStatusByCategory;

  /// Money that arrived in [budgetPeriod] per top-level income source: the
  /// confirmed credits filed under it or its sub categories.
  final Map<String, int> receivedByCategory;

  /// For a source whose line was marked paid, the transaction that marking
  /// it paid recorded, by source id.
  final Map<String, String> receiptTransactionByCategory;

  /// Money that arrived in [budgetPeriod], from the transactions — the
  /// figure used everywhere else money-in for this cycle is shown.
  final int actualIncomeMinor;

  /// [actualIncomeMinor] plus what is still expected: per source, the
  /// larger of what was planned and what has arrived.
  final int provisionalIncomeMinor;

  /// Confirmed debit spend per expense category for [budgetPeriod].
  final Map<String, int> spentByCategory;

  /// Confirmed debit spend across every category for [budgetPeriod].
  ///
  /// Confirmed-only when [includePlanned] is false; confirmed +
  /// [TxStatus.planned] (future/unpaid entries) when true.
  final int totalSpent;

  /// Whether [totalSpent] and [spentByCategory] also count planned
  /// (unpaid, possibly future-dated) transactions — the Budgets
  /// screen's "Planned" view, for previewing how scheduled expenses
  /// land against the plan. Defaults to actual-only every time the
  /// screen loads, so a total is never quietly inflated by something
  /// unpaid.
  final bool includePlanned;

  final String? errorMessage;

  /// Display label `DD/MM/YYYY – DD/MM/YYYY`, or empty before load.
  String get periodLabel => budgetPeriod?.label ?? '';

  /// The same window in prose — `1 – 31 Jul`, or `1 Jul – 4 Aug` when
  /// it straddles a month. The stored label is machine output.
  ///
  /// Deliberately identical to `DashboardState.periodDisplayLabel`:
  /// Home and Budgets walk the same budget periods, so a user moving
  /// between the two tabs must see the same window described the same
  /// way.
  String get periodDisplayLabel {
    final period = budgetPeriod;
    if (period == null) return '';
    final start = Iso.toDateTime(period.startAt).toLocal();
    final endInclusive = Iso.toDateTime(
      period.endAt,
    ).toLocal().subtract(const Duration(days: 1));

    final endDay = DateFormat('d MMM').format(endInclusive);
    if (start.month == endInclusive.month && start.year == endInclusive.year) {
      return '${DateFormat('d').format(start)} – $endDay';
    }
    return '${DateFormat('d MMM').format(start)} – $endDay';
  }

  /// Whole days left in the period, counting today. Zero once it ends.
  int get daysLeft {
    final period = budgetPeriod;
    if (period == null) return 0;
    final end = Iso.toDateTime(period.endAt).toLocal();
    final today = DateTime.now();
    final difference = DateTime(
      end.year,
      end.month,
      end.day,
    ).difference(DateTime(today.year, today.month, today.day)).inDays;
    return difference < 0 ? 0 : difference;
  }

  bool get isCurrentPeriod {
    final period = budgetPeriod;
    if (period == null) return false;
    final now = DateTime.now().toUtc();
    return now.isAfter(Iso.toDateTime(period.startAt)) &&
        now.isBefore(Iso.toDateTime(period.endAt));
  }

  List<Category> get budgetedExpenseCategories => categories
      .where((c) => c.isExpense && c.parentId == null && c.hasBudget)
      .toList();

  /// Every top-level expense category — with or without a budget or
  /// spend yet, same as [topLevelIncomeCategories].
  List<Category> get visibleExpenseCategories =>
      categories.where((c) => c.isExpense && c.parentId == null).toList();

  /// Every top-level income source — with or without a planned amount.
  List<Category> get topLevelIncomeCategories =>
      categories.where((c) => c.isIncome && c.parentId == null).toList();

  List<Category> get budgetedIncomeCategories =>
      topLevelIncomeCategories.where((c) => c.hasBudget).toList();

  List<Category> childrenOf(String parentId) =>
      categories.where((c) => c.parentId == parentId).toList();

  bool get isEmpty =>
      status == BudgetsStatus.loaded && visibleExpenseCategories.isEmpty;

  bool get hasIncome => budgetedIncomeCategories.isNotEmpty;

  bool get hasOverallBudget => overallBudget != null;

  /// The main income figure — actual (paid-only) income for this cycle.
  int get totalIncomeMinor => actualIncomeMinor;

  int get remainingMinor => totalIncomeMinor - totalSpent;

  IncomeStatus? statusFor(String categoryId) =>
      incomeStatusByCategory[categoryId];

  int get totalPlannedMinor => overallBudget?.amountMinor ?? 0;

  int get totalAllocatedMinor => budgetedExpenseCategories.fold(
    0,
    (sum, category) => sum + category.budgetedAmountMinor!,
  );

  int spentFor(String categoryId) => spentByCategory[categoryId] ?? 0;

  /// Categories already past their envelope.
  List<Category> get overspentCategories => budgetedExpenseCategories
      .where((c) => spentFor(c.id) > c.budgetedAmountMinor!)
      .toList();

  /// A plain read on the period for the insight strip.
  ///
  /// Computed here from figures already on screen rather than asked of
  /// the model: this line renders on every build, and an opinion that
  /// cost an API call and could contradict the numbers beside it would
  /// be worse than no opinion at all. The assistant is one tap away for
  /// anything that needs actual reasoning.
  String? get insight {
    if (status != BudgetsStatus.loaded) return null;
    if (budgetedExpenseCategories.isEmpty) return null;

    final over = overspentCategories;
    if (over.length == 1) {
      return "You're over on ${over.single.name}. "
          'Budget can be moved from another category.';
    }
    if (over.length > 1) {
      return "You're over on ${over.length} categories, including "
          '${over.first.name}.';
    }
    if (totalPlannedMinor > 0 && totalSpent > totalPlannedMinor) {
      return 'Every category is inside its budget, but the total is over '
          'the plan.';
    }
    if (totalPlannedMinor > 0 && totalAllocatedMinor > totalPlannedMinor) {
      return 'Your category budgets add up to more than the total plan.';
    }
    return "You're inside every category budget so far.";
  }

  BudgetsState copyWith({
    BudgetsStatus? status,
    BudgetPeriod? budgetPeriod,
    OverallBudget? overallBudget,
    bool clearOverallBudget = false,
    List<Category>? categories,
    Map<String, int>? categoryBudgets,
    Map<String, IncomeStatus>? incomeStatusByCategory,
    Map<String, int>? receivedByCategory,
    Map<String, String>? receiptTransactionByCategory,
    int? actualIncomeMinor,
    int? provisionalIncomeMinor,
    Map<String, int>? spentByCategory,
    int? totalSpent,
    bool? includePlanned,
    String? errorMessage,
  }) {
    return BudgetsState(
      status: status ?? this.status,
      budgetPeriod: budgetPeriod ?? this.budgetPeriod,
      overallBudget: clearOverallBudget
          ? null
          : (overallBudget ?? this.overallBudget),
      categories: categories ?? this.categories,
      categoryBudgets: categoryBudgets ?? this.categoryBudgets,
      incomeStatusByCategory:
          incomeStatusByCategory ?? this.incomeStatusByCategory,
      receivedByCategory: receivedByCategory ?? this.receivedByCategory,
      receiptTransactionByCategory:
          receiptTransactionByCategory ?? this.receiptTransactionByCategory,
      actualIncomeMinor: actualIncomeMinor ?? this.actualIncomeMinor,
      provisionalIncomeMinor:
          provisionalIncomeMinor ?? this.provisionalIncomeMinor,
      spentByCategory: spentByCategory ?? this.spentByCategory,
      totalSpent: totalSpent ?? this.totalSpent,
      includePlanned: includePlanned ?? this.includePlanned,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [
    status,
    budgetPeriod,
    overallBudget,
    categories,
    categoryBudgets,
    incomeStatusByCategory,
    receivedByCategory,
    receiptTransactionByCategory,
    actualIncomeMinor,
    provisionalIncomeMinor,
    spentByCategory,
    totalSpent,
    includePlanned,
    errorMessage,
  ];
}
