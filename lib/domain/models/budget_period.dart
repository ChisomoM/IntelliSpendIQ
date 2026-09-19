import 'package:equatable/equatable.dart';
import 'package:intellispendiq/domain/models/enums.dart';

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
    this.budgetSource = BudgetSource.manual,
  });

  final String id;
  final String scheduleId;

  /// Inclusive start, UTC ISO-8601.
  final String startAt;

  /// Exclusive end, UTC ISO-8601.
  final String endAt;

  /// Display label using `DD/MM/YYYY – DD/MM/YYYY`.
  final String label;

  /// Total spending plan for this period, in ngwee. Null = not set. When
  /// [budgetSource] isn't manual, this holds the last computed figure.
  final int? overallAmountMinor;

  /// Whether the next period should default from this one's plan.
  final bool carryOver;

  /// Whether [overallAmountMinor] is set by hand or derived from this
  /// period's income.
  final BudgetSource budgetSource;

  bool get hasOverallBudget =>
      overallAmountMinor != null && overallAmountMinor! > 0;

  bool get isIncomeDerived => budgetSource != BudgetSource.manual;

  @override
  List<Object?> get props => [
    id,
    scheduleId,
    startAt,
    endAt,
    label,
    overallAmountMinor,
    carryOver,
    budgetSource,
  ];
}
