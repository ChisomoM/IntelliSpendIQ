import 'package:equatable/equatable.dart';

/// Display helper for the overall spending plan on a [BudgetPeriod].
/// Prefer [BudgetPeriod.overallAmountMinor] for new code; this type
/// remains for editors and legacy backup JSON.
class OverallBudget extends Equatable {
  const OverallBudget({
    required this.id,
    required this.period,
    required this.amountMinor,
    this.carryOver = true,
  });

  final String id;

  /// Budget period id (or legacy `YYYY-MM` in old backups).
  final String period;

  /// Total monthly budget in ngwee.
  final int amountMinor;

  /// Whether next month defaults from this one.
  final bool carryOver;

  @override
  List<Object?> get props => [id, period, amountMinor, carryOver];
}
