part of 'savings_goal_detail_cubit.dart';

enum SavingsGoalDetailStatus { initial, loading, loaded, invalid, notFound }

class SavingsGoalDetailState extends Equatable {
  const SavingsGoalDetailState({
    required this.goalId,
    this.status = SavingsGoalDetailStatus.initial,
    this.goal,
    this.savedMinor = 0,
    this.entries = const [],
    this.accounts = const [],
    this.categories = const [],
    this.errorMessage,
  });

  final String goalId;
  final SavingsGoalDetailStatus status;
  final SavingsGoal? goal;

  /// This goal's live saved total — contributions minus withdrawals.
  final int savedMinor;
  final List<SavingsGoalEntry> entries;
  final List<Account> accounts;
  final List<Category> categories;
  final String? errorMessage;

  int get remainingMinor {
    final goal = this.goal;
    if (goal == null) return 0;
    final remaining = goal.targetMinor - savedMinor;
    return remaining > 0 ? remaining : 0;
  }

  double get progress {
    final goal = this.goal;
    if (goal == null || goal.targetMinor <= 0) return 0;
    return savedMinor / goal.targetMinor;
  }

  Map<String, String> get accountNames => {
    for (final account in accounts) account.id: account.name,
  };

  SavingsGoalDetailState copyWith({
    SavingsGoalDetailStatus? status,
    SavingsGoal? goal,
    int? savedMinor,
    List<SavingsGoalEntry>? entries,
    List<Account>? accounts,
    List<Category>? categories,
    String? errorMessage,
  }) {
    return SavingsGoalDetailState(
      goalId: goalId,
      status: status ?? this.status,
      goal: goal ?? this.goal,
      savedMinor: savedMinor ?? this.savedMinor,
      entries: entries ?? this.entries,
      accounts: accounts ?? this.accounts,
      categories: categories ?? this.categories,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [
    goalId,
    status,
    goal,
    savedMinor,
    entries,
    accounts,
    categories,
    errorMessage,
  ];
}
