part of 'budgets_cubit.dart';

enum BudgetsStatus { initial, loading, loaded, invalid }

class BudgetsState extends Equatable {
  const BudgetsState({
    required this.period,
    this.status = BudgetsStatus.initial,
    this.budgets = const [],
    this.categories = const [],
    this.spentByCategory = const {},
    this.errorMessage,
  });

  final BudgetsStatus status;

  /// Month key, `YYYY-MM`.
  final String period;
  final List<BudgetRow> budgets;
  final List<CategoryRow> categories;

  /// Confirmed debit spend per category for [period], in ngwee.
  final Map<String, int> spentByCategory;
  final String? errorMessage;

  bool get isEmpty => status == BudgetsStatus.loaded && budgets.isEmpty;

  int spentFor(String categoryId) => spentByCategory[categoryId] ?? 0;

  String categoryName(String categoryId) =>
      categories
          .where((c) => c.id == categoryId)
          .map((c) => '${c.icon ?? ''} ${c.name}')
          .firstOrNull ??
      'Category';

  BudgetsState copyWith({
    BudgetsStatus? status,
    String? period,
    List<BudgetRow>? budgets,
    List<CategoryRow>? categories,
    Map<String, int>? spentByCategory,
    String? errorMessage,
  }) {
    return BudgetsState(
      status: status ?? this.status,
      period: period ?? this.period,
      budgets: budgets ?? this.budgets,
      categories: categories ?? this.categories,
      spentByCategory: spentByCategory ?? this.spentByCategory,
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
    errorMessage,
  ];
}
