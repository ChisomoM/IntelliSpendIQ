part of 'reports_cubit.dart';

enum ReportsStatus { initial, loading, loaded }

/// Which dimension the donut chart and legend break spend down by.
enum ReportsBreakdown { category, account }

class ReportsState extends Equatable {
  const ReportsState({
    required this.period,
    this.status = ReportsStatus.initial,
    this.rows = const [],
    this.accountRows = const [],
    this.dailySpend = const [],
    this.monthTrend = const [],
    this.breakdown = ReportsBreakdown.category,
  });

  final ReportsStatus status;

  /// Month key, `YYYY-MM`.
  final String period;
  final List<CategorySpend> rows;
  final List<AccountSpend> accountRows;

  /// Confirmed debit spend per local day within [period], for the
  /// calendar heatmap.
  final List<DailySpend> dailySpend;

  /// Confirmed debit total for each of the trailing 6 months ending
  /// with [period], oldest first.
  final List<MonthSpend> monthTrend;
  final ReportsBreakdown breakdown;

  bool get isEmpty => status == ReportsStatus.loaded && rows.isEmpty;

  /// Total confirmed spend for the month, in ngwee.
  int get totalMinor => rows.fold(0, (sum, row) => sum + row.spentMinor);

  /// Largest single category, used to scale the bars.
  int get largestMinor => rows.isEmpty ? 0 : rows.first.spentMinor;

  double shareOf(CategorySpend row) =>
      totalMinor == 0 ? 0 : row.spentMinor / totalMinor;

  double barWidthOf(CategorySpend row) =>
      largestMinor == 0 ? 0 : row.spentMinor / largestMinor;

  double accountShareOf(AccountSpend row) =>
      totalMinor == 0 ? 0 : row.spentMinor / totalMinor;

  /// Largest single account, used to scale the account bars.
  int get largestAccountMinor =>
      accountRows.isEmpty ? 0 : accountRows.first.spentMinor;

  double accountBarWidthOf(AccountSpend row) =>
      largestAccountMinor == 0 ? 0 : row.spentMinor / largestAccountMinor;

  /// Largest single day's spend, used to scale the heatmap's shading.
  int get maxDailyMinor => dailySpend.isEmpty
      ? 0
      : dailySpend.map((d) => d.spentMinor).reduce((a, b) => a > b ? a : b);

  /// Confirmed spend on [day], or null if nothing was recorded.
  int? spendOn(DateTime day) {
    for (final entry in dailySpend) {
      if (entry.date.year == day.year &&
          entry.date.month == day.month &&
          entry.date.day == day.day) {
        return entry.spentMinor;
      }
    }
    return null;
  }

  ReportsState copyWith({
    ReportsStatus? status,
    String? period,
    List<CategorySpend>? rows,
    List<AccountSpend>? accountRows,
    List<DailySpend>? dailySpend,
    List<MonthSpend>? monthTrend,
    ReportsBreakdown? breakdown,
  }) {
    return ReportsState(
      status: status ?? this.status,
      period: period ?? this.period,
      rows: rows ?? this.rows,
      accountRows: accountRows ?? this.accountRows,
      dailySpend: dailySpend ?? this.dailySpend,
      monthTrend: monthTrend ?? this.monthTrend,
      breakdown: breakdown ?? this.breakdown,
    );
  }

  @override
  List<Object?> get props => [
    status,
    period,
    rows,
    accountRows,
    dailySpend,
    monthTrend,
    breakdown,
  ];
}
