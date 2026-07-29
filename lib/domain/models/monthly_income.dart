import 'package:equatable/equatable.dart';

/// Declared income for one month, used to track overall spend against
/// it rather than just per-category budget limits.
class MonthlyIncome extends Equatable {
  const MonthlyIncome({
    required this.id,
    required this.period,
    required this.amountMinor,
  });

  final String id;

  /// Month key, `YYYY-MM`.
  final String period;

  /// Declared income in ngwee.
  final int amountMinor;

  @override
  List<Object?> get props => [id, period, amountMinor];
}
