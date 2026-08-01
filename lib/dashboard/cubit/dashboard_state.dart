part of 'dashboard_cubit.dart';

enum DashboardStatus { initial, loading, loaded }

/// Where the figure the spend bar is measured against came from.
enum PlanSource {
  /// The period's own overall budget — what the user actually planned.
  overallBudget,

  /// No budget set, so planned income stands in as the ceiling.
  income,

  /// Neither is set: show spend on its own, with no bar.
  none,
}

/// Whether spending is running ahead of, behind, or level with an even
/// pace through the period.
enum PaceVerdict {
  onTrack,

  /// Spending faster than the period can carry.
  fast,

  /// Spending more slowly than planned — worth saying, because it is
  /// the one piece of good news this screen can give.
  slow,

  /// No plan, or the period is not the current one.
  none,
}

class DashboardState extends Equatable {
  const DashboardState({
    this.budgetPeriod,
    this.status = DashboardStatus.initial,
    this.incomeCategories = const [],
    this.totalSpent = 0,
    this.topCategories = const [],
    this.categoriesById = const {},
    this.recentTransactions = const [],
    this.accounts = const [],
    this.accountBalances = const {},
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

  /// Category per id, so a [CategorySpend] row — which carries only a
  /// name and a total — can still resolve both its glyph and its hue.
  final Map<String, Category> categoriesById;

  /// Most recent transactions, newest first.
  final List<Transaction> recentTransactions;

  /// Every account, for the balance strip.
  final List<Account> accounts;

  /// Account id to ledger-derived balance in ngwee.
  final Map<String, int> accountBalances;

  /// Transactions flagged needs_review or duplicate_suspect.
  final int needsReviewCount;

  /// Messages stored raw because no parser understood them.
  final int failedCaptureCount;

  /// Stored label, `DD/MM/YYYY – DD/MM/YYYY`.
  String get periodLabel => budgetPeriod?.label ?? '';

  /// The same window in prose — `1 – 31 Jul` or `1 Jul – 4 Aug` when it
  /// straddles a month boundary. The stored label is machine output and
  /// reads badly in a sentence, which is what the greeting needs.
  String get periodDisplayLabel {
    final period = budgetPeriod;
    if (period == null) return '';
    final start = Iso.toDateTime(period.startAt).toLocal();
    final endInclusive = Iso.toDateTime(
      period.endAt,
    ).toLocal().subtract(const Duration(days: 1));

    final startDay = DateFormat('d').format(start);
    final endDay = DateFormat('d MMM').format(endInclusive);
    if (start.month == endInclusive.month && start.year == endInclusive.year) {
      return '$startDay – $endDay';
    }
    return '${DateFormat('d MMM').format(start)} – $endDay';
  }

  /// Whole days left in the period, counting today. Zero once the
  /// period has ended.
  int get daysLeft {
    final period = budgetPeriod;
    if (period == null) return 0;
    final end = Iso.toDateTime(period.endAt).toLocal();
    final today = DateTime.now();
    final midnightToday = DateTime(today.year, today.month, today.day);
    final endDay = DateTime(end.year, end.month, end.day);
    final difference = endDay.difference(midnightToday).inDays;
    return difference < 0 ? 0 : difference;
  }

  bool get isCurrentPeriod {
    final period = budgetPeriod;
    if (period == null) return false;
    final now = DateTime.now().toUtc();
    return now.isAfter(Iso.toDateTime(period.startAt)) &&
        now.isBefore(Iso.toDateTime(period.endAt));
  }

  bool get hasIncome => incomeCategories.isNotEmpty;

  int get totalIncomeMinor => incomeCategories.fold(
    0,
    (sum, category) => sum + category.budgetedAmountMinor!,
  );

  /// An explicit budget beats planned income as the thing spend is
  /// measured against — income is only a stand-in for someone who has
  /// not set a budget yet. Before this the bar always used income, so
  /// a user who had set a real budget saw it ignored here while
  /// Budgets showed it.
  PlanSource get planSource {
    if (budgetPeriod?.hasOverallBudget ?? false) return PlanSource.overallBudget;
    if (hasIncome && totalIncomeMinor > 0) return PlanSource.income;
    return PlanSource.none;
  }

  /// What [totalSpent] is measured against, or null when nothing is.
  int? get planMinor => switch (planSource) {
    PlanSource.overallBudget => budgetPeriod!.overallAmountMinor,
    PlanSource.income => totalIncomeMinor,
    PlanSource.none => null,
  };

  bool get hasPlan => planMinor != null;

  /// Positive when there is money left, negative when overspent.
  int get remainingMinor => (planMinor ?? 0) - totalSpent;

  bool get isOverPlan => hasPlan && totalSpent > planMinor!;

  /// Fraction of the plan spent, 0..1+. Zero when there is no plan.
  double get planRatio {
    final plan = planMinor;
    if (plan == null || plan == 0) return 0;
    return totalSpent / plan;
  }

  int get pendingReviewCount => needsReviewCount + failedCaptureCount;

  /// Total across every account, ledger-derived.
  int get totalBalanceMinor =>
      accountBalances.values.fold(0, (sum, value) => sum + value);

  /// Total length of the period in whole days.
  int get periodLengthDays {
    final period = budgetPeriod;
    if (period == null) return 0;
    final start = Iso.toDateTime(period.startAt).toLocal();
    final end = Iso.toDateTime(period.endAt).toLocal();
    final days = DateTime(
      end.year,
      end.month,
      end.day,
    ).difference(DateTime(start.year, start.month, start.day)).inDays;
    return days <= 0 ? 1 : days;
  }

  /// How far through the period we are, 0..1.
  double get elapsedFraction {
    if (!isCurrentPeriod) return 1;
    final elapsed = periodLengthDays - daysLeft;
    return (elapsed / periodLengthDays).clamp(0.0, 1.0);
  }

  /// What a perfectly even spender would have spent by now.
  ///
  /// The honest comparison for "am I okay?" — a raw total answers
  /// "what have I spent", which on day 2 of the month is alarming for
  /// no reason and on day 28 is reassuring for no reason.
  int? get expectedSpendMinor {
    final plan = planMinor;
    if (plan == null) return null;
    return (plan * elapsedFraction).round();
  }

  /// Spend minus the even-pace expectation. Positive means spending
  /// faster than the period can carry.
  int? get paceDeltaMinor {
    final expected = expectedSpendMinor;
    if (expected == null) return null;
    return totalSpent - expected;
  }

  /// What is left, spread over the days that remain — the number that
  /// actually informs the next decision, rather than reporting history.
  int? get dailyAllowanceMinor {
    final plan = planMinor;
    if (plan == null || !isCurrentPeriod) return null;
    final left = plan - totalSpent;
    if (left <= 0) return 0;
    // daysLeft counts whole days remaining; today still counts as one
    // to spend in, so a period ending tomorrow allows one day, not zero.
    final days = daysLeft <= 0 ? 1 : daysLeft;
    return left ~/ days;
  }

  /// Verdict on pace, tolerant of small drift so the app is not
  /// permanently scolding someone who is a few kwacha out.
  PaceVerdict get paceVerdict {
    final delta = paceDeltaMinor;
    final plan = planMinor;
    if (delta == null || plan == null || plan == 0) return PaceVerdict.none;
    if (!isCurrentPeriod) return PaceVerdict.none;
    // Inside 5% of the plan either way reads as "on track".
    final tolerance = (plan * 0.05).round();
    if (delta > tolerance) return PaceVerdict.fast;
    if (delta < -tolerance) return PaceVerdict.slow;
    return PaceVerdict.onTrack;
  }

  DashboardState copyWith({
    BudgetPeriod? budgetPeriod,
    DashboardStatus? status,
    List<Category>? incomeCategories,
    int? totalSpent,
    List<CategorySpend>? topCategories,
    Map<String, Category>? categoriesById,
    List<Transaction>? recentTransactions,
    List<Account>? accounts,
    Map<String, int>? accountBalances,
    int? needsReviewCount,
    int? failedCaptureCount,
  }) {
    return DashboardState(
      budgetPeriod: budgetPeriod ?? this.budgetPeriod,
      status: status ?? this.status,
      incomeCategories: incomeCategories ?? this.incomeCategories,
      totalSpent: totalSpent ?? this.totalSpent,
      topCategories: topCategories ?? this.topCategories,
      categoriesById: categoriesById ?? this.categoriesById,
      recentTransactions: recentTransactions ?? this.recentTransactions,
      accounts: accounts ?? this.accounts,
      accountBalances: accountBalances ?? this.accountBalances,
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
    categoriesById,
    recentTransactions,
    accounts,
    accountBalances,
    needsReviewCount,
    failedCaptureCount,
  ];
}
