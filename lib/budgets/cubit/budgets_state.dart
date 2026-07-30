part of 'budgets_cubit.dart';

enum BudgetsStatus { initial, loading, loaded, invalid }

class BudgetsState extends Equatable {
  const BudgetsState({
    required this.period,
    this.status = BudgetsStatus.initial,
    this.budgets = const [],
    this.categories = const [],
    this.spentByCategory = const {},
    this.incomeSources = const [],
    this.totalSpent = 0,
    this.errorMessage,
  });

  final BudgetsStatus status;

  /// Month key, `YYYY-MM`.
  final String period;
  final List<Budget> budgets;
  final List<Category> categories;

  /// Confirmed debit spend per category for [period], in ngwee.
  final Map<String, int> spentByCategory;

  /// Every declared income stream for [period] — a month can have more
  /// than one, e.g. "Salary" and "Side hustle".
  final List<MonthlyIncome> incomeSources;

  /// Confirmed debit spend across every category for [period], in
  /// ngwee — tracked against [totalIncomeMinor] rather than a
  /// per-category limit.
  final int totalSpent;
  final String? errorMessage;

  bool get isEmpty => status == BudgetsStatus.loaded && budgets.isEmpty;

  bool get hasIncome => incomeSources.isNotEmpty;

  /// Every income stream summed, in ngwee.
  int get totalIncomeMinor =>
      incomeSources.fold(0, (sum, income) => sum + income.amountMinor);

  /// Income minus total spend, in ngwee. Zero when no income is set.
  int get remainingMinor => totalIncomeMinor - totalSpent;

  /// Every category budget limit summed, in ngwee — the "planned"
  /// figure to compare against [totalSpent], independent of whether
  /// every dollar spent actually falls inside a budgeted category.
  int get totalPlannedMinor =>
      budgets.fold(0, (sum, budget) => sum + budget.amountMinor);

  int spentFor(String categoryId) => spentByCategory[categoryId] ?? 0;

  String categoryName(String categoryId) =>
      categories
          .where((c) => c.id == categoryId)
          .map((c) => c.displayName)
          .firstOrNull ??
      'Category';

  BudgetsState copyWith({
    BudgetsStatus? status,
    String? period,
    List<Budget>? budgets,
    List<Category>? categories,
    Map<String, int>? spentByCategory,
    List<MonthlyIncome>? incomeSources,
    int? totalSpent,
    String? errorMessage,
  }) {
    return BudgetsState(
      status: status ?? this.status,
      period: period ?? this.period,
      budgets: budgets ?? this.budgets,
      categories: categories ?? this.categories,
      spentByCategory: spentByCategory ?? this.spentByCategory,
      incomeSources: incomeSources ?? this.incomeSources,
      totalSpent: totalSpent ?? this.totalSpent,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [
    status,
    period,
    budgets,
    categories,
    spentByCategory,
    incomeSources,
    totalSpent,
    errorMessage,
  ];
}
