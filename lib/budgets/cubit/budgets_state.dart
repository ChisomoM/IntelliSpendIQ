part of 'budgets_cubit.dart';

enum BudgetsStatus { initial, loading, loaded, invalid }

class BudgetsState extends Equatable {
  const BudgetsState({
    this.budgetPeriod,
    this.status = BudgetsStatus.initial,
    this.overallBudget,
    this.categories = const [],
    this.categoryBudgets = const {},
    this.spentByCategory = const {},
    this.totalSpent = 0,
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

  /// Confirmed debit spend per expense category for [budgetPeriod].
  final Map<String, int> spentByCategory;

  /// Confirmed debit spend across every category for [budgetPeriod].
  final int totalSpent;
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

  /// Top-level expense categories worth showing on the budget screen:
  /// budgeted themselves, with confirmed spend (direct or via a
  /// subcategory), or with a subcategory that has money assigned.
  List<Category> get visibleExpenseCategories => categories
      .where((c) => c.isExpense && c.parentId == null && _isVisibleExpense(c))
      .toList();

  bool _isVisibleExpense(Category category) {
    if (category.hasBudget || spentFor(category.id) > 0) return true;
    return childrenOf(category.id).any((child) => child.hasBudget);
  }

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

  int get totalIncomeMinor => budgetedIncomeCategories.fold(
    0,
    (sum, category) => sum + category.budgetedAmountMinor!,
  );

  int get remainingMinor => totalIncomeMinor - totalSpent;

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
    Map<String, int>? spentByCategory,
    int? totalSpent,
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
      spentByCategory: spentByCategory ?? this.spentByCategory,
      totalSpent: totalSpent ?? this.totalSpent,
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
    spentByCategory,
    totalSpent,
    errorMessage,
  ];
}
