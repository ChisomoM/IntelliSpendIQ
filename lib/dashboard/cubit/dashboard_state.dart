part of 'dashboard_cubit.dart';

enum DashboardStatus { initial, loading, loaded }

class DashboardState extends Equatable {
  const DashboardState({
    required this.period,
    this.status = DashboardStatus.initial,
    this.income,
    this.totalSpent = 0,
    this.topCategories = const [],
    this.recentTransactions = const [],
    this.needsReviewCount = 0,
    this.failedCaptureCount = 0,
  });

  /// Month key, `YYYY-MM`.
  final String period;
  final DashboardStatus status;

  /// Declared income for [period], or null if none has been set yet.
  final MonthlyIncome? income;

  /// Confirmed debit spend across every category for [period], in
  /// ngwee.
  final int totalSpent;

  /// Largest categories by spend for [period], already sorted and
  /// truncated to the top few.
  final List<CategorySpend> topCategories;

  /// Most recent transactions, newest first.
  final List<Transaction> recentTransactions;

  /// Transactions flagged needs_review or duplicate_suspect.
  final int needsReviewCount;

  /// Messages stored raw because no parser understood them.
  final int failedCaptureCount;

  bool get hasIncome => income != null;

  /// Income minus total spend, in ngwee. Zero when no income is set.
  int get remainingMinor => (income?.amountMinor ?? 0) - totalSpent;

  /// What the Review banner shows.
  int get pendingReviewCount => needsReviewCount + failedCaptureCount;

  DashboardState copyWith({
    String? period,
    DashboardStatus? status,
    MonthlyIncome? income,
    bool clearIncome = false,
    int? totalSpent,
    List<CategorySpend>? topCategories,
    List<Transaction>? recentTransactions,
    int? needsReviewCount,
    int? failedCaptureCount,
  }) {
    return DashboardState(
      period: period ?? this.period,
      status: status ?? this.status,
      income: clearIncome ? null : (income ?? this.income),
      totalSpent: totalSpent ?? this.totalSpent,
      topCategories: topCategories ?? this.topCategories,
      recentTransactions: recentTransactions ?? this.recentTransactions,
      needsReviewCount: needsReviewCount ?? this.needsReviewCount,
      failedCaptureCount: failedCaptureCount ?? this.failedCaptureCount,
    );
  }

  @override
  List<Object?> get props => [
    period,
    status,
    income,
    totalSpent,
    topCategories,
    recentTransactions,
    needsReviewCount,
    failedCaptureCount,
  ];
}
