part of 'reports_cubit.dart';

enum ReportsStatus { initial, loading, loaded }

class ReportsState extends Equatable {
  const ReportsState({
    required this.period,
    this.status = ReportsStatus.initial,
    this.rows = const [],
  });

  final ReportsStatus status;

  /// Month key, `YYYY-MM`.
  final String period;
  final List<CategorySpend> rows;

  bool get isEmpty => status == ReportsStatus.loaded && rows.isEmpty;

  /// Total confirmed spend for the month, in ngwee.
  int get totalMinor => rows.fold(0, (sum, row) => sum + row.spentMinor);

  /// Largest single category, used to scale the bars.
  int get largestMinor => rows.isEmpty ? 0 : rows.first.spentMinor;

  double shareOf(CategorySpend row) =>
      totalMinor == 0 ? 0 : row.spentMinor / totalMinor;

  double barWidthOf(CategorySpend row) =>
      largestMinor == 0 ? 0 : row.spentMinor / largestMinor;

  ReportsState copyWith({
    ReportsStatus? status,
    String? period,
    List<CategorySpend>? rows,
  }) {
    return ReportsState(
      status: status ?? this.status,
      period: period ?? this.period,
      rows: rows ?? this.rows,
    );
  }

  @override
  List<Object?> get props => [status, period, rows];
}
