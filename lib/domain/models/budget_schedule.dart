import 'package:equatable/equatable.dart';
import 'package:intellispendiq/domain/models/enums.dart';

/// The user's repeating budget-cycle rule. Generates [BudgetPeriod]
/// instances; amounts live on those instances, not here.
class BudgetSchedule extends Equatable {
  const BudgetSchedule({
    required this.id,
    required this.cadence,
    this.anchorDay,
    this.anchorDate,
    this.startWeekday,
  });

  final String id;
  final BudgetCadence cadence;

  /// Day of month for [BudgetCadence.payday] (1–31; clamped on short months).
  final int? anchorDay;

  /// Local calendar date (`YYYY-MM-DD`) anchor for biweekly / 4-weekly
  /// cycles — the start of a known period.
  final String? anchorDate;

  /// `DateTime.monday`…`sunday` for [BudgetCadence.weekly].
  final int? startWeekday;

  @override
  List<Object?> get props => [id, cadence, anchorDay, anchorDate, startWeekday];
}
