import 'package:equatable/equatable.dart';

/// One concrete budget window — half-open `[startAt, endAt)` in UTC ISO.
/// Overall plan amount and carry-forward live here; category envelopes
/// are in [CategoryBudget] rows keyed by [id].
class BudgetPeriod extends Equatable {
  const BudgetPeriod({
    required this.id,
    required this.scheduleId,
    required this.startAt,
    required this.endAt,
    required this.label,
    this.overallAmountMinor,
    this.carryOver = true,
  });

  final String id;
  final String scheduleId;

  /// Inclusive start, UTC ISO-8601.
  final String startAt;

  /// Exclusive end, UTC ISO-8601.
  final String endAt;

  /// Display label using `DD/MM/YYYY – DD/MM/YYYY`.
  final String label;

  /// Total spending plan for this period, in ngwee. Null = not set.
  final int? overallAmountMinor;

  /// Whether the next period should default from this one's plan.
  final bool carryOver;

  bool get hasOverallBudget =>
      overallAmountMinor != null && overallAmountMinor! > 0;

  @override
  List<Object?> get props => [
    id,
    scheduleId,
    startAt,
    endAt,
    label,
    overallAmountMinor,
    carryOver,
  ];
}
