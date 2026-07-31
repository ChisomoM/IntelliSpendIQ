part of 'dashboard_cubit.dart';

enum DashboardStatus { initial, loading, loaded }

class DashboardState extends Equatable {
  const DashboardState({
    this.budgetPeriod,
    this.status = DashboardStatus.initial,
    this.incomeCategories = const [],
    this.totalSpent = 0,
    this.topCategories = const [],
    this.recentTransactions = const [],
    this.needsReviewCount = 0,
    this.failedCaptureCount = 0,
  });

  /// Active budget window for home totals.
  final BudgetPeriod? budgetPeriod;
  final DashboardStatus status;

  /// Top-level income categories with a planned amount for [budgetPeriod].
  final List<Category> incomeCategories;

  /// Confirmed debit spend across every category for [budgetPeriod].
  final int totalSpent;

  /// Largest categories by spend for [budgetPeriod], already sorted and
  /// truncated to the top few.
  final List<CategorySpend> topCategories;

  /// Most recent transactions, newest first.
  final List<Transaction> recentTransactions;

  /// Transactions flagged needs_review or duplicate_suspect.
  final int needsReviewCount;

  /// Messages stored raw because no parser understood them.
  final int failedCaptureCount;

  /// Display label `DD/MM/YYYY – DD/MM/YYYY`.
  String get periodLabel => budgetPeriod?.label ?? '';

  bool get hasIncome => incomeCategories.isNotEmpty;

  int get totalIncomeMinor => incomeCategories.fold(
    0,
    (sum, category) => sum + category.budgetedAmountMinor!,
  );

  int get remainingMinor => totalIncomeMinor - totalSpent;

  int get pendingReviewCount => needsReviewCount + failedCaptureCount;

  DashboardState copyWith({
    BudgetPeriod? budgetPeriod,
    DashboardStatus? status,
    List<Category>? incomeCategories,
    int? totalSpent,
    List<CategorySpend>? topCategories,
    List<Transaction>? recentTransactions,
    int? needsReviewCount,
    int? failedCaptureCount,
  }) {
    return DashboardState(
      budgetPeriod: budgetPeriod ?? this.budgetPeriod,
      status: status ?? this.status,
      incomeCategories: incomeCategories ?? this.incomeCategories,
      totalSpent: totalSpent ?? this.totalSpent,
      topCategories: topCategories ?? this.topCategories,
      recentTransactions: recentTransactions ?? this.recentTransactions,
      needsReviewCount: needsReviewCount ?? this.needsReviewCount,
      failedCaptureCount: failedCaptureCount ?? this.failedCaptureCount,
    );
  }

  @override
  List<Object?> get props => [
    budgetPeriod,
    status,
    incomeCategories,
    totalSpent,
    topCategories,
    recentTransactions,
    needsReviewCount,
    failedCaptureCount,
  ];
}
