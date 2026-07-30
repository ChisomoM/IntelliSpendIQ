import 'package:equatable/equatable.dart';

/// The month's overall spending budget — separate from per-category
/// [Budget] limits, which allocate under this total rather than
/// defining it.
class OverallBudget extends Equatable {
  const OverallBudget({
    required this.id,
    required this.period,
    required this.amountMinor,
    this.carryOver = true,
  });

  final String id;

  /// Month key, `YYYY-MM`.
  final String period;

  /// Total monthly budget in ngwee.
  final int amountMinor;

  /// Whether next month defaults from this one.
  final bool carryOver;

  @override
  List<Object?> get props => [id, period, amountMinor, carryOver];
}
