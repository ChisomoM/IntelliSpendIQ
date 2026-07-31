part of 'budget_cycle_cubit.dart';

enum BudgetCycleStatus { initial, loading, loaded, saving }

class BudgetCycleState extends Equatable {
  const BudgetCycleState({
    this.status = BudgetCycleStatus.initial,
    this.schedule,
    this.savedMessage,
  });

  final BudgetCycleStatus status;
  final BudgetSchedule? schedule;
  final String? savedMessage;

  BudgetCycleState copyWith({
    BudgetCycleStatus? status,
    BudgetSchedule? schedule,
    String? savedMessage,
  }) {
    return BudgetCycleState(
      status: status ?? this.status,
      schedule: schedule ?? this.schedule,
      savedMessage: savedMessage,
    );
  }

  @override
  List<Object?> get props => [status, schedule, savedMessage];
}
