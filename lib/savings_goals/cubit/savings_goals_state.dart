part of 'savings_goals_cubit.dart';

enum SavingsGoalsStatus { initial, loading, loaded, invalid }

class SavingsGoalsState extends Equatable {
  const SavingsGoalsState({
    this.status = SavingsGoalsStatus.initial,
    this.goals = const [],
    this.saved = const {},
    this.accounts = const [],
    this.errorMessage,
  });

  final SavingsGoalsStatus status;
  final List<SavingsGoal> goals;

  /// Each goal's live saved total — see
  /// `SavingsGoalRepository.watchSaved`. A goal missing here (before the
  /// first emission arrives) reads as zero via [savedFor].
  final Map<String, int> saved;
  final List<Account> accounts;
  final String? errorMessage;

  bool get isEmpty => status == SavingsGoalsStatus.loaded && goals.isEmpty;

  int savedFor(String goalId) => saved[goalId] ?? 0;

  List<SavingsGoal> get active =>
      goals.where((g) => g.status == GoalStatus.active).toList();

  SavingsGoalsState copyWith({
    SavingsGoalsStatus? status,
    List<SavingsGoal>? goals,
    Map<String, int>? saved,
    List<Account>? accounts,
    String? errorMessage,
  }) {
    return SavingsGoalsState(
      status: status ?? this.status,
      goals: goals ?? this.goals,
      saved: saved ?? this.saved,
      accounts: accounts ?? this.accounts,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, goals, saved, accounts, errorMessage];
}
