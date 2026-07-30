part of 'budgets_cubit.dart';

enum BudgetsStatus { initial, loading, loaded, invalid }

class BudgetsState extends Equatable {
  const BudgetsState({
    required this.period,
    this.status = BudgetsStatus.initial,
    this.overallBudget,
    this.categories = const [],
    this.spentByCategory = const {},
    this.totalSpent = 0,
    this.errorMessage,
  });

  final BudgetsStatus status;

  /// Month key, `YYYY-MM`.
  final String period;

  /// The month's overall spending budget — a manual figure, separate
  /// from the sum of category budgets below.
  final OverallBudget? overallBudget;

  /// Every category, expense and income, at every level.
  final List<Category> categories;

  /// Confirmed debit spend per expense category for [period], in
  /// ngwee.
  final Map<String, int> spentByCategory;

  /// Confirmed debit spend across every category for [period], in
  /// ngwee — tracked against [totalIncomeMinor] and [totalAllocatedMinor].
  final int totalSpent;
  final String? errorMessage;

  /// Top-level expense categories with a budget set — the envelopes
  /// shown on the Budgets page. Categories without a budget still
  /// exist for tagging transactions; they just aren't envelopes.
  List<Category> get budgetedExpenseCategories => categories
      .where((c) => c.isExpense && c.parentId == null && c.hasBudget)
      .toList();

  /// Top-level income categories with a planned amount set.
  List<Category> get budgetedIncomeCategories => categories
      .where((c) => c.isIncome && c.parentId == null && c.hasBudget)
      .toList();

  List<Category> childrenOf(String parentId) =>
      categories.where((c) => c.parentId == parentId).toList();

  bool get isEmpty =>
      status == BudgetsStatus.loaded && budgetedExpenseCategories.isEmpty;

  bool get hasIncome => budgetedIncomeCategories.isNotEmpty;

  bool get hasOverallBudget => overallBudget != null;

  /// Every income category's planned amount summed, in ngwee.
  int get totalIncomeMinor => budgetedIncomeCategories.fold(
    0,
    (sum, category) => sum + category.budgetedAmountMinor!,
  );

  /// Income minus total spend, in ngwee. Zero when no income is set.
  int get remainingMinor => totalIncomeMinor - totalSpent;

  /// The overall monthly budget in ngwee — a manually set figure,
  /// independent of what's allocated across categories.
  int get totalPlannedMinor => overallBudget?.amountMinor ?? 0;

  /// Sum of top-level expense category budgets for [period], in
  /// ngwee — how much has been allocated across categories, which may
  /// be more or less than [totalPlannedMinor].
  int get totalAllocatedMinor => budgetedExpenseCategories.fold(
    0,
    (sum, category) => sum + category.budgetedAmountMinor!,
  );

  int spentFor(String categoryId) => spentByCategory[categoryId] ?? 0;

  BudgetsState copyWith({
    BudgetsStatus? status,
    String? period,
    OverallBudget? overallBudget,
    bool clearOverallBudget = false,
    List<Category>? categories,
    Map<String, int>? spentByCategory,
    int? totalSpent,
    String? errorMessage,
  }) {
    return BudgetsState(
      status: status ?? this.status,
      period: period ?? this.period,
      overallBudget: clearOverallBudget
          ? null
          : (overallBudget ?? this.overallBudget),
      categories: categories ?? this.categories,
      spentByCategory: spentByCategory ?? this.spentByCategory,
      totalSpent: totalSpent ?? this.totalSpent,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [
    status,
    period,
    overallBudget,
    categories,
    spentByCategory,
    totalSpent,
    errorMessage,
  ];
}
