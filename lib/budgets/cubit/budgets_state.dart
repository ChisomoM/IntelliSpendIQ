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

  List<Category> get budgetedExpenseCategories => categories
      .where((c) => c.isExpense && c.parentId == null && c.hasBudget)
      .toList();

  /// Every top-level income source — with or without a planned amount.
  List<Category> get topLevelIncomeCategories =>
      categories.where((c) => c.isIncome && c.parentId == null).toList();

  List<Category> get budgetedIncomeCategories =>
      topLevelIncomeCategories.where((c) => c.hasBudget).toList();

  List<Category> childrenOf(String parentId) =>
      categories.where((c) => c.parentId == parentId).toList();

  bool get isEmpty =>
      status == BudgetsStatus.loaded && budgetedExpenseCategories.isEmpty;

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
