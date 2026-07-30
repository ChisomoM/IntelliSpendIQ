part of 'budgets_cubit.dart';

enum BudgetsStatus { initial, loading, loaded, invalid }

class BudgetsState extends Equatable {
  const BudgetsState({
    required this.period,
    this.status = BudgetsStatus.initial,
    this.budgets = const [],
    this.categories = const [],
    this.spentByCategory = const {},
    this.income,
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

  /// Declared income for [period], or null if none has been set yet.
  final MonthlyIncome? income;

  /// Confirmed debit spend across every category for [period], in
  /// ngwee — tracked against [income] rather than a per-category limit.
  final int totalSpent;
  final String? errorMessage;

  bool get isEmpty => status == BudgetsStatus.loaded && budgets.isEmpty;

  bool get hasIncome => income != null;

  /// Income minus total spend, in ngwee. Zero when no income is set.
  int get remainingMinor => (income?.amountMinor ?? 0) - totalSpent;

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
    MonthlyIncome? income,
    bool clearIncome = false,
    int? totalSpent,
    String? errorMessage,
  }) {
    return BudgetsState(
      status: status ?? this.status,
      period: period ?? this.period,
      budgets: budgets ?? this.budgets,
      categories: categories ?? this.categories,
      spentByCategory: spentByCategory ?? this.spentByCategory,
      income: clearIncome ? null : (income ?? this.income),
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
    income,
    totalSpent,
    errorMessage,
  ];
}
